import 'package:flutter/material.dart';

import '../../domain/models/exercise.dart';

/// Displays a workout's resolved exercises in their defined order.
class WorkoutExerciseList extends StatelessWidget {
  /// Creates an exercise list.
  const WorkoutExerciseList({required this.exercises, super.key});

  /// Exercises to display.
  final List<Exercise> exercises;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: <Widget>[
          for (int index = 0; index < exercises.length; index++)
            ListTile(
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: Text(exercises[index].name),
              subtitle: Text(_labelFor(exercises[index])),
              onTap: () {},
            ),
        ],
      ),
    );
  }

  String _labelFor(Exercise exercise) {
    return '${exercise.category.name} • ${exercise.equipment.name}';
  }
}
