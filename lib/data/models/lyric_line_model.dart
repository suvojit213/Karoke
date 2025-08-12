
class LyricLine {
  int index;
  String text;
  int startMs;
  int? endMs;

  LyricLine({
    required this.index,
    required this.text,
    required this.startMs,
    this.endMs,
  });

  LyricLine copyWith({
    int? index,
    String? text,
    int? startMs,
    int? endMs,
  }) {
    return LyricLine(
      index: index ?? this.index,
      text: text ?? this.text,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'text': text,
      'startMs': startMs,
      'endMs': endMs,
    };
  }

  factory LyricLine.fromJson(Map<String, dynamic> json) {
    return LyricLine(
      index: json['index'],
      text: json['text'],
      startMs: json['startMs'],
      endMs: json['endMs'],
    );
  }
}
