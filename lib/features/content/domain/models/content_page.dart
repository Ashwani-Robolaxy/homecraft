class ContentPage {
  const ContentPage({required this.title, required this.content});

  final String title;
  final String content;

  factory ContentPage.fromMap(Map<String, dynamic> map) {
    return ContentPage(
      title: (map['title'] ?? map['heading'] ?? '').toString(),
      content: (map['content'] ?? map['description'] ?? '').toString(),
    );
  }
}
