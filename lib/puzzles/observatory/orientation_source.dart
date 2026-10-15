import 'package:flutter/services.dart';

class PointingSample {
  const PointingSample(this.azimuth, this.altitude);

  final double azimuth;
  final double altitude;

  bool get isValid =>
      azimuth.isFinite && altitude.isFinite && altitude.abs() <= 90;
}

abstract class OrientationSource {
  Stream<PointingSample> get samples;
}

class PlatformOrientationSource implements OrientationSource {
  static const channel = EventChannel('vestigia/game_orientation');

  @override
  Stream<PointingSample> get samples =>
      channel.receiveBroadcastStream().map((event) {
        final data = event as Map;
        final sample = PointingSample(
          (data['azimuth'] as num).toDouble(),
          (data['altitude'] as num).toDouble(),
        );
        if (!sample.isValid) throw const FormatException('Invalid orientation');
        return sample;
      });
}
