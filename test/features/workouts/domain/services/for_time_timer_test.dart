import 'package:flutter_test/flutter_test.dart';
import 'package:sagelift/features/workouts/domain/services/for_time_timer.dart';

void main() {
  test('For Time timer calculates elapsed time from its start timestamp', () {
    final DateTime startedAt = DateTime.utc(2026, 8, 8, 6);
    final ForTimeTimer timer = const ForTimeTimer().start(startedAt);

    expect(
      timer.elapsedAt(startedAt.add(const Duration(minutes: 18, seconds: 42))),
      const Duration(minutes: 18, seconds: 42),
    );
  });

  test('For Time timer excludes paused time after resume', () {
    final DateTime startedAt = DateTime.utc(2026, 8, 8, 6);
    final ForTimeTimer paused = const ForTimeTimer()
        .start(startedAt)
        .pause(startedAt.add(const Duration(minutes: 10)));
    final ForTimeTimer resumed = paused.start(
      startedAt.add(const Duration(minutes: 15)),
    );

    expect(
      resumed.elapsedAt(startedAt.add(const Duration(minutes: 20))),
      const Duration(minutes: 15),
    );
  });

  test('For Time timer catches up after a simulated app resume', () {
    final DateTime startedAt = DateTime.utc(2026, 8, 8, 6);
    final ForTimeTimer timer = const ForTimeTimer().start(startedAt);

    expect(
      timer.elapsedAt(startedAt.add(const Duration(minutes: 30))),
      const Duration(minutes: 30),
    );
  });
}
