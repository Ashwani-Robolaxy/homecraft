class Project {
  final String id;
  final String title;
  final String description;
  final String location;
  final String date;
  final String? budget;
  final String? imageUrl;
  final int acceptedCount;
  final List<ProjectComment> comments;

  Project({required this.id, required this.title, required this.description, required this.location, required this.date, this.budget, this.imageUrl, this.acceptedCount = 0, this.comments = const []});
}

class ProjectComment {
  final String userName;
  final String userAvatar;
  final String text;
  final int hoursAgo;

  ProjectComment({required this.userName, required this.userAvatar, required this.text, required this.hoursAgo});
}
