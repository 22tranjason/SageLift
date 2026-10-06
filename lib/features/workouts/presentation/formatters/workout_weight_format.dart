/// Displays the recorded load without rounding fractional kilograms.
/// Whole kilograms omit the redundant decimal; missing values stay explicit.
String formatWorkoutWeight(double? weight) =>
    weight?.toString().replaceFirst(RegExp(r'\.0$'), '') ?? '—';
