import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/mobile/widgets/phone_gestures.dart';

void main() {
  testWidgets('tap and double tap click; swipes scroll without pressing',
      (tester) async {
    final taps = <Offset>[];
    final scrolls = <Offset>[];
    var presses = 0;
    await tester.pumpWidget(PhoneGestureRegion(
      configure: (r) => r
        ..onTap = taps.add
        ..onScroll = ((_, delta) => scrolls.add(delta))
        ..onDragStart = ((_) => presses++),
      child: const SizedBox.expand(),
    ));
    await tester.tapAt(const Offset(70, 70));
    await tester.tapAt(const Offset(70, 70));
    await tester.tapAt(const Offset(70, 70));
    expect(taps, List.filled(3, const Offset(70, 70)));
    final finger = await tester.startGesture(const Offset(100, 100));
    await finger.moveBy(const Offset(0, -50));
    await finger.moveBy(const Offset(-50, 0));
    await finger.up();
    expect(scrolls, [const Offset(0, -50), const Offset(-50, 0)]);
    expect(taps.length, 3);
    expect(presses, 0);
  });

  testWidgets(
      'scroll transitions to local pinch; three fingers suppress actions',
      (tester) async {
    final scrolls = <Offset>[];
    final transforms = <double>[];
    var clicks = 0;
    await tester.pumpWidget(PhoneGestureRegion(
      configure: (r) => r
        ..onTap = ((_) => clicks++)
        ..onScroll = ((_, delta) => scrolls.add(delta))
        ..onTransform = ((scale, _, __) => transforms.add(scale)),
      child: const SizedBox.expand(),
    ));
    final one = await tester.startGesture(const Offset(100, 100), pointer: 1);
    await one.moveBy(const Offset(0, -40));
    final two = await tester.startGesture(const Offset(200, 60), pointer: 2);
    await two.moveBy(const Offset(20, 0));
    expect(transforms.single, closeTo(1.2, 0.001));
    final three = await tester.startGesture(const Offset(150, 150), pointer: 3);
    await one.moveBy(const Offset(0, -50));
    await three.up();
    await two.moveBy(const Offset(20, 0));
    await two.up();
    await one.moveBy(const Offset(0, -50));
    await one.up();
    expect(transforms.length, 1);
    expect(scrolls.length, 1);
    expect(clicks, 0);
    await tester.tapAt(const Offset(80, 80));
    expect(clicks, 1);
  });

  testWidgets('hold drag releases on cancel and leaves child controls usable',
      (tester) async {
    var downs = 0;
    var ups = 0;
    var moves = 0;
    var childTaps = 0;
    var remoteTaps = 0;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: PhoneGestureRegion(
        configure: (r) => r
          ..onTap = ((_) => remoteTaps++)
          ..onDragStart = ((_) => downs++)
          ..onDragUpdate = ((_) => moves++)
          ..onDragEnd = (() => ups++),
        child: Stack(children: [
          const Positioned.fill(child: ColoredBox(color: Colors.black)),
          Positioned(
              left: 0,
              top: 0,
              width: 60,
              height: 60,
              child: GestureDetector(
                  onTap: () => childTaps++,
                  child: const ColoredBox(color: Colors.red))),
        ]),
      ),
    ));
    await tester.tapAt(const Offset(20, 20));
    expect(childTaps, 1);
    expect(remoteTaps, 0);
    final finger = await tester.startGesture(const Offset(100, 100));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 1));
    await finger.moveBy(const Offset(20, 20));
    await finger.cancel();
    expect([downs, moves, ups, remoteTaps], [1, 1, 1, 0]);
  });
}
