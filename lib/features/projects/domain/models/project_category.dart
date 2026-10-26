class ProjectCategory {
  const ProjectCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.imageUrl,
  });

  final int id;
  final String name;
  final String slug;
  final String? imageUrl;

  factory ProjectCategory.fromMap(Map<String, dynamic> map) {
    String? pickImage() {
      final candidates = [
        map['imageUrl'],
        map['image'],
        map['iconUrl'],
        map['icon'],
        map['photoUrl'],
        map['photo'],
      ];
      for (final c in candidates) {
        if (c == null) continue;
        final text = c.toString().trim();
        if (text.isNotEmpty) return text;
      }
      final nested = map['categoryImage'];
      if (nested is Map) {
        final text = (nested['url'] ?? nested['imageUrl'] ?? '').toString().trim();
        if (text.isNotEmpty) return text;
      }
      return null;
    }

    return ProjectCategory(
      id: (map['id'] as num?)?.toInt() ?? 0,
      name: (map['name'] ?? '').toString(),
      slug: (map['slug'] ?? '').toString(),
      imageUrl: pickImage(),
    );
  }
}
