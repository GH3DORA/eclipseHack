import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/constants.dart';
import '../models/chat_message.dart';
import 'typing_indicator.dart';

/// Renders a single message bubble (user or AI).
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final void Function(String url)? onReplayAudio;

  const MessageBubble({
    super.key,
    required this.message,
    this.onReplayAudio,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isLoading) return _buildLoadingBubble();

    final isEmergency = !message.isUser &&
        (message.text.toUpperCase().contains('EMERGENCY') ||
            message.text.toUpperCase().contains('IMMEDIATELY') ||
            message.text.toUpperCase().contains('CALL 112') ||
            message.text.toUpperCase().contains('CALL 108'));

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: message.isUser
          ? _buildUserBubble(context)
          : _buildAiBubble(context, isEmergency),
    );
  }

  Widget _buildUserBubble(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: kPrimaryColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.isVoice) ...[
              const Icon(Icons.mic_rounded, color: Colors.white70, size: 14),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(message.text, style: kMessageStyle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiBubble(BuildContext context, bool isEmergency) {
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
              gradient: kPrimaryGradient,
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
                      color: kDangerColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: kDangerColor.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: kDangerColor, size: 14),
                        SizedBox(width: 5),
                        Text('EMERGENCY ADVICE',
                            style: TextStyle(
                                color: kDangerColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: kSurfaceColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Text(message.text, style: kAiMessageStyle),
                ),
                const SizedBox(height: 10),
                // Action row
                Row(
                  children: [
                    _actionIcon(Icons.content_copy_rounded, () {
                      Clipboard.setData(
                          ClipboardData(text: message.text));
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
                    if (message.audioUrl != null) ...[
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => onReplayAudio?.call(message.audioUrl!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color:
                                kPrimaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: kPrimaryColor
                                    .withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.volume_up_rounded,
                                  color: kPrimaryColor, size: 14),
                              SizedBox(width: 4),
                              Text('Play',
                                  style: TextStyle(
                                      color: kPrimaryColor,
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
              gradient: kPrimaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.medical_services_rounded,
                color: Colors.white, size: 17),
          ),
          const TypingIndicator(),
        ],
      ),
    );
  }

  static Widget _actionIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, size: 16, color: Colors.white30),
    );
  }
}
