class PerformanceWeekly {
  const PerformanceWeekly({
    required this.id,
    required this.userId,
    required this.weekStartDate,
    required this.totalScore,
    this.rank,
  });

  final int id;
  final String userId;
  final DateTime weekStartDate;
  final int totalScore;
  final int? rank;

  factory PerformanceWeekly.fromJson(Map<String, dynamic> json) {
    return PerformanceWeekly(
      id: (json['id'] as num).toInt(),
      userId: json['user_id'] as String,
      weekStartDate: DateTime.parse(json['week_start_date'] as String),
      totalScore: (json['total_score'] as num).toInt(),
      rank: json['rank'] == null ? null : (json['rank'] as num).toInt(),
    );
  }
}

