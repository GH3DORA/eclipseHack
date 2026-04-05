import 'package:flutter/material.dart';
import '../config/constants.dart';
import 'send_button.dart';

/// Bottom input bar with text field, mic button, and send button.
class InputBar extends StatelessWidget {
  final bool isCallMode;
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onMicTap;

  const InputBar({
    super.key,
    required this.isCallMode,
    required this.controller,
    required this.onSend,
    required this.onMicTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isCallMode) return const SizedBox.shrink();

    return Container(
      color: kBgColor,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: kSurfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kSurfaceBorderColor),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    style:
                        const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: 'Message MediGuide…',
                      hintStyle: TextStyle(color: Colors.white30),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 10),
                    ),
                    onSubmitted: (_) => onSend(),
                    keyboardType: TextInputType.multiline,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                  ),
                ),
                // Mic button
                IconButton(
                  onPressed: onMicTap,
                  tooltip: 'Voice call mode',
                  icon: const Icon(Icons.mic_none_rounded,
                      color: Colors.white54, size: 22),
                ),
                // Send button
                SendButton(onTap: onSend, controller: controller),
                const SizedBox(width: 4),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'MediGuide is AI-powered and can make mistakes. Always consult a qualified doctor for medical decisions.',
            style: kDisclaimerStyle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
