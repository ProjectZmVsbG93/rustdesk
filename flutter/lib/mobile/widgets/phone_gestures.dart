import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

typedef PhoneTransform = void Function(
    double scale, Offset previousFocalPoint, Offset delta);

/// One recognizer owns each contact sequence, including pointer-count changes.
class PhoneGestureRecognizer extends OneSequenceGestureRecognizer {
  PhoneGestureRecognizer() : super(supportedDevices: {PointerDeviceKind.touch});

  ValueChanged<Offset>? onTap;
  void Function(Offset origin, Offset delta)? onScroll;
  ValueChanged<Offset>? onDragStart;
  ValueChanged<Offset>? onDragUpdate;
  VoidCallback? onDragEnd;
  PhoneTransform? onTransform;

  final _points = <int, Offset>{};
  Offset _origin = Offset.zero;
  Offset? _pendingTap;
  Timer? _hold;
  bool _accepted = false;
  bool _scrolling = false;
  bool _dragging = false;
  bool _multiTouch = false;
  bool _blocked = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    _points[event.pointer] = event.localPosition;
    if (_points.length == 1) {
      _origin = event.localPosition;
      _hold = Timer(kLongPressTimeout, () {
        resolve(GestureDisposition.accepted);
        if (_accepted && !_multiTouch && !_blocked && !_scrolling) {
          _dragging = true;
          onDragStart?.call(_origin);
        }
      });
    } else {
      _hold?.cancel();
      _endDrag();
      _multiTouch = true;
      if (_points.length > 2) _blocked = true;
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (!_points.containsKey(event.pointer)) return;
    if (event is PointerMoveEvent) {
      final previous = _points[event.pointer]!;
      final oldPair = _points.values.toList();
      _points[event.pointer] = event.localPosition;
      if (_blocked) return;
      if (_points.length == 2) {
        final pair = _points.values.toList();
        final oldFocal = (oldPair[0] + oldPair[1]) / 2;
        final focal = (pair[0] + pair[1]) / 2;
        final oldSpan = (oldPair[0] - oldPair[1]).distance;
        final span = (pair[0] - pair[1]).distance;
        onTransform?.call(
            oldSpan > 0 ? span / oldSpan : 1, oldFocal, focal - oldFocal);
      } else if (!_multiTouch) {
        if (_dragging) {
          onDragUpdate?.call(event.localPosition);
        } else if (_scrolling) {
          onScroll?.call(_origin, event.localPosition - previous);
        } else if ((event.localPosition - _origin).distance > kTouchSlop) {
          _hold?.cancel();
          resolve(GestureDisposition.accepted);
          if (_accepted) {
            _scrolling = true;
            onScroll?.call(_origin, event.localPosition - _origin);
          }
        }
      }
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _hold?.cancel();
      if (event is PointerUpEvent &&
          !_multiTouch &&
          !_blocked &&
          !_scrolling &&
          !_dragging &&
          (event.localPosition - _origin).distance <= kTouchSlop) {
        _pendingTap = event.localPosition;
        // Let a descendant button win the tap arena. With no competing child,
        // the arena accepts this recognizer automatically.
        _deliverTap();
      }
      _endDrag();
      _points.remove(event.pointer);
      stopTrackingPointer(event.pointer);
      if (_points.isEmpty && _pendingTap == null) _reset();
    }
  }

  void _deliverTap() {
    if (_accepted && _pendingTap != null) {
      final position = _pendingTap!;
      _pendingTap = null;
      onTap?.call(position);
    }
  }

  void _endDrag() {
    if (_dragging) {
      _dragging = false;
      onDragEnd?.call();
    }
  }

  void _reset() {
    _hold?.cancel();
    _endDrag();
    _pendingTap = null;
    _accepted = _scrolling = _multiTouch = _blocked = false;
  }

  @override
  void acceptGesture(int pointer) {
    _accepted = true;
    _deliverTap();
    if (_points.isEmpty) _reset();
  }

  @override
  void rejectGesture(int pointer) {
    _hold?.cancel();
    _pendingTap = null;
    _blocked = true;
    _endDrag();
    _points.remove(pointer);
    stopTrackingPointer(pointer);
    if (_points.isEmpty) _reset();
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'phone remote gestures';

  @override
  void dispose() {
    _reset();
    super.dispose();
  }
}

class PhoneGestureRegion extends StatelessWidget {
  const PhoneGestureRegion(
      {super.key, required this.child, required this.configure});
  final Widget child;
  final void Function(PhoneGestureRecognizer) configure;

  @override
  Widget build(BuildContext context) => RawGestureDetector(
        behavior: HitTestBehavior.translucent,
        gestures: {
          PhoneGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<PhoneGestureRecognizer>(
                  PhoneGestureRecognizer.new, configure),
        },
        child: child,
      );
}
