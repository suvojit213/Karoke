
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_flutter_app/data/repositories/project_provider.dart';
import 'package:my_flutter_app/features/project/screens/project_creation_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsyncValue = ref.watch(projectListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Karaoke Projects'),
      ),
      body: projectsAsyncValue.when(
        data: (projects) {
          if (projects.isEmpty) {
            return const Center(
              child: Text('No projects yet. Create a new one!'),
            );
          }
          return ListView.builder(
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text(project.title),
                  subtitle: Text('Created: ${project.createdAt.toLocal().toString().split('.')[0]}'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SyncEditorScreen(project: project),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProjectCreationScreen()),
          );
          ref.invalidate(projectListProvider); // Refresh projects after returning
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
