
class RenderPreset {
  final String resolution;
  final int bitrate;
  final String bgPath;
  final String outputPath;

  RenderPreset({
    required this.resolution,
    required this.bitrate,
    required this.bgPath,
    required this.outputPath,
  });

  Map<String, dynamic> toJson() {
    return {
      'resolution': resolution,
      'bitrate': bitrate,
      'bgPath': bgPath,
      'outputPath': outputPath,
    };
  }

  factory RenderPreset.fromJson(Map<String, dynamic> json) {
    return RenderPreset(
      resolution: json['resolution'],
      bitrate: json['bitrate'],
      bgPath: json['bgPath'],
      outputPath: json['outputPath'],
    );
  }
}
