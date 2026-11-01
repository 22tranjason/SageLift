import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/exercise.dart';
import '../../domain/models/workout.dart';
import '../../domain/models/workout_set.dart';
import '../../domain/services/exercise_progress_history.dart';
import '../formatters/workout_weight_format.dart';
import '../providers/today_workout_provider.dart';

final FutureProvider<_ProgressData> _dataProvider =
    FutureProvider<_ProgressData>((Ref ref) async {
  ref.watch(workoutDataRevisionProvider);
  final List<Workout> workouts =
      await ref.read(workoutRepositoryProvider).getAll();
  final List<Exercise> catalogue =
      await ref.read(exerciseRepositoryProvider).getAll();
  final Map<String, String> names = <String, String>{
    for (final Exercise e in catalogue) e.id: e.name
  };
  for (final Workout w
      in workouts.where((Workout w) => w.status == WorkoutStatus.completed)) {
    for (final WorkoutSet s in w.sets) {
      names.putIfAbsent(s.exerciseId, () => s.exerciseId);
    }
  }
  return _ProgressData(workouts, names);
});

class _ProgressData {
  const _ProgressData(this.workouts, this.names);
  final List<Workout> workouts;
  final Map<String, String> names;
}

/// Local-only per-exercise history from the earliest available saved session.
class ProgressScreen extends ConsumerStatefulWidget {
  /// Creates the initial, deliberately simple progress view.
  const ProgressScreen({super.key});
  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  String? _exercise;
  String? _selectedSession;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Progress')),
        body: SafeArea(
            child: ref.watch(_dataProvider).when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (Object error, StackTrace stack) => const Center(
                      child: Text(
                          'Unable to load progress. Your saved workouts have not changed.')),
                  data: (_ProgressData data) {
                    final List<String> ids = data.names.keys.toList()
                      ..sort((String a, String b) =>
                          data.names[a]!.compareTo(data.names[b]!));
                    if (ids.isEmpty) {
                      return const Center(
                          child: Text(
                              'No exercises saved yet. Complete a workout to see progress.'));
                    }
                    final String id = ids.contains(_exercise)
                        ? _exercise!
                        : ids.firstWhere(
                            (String id) => ExerciseProgressHistory.points(
                                    data.workouts, id)
                                .isNotEmpty,
                            orElse: () => ids.first);
                    final List<ExerciseProgressPoint> points =
                        ExerciseProgressHistory.points(data.workouts, id);
                    final List<ExerciseProgressPoint> plotted = points
                        .where((ExerciseProgressPoint p) => p.weightKg != null)
                        .toList();
                    void select(ExerciseProgressPoint point) {
                      setState(() => _selectedSession = point.workout.id);
                      showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (BuildContext context) => SafeArea(
                              child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                            '${_date(point.date)} ${_time(point.date)} • ${point.workout.name}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium),
                                        for (final WorkoutSet set in point.sets)
                                          Text(
                                              'Set ${set.setNumber}: ${formatWorkoutWeight(set.weightKg)} kg × ${set.reps ?? '—'} reps${ExerciseProgressHistory.isWarmUp(set) ? ' • Warm-up (excluded)' : ''}'),
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('Close')),
                                      ]))));
                    }

                    return ListView(
                        padding: const EdgeInsets.all(16),
                        children: <Widget>[
                          DropdownButtonFormField<String>(
                              key: ValueKey<String>('exercise-$id'),
                              initialValue: id,
                              isExpanded: true,
                              decoration:
                                  const InputDecoration(labelText: 'Exercise'),
                              items: ids
                                  .map((String id) => DropdownMenuItem<String>(
                                      value: id,
                                      child: Text(data.names[id]!,
                                          overflow: TextOverflow.ellipsis)))
                                  .toList(),
                              onChanged: (String? id) => setState(() {
                                    _exercise = id;
                                    _selectedSession = null;
                                  })),
                          const SizedBox(height: 16),
                          const Text(
                              'Heaviest logged working-set weight per completed workout (kg). Tap a point for actual sets and reps. A heavier load alone does not mean better performance.'),
                          const SizedBox(height: 12),
                          if (points.isEmpty)
                            const Padding(
                                padding: EdgeInsets.symmetric(vertical: 32),
                                child: Text(
                                    'No completed sets for this exercise yet.'))
                          else ...<Widget>[
                            Text(
                                'All saved history: ${_date(points.first.date)} – ${_date(points.last.date)}'),
                            if (plotted.isEmpty)
                              const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                      'No recorded weight to plot. Reps and session details are listed below.'))
                            else
                              SizedBox(
                                  height: 260,
                                  child: LayoutBuilder(builder:
                                      (BuildContext context,
                                          BoxConstraints constraints) {
                                    final double width = math.max(
                                        constraints.maxWidth,
                                        plotted.length * 48.0 + 72);
                                    final _LoadPainter painter = _LoadPainter(
                                        plotted,
                                        Theme.of(context).colorScheme.primary,
                                        Theme.of(context)
                                            .colorScheme
                                            .onSurface);
                                    return SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTapUp: (TapUpDetails detail) {
                                            final List<Offset> positions =
                                                painter.positions(
                                                    Size(width, 260));
                                            int closest = 0;
                                            double distance = double.infinity;
                                            for (int i = 0;
                                                i < positions.length;
                                                i++) {
                                              final double d = (positions[i] -
                                                      detail.localPosition)
                                                  .distance;
                                              if (d < distance) {
                                                closest = i;
                                                distance = d;
                                              }
                                            }
                                            if (distance <= 36) {
                                              select(plotted[closest]);
                                            }
                                          },
                                          child: Semantics(
                                              label:
                                                  'Weight history chart. Choose a dated session below to inspect the same points.',
                                              child: CustomPaint(
                                                  key: const ValueKey<String>(
                                                      'progress-chart'),
                                                  size: Size(width, 260),
                                                  painter: painter)),
                                        ));
                                  })),
                            const Text(
                                'Sessions on the same date are shown separately on the chart. All sessions remain separate.'),
                            const SizedBox(height: 8),
                            const Text(
                                'Dates use completion time, or start/scheduled time for older records. Sets explicitly labelled warm-up in notes are excluded from the plotted maximum; older unlabelled warm-ups cannot be separated.'),
                            const SizedBox(height: 12),
                            for (final ExerciseProgressPoint point in points)
                              ListTile(
                                  key: ValueKey<String>(
                                      'progress-session-${point.workout.id}'),
                                  title: Text(
                                      '${_date(point.date)} ${_time(point.date)} • ${point.workout.name}'),
                                  subtitle: Text(point.weightKg == null
                                      ? 'No recorded working-set weight • View sets'
                                      : '${formatWorkoutWeight(point.weightKg)} kg maximum • View sets'),
                                  selected:
                                      point.workout.id == _selectedSession,
                                  onTap: () => select(point)),
                          ],
                        ]);
                  },
                )),
      );
}

String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';

String _time(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

class _LoadPainter extends CustomPainter {
  _LoadPainter(this.points, this.color, this.ink);
  final List<ExerciseProgressPoint> points;
  final Color color;
  final Color ink;
  double get _maximum => math.max(
      1, points.map((ExerciseProgressPoint p) => p.weightKg!).reduce(math.max));
  List<Offset> positions(Size size) {
    final List<int> dates = points
        .map((ExerciseProgressPoint p) =>
            DateTime.utc(p.date.year, p.date.month, p.date.day)
                .millisecondsSinceEpoch)
        .toList();
    final int span = dates.last - dates.first;
    final List<Offset> result = <Offset>[];
    for (int i = 0; i < points.length; i++) {
      final int sameDate = dates.where((int d) => d == dates[i]).length;
      final int before = dates.take(i).where((int d) => d == dates[i]).length;
      final double halfGroup = (sameDate - 1) * 6.0;
      final double centre = span == 0
          ? size.width / 2
          : (54 + (size.width - 84) * (dates[i] - dates.first) / span)
              .clamp(54 + halfGroup, size.width - 30 - halfGroup)
              .toDouble();
      result.add(Offset(centre + before * 12 - halfGroup,
          208 - 176 * points[i].weightKg! / _maximum));
    }
    return result;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Paint axis = Paint()
      ..color = ink
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(50, 24), const Offset(50, 208), axis);
    canvas.drawLine(const Offset(50, 208), Offset(size.width - 16, 208), axis);
    void label(String text, Offset at) {
      final TextPainter tp = TextPainter(
          text:
              TextSpan(text: text, style: TextStyle(color: ink, fontSize: 11)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, at);
    }

    for (final double f in <double>[0, 0.5, 1]) {
      label(
          '${formatWorkoutWeight(_maximum * f)} kg', Offset(0, 202 - 176 * f));
    }
    final List<Offset> dots = positions(size);
    final Paint line = Paint()
      ..color = color
      ..strokeWidth = 2;
    for (int i = 1; i < dots.length; i++) {
      canvas.drawLine(dots[i - 1], dots[i], line);
    }
    for (final Offset dot in dots) {
      canvas.drawCircle(dot, 5, line);
    }
    label(_date(points.first.date), const Offset(50, 220));
    if (points.length > 1) {
      label(_date(points.last.date), Offset(size.width - 90, 238));
    }
  }

  @override
  bool shouldRepaint(covariant _LoadPainter oldDelegate) => true;
}
