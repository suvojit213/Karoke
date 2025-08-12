
class Project {
  final String id;
  final String title;
  final String audioPath;
  final String? lyricsPath;
  final DateTime createdAt;
  final DateTime modifiedAt;

  Project({
    required this.id,
    required this.title,
    required this.audioPath,
    this.lyricsPath,
    required this.createdAt,
    required this.modifiedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'audioPath': audioPath,
      'lyricsPath': lyricsPath,
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt.toIso8601String(),
    };
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      title: json['title'],
      audioPath: json['audioPath'],
      lyricsPath: json['lyricsPath'],
      createdAt: DateTime.parse(json['createdAt']),
      modifiedAt: DateTime.parse(json['modifiedAt']),
    );
  }
}
