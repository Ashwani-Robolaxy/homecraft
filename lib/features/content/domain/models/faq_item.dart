class FaqItem {
  const FaqItem({
    required this.id,
    required this.question,
    required this.answer,
  });

  final String id;
  final String question;
  final String answer;

  factory FaqItem.fromMap(Map<String, dynamic> map) {
    return FaqItem(
      id: (map['id'] ?? map['_id'] ?? '').toString(),
      question: (map['question'] ?? '').toString(),
      answer: (map['answer'] ?? '').toString(),
    );
  }
}
