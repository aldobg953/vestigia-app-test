import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Vibraciones disponibles para los puzzles. Los patrones concretos viven en
/// Kotlin (`VestigiaHaptics`).
enum HapticCue {
  /// Toque muy ligero al pasar una muesca de la perilla.
  tick,

  /// Golpe seco al llegar a un tope.
  limit,

  /// Doble pulso al entrar en la franja de una señal.
  signalFound,

  /// Patrón al captar un dígito.
  capture,

  /// Patrón largo al completar el puzzle.
  complete,

  /// Vibración breve al completar la fotografía.
  photoSolved,
}

abstract class Haptics {
  void play(HapticCue cue);
}

class PlatformHaptics implements Haptics {
  PlatformHaptics({MethodChannel? channel})
    : _channel = channel ?? defaultChannel;

  static const MethodChannel defaultChannel = MethodChannel('vestigia/haptics');

  final MethodChannel _channel;

  @override
  void play(HapticCue cue) {
    _channel.invokeMethod<void>('play', {'cue': cue.name}).catchError((
      Object error,
    ) {
      debugPrint('Haptics.${cue.name} falló: $error');
    });
  }
}
