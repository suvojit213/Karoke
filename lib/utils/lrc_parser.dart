
import 'package:my_flutter_app/data/models/lyric_line_model.dart';

class LrcParser {
  static List<LyricLine> parseLrc(String lrcContent) {
    final List<LyricLine> lyrics = [];
    final RegExp regex = RegExp(r'^\[(\d+):(\d+\.\d+)\](.*)');
    int index = 0;

    for (String line in lrcContent.split('\n')) {
      final match = regex.firstMatch(line.trim());
      if (match != null) {
        final int minutes = int.parse(match.group(1)!);
        final double seconds = double.parse(match.group(2)!);
        final String text = match.group(3)!.trim();
        final int startMs = (minutes * 60 * 1000 + seconds * 1000).toInt();

        lyrics.add(LyricLine(
          index: index,
          text: text,
          startMs: startMs,
        ));
        index++;
      } else if (line.trim().isNotEmpty) {
        // Handle lines without timestamps, assign a dummy timestamp for now
        // These will be synced later
        lyrics.add(LyricLine(
          index: index,
          text: line.trim(),
          startMs: 0, // Will be updated during sync
        ));
        index++;
      }
    }

    // Sort lyrics by index to ensure correct order for syncing
    lyrics.sort((a, b) => a.index.compareTo(b.index));

    return lyrics;
  }

  static String formatMilliseconds(int milliseconds) {
    int minutes = (milliseconds / (60 * 1000)).floor();
    int seconds = ((milliseconds % (60 * 1000)) / 1000).floor();
    int centiseconds = ((milliseconds % 1000) / 10).floor();

    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${centiseconds.toString().padLeft(2, '0')}';
  }

  static String generateLrc(List<LyricLine> lyrics) {
    final StringBuffer buffer = StringBuffer();
    for (var line in lyrics) {
      final int minutes = (line.startMs / (60 * 1000)).floor();
      final double seconds = (line.startMs % (60 * 1000)) / 1000;
      buffer.writeln('[${minutes.toString().padLeft(2, '0')}:${seconds.toStringAsFixed(2)}]${line.text}');
    }
    return buffer.toString();
  }
}
