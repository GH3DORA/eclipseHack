import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../config/constants.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';

/// Handles all API communication with the backend.
class ChatService {
  // ── Conversation management ────────────────────────────────────────────────

  /// Create a new conversation on the server, returns the conversation ID.
  static Future<String> createConversation() async {
    final res = await http.post(Uri.parse('$kBaseUrl/conversations'));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['id'] as String;
    }
    throw Exception('Failed to create conversation: ${res.statusCode}');
  }

  /// List all conversations, newest first.
  static Future<List<Conversation>> listConversations() async {
    final res = await http.get(Uri.parse('$kBaseUrl/conversations'));
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      return data
          .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Get all messages for a specific conversation.
  static Future<List<ChatMessage>> getConversationMessages(
      String conversationId) async {
    final res = await http
        .get(Uri.parse('$kBaseUrl/conversations/$conversationId/messages'));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final List<dynamic> msgs = data['messages'] ?? [];
      return msgs.map((m) {
        final role = m['role'] as String;
        return ChatMessage(
          text: m['text'] as String? ?? '',
          isUser: role == 'user',
          audioUrl: m['audio_url'] as String?,
        );
      }).toList();
    }
    return [];
  }

  /// Delete a conversation.
  static Future<void> deleteConversation(String conversationId) async {
    await http.delete(Uri.parse('$kBaseUrl/conversations/$conversationId'));
  }

  // ── Messaging ──────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> sendTextMessage({
    required String message,
    String? conversationId,
    String? role,
    String? username,
    String? userId,
  }) async {
    final res = await http.post(
      Uri.parse('$kBaseUrl/chat/text'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'message': message,
        if (conversationId != null) 'conversation_id': conversationId,
        if (role != null) 'role_override': role,
        if (username != null) 'username': username,
        if (userId != null) 'user_id': userId,
      }),
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Text chat failed: ${res.statusCode}');
  }

  /// Send a voice message. Returns a map with 'transcription', 'reply',
  /// 'audio_url', and 'conversation_id'.
  static Future<Map<String, dynamic>> sendVoiceMessage({
    required String audioFilePath,
    String? conversationId,
    String? role,
    String? username,
    String? userId,
  }) async {
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
      request.files
          .add(await http.MultipartFile.fromPath('audio', audioFilePath));
    }

    if (conversationId != null) {
      request.fields['conversation_id'] = conversationId;
    }
    if (role != null) {
      request.fields['role_override'] = role;
    }
    if (username != null) {
      request.fields['username'] = username;
    }
    if (userId != null) {
      request.fields['user_id'] = userId;
    }

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Voice chat failed: ${res.statusCode}');
  }
}
