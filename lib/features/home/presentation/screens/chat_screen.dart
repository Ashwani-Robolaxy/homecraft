import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _showMenu(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (context) => Stack(
        children: [
          Positioned(
            top: 60,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 150,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMenuItem('Media', () {
                      Navigator.pop(context);
                      context.push('/media');
                    }),
                    const Divider(height: 1),
                    _buildMenuItem('Report', () {
                      Navigator.pop(context);
                      context.push('/take-action');
                    }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        width: double.infinity,
        alignment: Alignment.center,
        child: Text(
          title,
          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            const CircleAvatar(radius: 18, backgroundImage: AssetImage('assets/images/cleaner_profile_1.png')),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
                      children: [
                        const TextSpan(text: 'Gusef chici '),
                        TextSpan(
                          text: 'Cleaner',
                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w400, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  Text('Active 2 hours ago', style: GoogleFonts.outfit(fontSize: 10, color: Colors.black45)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.moreVertical, color: Colors.black),
            onPressed: () => _showMenu(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildDateSeparator('Yesterday, 9.00 PM'),
                _buildChatBubble('Hi, I\'m looking to get my backyard pool cleaned. Do you offer that service?', false),
                _buildDateSeparator('Today, 8.30 AM'),
                _buildChatBubble('Yes, we do! Can you tell me the size and condition of your pool?', true),
                _buildChatBubble('It\'s medium-sized, 15x30 feet. Haven\'t cleaned it in months, so there\'s algae and leaves.', false),
                _buildChatBubble('Got it. We recommend a thorough cleaning. When would you like us to come by?', true, time: '8.39 AM'),
              ],
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.outfit(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isMe, {String? time}) {
    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isMe ? AppColors.primaryRed : const Color(0xFFEFEFEF),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
              bottomRight: isMe ? Radius.zero : const Radius.circular(16),
            ),
          ),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
          child: Text(text, style: GoogleFonts.outfit(fontSize: 14, color: isMe ? Colors.white : Colors.black87, height: 1.4)),
        ),
        if (time != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(time, style: GoogleFonts.outfit(fontSize: 10, color: Colors.black45)),
          ),
      ],
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(color: AppColors.primaryRed, shape: BoxShape.circle),
            child: const Icon(LucideIcons.image, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.black12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type your message',
                        hintStyle: GoogleFonts.outfit(color: Colors.black38, fontSize: 14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const Icon(LucideIcons.smile, color: Colors.black38, size: 24),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: AppColors.primaryRed, shape: BoxShape.circle),
            child: const Icon(LucideIcons.send, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }
}
