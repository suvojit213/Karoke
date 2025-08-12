
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:my_flutter_app/data/models/project_model.dart';
import 'package:my_flutter_app/data/repositories/project_repository.dart';

class ProjectCreationScreen extends StatefulWidget {
  const ProjectCreationScreen({super.key});

  @override
  State<ProjectCreationScreen> createState() => _ProjectCreationScreenState();
}

class _ProjectCreationScreenState extends State<ProjectCreationScreen> {
  String? _audioFilePath;
  final TextEditingController _lyricsController = TextEditingController();
  final ProjectRepository _projectRepository = ProjectRepository();
  final Uuid _uuid = const Uuid();

  Future<void> _pickAudioFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result != null) {
      setState(() {
        _audioFilePath = result.files.single.path;
      });
    }
  }

  Future<void> _createProject() async {
    if (_audioFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an audio file.')),
      );
      return;
    }

    if (_lyricsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter lyrics.')),
      );
      return;
    }

    final String projectId = _uuid.v4();
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String projectDirPath = '${appDocDir.path}/projects/$projectId';
    await Directory(projectDirPath).create(recursive: true);

    final String lyricsFilePath = '$projectDirPath/lyrics.lrc';
    final File lyricsFile = File(lyricsFilePath);
    await lyricsFile.writeAsString(_lyricsController.text);

    final newProject = Project(
      id: projectId,
      title: _audioFilePath!.split('/').last.split('.').first, // Use audio file name as title
      audioPath: _audioFilePath!,
      lyricsPath: lyricsFilePath,
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
    );

    try {
      await _projectRepository.saveProject(newProject);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project created successfully!')),
      );
      Navigator.pop(context); // Go back to home screen
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating project: $e')),
      );
    }
  }

  @override
  void dispose() {
    _lyricsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Project'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _pickAudioFile,
              child: const Text('Select Audio File'),
            ),
            if (_audioFilePath != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text('Selected: ${_audioFilePath!.split('/').last}'),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _lyricsController,
              decoration: const InputDecoration(
                labelText: 'Enter Lyrics',
                border: OutlineInputBorder(),
              ),
              maxLines: 10,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _createProject,
              child: const Text('Create Project'),
            ),
          ],
        ),
      ),
    );
  }
}
