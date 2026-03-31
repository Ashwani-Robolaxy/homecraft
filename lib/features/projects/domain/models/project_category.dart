class ProjectCategory {
  const ProjectCategory({
    required this.id,
    required this.name,
    required this.slug,
  });

  final int id;
  final String name;
  final String slug;

  factory ProjectCategory.fromMap(Map<String, dynamic> map) {
    return ProjectCategory(
      id: (map['id'] as num?)?.toInt() ?? 0,
      name: (map['name'] ?? '').toString(),
      slug: (map['slug'] ?? '').toString(),
    );
  }
}
