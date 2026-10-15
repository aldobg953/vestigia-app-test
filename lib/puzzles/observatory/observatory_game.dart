import 'dart:math';

import '../../core/celestial_target.dart';
import 'orientation_source.dart';

enum ObservatoryPhase { coordinates, calibrating, searching, solved }

class ObservatoryConfig {
  const ObservatoryConfig({
    this.toleranceDegrees = 6,
    this.holdDuration = const Duration(seconds: 2),
    this.maxSampleAge = const Duration(milliseconds: 500),
  }) : assert(toleranceDegrees > 0 && toleranceDegrees < 90);

  final double toleranceDegrees;
  final Duration holdDuration;
  final Duration maxSampleAge;
}

double normalizeHeading(double degrees) => (degrees % 360 + 360) % 360;

double angularDistance(PointingSample a, PointingSample b) {
  const rad = pi / 180;
  final cosine =
      sin(a.altitude * rad) * sin(b.altitude * rad) +
      cos(a.altitude * rad) *
          cos(b.altitude * rad) *
          cos((a.azimuth - b.azimuth) * rad);
  return acos(cosine.clamp(-1.0, 1.0)) / rad;
}

class ObservatoryGame {
  ObservatoryGame([this.config = const ObservatoryConfig()])
    : assert(config.holdDuration > Duration.zero),
      assert(config.maxSampleAge > Duration.zero);

  final ObservatoryConfig config;
  static const target = PointingSample(
    PrototypeSky.azimuthDegrees,
    PrototypeSky.altitudeDegrees,
  );

  ObservatoryPhase phase = ObservatoryPhase.coordinates;
  PointingSample? _latest;
  Duration? _receivedAt;
  Duration? _lastAdvance;
  double? _northReference;
  Duration _hold = Duration.zero;

  PointingSample get pointing => PointingSample(
    _northReference == null
        ? 0
        : normalizeHeading((_latest?.azimuth ?? 0) - _northReference!),
    _latest?.altitude ?? 0,
  );

  double get separation => angularDistance(pointing, target);
  double get holdProgress =>
      (_hold.inMicroseconds / config.holdDuration.inMicroseconds).clamp(0, 1);

  bool hasFreshSample(Duration now) =>
      _latest != null &&
      _receivedAt != null &&
      now >= _receivedAt! &&
      now - _receivedAt! <= config.maxSampleAge;

  bool submitCodes(String ar, String dec) {
    if (phase != ObservatoryPhase.coordinates) return false;
    if (ar.trim() != PrototypeSky.radioDigits.join() ||
        dec.trim() != PrototypeSky.photoCode) {
      return false;
    }
    phase = ObservatoryPhase.calibrating;
    return true;
  }

  void receive(PointingSample sample, Duration now) {
    if (!sample.isValid) return;
    if (_receivedAt != null && now - _receivedAt! > config.maxSampleAge) {
      _hold = Duration.zero;
    }
    _latest = sample;
    _receivedAt = now;
    if (phase == ObservatoryPhase.searching &&
        separation > config.toleranceDegrees) {
      _hold = Duration.zero;
    }
  }

  bool calibrate(Duration now) {
    if (phase != ObservatoryPhase.calibrating ||
        !hasFreshSample(now) ||
        _latest!.altitude.abs() > 75) {
      return false;
    }
    _northReference = _latest!.azimuth;
    _hold = Duration.zero;
    _lastAdvance = now;
    phase = ObservatoryPhase.searching;
    return true;
  }

  void requestCalibration() {
    if (phase != ObservatoryPhase.searching) return;
    _northReference = null;
    _hold = Duration.zero;
    phase = ObservatoryPhase.calibrating;
  }

  /// Returns true only on the transition to solved. Missing samples cannot
  /// complete a hold, and a large frame gap discards the interrupted hold.
  bool advance(Duration now) {
    final previous = _lastAdvance;
    _lastAdvance = now;
    if (phase != ObservatoryPhase.searching) return false;
    if (!hasFreshSample(now) || separation > config.toleranceDegrees) {
      _hold = Duration.zero;
      return false;
    }
    if (previous == null || now < previous) return false;
    final delta = now - previous;
    if (delta > config.maxSampleAge) {
      _hold = Duration.zero;
      return false;
    }
    _hold += delta;
    if (_hold < config.holdDuration) return false;
    phase = ObservatoryPhase.solved;
    return true;
  }

  void suspend() {
    if (phase == ObservatoryPhase.solved) return;
    _latest = null;
    _receivedAt = null;
    _lastAdvance = null;
    _hold = Duration.zero;
    _northReference = null;
    if (phase == ObservatoryPhase.searching) {
      phase = ObservatoryPhase.calibrating;
    }
  }

  void reset() {
    phase = ObservatoryPhase.coordinates;
    suspend();
  }
}
