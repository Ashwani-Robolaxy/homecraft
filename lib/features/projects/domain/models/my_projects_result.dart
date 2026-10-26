import 'project.dart';

class MyProjectsResult {
  const MyProjectsResult({
    required this.projects,
    this.remainingProjects,
    this.maxProjects,
  });

  final List<Project> projects;
  final int? remainingProjects;
  final int? maxProjects;

  String? get remainingDisplay {
    if (remainingProjects == null && maxProjects == null) return null;
    if (remainingProjects != null && maxProjects != null) {
      return '${remainingProjects!}/${maxProjects!}';
    }
    return (remainingProjects ?? maxProjects).toString();
  }
}
