import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../providers.dart';
import '../theme.dart';
import '../widgets/chat_bubble.dart';
import 'paywall_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.uid});

  final String uid;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send({String? photoUrl}) async {
    final text = _textController.text.trim();
    if (text.isEmpty && photoUrl == null) return;
    _textController.clear();

    final firestore = ref.read(firestoreServiceProvider);
    final api = ref.read(apiServiceProvider);
    ref.read(chatErrorProvider.notifier).state = null;
    ref.read(chatLoadingProvider.notifier).state = true;

    try {
      await firestore.sendUserMessage(widget.uid, text, photoUrl: photoUrl);
      // The checkIn Cloud Function writes the AI reply to Firestore,
      // which arrives via the StreamBuilder below.
      await api.checkIn(userId: widget.uid, message: text, photoUrl: photoUrl);
    } catch (e) {
      ref.read(chatErrorProvider.notifier).state =
          'Could not reach your coach. Try again.';
    } finally {
      ref.read(chatLoadingProvider.notifier).state = false;
      _scrollToBottom();
    }
  }

  Future<void> _pickAndSendPhoto() async {
    final isPremium = await ref.read(isPremiumProvider.future);
    if (!mounted) return;
    if (!isPremium) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      return;
    }
    final picked =
        await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1280);
    if (picked == null) return;

    final storageRef = FirebaseStorage.instance.ref(
        'users/${widget.uid}/photos/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await storageRef.putFile(File(picked.path));
    final url = await storageRef.getDownloadURL();
    await _send(photoUrl: url);
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    // List is reversed, so offset 0 is the newest message.
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(chatLoadingProvider);
    final error = ref.watch(chatErrorProvider);
    final isPremium = ref.watch(isPremiumProvider).value ?? false;
    final messagesStream =
        ref.watch(firestoreServiceProvider).watchMessages(widget.uid);

    return Scaffold(
      appBar: AppBar(title: const Text('Your Coach 💧')),
      body: Column(
        children: [
          if (error != null)
            MaterialBanner(
              backgroundColor: Colors.red.shade900,
              content: Text(error),
              actions: [
                TextButton(
                  onPressed: () =>
                      ref.read(chatErrorProvider.notifier).state = null,
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: messagesStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: docs.length + (loading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (loading && index == 0) return const TypingIndicator();
                    final i = loading ? index - 1 : index;
                    final data = docs[i].data();
                    final ts = (data['timestamp'] as Timestamp?)?.toDate();
                    final bubble = ChatBubble(
                      text: data['text'] as String? ?? '',
                      isUser: data['sender'] == 'user',
                      photoUrl: data['photo_url'] as String?,
                    );
                    // Date separator when the next-older message is a
                    // different calendar day.
                    final older = i + 1 < docs.length
                        ? (docs[i + 1].data()['timestamp'] as Timestamp?)
                            ?.toDate()
                        : null;
                    if (ts != null && (older == null || !_sameDay(ts, older))) {
                      return Column(
                        children: [_DateSeparator(date: ts), bubble],
                      );
                    }
                    return bubble;
                  },
                );
              },
            ),
          ),
          _buildInputBar(isPremium),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isPremium) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        color: AppColors.navy,
        child: Row(
          children: [
            if (isPremium)
              IconButton(
                key: const Key('camera_button'),
                icon: const Icon(Icons.camera_alt, color: AppColors.teal),
                onPressed: _pickAndSendPhoto,
              ),
            Expanded(
              child: TextField(
                key: const Key('chat_input'),
                controller: _textController,
                style: const TextStyle(color: AppColors.offwhite),
                decoration: InputDecoration(
                  hintText: 'Tell me what you drank...',
                  hintStyle: TextStyle(
                      color: AppColors.offwhite.withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              key: const Key('send_button'),
              icon: const Icon(Icons.send, color: AppColors.teal),
              onPressed: _send,
            ),
          ],
        ),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        DateFormat('EEEE, MMM d').format(date),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.offwhite.withValues(alpha: 0.4),
          fontSize: 12,
        ),
      ),
    );
  }
}
