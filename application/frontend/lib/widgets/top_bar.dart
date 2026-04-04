import 'package:flutter/material.dart';
import '../config/constants.dart';

/// The top bar of the chat screen with menu button, app title, and live badge.
class TopBar extends StatelessWidget {
  final VoidCallback onMenuTap;
  final VoidCallback onNewChatTap;
  final bool isCallMode;

  const TopBar({
    super.key,
    required this.onMenuTap,
    required this.onNewChatTap,
    required this.isCallMode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [


          // App title + status badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('MediGuide', style: kAppTitleStyle),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: kPrimaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Local SLM · Private & Offline',
                      style: kSubtitleStyle,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Live call badge
          if (isCallMode)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: kDangerColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: kDangerColor.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: kDangerColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      color: kDangerColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),

          // New Chat button
          if (!isCallMode)
            IconButton(
              onPressed: onNewChatTap,
              icon: const Icon(Icons.edit_square,
                  color: Colors.white70, size: 20),
              tooltip: 'New Chat',
            ),
          
          // Old Chats (History) button
          IconButton(
            onPressed: onMenuTap,
            icon: const Icon(Icons.history_rounded,
                color: Colors.white70, size: 22),
            tooltip: 'Chat History',
          ),
        ],
      ),
    );
  }
}
