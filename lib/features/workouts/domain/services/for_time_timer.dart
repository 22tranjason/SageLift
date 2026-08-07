/// Timestamp-based state for a conditioning stopwatch.
///
/// Elapsed time is derived when read, so it catches up after normal navigation
/// or a browser/PWA resume rather than relying on per-second counters.
class ForTimeTimer {
  /// Creates a stopped timer with any previously accumulated [elapsed] time.
  const ForTimeTimer({
    this.startedAt,
    this.elapsed = Duration.zero,
  });

  /// Timestamp when the current running period began; null when paused/stopped.
  final DateTime? startedAt;

  /// Elapsed time accumulated before the current running period.
  final Duration elapsed;

  /// Whether the stopwatch is currently running.
  bool get isRunning => startedAt != null;

  /// Calculates elapsed time at [now].
  Duration elapsedAt(DateTime now) {
    final DateTime? started = startedAt;
    return started == null ? elapsed : elapsed + now.difference(started);
  }

  /// Starts a stopped stopwatch at [now].
  ForTimeTimer start(DateTime now) {
    return isRunning ? this : ForTimeTimer(startedAt: now, elapsed: elapsed);
  }

  /// Pauses a running stopwatch and retains its calculated elapsed time.
  ForTimeTimer pause(DateTime now) {
    return isRunning ? ForTimeTimer(elapsed: elapsedAt(now)) : this;
  }

  /// Stops a stopwatch and returns its final elapsed time.
  ForTimeTimer finish(DateTime now) => pause(now);
}
