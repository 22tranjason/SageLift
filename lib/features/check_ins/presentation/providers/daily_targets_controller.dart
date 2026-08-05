import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../habits/domain/models/habit.dart';
import '../../../habits/domain/repositories/habit_repository.dart';
import '../../domain/models/daily_check_in.dart';
import '../../domain/repositories/daily_check_in_repository.dart';

/// Supplies persisted daily check-ins to the daily-target presentation layer.
final Provider<DailyCheckInRepository> dailyCheckInRepositoryProvider =
    Provider<DailyCheckInRepository>((Ref ref) {
  throw UnimplementedError(
    'DailyCheckInRepository must be provided during bootstrap.',
  );
});

/// Supplies persisted habit definitions to today's target list.
final Provider<HabitRepository> habitRepositoryProvider =
    Provider<HabitRepository>((Ref ref) {
  throw UnimplementedError(
      'HabitRepository must be provided during bootstrap.');
});

/// Clock seam used to test local-calendar-day behaviour deterministically.
final Provider<DateTime Function()> dailyTargetsNowProvider =
    Provider<DateTime Function()>((Ref ref) => DateTime.now);

/// Persisted values entered for one local calendar day.
class DailyTargets {
  /// Creates immutable values for [date].
  DailyTargets({
    required this.date,
    this.proteinGrams = 0,
    this.waterMillilitres = 0,
    this.steps = 0,
    List<DailyHabitProgress> habits = const <DailyHabitProgress>[],
  }) : _habits = List<DailyHabitProgress>.unmodifiable(habits);

  /// The local calendar date represented by these targets.
  final DateTime date;

  /// Protein entered for the current day, in grams.
  final double proteinGrams;

  /// Water entered for the current day, in millilitres.
  final double waterMillilitres;

  /// Manually entered steps until a health integration is available.
  final int steps;

  final List<DailyHabitProgress> _habits;

  /// Today's available habits and their persisted completion state.
  List<DailyHabitProgress> get habits => _habits;

  /// Returns this state with selected values replaced.
  DailyTargets copyWith({
    DateTime? date,
    double? proteinGrams,
    double? waterMillilitres,
    int? steps,
    List<DailyHabitProgress>? habits,
  }) {
    return DailyTargets(
      date: date ?? this.date,
      proteinGrams: proteinGrams ?? this.proteinGrams,
      waterMillilitres: waterMillilitres ?? this.waterMillilitres,
      steps: steps ?? this.steps,
      habits: habits ?? _habits,
    );
  }
}

/// One habit displayed in today's target list.
class DailyHabitProgress {
  /// Creates a habit completion value for today.
  const DailyHabitProgress({
    required this.id,
    required this.name,
    this.isCompleted = false,
  });

  /// Stable identifier from the habit source.
  final String id;

  /// Display name of the habit.
  final String name;

  /// Whether the user has marked this habit complete today.
  final bool isCompleted;

  /// Returns this habit with a new completion state.
  DailyHabitProgress copyWith({bool? isCompleted}) {
    return DailyHabitProgress(
      id: id,
      name: name,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

/// Exposes the current local day's persisted daily targets.
final NotifierProvider<DailyTargetsController, DailyTargets>
    dailyTargetsControllerProvider =
    NotifierProvider<DailyTargetsController, DailyTargets>(
  DailyTargetsController.new,
);

/// Updates one local day's targets through [DailyCheckInRepository].
class DailyTargetsController extends Notifier<DailyTargets> {
  late final DailyCheckInRepository _repository;
  late final HabitRepository _habitRepository;
  late final DateTime Function() _now;

  @override
  DailyTargets build() {
    _repository = ref.read(dailyCheckInRepositoryProvider);
    _habitRepository = ref.read(habitRepositoryProvider);
    _now = ref.read(dailyTargetsNowProvider);
    final DateTime today = _localDay(_now());
    unawaited(_load(today));
    return DailyTargets(date: today);
  }

  /// Reloads values when the local calendar day changes.
  Future<void> refreshForCurrentDay() => _load(_localDay(_now()));

  /// Adds [grams] of protein to today's persisted total.
  Future<void> addProtein(double grams) async {
    if (grams <= 0) return;
    await _ensureCurrentDay();
    state = state.copyWith(proteinGrams: state.proteinGrams + grams);
    await _save();
  }

  /// Adds [millilitres] of water to today's persisted total.
  Future<void> addWater(double millilitres) async {
    if (millilitres <= 0) return;
    await _ensureCurrentDay();
    state = state.copyWith(
      waterMillilitres: state.waterMillilitres + millilitres,
    );
    await _save();
  }

  /// Replaces today's manually entered step count.
  Future<void> setSteps(int steps) async {
    if (steps < 0) return;
    await _ensureCurrentDay();
    state = state.copyWith(steps: steps);
    await _save();
  }

  /// Supplies habits that apply today and restores their saved completion state.
  Future<void> setHabits(List<DailyHabitProgress> habits) async {
    await _ensureCurrentDay();
    final Set<String> completedIds = state.habits
        .where((DailyHabitProgress habit) => habit.isCompleted)
        .map((DailyHabitProgress habit) => habit.id)
        .toSet();
    state = state.copyWith(
      habits: habits
          .map(
            (DailyHabitProgress habit) => habit.copyWith(
              isCompleted: completedIds.contains(habit.id),
            ),
          )
          .toList(growable: false),
    );
    await _save();
  }

  /// Toggles today's persisted completion state for [habitId].
  Future<void> toggleHabit(String habitId) async {
    await _ensureCurrentDay();
    state = state.copyWith(
      habits: state.habits
          .map(
            (DailyHabitProgress habit) => habit.id == habitId
                ? habit.copyWith(isCompleted: !habit.isCompleted)
                : habit,
          )
          .toList(growable: false),
    );
    await _save();
  }

  Future<void> _ensureCurrentDay() async {
    final DateTime today = _localDay(_now());
    if (_sameDay(state.date, today)) return;
    await _load(today);
  }

  Future<void> _load(DateTime date) async {
    final DailyCheckIn? checkIn = await _repository.getByDate(date);
    final List<Habit> habits = await _habitRepository.getActive();
    if (!_sameDay(_localDay(_now()), date)) return;
    final Set<String> completedIds =
        checkIn?.completedHabitIds.toSet() ?? <String>{};
    state = DailyTargets(
      date: date,
      proteinGrams: checkIn?.proteinGrams ?? 0,
      waterMillilitres: checkIn?.waterMillilitres ?? 0,
      steps: checkIn?.steps ?? 0,
      habits: habits
          .where((Habit habit) => _appliesOn(habit, date))
          .map(
            (Habit habit) => DailyHabitProgress(
              id: habit.id,
              name: habit.name,
              isCompleted: completedIds.contains(habit.id),
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> _save() {
    final List<String> completedHabitIds = state.habits
        .where((DailyHabitProgress habit) => habit.isCompleted)
        .map((DailyHabitProgress habit) => habit.id)
        .toList(growable: false);
    return _repository.save(
      DailyCheckIn(
        id: 'daily-check-in-${_dateKey(state.date)}',
        date: state.date,
        bodyWeightKg: 0,
        proteinGrams: state.proteinGrams,
        waterMillilitres: state.waterMillilitres,
        steps: state.steps,
        completedHabitIds: completedHabitIds,
      ),
    );
  }

  DateTime _localDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _sameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  bool _appliesOn(Habit habit, DateTime date) {
    return habit.activeDays.isEmpty ||
        habit.activeDays.contains(Weekday.values[date.weekday - 1]);
  }

  String _dateKey(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
