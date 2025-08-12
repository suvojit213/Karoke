
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:share_plus/share_plus.dart';
import 'package:my_flutter_app/data/models/lyric_line_model.dart';
import 'package:my_flutter_app/data/models/project_model.dart';
import 'package:my_flutter_app/utils/lrc_parser.dart';
import 'package:my_flutter_app/utils/ass_converter.dart';
import 'package:my_flutter_app/data/repositories/project_repository.dart';
import 'package:path_provider/path_provider.dart';

class ReviewEditorScreen extends StatefulWidget {
  final Project project;

  const ReviewEditorScreen({super.key, required this.project});

  @override
  State<ReviewEditorScreen> createState() => _ReviewEditorScreenState();
}

class _ReviewEditorScreenState extends State<ReviewEditorScreen> {
  late AudioPlayer _audioPlayer;
  late PlayerController _waveformController;
  bool _isPlaying = false;
  List<LyricLine> _lyrics = [];
  int _currentLyricIndex = -1;
  final ProjectRepository _projectRepository = ProjectRepository();

  String? _backgroundImagePath;
  String? _backgroundVideoPath;
  String _selectedResolution = '1280x720'; // Default resolution
  bool _isRendering = false;

  final List<String> _resolutions = ['1280x720', '1920x1080'];

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _waveformController = PlayerController();
    _loadAudio();
    _loadLyrics();

    _audioPlayer.positionStream.listen((position) {
      _updateCurrentLyric(position.inMilliseconds);
      _waveformController.seekTo(position.inMilliseconds);
    });

    _audioPlayer.playerStateStream.listen((playerState) {
      if (playerState.playing) {
        _waveformController.startPlayer();
      } else if (playerState.processingState == ProcessingState.completed) {
        _waveformController.stopPlayer();
        setState(() {
          _isPlaying = false;
        });
      } else {
        _waveformController.pausePlayer();
      }
    });
  }

  Future<void> _loadAudio() async {
    try {
      await _audioPlayer.setFilePath(widget.project.audioPath);
      await _waveformController.preparePlayer(path: widget.project.audioPath);
    } catch (e) {
      print("Error loading audio: $e");
    }
  }

  Future<void> _loadLyrics() async {
    if (widget.project.lyricsPath != null) {
      final File lyricsFile = File(widget.project.lyricsPath!);
      if (await lyricsFile.exists()) {
        final String lrcContent = await lyricsFile.readAsString();
        setState(() {
          _lyrics = LrcParser.parseLrc(lrcContent);
        });
      }
    }
  }

  void _updateCurrentLyric(int currentPositionMs) {
    for (int i = 0; i < _lyrics.length; i++) {
      if (currentPositionMs >= _lyrics[i].startMs &&
          (i == _lyrics.length - 1 || currentPositionMs < _lyrics[i + 1].startMs)) {
        if (_currentLyricIndex != i) {
          setState(() {
            _currentLyricIndex = i;
          });
        }
        return;
      }
    }
    if (_currentLyricIndex != -1 && currentPositionMs < _lyrics[0].startMs) {
      setState(() {
        _currentLyricIndex = -1;
      });
    }
  }

  void _playPause() {
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  void _adjustTimestamp(int index, int milliseconds) {
    setState(() {
      _lyrics[index].startMs += milliseconds;
      if (index > 0) {
        _lyrics[index - 1].endMs = _lyrics[index].startMs;
      }
      // Ensure endMs is always after startMs
      if (_lyrics[index].endMs != null && _lyrics[index].endMs! < _lyrics[index].startMs) {
        _lyrics[index].endMs = _lyrics[index].startMs + 100; // Small default duration
      }
    });
    _saveLyricsToFile();
  }

  Future<void> _saveLyricsToFile() async {
    if (widget.project.lyricsPath != null) {
      final File lyricsFile = File(widget.project.lyricsPath!);
      final String lrcContent = LrcParser.generateLrc(_lyrics);
      await lyricsFile.writeAsString(lrcContent);
      final updatedProject = widget.project.copyWith(modifiedAt: DateTime.now());
      await _projectRepository.saveProject(updatedProject);
    }
  }

  Future<void> _pickBackgroundImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _backgroundImagePath = image.path;
        _backgroundVideoPath = null; // Clear video path if image is selected
      });
    }
  }

  Future<void> _pickBackgroundVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _backgroundVideoPath = video.path;
        _backgroundImagePath = null; // Clear image path if video is selected
      }
      );
    }
  }

  Future<void> _renderVideo() async {
    setState(() {
      _isRendering = true;
    });

    try {
      final String assContent = AssConverter.convertLrcToAss(widget.project.title, _lyrics);
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String projectDirPath = '${appDocDir.path}/projects/${widget.project.id}';
      final String assFilePath = '$projectDirPath/lyrics.ass';
      final File assFile = File(assFilePath);
      await assFile.writeAsString(assContent);

      final String audioPath = widget.project.audioPath;
      final String outputPath = '$projectDirPath/output.mp4';

      String ffmpegCommand = '';

      if (_backgroundImagePath != null) {
        ffmpegCommand = '-loop 1 -i "$_backgroundImagePath" -i "$audioPath" -vf "ass=$assFilePath,scale=$_selectedResolution" -shortest -c:v libx264 -preset medium -crf 18 -c:a aac "$outputPath" ';
      } else if (_backgroundVideoPath != null) {
        ffmpegCommand = '-i "$_backgroundVideoPath" -i "$audioPath" -vf "ass=$assFilePath" -map 0:v -map 1:a -c:v libx264 -preset medium -crf 18 -c:a aac "$outputPath" ';
      } else {
        // Default to a black background if no image/video is selected
        ffmpegCommand = '-f lavfi -i color=c=black:s=$_selectedResolution -i "$audioPath" -vf "ass=$assFilePath" -shortest -c:v libx264 -preset medium -crf 18 -c:a aac "$outputPath" ';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rendering video...')),
      );

      final session = await FFmpegKit.execute(ffmpegCommand);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video rendered successfully!')),
        );
        // Share the video
        Share.shareXFiles([XFile(outputPath)]);
      } else if (ReturnCode.isCancel(returnCode)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video rendering cancelled.')),
        );
      } else {
        final error = await session.getFailStackTrace();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video rendering failed: $error')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during rendering: $e')),
      );
    } finally {
      setState(() {
        _isRendering = false;
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _waveformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Review: ${widget.project.title}'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text('Audio: ${widget.project.audioPath.split('/').last}'),
                const SizedBox(height: 20),
                AudioWaveforms(
                  size: Size(MediaQuery.of(context).size.width, 100.0),
                  playerController: _waveformController,
                  waveformType: WaveformType.long,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.0),
                    color: const Color(0xFF1E1E1E),
                  ),
                  waveColor: Colors.blueAccent,
                  padding: const EdgeInsets.all(10.0),
                  margin: const EdgeInsets.symmetric(horizontal: 15.0),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _playPause,
                  child: Text(_isPlaying ? 'Pause' : 'Play'),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton(
                      onPressed: _pickBackgroundImage,
                      child: const Text('Select Image'),
                    ),
                    ElevatedButton(
                      onPressed: _pickBackgroundVideo,
                      child: const Text('Select Video'),
                    ),
                  ],
                ),
                if (_backgroundImagePath != null)
                  Text('Image: ${_backgroundImagePath!.split('/').last}')
                else if (_backgroundVideoPath != null)
                  Text('Video: ${_backgroundVideoPath!.split('/').last}'),
                const SizedBox(height: 10),
                DropdownButton<String>(
                  value: _selectedResolution,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedResolution = newValue!;
                    });
                  },
                  items: _resolutions.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _lyrics.length,
              itemBuilder: (context, index) {
                final lyric = _lyrics[index];
                final isCurrent = index == _currentLyricIndex;
                return Card(
                  color: isCurrent ? Colors.blue.withOpacity(0.3) : null,
                  margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: ListTile(
                    title: Text(lyric.text),
                    subtitle: Text(
                      'Start: ${LrcParser.formatMilliseconds(lyric.startMs)} ' +
                          (lyric.endMs != null ? 'End: ${LrcParser.formatMilliseconds(lyric.endMs!)}' : ''),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: () => _adjustTimestamp(index, -50),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => _adjustTimestamp(index, 50),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _isRendering
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _renderVideo,
                    child: const Text('Render Video'),
                  ),
          ),
        ],
      ),
    );
  }
}
