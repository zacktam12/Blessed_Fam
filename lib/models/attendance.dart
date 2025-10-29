class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.userId,
    required this.sessionId,
    required this.date,
    required this.status,
    this.arrivalTime,
  });

  final int id;
  final String userId;
  final int sessionId;
  final DateTime date;
  final String status; // present | absent
  final DateTime? arrivalTime;

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: (json['id'] as num).toInt(),
      userId: json['user_id'] as String,
      sessionId: (json['session_id'] as num).toInt(),
      date: DateTime.parse(json['date'] as String),
      status: json['status'] as String,
      arrivalTime: json['arrival_time'] == null ? null : DateTime.parse(json['arrival_time'] as String),
    );
  }
}

