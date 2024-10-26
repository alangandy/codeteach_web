import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';

part 'chat_state_provider.g.dart';

final _logger = Logger('ChatStateProvider');

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final bool isLoading;
  final bool isError;
  final String? originalMessage;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    this.isLoading = false,
    this.isError = false,
    this.originalMessage,
  });
}

@riverpod
class ChatState extends _$ChatState {
  String? _currentThreadId;
  final _supabase = Supabase.instance.client;
  
  @override
  FutureOr<List<ChatMessage>> build() {
    ref.onDispose(() {
      _cleanupThread();
    });
    return [];
  }

  Future<void> _cleanupThread() async {
    if (_currentThreadId != null) {
      try {
        // Get the current session
        final session = _supabase.auth.currentSession;
        if (session == null) return;

        await _supabase.functions.invoke(
          'openai-assistant',
          body: {
            'action': 'deleteThread',
            'threadId': _currentThreadId,
          },
          headers: {
            'Authorization': 'Bearer ${session.accessToken}'
          }
        );
        _currentThreadId = null;
      } catch (e) {
        _logger.warning('Error cleaning up thread: $e');
      }
    }
  }

  Future<void> sendMessage(String message) async {
    final currentMessages = state.valueOrNull ?? [];
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    
    state = AsyncData([
      ...currentMessages,
      const ChatMessage(
        id: 'typing',
        text: '',
        isUser: false,
        isLoading: true,
      ),
    ]);

    try {
      // Get the current session
      final session = _supabase.auth.currentSession;
      if (session == null) throw Exception('Not authenticated');

      final response = await _supabase.functions.invoke(
        'openai-assistant',
        body: {
          'query': message,
          'assistantId': dotenv.env['ASSISTANT_ID'],
          'threadId': _currentThreadId,
        },
        headers: {
          'Authorization': 'Bearer ${session.accessToken}'
        }
      );

      if (response.status != 200) {
        throw Exception(response.data['error'] ?? 'Failed to get response');
      }

      _currentThreadId ??= response.data['threadId'] as String?;

      final messages = state.valueOrNull ?? [];
      messages.removeLast(); // Remove typing indicator
      
      state = AsyncData([
        ...messages,
        ChatMessage(
          id: '${messageId}_response',
          text: response.data['response'] as String,
          isUser: false,
        ),
      ]);
    } catch (e, st) {
      _logger.severe('Error sending message', e, st);
      
      final messages = state.valueOrNull ?? [];
      messages.removeLast(); // Remove typing indicator
      
      state = AsyncData([
        ...messages,
        ChatMessage(
          id: '${messageId}_error',
          text: "Sorry, I encountered an error. Please try again.",
          isUser: false,
          isError: true,
          originalMessage: message,
        ),
      ]);
    }
  }

  Future<void> retryMessage(ChatMessage errorMessage) async {
    if (!errorMessage.isError || errorMessage.originalMessage == null) return;

    final messages = state.valueOrNull ?? [];
    final errorIndex = messages.indexWhere((m) => m.id == errorMessage.id);
    if (errorIndex != -1) {
      messages.removeAt(errorIndex);
      state = AsyncData(messages);
    }

    await sendMessage(errorMessage.originalMessage!);
  }

  void clearMessages() {
    _cleanupThread();
    state = const AsyncData([]);
  }
}