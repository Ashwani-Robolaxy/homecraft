import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/my_projects_result.dart';
import '../../domain/models/project.dart';
import '../../domain/models/project_category.dart';
import '../../data/repositories/project_repository_impl.dart';
import '../../domain/repositories/project_repository.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepositoryImpl();
});

final myProjectsProvider = FutureProvider<MyProjectsResult>((ref) async {
  final repo = ref.watch(projectRepositoryProvider);
  final result = await repo.getMyProjects();

  // Fetch interest count for each project in parallel
  final updatedProjects = await Future.wait(
    result.projects.map((p) async {
      try {
        final interestsResult = await repo.fetchProjectInterests(p.id);
        return p.copyWith(acceptedCount: interestsResult.interestedCount);
      } catch (_) {
        return p;
      }
    }),
  );

  return MyProjectsResult(
    projects: updatedProjects,
    remainingProjects: result.remainingProjects,
    maxProjects: result.maxProjects,
  );
});

final projectCategoriesProvider = FutureProvider<List<ProjectCategory>>((ref) async {
  final repo = ref.watch(projectRepositoryProvider);
  return repo.getCategories();
});

final professionalProjectsProvider = FutureProvider<List<Project>>((ref) async {
  final repo = ref.watch(projectRepositoryProvider);
  return repo.getProfessionalProjects();
});
