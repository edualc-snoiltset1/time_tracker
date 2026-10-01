import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:time_tracker/database/database.dart';
import 'package:time_tracker/screens/projects/projects_screen.dart';

void main() {
  testWidgets('shows hours used this month against the monthly limit', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1, 9);
    await tester.runAsync(() async {
      final clientId = await db.into(db.clients).insert(ClientsCompanion.insert(name: 'Acme'));
      final limited = await db.into(db.projects).insert(ProjectsCompanion.insert(
            clientId: clientId,
            name: 'Limited',
            hourlyRate: 50,
            monthlyTimeLimit: const Value(10),
          ));
      await db.into(db.projects).insert(ProjectsCompanion.insert(
            clientId: clientId,
            name: 'Unlimited',
            hourlyRate: 50,
          ));
      await db.into(db.timeEntries).insert(TimeEntriesCompanion.insert(
            projectId: limited,
            description: 'Work',
            startTime: monthStart,
            endTime: Value(monthStart.add(const Duration(hours: 9))),
            category: 'Dev',
          ));
    });

    await tester.pumpWidget(
      Provider<AppDatabase>.value(
        value: db,
        child: const MaterialApp(home: ProjectsScreen()),
      ),
    );
    // Let the drift streams emit.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();

    expect(find.text('Limited'), findsOneWidget);
    expect(find.text('Unlimited'), findsOneWidget);
    expect(find.text('9.0 / 10 h this month'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    // Unmount and flush drift's stream-cleanup timer before closing the database.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
    await tester.runAsync(db.close);
  });
}
