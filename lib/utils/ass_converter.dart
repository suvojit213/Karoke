
import 'package:my_flutter_app/data/models/lyric_line_model.dart';
import 'package:my_flutter_app/utils/lrc_parser.dart';

class AssConverter {
  static String convertLrcToAss(String title, List<LyricLine> lyrics) {
    final StringBuffer assContent = StringBuffer();

    // ASS Header
    assContent.writeln('[Script Info]');
    assContent.writeln('Title: $title');
    assContent.writeln('ScriptType: v4.00+');
    assContent.writeln('PlayResX: 1280');
    assContent.writeln('PlayResY: 720');
    assContent.writeln('');

    // ASS Styles
    assContent.writeln('[V4+ Styles]');
    assContent.writeln('Format: Name, Fontname, Fontsize, PrimaryColour, OutlineColour, Bold, Italic, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding');
    assContent.writeln('Style: Default,Arial,48,&H00FFFFFF,&H00000000,0,0,1,2,0,2,10,10,1');
    assContent.writeln('');

    // ASS Events
    assContent.writeln('[Events]');
    assContent.writeln('Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text');

    for (int i = 0; i < lyrics.length; i++) {
      final LyricLine lyric = lyrics[i];
      final int startMs = lyric.startMs;
      int endMs = lyric.endMs ?? (lyric.startMs + 3000); // Default 3 seconds if endMs is null

      // Ensure endMs is not before startMs
      if (endMs < startMs) {
        endMs = startMs + 100; // Small default duration
      }

      final String startTime = _formatMsToAssTime(startMs);
      final String endTime = _formatMsToAssTime(endMs);

      // Dialogue: 0,Start,End,Style,,0,0,0,,Text
      assContent.writeln('Dialogue: 0,$startTime,$endTime,Default,,0,0,0,,${lyric.text}');
    }

    return assContent.toString();
  }

  static String _formatMsToAssTime(int milliseconds) {
    final int hours = (milliseconds ~/ 3600000);
    final int minutes = (milliseconds ~/ 60000) % 60;
    final int seconds = (milliseconds ~/ 1000) % 60;
    final int centiseconds = (milliseconds % 1000) ~/ 10; // Convert to centiseconds

    return '${hours.toString().padLeft(1, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${centiseconds.toString().padLeft(2, '0')}';
  }
}
