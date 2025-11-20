class SessionModel {
  final int? id;
  final String date;
  final int duration;
  final int avgHR;
  final double focusLevel;
  final String focusTimelineJson;

  SessionModel({
    this.id,
    required this.date,
    required this.duration,
    required this.avgHR,
    required this.focusLevel,
    required this.focusTimelineJson,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'duration': duration,
      'avgHR': avgHR,
      'focusLevel': focusLevel,
      'focusTimelineJson': focusTimelineJson,
    };
  }

  factory SessionModel.fromMap(Map<String, dynamic> map) {
    return SessionModel(
      id: map['id'],
      date: map['date'],
      duration: map['duration'],
      avgHR: map['avgHR'],
      focusLevel: map['focusLevel'],
      focusTimelineJson: map['focusTimelineJson'],
    );
  }
}
