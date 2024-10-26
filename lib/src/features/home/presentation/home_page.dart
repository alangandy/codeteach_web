import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/providers/chat_state_provider.dart';
import '../../chat/presentation/chat_bubble.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TextEditingController codeController = TextEditingController();
  final TextEditingController chatController = TextEditingController();
  final FocusNode chatFocusNode = FocusNode();
  final ScrollController chatScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    codeController.text = '// Enter your code here\n';
  }

  Future<void> sendMessage() async {
    final message = chatController.text.trim();
    if (message.isEmpty) return;

    chatController.clear();
    await ref.read(chatStateProvider.notifier).sendMessage(message);
    scrollToBottom();
    chatFocusNode.requestFocus();
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (chatScrollController.hasClients) {
        chatScrollController.animateTo(
          chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CodeTeach.ai'),
        backgroundColor: const Color.fromARGB(255, 204, 230, 245),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 6,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: LineNumberedTextField(
                    controller: codeController,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      filled: true,
                      fillColor: Color(0xFF2B2B2B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            flex: 4,
            child: Column(
              children: [
                Expanded(
                  child: chatState.when(
                    data: (messages) => ListView.builder(
                      controller: chatScrollController,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        return ChatBubble(message: message);
                      },
                    ),
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (error, stack) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error: $error',
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => ref.invalidate(chatStateProvider),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: chatController,
                          focusNode: chatFocusNode,
                          decoration: const InputDecoration(
                            hintText: 'Type your message...',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => sendMessage(),
                          enabled: !chatState.isLoading,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: chatState.isLoading ? null : sendMessage,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    codeController.dispose();
    chatController.dispose();
    chatFocusNode.dispose();
    chatScrollController.dispose();
    super.dispose();
  }
}

class LineNumberedTextField extends StatefulWidget {
  final TextEditingController? controller;
  final TextStyle? style;
  final InputDecoration? decoration;

  const LineNumberedTextField({
    super.key,
    this.controller,
    this.style,
    this.decoration,
  });

  @override
  State<LineNumberedTextField> createState() => _LineNumberedTextFieldState();
}

class _LineNumberedTextFieldState extends State<LineNumberedTextField> {
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      style: widget.style,
      decoration: widget.decoration,
      maxLines: null,
      expands: true,
    );
  }
}