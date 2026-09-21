import 'package:flutter/material.dart';

class Topic {
  Topic({
    required this.id,
    required this.name,
    this.manualProgress,
  });

  final String id;
  String name;
  /// Optional 0–1 override. Null means derive from sessions.
  double? manualProgress;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'manualProgress': manualProgress,
      };

  factory Topic.fromJson(Map<String, dynamic> json) => Topic(
        id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: json['name'] as String? ?? 'Topic',
        manualProgress: (json['manualProgress'] as num?)?.toDouble(),
      );

  Topic copyWith({String? name, double? manualProgress, bool clearProgress = false}) {
    return Topic(
      id: id,
      name: name ?? this.name,
      manualProgress: clearProgress ? null : (manualProgress ?? this.manualProgress),
    );
  }
}

class Subject {
  Subject({
    required this.id,
    required this.name,
    this.colorValue = 0xFF4F46E5,
    this.iconCodePoint = 0xe0ea, // Icons.school
    this.targetHours,
    this.examDate,
    this.archived = false,
    List<Topic>? topics,
    DateTime? createdAt,
  })  : topics = topics ?? [],
        createdAt = createdAt ?? DateTime.now();

  final String id;
  String name;
  int colorValue;
  int iconCodePoint;
  double? targetHours;
  DateTime? examDate;
  bool archived;
  List<Topic> topics;
  final DateTime createdAt;

  Color get color => Color(colorValue);
  IconData get icon => Icons.school_rounded;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorValue': colorValue,
        'iconCodePoint': iconCodePoint,
        'targetHours': targetHours,
        'examDate': examDate?.toIso8601String(),
        'archived': archived,
        'topics': topics.map((t) => t.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Subject.fromJson(Map<String, dynamic> json) {
    final topics = <Topic>[];
    if (json['topics'] is List) {
      topics.addAll(
        (json['topics'] as List).map((e) => Topic.fromJson(e as Map<String, dynamic>)),
      );
    }
    return Subject(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Subject',
      colorValue: json['colorValue'] as int? ?? 0xFF4F46E5,
      iconCodePoint: json['iconCodePoint'] as int? ?? 0xe0ea,
      targetHours: (json['targetHours'] as num?)?.toDouble(),
      examDate: json['examDate'] == null ? null : DateTime.tryParse(json['examDate'] as String),
      archived: json['archived'] as bool? ?? false,
      topics: topics,
      createdAt: json['createdAt'] == null
          ? DateTime.now()
          : DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now(),
    );
  }

  Subject copyWith({
    String? name,
    int? colorValue,
    int? iconCodePoint,
    double? targetHours,
    bool clearTarget = false,
    DateTime? examDate,
    bool clearExam = false,
    bool? archived,
    List<Topic>? topics,
  }) {
    return Subject(
      id: id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      targetHours: clearTarget ? null : (targetHours ?? this.targetHours),
      examDate: clearExam ? null : (examDate ?? this.examDate),
      archived: archived ?? this.archived,
      topics: topics ?? this.topics.map((t) => t.copyWith()).toList(),
      createdAt: createdAt,
    );
  }
}
