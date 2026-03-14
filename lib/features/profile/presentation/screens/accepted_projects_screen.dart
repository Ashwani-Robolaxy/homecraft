import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/common_app_bar.dart';

class AcceptedProjectsScreen extends StatefulWidget {
  const AcceptedProjectsScreen({super.key});

  @override
  State<AcceptedProjectsScreen> createState() => _AcceptedProjectsScreenState();
}

class _AcceptedProjectsScreenState extends State<AcceptedProjectsScreen> {
  final List<_ProjectItem> _projects = [
    _ProjectItem(title: 'Gardeners, landscaper', location: 'New York, US', date: 'Jun14,2025', price: '€ 200', description: 'Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry\'s standard dummy text ever since the 1500s,', isAccepted: false, isFavorite: false),
    _ProjectItem(title: 'Gardeners, landscaper', location: 'New York, US', date: 'Jun14,2025', price: '€ 200', description: 'Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry\'s standard dummy text ever since the 1500s,', isAccepted: true, isFavorite: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8E8E8),
      appBar: CommonAppBar(title: 'provider.profile.accepted_projects'.tr(), showNotification: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('provider.profile.accepted_count'.tr(namedArgs: {'count': '12'}), style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF4CAF50))),
            const SizedBox(height: 16),
            ..._projects.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _ProjectCard(item: p, onToggleFavorite: () => setState(() => p.isFavorite = !p.isFavorite)),
                )),
          ],
        ),
      ),
    );
  }
}

class _ProjectItem {
  final String title;
  final String location;
  final String date;
  final String price;
  final String description;
  bool isAccepted;
  bool isFavorite;

  _ProjectItem({required this.title, required this.location, required this.date, required this.price, required this.description, this.isAccepted = false, this.isFavorite = false});
}

class _ProjectCard extends StatelessWidget {
  final _ProjectItem item;
  final VoidCallback onToggleFavorite;

  const _ProjectCard({required this.item, required this.onToggleFavorite});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.asset(
                  'assets/images/garden.png',
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    color: Colors.grey[300],
                    child: Center(child: Icon(LucideIcons.image, size: 48, color: Colors.grey[600])),
                  ),
                ),
              ),
              if (item.isAccepted)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _imageIcon(LucideIcons.heart, onTap: onToggleFavorite),
                      const SizedBox(width: 8),
                      _imageIcon(LucideIcons.messageCircle, onTap: () => context.push('/chat')),
                    ],
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(item.title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain))),
                    Text(item.price, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryRed)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${item.location} ${item.date}', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                Text(
                  item.description,
                  style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: item.isAccepted
                      ? OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4CAF50),
                            side: const BorderSide(color: Color(0xFF4CAF50)),
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('provider.profile.accepted_button'.tr(), style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
                        )
                      : ElevatedButton(
                          onPressed: onToggleFavorite,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Text('provider.profile.add_your_favorite'.tr(), style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageIcon(IconData icon, {required VoidCallback onTap}) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(padding: const EdgeInsets.all(10), child: Icon(icon, size: 20, color: AppColors.textMain)),
      ),
    );
  }
}
