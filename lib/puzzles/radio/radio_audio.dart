import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Sonido de la radio: ruido que se convierte en señal según la intensidad
/// calculada por la lógica del puzzle.
abstract class RadioAudio {
  void start(double signalStrength);
  void setSignalStrength(double strength);
  void pause();
  void resume();

  /// Detiene el sonido y libera los recursos. Llamar más de una vez no
  /// tiene efecto.
  void dispose();
}

/// Implementación Android: el ruido y la señal se sintetizan en tiempo real
/// en Kotlin (`RadioNoiseSynth`), sin archivos de audio.
class PlatformRadioAudio implements RadioAudio {
  PlatformRadioAudio({MethodChannel? channel})
    : _channel = channel ?? defaultChannel;

  static const MethodChannel defaultChannel = MethodChannel(
    'vestigia/radio_audio',
  );

  final MethodChannel _channel;
  bool _disposed = false;
  double? _lastSent;

  @override
  void start(double signalStrength) {
    _lastSent = signalStrength;
    _invoke('start', {'strength': signalStrength});
  }

  @override
  void setSignalStrength(double strength) {
    final last = _lastSent;
    // El lado nativo suaviza los cambios; no hace falta enviar cada frame.
    final reachedEnd = (strength == 0 || strength == 1) && strength != last;
    if (last != null && (strength - last).abs() < 0.01 && !reachedEnd) return;
    _lastSent = strength;
    _invoke('setStrength', {'strength': strength});
  }

  @override
  void pause() => _invoke('pause');

  @override
  void resume() => _invoke('resume');

  @override
  void dispose() {
    if (_disposed) return;
    _invoke('stop');
    _disposed = true;
  }

  void _invoke(String method, [Map<String, Object?>? arguments]) {
    if (_disposed) return;
    _channel.invokeMethod<void>(method, arguments).catchError((Object error) {
      // El puzzle sigue siendo jugable sin sonido.
      debugPrint('RadioAudio.$method falló: $error');
    });
  }
}
