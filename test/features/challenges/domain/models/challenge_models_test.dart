import 'package:flutter_test/flutter_test.dart';
import 'package:sagelift/features/challenges/domain/models/challenge.dart';
import 'package:sagelift/features/challenges/domain/models/challenge_day.dart';

void main() {
  ChallengeDay createDay() {
    return ChallengeDay(
      id: 'challenge-day-1',
      challengeId: 'challenge-1',
      date: DateTime.utc(2026, 8, 1),
      targetDescription: 'Walk 10,000 steps',
      targetValue: 10000,
      progressValue: 7500,
      unit: ChallengeProgressUnit.count,
      status: ChallengeDayStatus.pending,
    );
  }

  Challenge createChallenge({List<ChallengeDay>? days}) {
    return Challenge(
      id: 'challenge-1',
      title: '42-day consistency',
      description: 'Build a sustainable training habit.',
      startDate: DateTime.utc(2026, 8, 1),
      endDate: DateTime.utc(2026, 9, 11),
      status: ChallengeStatus.upcoming,
      days: days ?? <ChallengeDay>[createDay()],
    );
  }

  test('ChallengeDay uses value equality', () {
    final ChallengeDay day = createDay();

    expect(day, equals(day.copyWith()));
    expect(day.hashCode, day.copyWith().hashCode);
  });

  test('Challenge compares ordered days by value', () {
    final Challenge first = createChallenge();
    final Challenge equal = createChallenge();
    final Challenge different = createChallenge(
      days: <ChallengeDay>[
        createDay().copyWith(id: 'challenge-day-2'),
        createDay()
      ],
    );

    expect(first, equals(equal));
    expect(first.hashCode, equal.hashCode);
    expect(first, isNot(equals(different)));
  });

  test('Challenge copies and exposes an unmodifiable day list', () {
    final List<ChallengeDay> days = <ChallengeDay>[createDay()];
    final Challenge challenge = createChallenge(days: days);

    days.clear();

    expect(challenge.days, hasLength(1));
    expect(
      () => challenge.days.add(createDay()),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('copyWith can intentionally clear a challenge description', () {
    final Challenge cleared = createChallenge().copyWith(description: null);

    expect(cleared.description, isNull);
  });
}
