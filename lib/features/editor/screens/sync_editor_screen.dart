
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:my_flutter_app/data/models/lyric_line_model.dart';
import 'package:my_flutter_app/data/models/project_model.dart';
import 'package:my_flutter_app/data/repositories/project_repository.dart';
import 'package:my_flutter_app/utils/lrc_parser.dart';
import 'package:my_flutter_app/features/editor/screens/review_editor_screen.dart';

class SyncEditorScreen extends StatefulWidget {
  final Project project;

  const SyncEditorScreen({super.key, required this.project});

  @override
  State<SyncEditorScreen> createState() => _SyncEditorScreenState();
}

class _SyncEditorScreenState extends State<SyncEditorScreen> {
  late AudioPlayer _audioPlayer;
  late PlayerController _waveformController;
  bool _isPlaying = false;
  List<LyricLine> _lyrics = [];
  int _currentLyricIndex = -1;
  int _currentLyricIndexToSync = 0; // Index of the lyric line to be synced next
  final ProjectRepository _projectRepository = ProjectRepository();

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

  Future<void> _markTimestamp() async {
    if (_currentLyricIndexToSync >= _lyrics.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All lyrics synced!')),
      );
      return;
    }

    final currentPosition = _audioPlayer.position.inMilliseconds;

    setState(() {
      // Set startMs for the current lyric line being synced
      _lyrics[_currentLyricIndexToSync].startMs = currentPosition;

      // Set endMs for the previous lyric line
      if (_currentLyricIndexToSync > 0) {
        _lyrics[_currentLyricIndexToSync - 1].endMs = currentPosition;
      }
      _currentLyricIndexToSync++;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Marked: ${LrcParser.formatMilliseconds(currentPosition)}')),
    );

    // Save updated lyrics to file
    await _saveLyricsToFile();
  }

  Future<void> _saveLyricsToFile() async {
    if (widget.project.lyricsPath != null) {
      final File lyricsFile = File(widget.project.lyricsPath!);
      final String lrcContent = LrcParser.generateLrc(_lyrics);
      await lyricsFile.writeAsString(lrcContent);
      // Optionally, update the project's modifiedAt timestamp
      final updatedProject = widget.project.copyWith(modifiedAt: DateTime.now());
      await _projectRepository.saveProject(updatedProject);
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

  void _finishSync() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewEditorScreen(project: widget.project),
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _waveformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool allLyricsSynced = _currentLyricIndexToSync >= _lyrics.length && _lyrics.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('Sync: ${widget.project.title}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Audio: ${widget.project.audioPath.split('/').last}'),
            const SizedBox(height: 20),
            AudioWaveforms(
              size: Size(MediaQuery.of(context).size.width, 100.0),
              controller: _waveformController,
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
            if (!allLyricsSynced)
              ElevatedButton(
                onPressed: _markTimestamp,
                child: const Text('Mark'),
              ) else
              ElevatedButton(
                onPressed: _finishSync,
                child: const Text('Finish Sync & Review'),
              ),
            const SizedBox(height: 20),
            if (_lyrics.isNotEmpty && _currentLyricIndexToSync < _lyrics.length)
              Text(
                'Next to sync: ${_lyrics[_currentLyricIndexToSync].text}',
                style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 10),
            if (_lyrics.isNotEmpty && _currentLyricIndex != -1)
              Text(
                _lyrics[_currentLyricIndex].text,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ) else if (_lyrics.isEmpty)
              const Text('No lyrics loaded.')
            else
              const Text('Waiting for audio...'),
            const SizedBox(height: 20),
            Text('Synced: $_currentLyricIndexToSync / ${_lyrics.length}'),
          ],
        ),
      ),
    );
  }
}
