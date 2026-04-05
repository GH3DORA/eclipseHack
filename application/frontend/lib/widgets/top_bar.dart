import 'package:flutter/material.dart';
import '../config/constants.dart';

/// The top bar of the chat screen with menu button, app title, and live badge.
class TopBar extends StatelessWidget {
  final VoidCallback onMenuTap;
  final VoidCallback onNewChatTap;
  final bool isCallMode;
  final String activeRole;

  const TopBar({
    super.key,
    required this.onMenuTap,
    required this.onNewChatTap,
    required this.isCallMode,
    required this.activeRole,
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
                Text('MediGuide', style: kAppTitleStyle),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: kPrimaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: kPrimaryColor.withValues(alpha: 0.6),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Local SLM · Private',
                      style: kSubtitleStyle,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: kSurfaceColor,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: kSurfaceBorderColor),
                      ),
                      child: Text(
                        activeRole.toUpperCase(),
                        style: const TextStyle(
                          color: kPrimaryColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
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
