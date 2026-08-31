import 'package:czechify/domain/engines/silence_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Duration ms(int m) => Duration(milliseconds: m);

  test('never stops before any speech is detected', () {
    final d = SilenceDetector(silenceTimeout: ms(3000));
    // Flat quiet input: no rise above the floor, so speech never starts.
    for (var t = 0; t <= 10000; t += 150) {
      expect(d.accept(-60, ms(t)), isFalse);
    }
    expect(d.speechStarted, isFalse);
  });

  test('detects speech relative to the noise floor, whatever the scale', () {
    // Ambient floor around -30 dBFS (a "loud" room) — an absolute -40 threshold
    // would misfire here, but the relative rise still detects speech.
    final d = SilenceDetector(silenceTimeout: ms(3000));
    expect(d.accept(-30, ms(0)), isFalse); // floor
    expect(d.accept(-12, ms(200)), isFalse); // +18 over floor → speech
    expect(d.speechStarted, isTrue);
  });

  test('stops after silenceTimeout of quiet following speech', () {
    final d = SilenceDetector(silenceTimeout: ms(3000));
    expect(d.accept(-60, ms(0)), isFalse); // floor
    expect(d.accept(-30, ms(200)), isFalse); // speech (peak = -30)
    expect(d.accept(-30, ms(400)), isFalse); // still speaking
    // Level drops well below the peak → quiet begins at 600.
    expect(d.accept(-55, ms(600)), isFalse);
    expect(d.accept(-55, ms(3599)), isFalse); // 2999ms — not yet
    expect(d.accept(-55, ms(3600)), isTrue); // 3000ms of quiet → stop
  });

  test('a brief pause under the timeout does not stop; speech resets it', () {
    final d = SilenceDetector(silenceTimeout: ms(3000));
    expect(d.accept(-60, ms(0)), isFalse); // floor
    expect(d.accept(-25, ms(200)), isFalse); // speech (peak = -25)
    expect(d.accept(-55, ms(400)), isFalse); // quiet starts
    expect(d.accept(-55, ms(1900)), isFalse); // 1.5s — under timeout
    expect(d.accept(-25, ms(2100)), isFalse); // speaks again → resets
    expect(d.accept(-55, ms(2600)), isFalse); // new quiet starts
    expect(d.accept(-55, ms(5599)), isFalse); // 2999ms — not yet
    expect(d.accept(-55, ms(5600)), isTrue); // 3000ms → stop
  });
}
