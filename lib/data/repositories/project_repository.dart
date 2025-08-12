
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:my_flutter_app/data/models/project_model.dart';

class ProjectRepository {
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> _localFile(String projectId) async {
    final path = await _localPath;
    return File('$path/projects/$projectId.json');
  }

  Future<Project> saveProject(Project project) async {
    final file = await _localFile(project.id);
    await file.create(recursive: true);
    await file.writeAsString(jsonEncode(project.toJson()));
    return project;
  }

  Future<Project?> loadProject(String projectId) async {
    try {
      final file = await _localFile(projectId);
      if (!await file.exists()) {
        return null;
      }
      final contents = await file.readAsString();
      return Project.fromJson(jsonDecode(contents));
    } catch (e) {
      // If encountering an error, return null
      return null;
    }
  }

  Future<List<Project>> loadAllProjects() async {
    final path = await _localPath;
    final projectsDir = Directory('$path/projects');
    if (!await projectsDir.exists()) {
      return [];
    }
    final files = projectsDir.listSync().whereType<File>().toList();
    List<Project> projects = [];
    for (var file in files) {
      if (file.path.endsWith('.json')) {
        final contents = await file.readAsString();
        try {
          projects.add(Project.fromJson(jsonDecode(contents)));
        } catch (e) {
          // Handle corrupted project files
          print('Error loading project from ${file.path}: $e');
        }
      }
    }
    return projects;
  }
}
