import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/models/android_ime_input.dart';

void main() {
  testWidgets('IME commits with unchanged text reach the host exactly once',
      (tester) async {
    final controller = TextEditingController();
    final sent = <AndroidImeEdit>[];
    final ime = AndroidImeController(controller, sent.addAll)..reset();
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: TextField(controller: controller))));
    await tester.showKeyboard(find.byType(TextField));
    final seed = AndroidImeInput.seed;
    void edit(String text, {bool composing = false}) {
      tester.testTextInput.updateEditingValue(TextEditingValue(
        text: seed + text,
        selection: TextSelection.collapsed(offset: seed.length + text.length),
        composing: composing
            ? TextRange(start: seed.length, end: seed.length + text.length)
            : TextRange.empty,
      ));
    }

    for (final text in ['は', 'ば', 'ぱ', 'ゃ', 'っ', 'きょう', '今日', '京']) {
      edit(text, composing: true);
      expect(sent, isEmpty, reason: 'preedit must stay local: $text');
    }
    edit('今日', composing: true);
    edit('今日'); // composing-only change: TextField.onChanged will not fire.
    expect(sent.map((e) => e.value), ['今日']);
    sent.clear();
    edit('きょう', composing: true); // reconvert an already committed range.
    edit('京都', composing: true);
    expect(sent, isEmpty);
    edit('京都');
    expect(sent.map((e) => e.value), ['VK_BACK', 'VK_BACK', '京都']);
    sent.clear();
    edit('京都');
    expect(sent, isEmpty);
    await tester.pumpWidget(const SizedBox());
    ime.dispose();
    controller.dispose();
  });

  test('content replacements, Unicode, middle edits and deletions converge',
      () {
    final input = AndroidImeInput();
    var host = <String>[];
    var caret = 0;
    void apply(String text, {int? cursor}) {
      final edits = input.update(TextEditingValue(
          text: AndroidImeInput.seed + text,
          selection: TextSelection.collapsed(
              offset: AndroidImeInput.seed.length + (cursor ?? text.length))));
      for (final edit in edits) {
        if (edit.isText) {
          final chars = edit.value.characters.toList();
          host.insertAll(caret, chars);
          caret += chars.length;
        } else if (edit.value == 'VK_BACK') {
          if (caret > 0) host.removeAt(--caret);
        } else if (edit.value == 'VK_LEFT') {
          caret--;
        } else if (edit.value == 'VK_RIGHT') {
          caret++;
        }
      }
      expect(host.join(), text);
      expect(caret, text.substring(0, cursor ?? text.length).characters.length);
    }

    for (final text in [
      'は',
      'ば',
      'ぱ',
      'や',
      'ゃ',
      'つ',
      'っ',
      'こんにちは',
      'コンピューター',
      '今日',
      '今日😀👨‍👩‍👧‍👦か\u3099',
      '今日😀',
      ''
    ]) {
      apply(text);
    }
    apply('()', cursor: 1);
    apply('(a)', cursor: 2);
    apply('(あ)', cursor: 2);
    apply('(あ)');
    apply('abc123 !?\nこんにちは' * 200);
    apply('');
  });

  test('paste replaces synthetic context and repeated backspace refills it',
      () {
    final controller = TextEditingController();
    final sent = <AndroidImeEdit>[];
    final ime = AndroidImeController(controller, sent.addAll)..reset();
    controller.value = const TextEditingValue(
        text: '123😀', selection: TextSelection.collapsed(offset: 5));
    expect(sent.map((e) => e.value), ['123😀']);
    sent.clear();
    ime.reset();
    for (var i = 0; i < 130; i++) {
      final text = controller.text;
      controller.value = TextEditingValue(
          text: text.substring(0, text.length - 1),
          selection: TextSelection.collapsed(offset: text.length - 1));
    }
    expect(sent.length, 130);
    expect(sent.every((e) => !e.isText && e.value == 'VK_BACK'), isTrue);
    ime.dispose();
    controller.dispose();
  });
}
