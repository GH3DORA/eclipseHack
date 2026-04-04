/// Represents a single message in a conversation.
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

/// Voice call state machine.
enum CallState { idle, listening, processing, speaking }
