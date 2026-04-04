// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';

const String kBaseUrl = 'http://127.0.0.1:5000';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

// ─────────────────────────── DATA MODELS ──────────────────────────────────
class ChatMessage {
  final String text;
  final bool isUser;
  final bool isVoice;
  final String? audioUrl;
  final bool isLoading;

  const ChatMessage({
    required this.text,
    required this.isUser,
    this.isVoice = false,
    this.audioUrl,
    this.isLoading = false,
  });

  ChatMessage copyWith({
    String? text,
    bool? isUser,
    bool? isVoice,
    String? audioUrl,
    bool? isLoading,
  }) {
    return ChatMessage(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      isVoice: isVoice ?? this.isVoice,
      audioUrl: audioUrl ?? this.audioUrl,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class HistoryEntry {
  final String userText;
  final String aiText;
  final DateTime timestamp;

  HistoryEntry({
    required this.userText,
    required this.aiText,
    required this.timestamp,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    DateTime ts;
    try {
      ts = DateTime.parse(json['timestamp'] as String);
    } catch (_) {
      ts = DateTime.now();
    }
    return HistoryEntry(
      userText: json['user'] as String? ?? '',
      aiText: json['ai'] as String? ?? '',
      timestamp: ts,
    );
  }
}

enum CallState { idle, listening, processing, speaking }

// ─────────────────────────── APP ROOT ─────────────────────────────────────
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MediGuide Assistant',
      theme: _buildTheme(),
      home: const ChatScreen(),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0D0D0D),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF00E5C8),
        secondary: Color(0xFF7B61FF),
        surface: Color(0xFF1A1A1A),
        onSurface: Colors.white,
      ),
      fontFamily: 'sans-serif',
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0D0D0D),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white70),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: Color(0xFF111111),
      ),
    );
  }
}

// ─────────────────────────── MAIN CHAT SCREEN ─────────────────────────────
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isCallMode = false;
  CallState _callState = CallState.idle;
  bool _isHistoryLoading = false;
  List<HistoryEntry> _historyEntries = [];

  Timer? _silenceTimer;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  StreamSubscription<void>? _playerCompleteSubscription;

  // Waveform animation
  late AnimationController _waveController;
  final List<double> _waveBars = List.generate(18, (i) => 0.2);
  Timer? _waveTimer;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (_isCallMode && mounted) {
        setState(() => _callState = CallState.idle);
        _startListeningForVoice();
      }
    });

    _loadHistoryIntoChat();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _silenceTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _waveController.dispose();
    _waveTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Scroll ──────────────────────────────────────────────────────────────
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

  // ── History Loading ──────────────────────────────────────────────────────
  Future<void> _loadHistoryIntoChat() async {
    try {
      final res = await http.get(Uri.parse('$kBaseUrl/chat/history'));
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        if (data.isNotEmpty && mounted) {
          setState(() {
            _messages.clear();
            for (final item in data) {
              final userTxt = item['user'] as String? ?? '';
              final aiTxt = item['ai'] as String? ?? '';
              if (userTxt.isNotEmpty) {
                _messages.add(ChatMessage(text: userTxt, isUser: true));
              }
              if (aiTxt.isNotEmpty) {
                _messages.add(ChatMessage(text: aiTxt, isUser: false));
              }
            }
          });
          Future.delayed(const Duration(milliseconds: 120), _scrollToBottom);
        } else {
          _addWelcomeMessage();
        }
      } else {
        _addWelcomeMessage();
      }
    } catch (_) {
      _addWelcomeMessage();
    }
  }

  Future<void> _loadDrawerHistory() async {
    setState(() => _isHistoryLoading = true);
    try {
      final res = await http.get(Uri.parse('$kBaseUrl/chat/history'));
      if (res.statusCode == 200 && mounted) {
        final List<dynamic> data = jsonDecode(res.body);
        setState(() {
          _historyEntries =
              data.map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>)).toList();
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isHistoryLoading = false);
    }
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.add(const ChatMessage(
        text: "Hello! I'm MediGuide, your personal health assistant. How can I help you today? You can type or use voice call mode to speak with me.",
        isUser: false,
      ));
    });
  }

  void _loadConversationFromHistory(HistoryEntry entry) {
    Navigator.of(context).pop(); // close drawer
    setState(() {
      _messages.add(ChatMessage(text: entry.userText, isUser: true));
      _messages.add(ChatMessage(text: entry.aiText, isUser: false));
    });
    _scrollToBottom();
  }

  // ── Waveform Animation ───────────────────────────────────────────────────
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

  // ── Voice Call Mode ──────────────────────────────────────────────────────
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
    _silenceTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _audioRecorder.stop();
    _audioPlayer.stop();
    _stopWaveAnimation();
    setState(() {
      _isCallMode = false;
      _callState = CallState.idle;
    });
  }

  Future<void> _startListeningForVoice() async {
    if (!_isCallMode || !mounted) return;
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied.')),
          );
          _endCallMode();
        }
        return;
      }

      String path = '';
      if (!kIsWeb) {
        final dir = await getTemporaryDirectory();
        path = '${dir.path}/mg_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      }

      await _audioRecorder.start(const RecordConfig(), path: path);
      if (!mounted) return;
      setState(() => _callState = CallState.listening);
      _startWaveAnimation();

      _silenceTimer?.cancel();
      _amplitudeSubscription?.cancel();

      bool speechDetected = false;

      _amplitudeSubscription = _audioRecorder
          .onAmplitudeChanged(const Duration(milliseconds: 150))
          .listen((amp) {
        if (amp.current > -28.0) {
          speechDetected = true;
          _silenceTimer?.cancel();
          _silenceTimer = Timer(const Duration(milliseconds: 1800), () {
            if (_callState == CallState.listening && speechDetected) {
              _stopListeningAndSend();
            }
          });
        }
      });

      // Auto-timeout if no speech after 8s
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted && _callState == CallState.listening && !speechDetected) {
          _stopListeningAndSend();
        }
      });
    } catch (e) {
      debugPrint('[Voice] Error starting recording: $e');
      if (mounted) _endCallMode();
    }
  }

  Future<void> _stopListeningAndSend() async {
    _silenceTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _stopWaveAnimation();

    try {
      final path = await _audioRecorder.stop();
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

  // ── Message Sending ──────────────────────────────────────────────────────
  Future<void> _sendTextMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    setState(() => _messages.add(ChatMessage(text: text, isUser: true)));
    _scrollToBottom();

    // Show loading bubble
    setState(() => _messages.add(const ChatMessage(text: '', isUser: false, isLoading: true)));
    _scrollToBottom();

    try {
      final res = await http.post(
        Uri.parse('$kBaseUrl/chat/text'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': text}),
      );

      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final reply = data['reply'] as String? ?? 'Sorry, I could not process that.';
      final audioUrl = data['audio_url'] as String?;

      setState(() {
        // Replace loading bubble
        _messages.removeLast();
        _messages.add(ChatMessage(text: reply, isUser: false, audioUrl: audioUrl));
      });
      _scrollToBottom();

      // Optionally auto-play in non-call text mode
      if (audioUrl != null) {
        await _audioPlayer.play(UrlSource(audioUrl));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeLast();
        _messages.add(const ChatMessage(
          text: '⚠️ Could not reach the server. Make sure the backend is running.',
          isUser: false,
        ));
      });
      _scrollToBottom();
    }
  }

  Future<void> _sendVoiceMessage(String audioFilePath) async {
    // Add placeholder
    setState(() {
      _messages.add(const ChatMessage(text: '🎤 Processing voice…', isUser: true, isVoice: true));
      _messages.add(const ChatMessage(text: '', isUser: false, isLoading: true));
    });
    _scrollToBottom();

    try {
      final request =
          http.MultipartRequest('POST', Uri.parse('$kBaseUrl/chat/voice'));

      if (kIsWeb) {
        final byteRes = await http.get(Uri.parse(audioFilePath));
        request.files.add(http.MultipartFile.fromBytes(
          'audio',
          byteRes.bodyBytes,
          filename: 'audio.m4a',
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath('audio', audioFilePath));
      }

      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);

      if (!mounted) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final transcription = data['transcription'] as String? ?? '(voice)';
      final reply = data['reply'] as String? ?? 'Sorry, I could not process that.';
      final audioUrl = data['audio_url'] as String?;

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
        _messages.add(ChatMessage(text: reply, isUser: false, audioUrl: audioUrl));
      });
      _scrollToBottom();

      if (audioUrl != null && _isCallMode && mounted) {
        setState(() => _callState = CallState.speaking);
        await _audioPlayer.play(UrlSource(audioUrl));
        // _playerCompleteSubscription handles re-listen
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

  Future<void> _replayAudio(String url) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
    } catch (_) {}
  }

  // ── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF0D0D0D),
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            const Divider(height: 1, color: Color(0xFF222222)),
            Expanded(
              child: _messages.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      itemCount: _messages.length,
                      itemBuilder: (ctx, i) => _buildMessageBubble(_messages[i]),
                    ),
            ),
            _buildCallOverlay(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  // ── Top Bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              _loadDrawerHistory();
              _scaffoldKey.currentState?.openDrawer();
            },
            icon: const Icon(Icons.menu_rounded, color: Colors.white70, size: 22),
            tooltip: 'Chat History',
          ),
          const SizedBox(width: 4),
          // App name + model badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MediGuide',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00E5C8),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Local SLM · Private & Offline',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isCallMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B3B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFF3B3B).withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF3B3B),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Color(0xFFFF3B3B),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Drawer / History ───────────────────────────────────────────────────────
  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 20),
            decoration: const BoxDecoration(
              color: Color(0xFF111111),
              border: Border(bottom: BorderSide(color: Color(0xFF1E1E1E))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00E5C8), Color(0xFF7B61FF)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.medical_services_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'MediGuide',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Recent Conversations',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // History list
          Expanded(
            child: _isHistoryLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF00E5C8),
                      strokeWidth: 2,
                    ),
                  )
                : _historyEntries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded,
                                color: Colors.white12, size: 48),
                            const SizedBox(height: 12),
                            const Text(
                              'No history yet.\nStart a conversation!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white38, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _historyEntries.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Color(0xFF1A1A1A)),
                        itemBuilder: (ctx, i) {
                          // Show newest first in drawer
                          final entry =
                              _historyEntries[_historyEntries.length - 1 - i];
                          return _buildHistoryTile(entry);
                        },
                      ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF1E1E1E))),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white24, size: 14),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Showing last 10 conversations',
                    style: TextStyle(color: Colors.white24, fontSize: 11),
                  ),
                ),
                GestureDetector(
                  onTap: _loadDrawerHistory,
                  child: const Icon(Icons.refresh_rounded,
                      color: Color(0xFF00E5C8), size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTile(HistoryEntry entry) {
    final timeStr = DateFormat('MMM d, h:mm a').format(entry.timestamp.toLocal());
    final preview = entry.userText.length > 60
        ? '${entry.userText.substring(0, 60)}…'
        : entry.userText;

    return InkWell(
      onTap: () => _loadConversationFromHistory(entry),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: const Icon(Icons.person_rounded,
                  color: Color(0xFF00E5C8), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preview,
                    style: const TextStyle(
                        color: Color(0xDEFFFFFF),
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    timeStr,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00E5C8), Color(0xFF7B61FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.medical_services_rounded,
                color: Colors.white, size: 40),
          ),
          const SizedBox(height: 20),
          const Text(
            'MediGuide',
            style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your personal health assistant.\nType or speak to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 15, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ── Message Bubble ──────────────────────────────────────────────────────────
  Widget _buildMessageBubble(ChatMessage msg) {
    if (msg.isLoading) return _buildLoadingBubble();

    final isEmergency = !msg.isUser &&
        (msg.text.toUpperCase().contains('EMERGENCY') ||
            msg.text.toUpperCase().contains('IMMEDIATELY') ||
            msg.text.toUpperCase().contains('CALL 112') ||
            msg.text.toUpperCase().contains('CALL 108'));

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: msg.isUser ? _buildUserBubble(msg) : _buildAiBubble(msg, isEmergency),
    );
  }

  Widget _buildUserBubble(ChatMessage msg) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (msg.isVoice) ...[
              const Icon(Icons.mic_rounded, color: Color(0xFF00E5C8), size: 14),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                msg.text,
                style: const TextStyle(
                    color: Colors.white, fontSize: 15, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiBubble(ChatMessage msg, bool isEmergency) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Avatar
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 10, top: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00E5C8), Color(0xFF7B61FF)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.medical_services_rounded,
                color: Colors.white, size: 17),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isEmergency)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B3B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: const Color(0xFFFF3B3B).withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Color(0xFFFF3B3B), size: 14),
                        SizedBox(width: 5),
                        Text('EMERGENCY ADVICE',
                            style: TextStyle(
                                color: Color(0xFFFF3B3B),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                Text(
                  msg.text,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, height: 1.6),
                ),
                const SizedBox(height: 10),
                // Action row
                Row(
                  children: [
                    _actionIcon(Icons.content_copy_rounded, () {
                      Clipboard.setData(ClipboardData(text: msg.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copied to clipboard'),
                          duration: Duration(seconds: 1),
                          backgroundColor: Color(0xFF1E1E1E),
                        ),
                      );
                    }),
                    const SizedBox(width: 16),
                    _actionIcon(Icons.thumb_up_alt_outlined, () {}),
                    const SizedBox(width: 16),
                    _actionIcon(Icons.thumb_down_alt_outlined, () {}),
                    if (msg.audioUrl != null) ...[
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => _replayAudio(msg.audioUrl!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5C8).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFF00E5C8).withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.volume_up_rounded,
                                  color: Color(0xFF00E5C8), size: 14),
                              SizedBox(width: 4),
                              Text('Play',
                                  style: TextStyle(
                                      color: Color(0xFF00E5C8),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, size: 16, color: Colors.white30),
    );
  }

  Widget _buildLoadingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 10, top: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00E5C8), Color(0xFF7B61FF)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.medical_services_rounded,
                color: Colors.white, size: 17),
          ),
          TypingIndicator(),
        ],
      ),
    );
  }

  // ── Call Overlay (shown above input bar when in call mode) ─────────────────
  Widget _buildCallOverlay() {
    if (!_isCallMode) return const SizedBox.shrink();

    final stateLabel = switch (_callState) {
      CallState.listening => 'Listening…',
      CallState.processing => 'Thinking…',
      CallState.speaking => 'Speaking…',
      CallState.idle => 'Ready',
    };

    final stateColor = switch (_callState) {
      CallState.listening => const Color(0xFF00E5C8),
      CallState.processing => const Color(0xFF7B61FF),
      CallState.speaking => const Color(0xFFFF9500),
      CallState.idle => Colors.white38,
    };

    return Container(
      color: const Color(0xFF0D0D0D),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Waveform bars (only during listening)
          if (_callState == CallState.listening)
            SizedBox(
              height: 50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(_waveBars.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 4,
                    height: 8 + _waveBars[i] * 42,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5C8)
                          .withValues(alpha: 0.5 + _waveBars[i] * 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),

          if (_callState == CallState.processing ||
              _callState == CallState.speaking)
            SizedBox(
            height: 50,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: stateColor,
                ),
              ),
            ),

          if (_callState == CallState.idle)
            const SizedBox(height: 50),

          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: stateColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                stateLabel,
                style: TextStyle(
                  color: stateColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // End call button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _endCallMode,
              icon: const Icon(Icons.call_end_rounded, size: 18),
              label: const Text('End Voice Call'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B3B).withValues(alpha: 0.85),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Input Bar ─────────────────────────────────────────────────────────────
  Widget _buildInputBar() {
    if (_isCallMode) return const SizedBox.shrink();

    return Container(
      color: const Color(0xFF0D0D0D),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: 'Message MediGuide…',
                      hintStyle: TextStyle(color: Colors.white30),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    onSubmitted: (_) => _sendTextMessage(),
                    keyboardType: TextInputType.multiline,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                  ),
                ),
                // Mic button → starts voice call mode
                IconButton(
                  onPressed: _toggleCallMode,
                  tooltip: 'Voice call mode',
                  icon: const Icon(Icons.mic_none_rounded,
                      color: Colors.white54, size: 22),
                ),
                // Send button
                SendButton(onTap: _sendTextMessage, controller: _controller),
                const SizedBox(width: 4),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'MediGuide is AI-powered and can make mistakes. Always consult a qualified doctor for medical decisions.',
            style: TextStyle(color: Colors.white24, fontSize: 10.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── TYPING INDICATOR ────────────────────────────────
class TypingIndicator extends StatefulWidget {
  @override
  State<TypingIndicator> createState() => TypingIndicatorState();
}

class TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> controllers;
  late List<Animation<double>> anims;

  @override
  void initState() {
    super.initState();
    controllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      )..repeat(reverse: true),
    );
    anims = controllers
        .map((c) => Tween<double>(begin: 0, end: 1).animate(c))
        .toList();
    // Stagger
    Future.delayed(const Duration(milliseconds: 150),
        () => controllers[0].forward());
    Future.delayed(const Duration(milliseconds: 300),
        () => controllers[1].forward());
    Future.delayed(const Duration(milliseconds: 450),
        () => controllers[2].forward());
  }

  @override
  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: anims[i],
            builder: (ctx, child) {
              return Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: Color.lerp(
                    Colors.white30,
                    const Color(0xFF00E5C8),
                    anims[i].value,
                  ),
                  shape: BoxShape.circle,
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

// ─────────────────────────── SEND BUTTON ─────────────────────────────────────
class SendButton extends StatefulWidget {
  final VoidCallback onTap;
  final TextEditingController controller;

  const SendButton({super.key, required this.onTap, required this.controller});

  @override
  State<SendButton> createState() => SendButtonState();
}

class SendButtonState extends State<SendButton> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: _hasText
            ? const LinearGradient(
                colors: [Color(0xFF00E5C8), Color(0xFF7B61FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: _hasText ? null : const Color(0xFF2A2A2A),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: _hasText ? widget.onTap : null,
        icon: Icon(
          Icons.arrow_upward_rounded,
          color: _hasText ? Colors.white : Colors.white30,
          size: 18,
        ),
      ),
    );
  }
}
