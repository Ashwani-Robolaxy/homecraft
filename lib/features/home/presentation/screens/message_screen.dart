import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/common_app_bar.dart';

class MessageScreen extends StatefulWidget {
  const MessageScreen({super.key});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF9F9),
      appBar: CommonAppBar(title: 'provider.nav.message'.tr(), showBackButton: false, showLogo: true, showNotification: true, notificationCount: 1),
      body: Stack(
        children: [
          // Timeline Line
          Positioned(left: 31, top: 0, bottom: 0, child: Container(width: 2, color: AppColors.primaryRed)),
          ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 20),
            itemCount: 3,
            itemBuilder: (context, index) {
              return MessageItem(isLast: index == 2, showExpand: index == 1);
            },
          ),
        ],
      ),
    );
  }
}

class MessageItem extends StatefulWidget {
  final bool isLast;
  final bool showExpand;

  const MessageItem({super.key, this.isLast = false, this.showExpand = false});

  @override
  State<MessageItem> createState() => _MessageItemState();
}

class _MessageItemState extends State<MessageItem> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.showExpand;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline Node
            Container(
              margin: const EdgeInsets.only(left: 24, top: 18),
              width: 16,
              height: 16,
              decoration: const BoxDecoration(color: AppColors.primaryRed, shape: BoxShape.circle),
            ),
            const SizedBox(width: 16),
            // Message Card
            Expanded(
              child: GestureDetector(
                onTap: () => context.push('/chat'),
                child: Container(
                  margin: const EdgeInsets.only(right: 20, bottom: 20),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    style: GoogleFonts.outfit(fontSize: 16, color: Colors.black),
                                    children: [
                                      const TextSpan(
                                        text: 'Name: ',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      const TextSpan(text: 'abcd'),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                RichText(
                                  text: TextSpan(
                                    style: GoogleFonts.outfit(fontSize: 14),
                                    children: [
                                      const TextSpan(
                                        text: 'Profession: ',
                                        style: TextStyle(color: AppColors.primaryRed),
                                      ),
                                      const TextSpan(
                                        text: 'Cleaner',
                                        style: TextStyle(color: AppColors.primaryRed),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 80,
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              image: const DecorationImage(image: AssetImage('assets/images/professional_cleaner_male.png'), fit: BoxFit.cover),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('2 min ago', style: GoogleFonts.outfit(fontSize: 10, color: Colors.black54)),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isExpanded = !_isExpanded;
                                  });
                                },
                                child: Icon(_isExpanded ? Icons.arrow_drop_up : Icons.arrow_drop_down, color: Colors.black),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (_isExpanded) ...[
                        const Divider(height: 24),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: GoogleFonts.outfit(fontSize: 14, color: Colors.black),
                                children: [
                                  const TextSpan(
                                    text: 'Last Messages : ',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(
                                    text: 'Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry\'s standard dummy text ever since the 1500s,',
                                    style: GoogleFonts.outfit(color: Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
