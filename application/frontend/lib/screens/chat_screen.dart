// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../services/chat_service.dart';
import '../services/audio_service.dart';
import '../widgets/top_bar.dart';
import '../widgets/chat_drawer.dart';
import '../widgets/message_bubble.dart';
import '../widgets/call_overlay.dart';
import '../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/empty_state.dart';
import '../widgets/input_bar.dart';
import '../widgets/role_switcher_menu.dart';

/// Main chat screen — manages conversation state, messaging, and voice calls.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final AudioService _audioService = AudioService();

  String? _currentConversationId;
  List<Conversation> _conversations = [];
  bool _isConversationsLoading = false;

  bool _isCallMode = false;
  CallState _callState = CallState.idle;

  // Waveform animation
  late AnimationController _waveController;
  final List<double> _waveBars = List.generate(18, (i) => 0.2);
  Timer? _waveTimer;

  // Role Settings
  String _activeRole = 'doctor';
  bool _isRoleMenuOpen = false;
  String _username = 'Guest';
  String _userId = 'local_user';

  @override
  void initState() {
    super.initState();
    _loadRolePreference();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    // When audio playback completes in call mode, resume listening
    _audioService.onPlayerComplete = () {
      if (_isCallMode && mounted) {
        setState(() => _callState = CallState.idle);
        _startListeningForVoice();
      }
    };
  }

  Future<void> _loadRolePreference() async {
    final user = AuthService.currentUser;
    if (user != null) {
      _userId = user.uid;
      _username = user.displayName ?? 'Guest';
      final dbRole = await AuthService.getRole(user.uid);
      if (dbRole != null && dbRole.isNotEmpty && mounted) {
        setState(() {
          _activeRole = dbRole;
        });
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _activeRole = prefs.getString('user_role') ?? 'doctor';
        });
      }
    }
  }

  Future<void> _changeRole(String newRole) async {
    // 1. Sync strictly to Firebase Cloud
    if (_userId != 'local_user') {
      try {
        await AuthService.setRole(_userId, newRole);
      } catch (e) {
        debugPrint('[ChatScreen] Error syncing role to cloud: $e');
      }
    }

    // 2. Fallback local sync
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', newRole);
    
    if (mounted) {
      setState(() {
        _activeRole = newRole;
        _isRoleMenuOpen = false;
      });
    }
  }

  @override
  void dispose() {
    _audioService.dispose();
    _waveController.dispose();
    _waveTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Scroll ────────────────────────────────────────────────────────────────
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Conversation Management ───────────────────────────────────────────────

  /// Load conversations list for the drawer.
  Future<void> _loadConversations() async {
    setState(() => _isConversationsLoading = true);
    try {
      final convs = await ChatService.listConversations();
      if (mounted) {
        setState(() => _conversations = convs);
      }
    } catch (_) {
      // Silently fail — drawer will show empty
    } finally {
      if (mounted) setState(() => _isConversationsLoading = false);
    }
  }

  /// Start a brand new chat — clear messages and reset conversation ID.
  void _startNewChat() {
    setState(() {
      _currentConversationId = null;
      _messages.clear();
    });
    if (_isCallMode) _endCallMode();
  }

  /// Load a specific conversation's messages into the chat area.
  Future<void> _loadConversation(Conversation conv) async {
    if (_isCallMode) _endCallMode();

    setState(() {
      _currentConversationId = conv.id;
      _messages.clear();
      _messages.add(const ChatMessage(text: '', isUser: false, isLoading: true));
    });

    try {
      final msgs = await ChatService.getConversationMessages(conv.id);
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(msgs);
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.add(const ChatMessage(
            text: '⚠️ Could not load this conversation.',
            isUser: false,
          ));
        });
      }
    }
  }

  /// Delete a conversation.
  Future<void> _deleteConversation(Conversation conv) async {
    try {
      await ChatService.deleteConversation(conv.id);
      // If it's the active conversation, start a new chat
      if (_currentConversationId == conv.id) {
        _startNewChat();
      }
      // Refresh the list
      await _loadConversations();
    } catch (_) {}
  }

  // ── Waveform Animation ────────────────────────────────────────────────────
  void _startWaveAnimation() {
    final rand = Random();
    _waveTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (mounted && _callState == CallState.listening) {
        setState(() {
          for (int i = 0; i < _waveBars.length; i++) {
            _waveBars[i] = 0.15 + rand.nextDouble() * 0.85;
          }
        });
      }
    });
  }

  void _stopWaveAnimation() {
    _waveTimer?.cancel();
    if (mounted) {
      setState(() {
        for (int i = 0; i < _waveBars.length; i++) {
          _waveBars[i] = 0.2;
        }
      });
    }
  }

  // ── Voice Call Mode ───────────────────────────────────────────────────────
  void _toggleCallMode() {
    if (_isCallMode) {
      _endCallMode();
    } else {
      setState(() {
        _isCallMode = true;
        _callState = CallState.idle;
      });
      _startListeningForVoice();
    }
  }

  void _endCallMode() {
    _audioService.stopRecording();
    _audioService.stopAudio();
    _stopWaveAnimation();
    setState(() {
      _isCallMode = false;
      _callState = CallState.idle;
    });
  }

  Future<void> _startListeningForVoice() async {
    if (!_isCallMode || !mounted) return;
    try {
      final hasPermission = await _audioService.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied.')),
          );
          _endCallMode();
        }
        return;
      }

      await _audioService.startRecording();
      if (!mounted) return;
      setState(() => _callState = CallState.listening);
      _startWaveAnimation();

      _audioService.listenAmplitude(
        onSilenceTimeout: () {
          if (_callState == CallState.listening) {
            _stopListeningAndSend();
          }
        },
      );
    } catch (e) {
      debugPrint('[Voice] Error starting recording: $e');
      if (mounted) _endCallMode();
    }
  }

  Future<void> _stopListeningAndSend() async {
    _stopWaveAnimation();
    try {
      final path = await _audioService.stopRecording();
      if (!mounted) return;

      if (path != null && path.isNotEmpty) {
        setState(() => _callState = CallState.processing);
        await _sendVoiceMessage(path);
      } else {
        setState(() => _callState = CallState.idle);
        if (_isCallMode) _startListeningForVoice();
      }
    } catch (e) {
      debugPrint('[Voice] Error stopping: $e');
      if (mounted) setState(() => _callState = CallState.idle);
      if (_isCallMode && mounted) _startListeningForVoice();
    }
  }

  // ── Message Sending ───────────────────────────────────────────────────────
  void _sendQuickAction(String text) {
    _controller.text = text;
    _sendTextMessage();
  }

  Future<void> _sendTextMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    setState(() => _messages.add(ChatMessage(text: text, isUser: true)));
    _scrollToBottom();

    // Show loading bubble
    setState(() => _messages
        .add(const ChatMessage(text: '', isUser: false, isLoading: true)));
    _scrollToBottom();

    try {
      final data = await ChatService.sendTextMessage(
        message: text,
        conversationId: _currentConversationId,
        role: _activeRole,
        username: _username,
        userId: _userId,
      );

      if (!mounted) return;
      final reply =
          data['reply'] as String? ?? 'Sorry, I could not process that.';
      final audioUrl = data['audio_url'] as String?;
      final returnedConvId = data['conversation_id'] as String?;

      // Update conversation ID if server created one
      if (_currentConversationId == null && returnedConvId != null) {
        _currentConversationId = returnedConvId;
      }

      setState(() {
        _messages.removeLast(); // Remove loading bubble
        _messages
            .add(ChatMessage(text: reply, isUser: false, audioUrl: audioUrl));
      });
      _scrollToBottom();

      // Auto-play audio response
      if (audioUrl != null) {
        await _audioService.playAudio(audioUrl);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeLast();
        _messages.add(const ChatMessage(
          text:
              '⚠️ Could not reach the server. Make sure the backend is running.',
          isUser: false,
        ));
      });
      _scrollToBottom();
    }
  }

  Future<void> _sendVoiceMessage(String audioFilePath) async {
    // Add placeholder
    setState(() {
      _messages.add(const ChatMessage(
          text: '🎤 Processing voice…', isUser: true, isVoice: true));
      _messages
          .add(const ChatMessage(text: '', isUser: false, isLoading: true));
    });
    _scrollToBottom();

    try {
      final data = await ChatService.sendVoiceMessage(
        audioFilePath: audioFilePath,
        conversationId: _currentConversationId,
        role: _activeRole,
        username: _username,
        userId: _userId,
      );

      if (!mounted) return;
      final transcription = data['transcription'] as String? ?? '(voice)';
      final reply =
          data['reply'] as String? ?? 'Sorry, I could not process that.';
      final audioUrl = data['audio_url'] as String?;
      final returnedConvId = data['conversation_id'] as String?;

      // Update conversation ID if server created one
      if (_currentConversationId == null && returnedConvId != null) {
        _currentConversationId = returnedConvId;
      }

      setState(() {
        // Replace voice placeholder with actual transcription
        final voiceIdx = _messages.lastIndexWhere((m) => m.isUser && m.isVoice);
        if (voiceIdx >= 0) {
          _messages[voiceIdx] = ChatMessage(
            text: transcription,
            isUser: true,
            isVoice: true,
          );
        }
        // Replace loading bubble
        _messages.removeLast();
        _messages
            .add(ChatMessage(text: reply, isUser: false, audioUrl: audioUrl));
      });
      _scrollToBottom();

      if (audioUrl != null && _isCallMode && mounted) {
        setState(() => _callState = CallState.speaking);
        await _audioService.playAudio(audioUrl);
        // onPlayerComplete handles re-listen
      } else if (_isCallMode && mounted) {
        setState(() => _callState = CallState.idle);
        _startListeningForVoice();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeLast();
        _messages.add(const ChatMessage(
          text: '⚠️ Voice processing failed. Please try again.',
          isUser: false,
        ));
        if (_isCallMode) _callState = CallState.idle;
      });
      _scrollToBottom();
      if (_isCallMode && mounted) _startListeningForVoice();
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: kBgColor,
      endDrawer: ChatDrawer(
        conversations: _conversations,
        isLoading: _isConversationsLoading,
        activeConversationId: _currentConversationId,
        onNewChat: _startNewChat,
        onRefresh: _loadConversations,
        onConversationTap: _loadConversation,
        onConversationDelete: _deleteConversation,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                TopBar(
                  onMenuTap: () {
                    _loadConversations();
                    _scaffoldKey.currentState?.openEndDrawer();
                  },
                  onNewChatTap: _startNewChat,
                  isCallMode: _isCallMode,
                  activeRole: _activeRole,
                ),
                const Divider(height: 1, color: kDividerColor),
                Expanded(
                  child: _messages.isEmpty
                      ? EmptyState(onQuickAction: _sendQuickAction)
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          itemCount: _messages.length,
                          itemBuilder: (ctx, i) => MessageBubble(
                            message: _messages[i],
                            onReplayAudio: (url) => _audioService.playAudio(url),
                          ),
                        ),
                ),
                CallOverlay(
                  isCallMode: _isCallMode,
                  callState: _callState,
                  waveBars: _waveBars,
                  onEndCall: _endCallMode,
                ),
                InputBar(
                  isCallMode: _isCallMode,
                  controller: _controller,
                  onSend: _sendTextMessage,
                  onMicTap: _toggleCallMode,
                ),
              ],
            ),
            
            // The popup menu
            Positioned.fill(
              child: RoleSwitcherMenu(
                isOpen: _isRoleMenuOpen,
                activeRole: _activeRole,
                onRoleSelected: _changeRole,
                onTapOutside: () => setState(() => _isRoleMenuOpen = false),
              ),
            ),
            
            // Settings Floating Button
            Positioned(
              bottom: 80,
              right: 16,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: kSurfaceColor,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: kSurfaceBorderColor),
                ),
                child: const Icon(Icons.settings_rounded, color: kPrimaryColor, size: 20),
                onPressed: () {
                  setState(() => _isRoleMenuOpen = !_isRoleMenuOpen);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
