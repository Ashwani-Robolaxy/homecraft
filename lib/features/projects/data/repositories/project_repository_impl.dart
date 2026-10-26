import '../../../../core/network/api_exception.dart';
import '../../domain/models/my_projects_result.dart';
import '../../domain/models/project.dart';
import '../../domain/models/project_category.dart';
import '../../domain/repositories/project_repository.dart';
import '../datasources/project_remote_datasource.dart';

class ProjectRepositoryImpl implements ProjectRepository {
  ProjectRepositoryImpl({ProjectRemoteDatasource? datasource})
      : _ds = datasource ?? ProjectRemoteDatasource();

  final ProjectRemoteDatasource _ds;

  @override
  Future<ProjectActionResult> createProject(CreateProjectInput input) async {
    try {
      await _ds.createProject(input);
      return (errorMessage: null);
    } on ApiException catch (e) {
      return (errorMessage: e.message);
    } catch (_) {
      return (errorMessage: 'Network error. Check your connection.');
    }
  }

  @override
  Future<ProjectActionResult> updateProject(String projectId, CreateProjectInput input) async {
    try {
      await _ds.updateProject(projectId, input);
      return (errorMessage: null);
    } on ApiException catch (e) {
      final msg = e.message;
      // Server returns this when PUT /users/projects/{id} is not registered (not a GoRouter issue).
      if (e.statusCode == 404 &&
          msg.toLowerCase().contains('route not found') &&
          msg.contains('/users/projects')) {
        return (
          errorMessage:
              'Cannot update project: the server has no PUT/PATCH handler for /users/projects/{id}. Add it (multipart, same fields as create).',
        );
      }
      return (errorMessage: msg);
    } catch (_) {
      return (errorMessage: 'Network error. Check your connection.');
    }
  }

  @override
  Future<ProjectActionResult> deleteProject(String projectId) async {
    try {
      await _ds.deleteProject(projectId);
      return (errorMessage: null);
    } on ApiException catch (e) {
      return (errorMessage: e.message);
    } catch (_) {
      return (errorMessage: 'Network error. Check your connection.');
    }
  }

  @override
  Future<ProjectActionResult> markProjectInterest(String projectId, {String? comment}) async {
    try {
      await _ds.markProjectInterest(projectId, comment: comment);
      return (errorMessage: null);
    } on ApiException catch (e) {
      return (errorMessage: e.message);
    } catch (_) {
      return (errorMessage: 'Network error. Check your connection.');
    }
  }

  @override
  Future<ProjectInterestsResult> fetchProjectInterests(String projectId) async {
    try {
      return await _ds.fetchProjectInterests(projectId);
    } on ApiException catch (e) {
      throw ApiException(e.message, statusCode: e.statusCode);
    } catch (_) {
      throw ApiException('Network error. Check your connection.');
    }
  }

  @override
  Future<List<ProjectCategory>> getCategories() => _ds.getCategories();

  @override
  Future<MyProjectsResult> getMyProjects() => _ds.getMyProjects();

  @override
  Future<List<Project>> getProfessionalProjects({
    int limit = 20,
    int? beforeId,
    int? categoryId,
    String? search,
  }) =>
      _ds.getProfessionalProjects(
        limit: limit,
        beforeId: beforeId,
        categoryId: categoryId,
        search: search,
      );

  @override
  Future<List<ProfessionalInterestedProject>> getProfessionalInterestedProjects() =>
      _ds.getProfessionalInterestedProjects();
}
