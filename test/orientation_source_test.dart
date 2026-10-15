import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radio_coordenadas/puzzles/observatory/orientation_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const codec = StandardMethodCodec();
  const name = 'vestigia/game_orientation';
  const control = MethodChannel(name);

  test('canal convierte lecturas numéricas y cancela la suscripción', () async {
    final calls = <String>[];
    final samples = <PointingSample>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(control, (call) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(control, null));
    final subscription = PlatformOrientationSource().samples.listen(
      samples.add,
    );
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['listen']);
    ServicesBinding.instance.channelBuffers.push(
      name,
      codec.encodeSuccessEnvelope({'azimuth': 12, 'altitude': 34.5}),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
    expect(samples.single.azimuth, 12);
    expect(samples.single.altitude, 34.5);
    await subscription.cancel();
    expect(calls, ['listen', 'cancel']);
  });

  test('canal propaga sensor ausente y rechaza lectura inválida', () async {
    final errors = <Object>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(control, (_) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(control, null));
    final subscription = PlatformOrientationSource().samples.listen(
      (_) => fail('Invalid sample accepted'),
      onError: errors.add,
    );
    await Future<void>.delayed(Duration.zero);
    ServicesBinding.instance.channelBuffers.push(
      name,
      codec.encodeSuccessEnvelope({'azimuth': double.nan, 'altitude': 20}),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
    expect(errors.single, isA<FormatException>());
    ServicesBinding.instance.channelBuffers.push(
      name,
      codec.encodeErrorEnvelope(
        code: 'sensor_unavailable',
        message: 'Missing sensor',
      ),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      errors.last,
      isA<PlatformException>().having(
        (e) => e.code,
        'code',
        'sensor_unavailable',
      ),
    );
    await subscription.cancel();
  });
}
