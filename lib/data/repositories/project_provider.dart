
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_flutter_app/data/models/project_model.dart';
import 'package:my_flutter_app/data/repositories/project_repository.dart';

final projectRepositoryProvider = Provider((ref) => ProjectRepository());

final projectListProvider = FutureProvider<List<Project>>((ref) async {
  final projectRepository = ref.watch(projectRepositoryProvider);
  return projectRepository.loadAllProjects();
});
