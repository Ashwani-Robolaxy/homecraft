import '../models/my_projects_result.dart';
import '../models/project.dart';
import '../models/project_category.dart';

typedef ProjectActionResult = ({String? errorMessage});
typedef ProjectInterestsResult = ({int interestedCount, List<ProjectComment> comments, List<ProjectInterest> interests});

class CreateProjectInput {
  const CreateProjectInput({
    required this.title,
    required this.description,
    required this.categoryId,
    required this.location,
    required this.desiredDate,
    this.budget,
    this.attachmentPath,
    this.latitude,
    this.longitude,
  });

  final String title;
  final String description;
  final int categoryId;
  final String location;
  /// Format: yyyy-MM-dd
  final String desiredDate;
  final String? budget;
  final String? attachmentPath;
  /// From Google Place Details when available (optional for older backends).
  final double? latitude;
  final double? longitude;
}

abstract class ProjectRepository {
  Future<List<ProjectCategory>> getCategories();
  Future<MyProjectsResult> getMyProjects();
  Future<List<Project>> getProfessionalProjects({
    int limit = 20,
    int? beforeId,
    int? categoryId,
    String? search,
  });
  Future<ProjectActionResult> createProject(CreateProjectInput input);
  Future<ProjectActionResult> updateProject(String projectId, CreateProjectInput input);
  Future<ProjectActionResult> deleteProject(String projectId);
  Future<ProjectActionResult> markProjectInterest(String projectId, {String? comment});
  Future<ProjectInterestsResult> fetchProjectInterests(String projectId);
  Future<List<ProfessionalInterestedProject>> getProfessionalInterestedProjects();
}
