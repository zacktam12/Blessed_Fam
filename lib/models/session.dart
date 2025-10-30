import 'package:flutter/material.dart';

class SessionType {
  const SessionType({
    required this.id, 
    required this.name, 
    required this.weight, 
    required this.trackTime,
    this.startTime,
  });
  final int id;
  final String name;
  final int weight;
  final bool trackTime;
  final TimeOfDay? startTime;

  factory SessionType.fromJson(Map<String, dynamic> json) {
    TimeOfDay? parseTime(String? timeStr) {
      if (timeStr == null) return null;
      try {
        final parts = timeStr.split(':');
        return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      } catch (_) {
        return null;
      }
    }
    
    return SessionType(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      weight: (json['weight'] as num).toInt(),
      trackTime: json['track_time'] as bool,
      startTime: parseTime(json['start_time'] as String?),
    );
  }
}

