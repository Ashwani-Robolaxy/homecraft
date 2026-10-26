import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/app_toast.dart';
import '../../../../core/widgets/project_image_placeholder.dart';
import '../../../favorites/presentation/providers/favorites_provider.dart';
import '../../../projects/domain/models/project.dart';
import '../../../chat/presentation/professional_chat_args.dart';
import 'chat_screen.dart';

class ProjectDetailsScreen extends ConsumerWidget {
  const ProjectDetailsScreen({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(
        favoritesProvider.select((s) => s.isFavorited(project.id)));
    final isToggling = ref.watch(
        favoritesProvider.select((s) => s.togglingIds.contains(project.id)));

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, ref, isFav, isToggling),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProjectImage(),
                    const SizedBox(height: 24),
                    _buildTitlePrice(project),
                    const SizedBox(height: 4),
                    _buildLocationDate(project),
                    const SizedBox(height: 16),
                    _buildDescription(project),
                  ],
                ),
              ),
            ),
            _buildBottomButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, WidgetRef ref, bool isFav, bool isToggling) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: const Icon(LucideIcons.chevronLeft, color: Colors.black, size: 20),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            'project_details_screen.title'.tr(),
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          // Heart / favorite button
          GestureDetector(
            onTap: isToggling
                ? null
                : () async {
                    final notifier = ref.read(favoritesProvider.notifier);
                    final nowFav = await notifier.toggleProject(
                      project.id,
                      displayName: project.title,
                      subtitle: project.serviceType ?? '',
                      imageUrl: project.imageUrl,
                    );
                    if (!context.mounted) return;
                    final err = notifier.consumeError();
                    if (err != null) {
                      AppToast.error('project_details_screen.favorites_error'.tr());
                    } else {
                      AppToast.info(nowFav
                          ? 'project_details_screen.added_favorites'.tr()
                          : 'project_details_screen.removed_favorites'.tr());
                    }
                  },
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 4),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: isToggling
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primaryRed),
                    )
                  : Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      color: isFav ? AppColors.primaryRed : Colors.black54,
                      size: 22,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: ProjectImagePlaceholder.hasDisplayableUrl(project.imageUrl)
          ? Image.network(
              project.imageUrl!,
              height: 250,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const ProjectImagePlaceholder(height: 250),
            )
          : const ProjectImagePlaceholder(height: 250),
    );
  }

  Widget _buildTitlePrice(Project project) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          project.serviceType?.isNotEmpty == true ? project.serviceType! : project.title,
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          project.budget ?? 'N/A',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationDate(Project project) {
    return Row(
      children: [
        Text(
          project.location,
          style: GoogleFonts.outfit(fontSize: 12, color: Colors.black45),
        ),
        const SizedBox(width: 12),
        Text(
          project.date,
          style: GoogleFonts.outfit(fontSize: 12, color: Colors.black45),
        ),
      ],
    );
  }

  Widget _buildDescription(Project project) {
    return Text(
      project.description,
      style: GoogleFonts.outfit(
        fontSize: 14,
        color: Colors.black87,
        height: 1.5,
      ),
    );
  }

  Widget _buildBottomButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _openClientChat(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primaryRed),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: Text(
                'common.messages'.tr(),
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryRed,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF800000), // Darker red from screenshot
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 0,
              ),
              child: Text(
                'common.accept'.tr(),
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openClientChat(BuildContext context) {
    final uid = project.clientUserId?.trim();
    if (uid == null || uid.isEmpty) {
      AppToast.info('project_details_screen.no_client_info'.tr());
      return;
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ChatScreen(
          args: ProfessionalChatArgs(
            clientUserId: uid,
            clientDisplayName: project.clientDisplayName,
            projectId: project.id,
          ),
        ),
      ),
    );
  }
}
