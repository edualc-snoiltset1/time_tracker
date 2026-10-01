// lib/screens/projects/projects_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:time_tracker/database/database.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:time_tracker/screens/projects/project_edit_screen.dart';
import 'package:time_tracker/utils/monthly_usage.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  void _deleteProject(BuildContext context, Project project) {
    final db = Provider.of<AppDatabase>(context, listen: false);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Project'),
          content: Text('Are you sure you want to delete ${project.name}? This will also delete all associated time entries and expenses.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onPressed: () {
                db.delete(db.projects).where((p) => p.id.equals(project.id));
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Color _limitColor(BuildContext context, LimitStatus status) {
    switch (status) {
      case LimitStatus.limitReached:
        return Theme.of(context).colorScheme.error;
      case LimitStatus.nearingLimit:
        return Colors.orangeAccent;
      case LimitStatus.withinLimit:
      case LimitStatus.noLimit:
        return Colors.tealAccent;
    }
  }

  // Shows this month's tracked hours against the project's monthly limit.
  Widget _buildSubtitle(BuildContext context, Project project, Client client, double usedHours) {
    final limit = project.monthlyTimeLimit;
    final status = limitStatus(usedHours, limit);
    if (status == LimitStatus.noLimit) {
      return Text(client.name);
    }
    final color = _limitColor(context, status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(client.name),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: (usedHours / limit!).clamp(0.0, 1.0),
          color: color,
          backgroundColor: color.withAlpha(51),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (status != LimitStatus.withinLimit) ...[
              Icon(Icons.warning_amber, size: 14, color: color),
              const SizedBox(width: 4),
            ],
            Text(
              '${usedHours.toStringAsFixed(1)} / $limit h this month',
              style: TextStyle(fontSize: 12, color: status == LimitStatus.withinLimit ? null : color),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context);
    final query = db.select(db.projects).join([
      innerJoin(db.clients, db.clients.id.equalsExp(db.projects.clientId))
    ]);
    final month = monthRange(DateTime.now());
    final monthEntriesQuery = db.select(db.timeEntries)
      ..where((t) =>
          t.startTime.isSmallerThanValue(month.end) &
          (t.endTime.isNull() | t.endTime.isBiggerThanValue(month.start)));

    return Scaffold(
      body: StreamBuilder<List<TimeEntry>>(
        stream: monthEntriesQuery.watch(),
        builder: (context, entriesSnapshot) {
          final entriesByProject = <int, List<TimeEntry>>{};
          for (final entry in entriesSnapshot.data ?? <TimeEntry>[]) {
            entriesByProject.putIfAbsent(entry.projectId, () => []).add(entry);
          }
          return StreamBuilder(
            stream: query.watch(),
            builder: (context, snapshot) {
              final projectsWithClients = snapshot.data ?? [];
              if (projectsWithClients.isEmpty && snapshot.connectionState == ConnectionState.active) {
                return const Center(child: Text("No projects found. Click '+' to add one!"));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView.builder(
                itemCount: projectsWithClients.length,
                itemBuilder: (context, index) {
                  final result = projectsWithClients[index];
                  final project = result.readTable(db.projects);
                  final client = result.readTable(db.clients);

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Dismissible(
                      key: Key(project.id.toString()),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.redAccent,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => _deleteProject(context, project),
                      child: ListTile(
                        title: Text(project.name),
                        subtitle: _buildSubtitle(
                          context,
                          project,
                          client,
                          hoursInRange(entriesByProject[project.id] ?? const [], month.start, month.end, DateTime.now()),
                        ),
                        trailing: Text('\$${project.hourlyRate.toStringAsFixed(2)}/hr'),
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => ProjectEditScreen(project: project),
                          ));
                        },
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => const ProjectEditScreen(),
          ));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}