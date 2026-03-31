import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../domain/models/project.dart';

class ProjectCard extends StatelessWidget {
  final Project project;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onChat;

  const ProjectCard({super.key, required this.project, this.onEdit, this.onDelete, this.onChat});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/project-details', extra: project),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image and Action Icons
            Stack(
              children: [
                Image.network(
                  project.imageUrl ?? 'https://via.placeholder.com/400x200',
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return AppShimmer(
                      child: ShimmerBox(
                        width: double.infinity,
                        height: 180,
                        radius: 0,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 180,
                    width: double.infinity,
                    color: Colors.grey[200],
                    child: const Center(child: Icon(LucideIcons.image, color: Colors.grey, size: 40)),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Row(
                    children: [
                      _CircleActionButton(icon: LucideIcons.pencil, color: AppColors.primaryRed, onTap: onEdit),
                      const SizedBox(width: 8),
                      _CircleActionButton(icon: LucideIcons.trash2, color: AppColors.primaryRed, onTap: onDelete),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Row(
                    children: [
                      _CircleActionButton(icon: LucideIcons.messageSquare, color: AppColors.primaryRed, onTap: () => _showCommentsBottomSheet(context)),
                      const SizedBox(width: 8),
                      _CircleActionButton(icon: LucideIcons.messageCircle, color: AppColors.primaryRed, onTap: onChat),
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
                    children: [
                      Expanded(
                        child: Text(
                          project.title,
                          style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
                        ),
                      ),
                      Text(
                        project.budget ?? 'N/A',
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(LucideIcons.mapPin, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        project.location,
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 12),
                      const Icon(LucideIcons.calendar, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        project.date,
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    project.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.8), height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.primaryRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      tr('projects.status.accepted', namedArgs: {'count': project.acceptedCount.toString()}),
                      style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppColors.primaryRed, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCommentsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 20),
                Text(
                  tr('projects.comments.title'),
                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textMain),
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    itemCount: project.comments.isEmpty ? 3 : project.comments.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 20),
                    itemBuilder: (context, index) {
                      final comment = project.comments.isNotEmpty
                          ? project.comments[index]
                          : ProjectComment(
                              userName: 'Rihanna Josephine',
                              userAvatar: 'https://i.pravatar.cc/150?u=rihanna',
                              text: 'Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry\'s standard dummy text ever since the 1500s,',
                              hoursAgo: 2,
                            );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(radius: 18, backgroundImage: NetworkImage(comment.userAvatar)),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    comment.userName,
                                    style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMain),
                                  ),
                                  Text(
                                    '${tr('projects.comments.added_comment')} ${tr('projects.comments.time_ago', namedArgs: {'count': comment.hoursAgo.toString()})}',
                                    style: TextStyle(fontFamily: 'Outfit', fontSize: 10, color: AppColors.textSecondary.withValues(alpha: 0.6)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(12)),
                            child: Text(
                              comment.text,
                              style: const TextStyle(fontFamily: 'Outfit', fontSize: 12, color: AppColors.textMain, height: 1.4),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _CircleActionButton({required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
