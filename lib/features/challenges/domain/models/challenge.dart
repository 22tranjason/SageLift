import 'challenge_day.dart';

/// The lifecycle state of a multi-day challenge.
enum ChallengeStatus {
  /// The challenge has not yet started.
  upcoming,

  /// The challenge is active.
  active,

  /// The challenge reached its intended end.
  completed,

  /// The challenge was ended before its intended completion.
  abandoned,
}

/// A dated challenge made up of individually trackable challenge days.
class Challenge {
  /// Creates an immutable challenge aggregate.
  Challenge({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.status,
    List<ChallengeDay> days = const <ChallengeDay>[],
    this.description,
  }) : _days = List<ChallengeDay>.unmodifiable(days);

  /// Stable, client-generated identifier for this challenge.
  final String id;

  /// Human-readable challenge title.
  final String title;

  /// Optional explanation or rules for the challenge.
  final String? description;

  /// Calendar date on which the challenge begins.
  final DateTime startDate;

  /// Calendar date on which the challenge ends.
  final DateTime endDate;

  /// Dated targets belonging to this challenge, in their defined order.
  List<ChallengeDay> get days => _days;
  final List<ChallengeDay> _days;

  /// Current lifecycle state of the challenge.
  final ChallengeStatus status;

  static const Object _unset = Object();

  /// Returns this challenge with selected values replaced.
  ///
  /// Pass `null` to [description] to clear it. Supplied [days] are copied into
  /// an unmodifiable list before being exposed.
  Challenge copyWith({
    String? id,
    String? title,
    Object? description = _unset,
    DateTime? startDate,
    DateTime? endDate,
    List<ChallengeDay>? days,
    ChallengeStatus? status,
  }) {
    return Challenge(
      id: id ?? this.id,
      title: title ?? this.title,
      description: identical(description, _unset)
          ? this.description
          : description as String?,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      days: days ?? _days,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Challenge &&
        other.id == id &&
        other.title == title &&
        other.description == description &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        _listEquals(other._days, _days) &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        description,
        startDate,
        endDate,
        Object.hashAll(_days),
        status,
      );
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (int index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
