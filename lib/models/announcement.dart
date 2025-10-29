class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    this.postedBy,
  });

  final int id;
  final String title;
  final String message;
  final DateTime createdAt;
  final String? postedBy;

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      postedBy: json['posted_by'] as String?,
    );
  }
}

