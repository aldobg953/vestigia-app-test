import 'package:flutter_test/flutter_test.dart';
import 'package:radio_coordenadas/core/dial_feedback.dart';

Duration ms(int value) => Duration(milliseconds: value);

void main() {
  test('vibra al cruzar una muesca, no dentro de la misma', () {
    final tracker = DialDetentTracker()..reset(0.5);
    expect(tracker.onMoved(0.505, ms(0)), DialFeedback.none);
    expect(tracker.onMoved(0.512, ms(100)), DialFeedback.detent);
    expect(tracker.onMoved(0.515, ms(200)), DialFeedback.none);
    expect(tracker.onMoved(0.498, ms(300)), DialFeedback.detent);
  });

  test('limita la frecuencia de las vibraciones ligeras', () {
    final tracker = DialDetentTracker()..reset(0.5);
    expect(tracker.onMoved(0.515, ms(0)), DialFeedback.detent);
    expect(tracker.onMoved(0.525, ms(10)), DialFeedback.none);
    expect(tracker.onMoved(0.535, ms(30)), DialFeedback.none);
    expect(tracker.onMoved(0.545, ms(50)), DialFeedback.detent);
  });

  test('marca el tope una sola vez hasta separarse de él', () {
    final tracker = DialDetentTracker()..reset(0.02);
    expect(tracker.onMoved(0, ms(0)), DialFeedback.limit);
    expect(tracker.onMoved(0, ms(100)), DialFeedback.none);
    tracker.onMoved(0.05, ms(200));
    expect(tracker.onMoved(0, ms(300)), DialFeedback.limit);
    tracker.reset(0.99);
    expect(tracker.onMoved(1, ms(400)), DialFeedback.limit);
  });
}
