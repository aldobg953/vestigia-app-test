/// Fixed, fictional sky used by both lookout and observatory prototypes.
/// At latitude 20 N and local sidereal time 137 deg, AR 137 / DEC +42
/// culminates at altitude 68 deg, azimuth 0 deg. No live ephemeris is used.
abstract final class PrototypeSky {
  static const radioDigits = [1, 3, 7];
  static const photoCode = '+042';
  static const altitudeDegrees = 68.0;
  static const azimuthDegrees = 0.0;
}
