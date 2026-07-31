/// Build-time developer flags. All default to false, so production builds are
/// never affected unless the flag is explicitly passed at build time, e.g.:
///
///   flutter run --dart-define=UNLOCK_ALL=true
class DevFlags {
  const DevFlags._();

  /// Unlocks every unit and lesson regardless of progress — for reviewing
  /// content without playing through the prerequisites. Never enabled in a
  /// normal build.
  static const bool unlockAll = bool.fromEnvironment(
    'UNLOCK_ALL',
    defaultValue: false,
  );
}
