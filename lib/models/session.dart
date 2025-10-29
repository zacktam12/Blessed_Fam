class SessionType {
  const SessionType({required this.id, required this.name, required this.weight, required this.trackTime});
  final int id;
  final String name;
  final int weight;
  final bool trackTime;

  factory SessionType.fromJson(Map<String, dynamic> json) {
    return SessionType(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      weight: (json['weight'] as num).toInt(),
      trackTime: json['track_time'] as bool,
    );
  }
}

