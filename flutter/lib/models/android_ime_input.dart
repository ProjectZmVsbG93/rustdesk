import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart'
    show TextEditingController, StringCharacters;

/// A local editing context; only committed text is mirrored to the host.
class AndroidImeInput {
  static final seed = '\u200b' * 64;
  static TextEditingValue get initialValue => TextEditingValue(
      text: seed, selection: TextSelection.collapsed(offset: seed.length));

  String _committed = '';
  int _caret = 0;
  int _guardLength = seed.length;

  void reset() {
    _committed = '';
    _caret = 0;
    _guardLength = seed.length;
  }

  List<AndroidImeEdit> update(TextEditingValue value) {
    // Do not mutate the controller/composing range: Gboard can restore it in a
    // loop. A controller listener also observes commit-without-text-change.
    if (value.isComposingRangeValid && !value.composing.isCollapsed) return [];

    var guardLength = 0;
    while (guardLength < seed.length &&
        guardLength < value.text.length &&
        value.text[guardLength] == '\u200b') {
      guardLength++;
    }
    final text = value.text.substring(guardLength);
    final oldChars = _committed.characters.toList();
    final newChars = text.characters.toList();
    final caretOffset = value.selection.isValid
        ? (value.selection.extentOffset - guardLength).clamp(0, text.length)
        : text.length;
    final caret = text.substring(0, caretOffset).characters.length;
    final edits = <AndroidImeEdit>[];
    void keys(String name, int count) {
      for (var i = 0; i < count; i++) {
        edits.add(AndroidImeEdit.key(name));
      }
    }

    if (text != _committed) {
      var common = 0;
      while (common < oldChars.length &&
          common < newChars.length &&
          oldChars[common] == newChars[common]) {
        common++;
      }
      // The protocol exposes keys and insertion, not range replacement. Rewrite
      // the changed tail, then restore the IME caret (e.g. inside paired brackets).
      keys('VK_RIGHT', oldChars.length - _caret);
      keys('VK_BACK', oldChars.length - common);
      final inserted = newChars.skip(common).join();
      if (inserted.isNotEmpty) edits.add(AndroidImeEdit.text(inserted));
      keys('VK_LEFT', newChars.length - caret);
    } else {
      keys(caret < _caret ? 'VK_LEFT' : 'VK_RIGHT', (caret - _caret).abs());
      if (text.isEmpty && value.text.length < _guardLength) {
        keys('VK_BACK', _guardLength - value.text.length);
      }
    }
    _committed = text;
    _caret = caret;
    _guardLength = guardLength;
    return edits;
  }
}

class AndroidImeEdit {
  final String value;
  final bool isText;
  const AndroidImeEdit.key(this.value) : isText = false;
  const AndroidImeEdit.text(this.value) : isText = true;
}

/// Controller listener binding, kept separate from FFI for IME regression tests.
class AndroidImeController {
  AndroidImeController(this.controller, this.send) {
    controller.addListener(_changed);
  }
  final TextEditingController controller;
  final void Function(List<AndroidImeEdit>) send;
  final input = AndroidImeInput();
  bool _resetting = false;

  void reset() {
    _resetting = true;
    input.reset();
    controller.value = AndroidImeInput.initialValue;
    _resetting = false;
  }

  void _changed() {
    if (_resetting) return;
    final value = controller.value;
    final edits = input.update(value);
    if (edits.isNotEmpty) send(edits);
    // Refill only an exhausted, non-composing guard, never active IME text.
    if (value.text.isEmpty && value.composing.isCollapsed) reset();
  }

  void dispose() => controller.removeListener(_changed);
}
