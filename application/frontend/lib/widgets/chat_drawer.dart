import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/constants.dart';
import '../models/conversation.dart';

/// Sidebar drawer showing conversation history with New Chat button.
class ChatDrawer extends StatelessWidget {
  final List<Conversation> conversations;
  final bool isLoading;
  final String? activeConversationId;
  final VoidCallback onNewChat;
  final VoidCallback onRefresh;
  final void Function(Conversation conversation) onConversationTap;
  final void Function(Conversation conversation) onConversationDelete;

  const ChatDrawer({
    super.key,
    required this.conversations,
    required this.isLoading,
    required this.activeConversationId,
    required this.onNewChat,
    required this.onRefresh,
    required this.onConversationTap,
    required this.onConversationDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: kDrawerBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          Expanded(child: _buildBody()),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 52, 12, 16),
      decoration: const BoxDecoration(
        color: kDrawerBg,
        border: Border(bottom: BorderSide(color: kDrawerBorder)),
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
                  gradient: kPrimaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.medical_services_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('MediGuide', style: kDrawerTitleStyle),
              ),

              // ── NEW CHAT BUTTON ───────────────────────────
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Navigator.of(context).pop(); // close drawer
                    onNewChat();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: kPrimaryGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded,
                            color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'New Chat',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('Recent Conversations', style: kDrawerSectionStyle),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: kPrimaryColor,
          strokeWidth: 2,
        ),
      );
    }

    if (conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                color: Colors.white12, size: 48),
            const SizedBox(height: 12),
            const Text(
              'No conversations yet.\nStart a new chat!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: conversations.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: Color(0xFF1A1A1A)),
      itemBuilder: (ctx, i) => _buildConversationTile(ctx, conversations[i]),
    );
  }

  Widget _buildConversationTile(BuildContext context, Conversation conv) {
    final timeStr =
        DateFormat('MMM d, h:mm a').format(conv.updatedAt.toLocal());
    final preview =
        conv.title.length > 50 ? '${conv.title.substring(0, 50)}…' : conv.title;
    final isActive = conv.id == activeConversationId;

    return Dismissible(
      key: Key(conv.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: kDangerColor.withValues(alpha: 0.3),
        child:
            const Icon(Icons.delete_rounded, color: Colors.white, size: 20),
      ),
      onDismissed: (_) => onConversationDelete(conv),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop(); // close drawer
          onConversationTap(conv);
        },
        child: Container(
          color: isActive ? kPrimaryColor.withValues(alpha: 0.08) : null,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isActive
                      ? kPrimaryColor.withValues(alpha: 0.15)
                      : kSurfaceColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive
                        ? kPrimaryColor.withValues(alpha: 0.4)
                        : kSurfaceBorderColor,
                  ),
                ),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: isActive ? kPrimaryColor : Colors.white38,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview,
                      style: TextStyle(
                        color: isActive
                            ? kPrimaryColor
                            : const Color(0xDEFFFFFF),
                        fontSize: 13,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      timeStr,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white24, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: kDrawerBorder)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.white24, size: 14),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Swipe left to delete a conversation',
              style: TextStyle(color: Colors.white24, fontSize: 11),
            ),
          ),
          GestureDetector(
            onTap: onRefresh,
            child: const Icon(Icons.refresh_rounded,
                color: kPrimaryColor, size: 18),
          ),
        ],
      ),
    );
  }
}
