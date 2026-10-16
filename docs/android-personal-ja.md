# RustDesk Personal Android

AndroidスマートフォンからWindowsを操作するための個人版です。公式masterの
`53996e3c404ea5083df0775057e4149e49102084`（2026-10-16取得）を基にしています。
作業ブランチは `personal/android-touch-ime` です。

## 操作

Windowsに接続したAndroid端末では「スマホ操作」が初期状態で有効です。

| 操作 | 動作 |
| --- | --- |
| 1本指の短いタップ | 指の位置へ移動して左クリック |
| 同じ位置を素早く2回タップ | 2回の左クリック。Windowsがダブルクリックとして判定 |
| 1本指の上下・左右スワイプ | Windowsの対象コントロールを縦・横にスクロール |
| 約500ms長押し後に移動 | 左ボタンを押しながらドラッグ。離す・キャンセルで解放 |
| 2本指ピンチ・移動 | Android上の表示を拡大縮小・移動 |
| 3本指以上 | 全ての指を離すまで操作を抑止 |

タップは約18論理ピクセルの移動しきい値と長押し時間でスワイプから区別します。
スクロールは移動量に比例し、既存のtrackpadイベントでWindowsへ送ります。
上へのスワイプで先の内容へ進みます。既存のホイール反転設定の影響は補正します。
横スクロールの有無や速度の最終的な解釈はWindowsアプリに依存します。
慣性スクロールは追加していません。

スクロール中に2本目を置くと表示操作へ切り替わります。
2本指操作の後に1本だけ残してもクリックやスクロールは開始しません。
一旦全て離してから次の1本指操作を始めてください。
3本目が触れた場合も同じです。ドラッグ中の追加接触ではボタンを解放します。

下部のジェスチャー設定で「スマホ操作」をオフにすると、従来のマウス／タッチ操作へ戻ります。
この切り替えは接続中だけ保持します。相対マウスモードでは従来の経路を使います。
右クリックは同画面のボタン、または既存の仮想マウスから実行できます。
画面ロック中は従来と同じく表示の拡大・移動を抑止します。

## 日本語入力

従来のAndroid処理は `String.length` の増減で入力を判定し、同じ長さの変更を無視していました。
また、TextFieldの `onChanged` だけでは文字列が同じまま変換確定したイベントを検出できません。
1文字を物理キー相当の経路へ送る処理も、確定文字列の送信とは分ける必要がありました。

この版はTextEditingControllerのリスナーからTextEditingValueを受け取り、
非空のcomposing範囲がある間はPCへ送信しません。
変換が確定すると確定済みのローカル文脈と内容を比較し、変更された末尾を置換します。
比較と差分の境界にはUnicodeの書記素クラスタを使い、サロゲートペアを分割しません。
IMEが括弧内などにカーソルを残した場合は既存の左右キーで位置を合わせます。
BackspaceとEnterは既存のキーAPI、確定した通常文字は1文字でも `sessionInputString` へ送ります。
Ctrlなどのツールバー修飾キーを使った1文字のショートカットは修飾付きキーとして送信します。
入力を順番に送信し、閲覧専用・入力許可も確認します。

Android IMEの有効なcomposing範囲を書き換えないため、Gboardによる範囲復元ループを避けます。
空の入力欄でBackspaceを継続して使えるよう、PCへ送らない不可視のガード文字を保持します。
リモート画面のタップや入力補助バーの操作では、古い文脈を次の入力へ使わないようリセットします。
iOSのIME経路は変更していません。

調査した関連情報:

- [PR #15429](https://github.com/rustdesk/rustdesk/pull/15429): 同じ長さのCJK置換を欠落させる問題。既存コードをそのまま適用せず、composingを保留する方式で実装。
- [PR #16528](https://github.com/rustdesk/rustdesk/pull/16528): 確定文字列のseq送信経路。1文字の通常入力にも既存の文字列APIを使用。
- [Discussion #7277](https://github.com/rustdesk/rustdesk/discussions/7277): Androidの3本指スクロールとシステムジェスチャーの衝突。
- [Flutter TextEditingController](https://api.flutter.dev/flutter/widgets/TextEditingController-class.html): リスナーとGboardのcomposing範囲に関する注意。

## 検証

Flutter 3.24.5 / Dart 3.5.4を使用します。自動テストは次のとおりです。

```sh
cd flutter
flutter pub get
flutter test
flutter analyze --no-fatal-infos lib/models/android_ime_input.dart \
  lib/mobile/widgets/phone_gestures.dart lib/mobile/pages/remote_page.dart \
  lib/common/widgets/remote_input.dart test/android_ime_input_test.dart \
  test/phone_gestures_test.dart
```

- 新規6テストを含む全体テスト: 123成功、1スキップ。
- 変更箇所の解析: エラー・警告なし。既存APIの非推奨情報4件。
- 全体解析: エラーなし。変更していない `lib/common.dart` の未使用import警告1件、情報55件のため標準コマンドの終了値は1。
- Android ARM64のrelease APKビルド成功（約27.6MiB）。APKのv1/v2署名検証に成功。個人版アプリID、表示名、MainActivity、ARM64 ABIも確認。
- Android API 36.1エミュレーター（x86_64上のARM64変換）へインストールし、接続先入力画面の表示とFFI初期化を確認。初回の `am start -W` はタイムアウトしましたが、その後画面表示とプロセス継続を確認しています。
- 同エミュレーターに公式版もインストールし、公式版と個人版の両パッケージが共存することを確認。
- Android実機は接続されていないため、Android→Windowsの実機試験は未実施です。

ローカルAPKでは、公式の[2026-10-16 nightlyビルド](https://github.com/rustdesk/rustdesk/actions/runs/38829001226)のネイティブライブラリとブリッジを利用しています。
そのソースは `e400bb75546cebf4f72a5ef3cf6e4a3efa2c3aa7` です。
今回の取得元masterとの差分はRust側では `src/lang/ru.rs` の翻訳だけで、ネイティブ入力・接続処理とFFIには差分がないことを確認しました。
ローカルではRustネイティブ部を再コンパイルしていません。
専用Actionsはチェックアウトしたソースからネイティブ部も構築します。
APK、SHA256、署名・ビルド・テスト・解析ログ、由来を記した `build-provenance.json` はローカルの `artifacts/android-personal/` に保存します。

テストはcomposingだけが変わる確定イベント、候補の置換・再変換、同じ長さの編集、
日本語、英数字、Unicode結合文字・絵文字、括弧内入力、長文、複数文字削除、
ガード補充、タップ、スワイプ、ピンチへの移行、3本指抑止、ドラッグ解放、
画面内ボタンとのジェスチャー競合を対象にしています。

## APKの取得・ビルド

GitHubの個人用forkで **Actions → Android Personal APK → Run workflow** を選び、
`personal/android-touch-ime` ブランチで実行してください。
完了すると、その実行のArtifactsから `rustdesk-personal-arm64-<commit>` をダウンロードできます。
Google Playへの公開や自動リリースは行いません。APKはARM64端末用です。

[専用ワークフロー](../.github/workflows/android-personal.yml)は公式と同じFlutter、
Rust、NDK、vcpkgのバージョンを使い、そのチェックアウトからネイティブライブラリも構築します。
ブリッジ生成は公式の既存CIに委譲します。ローカルでブリッジを再生成する必要はありません。
ローカルビルドでも、ブリッジ、NDK依存ライブラリ、`librustdesk.so` と
`libc++_shared.so` を先に同ワークフローに従って用意する必要があります。
その後のFlutterビルドは次のとおりです。

```sh
cd flutter
RUSTDESK_ANDROID_PERSONAL=true flutter build apk --release \
  --target-platform android-arm64 --split-per-abi
```

PowerShellでは先に `$env:RUSTDESK_ANDROID_PERSONAL='true'` を設定します。
Windowsでは日本語を含まないパスでビルドしてください。
出力は `flutter/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` です。

アプリIDは `com.carriez.flutter_hbb.personal`、表示名は `RustDesk Personal`、
リンクスキームは `rustdesk-personal://` です。JNI/Kotlinのnamespaceは維持します。
公式アプリと保存領域が異なるため、サーバー設定・鍵・接続履歴・保存済みパスワードは自動移行されません。
必要な接続先と認証情報を個人版に設定し直してください。Windows側の設定変更は不要です。

端末へAPKをコピーし、ファイル管理アプリから開いてインストールします。
ADBを使う場合は次のコマンドです。

```sh
adb install -r app-arm64-v8a-release.apk
```

個人用署名鍵を未設定の場合は開発用のdebug鍵でrelease APKを署名します。
Actionsはdebug.keystoreをキャッシュしますが、キャッシュ削除・期限切れで署名が変わる可能性があります。
継続して上書き更新するには自身の署名鍵を使ってください。
ActionsのSecretsに `ANDROID_SIGNING_KEY`（keystoreのBase64）、`ANDROID_ALIAS`、
`ANDROID_KEY_STORE_PASSWORD`、`ANDROID_KEY_PASSWORD` を設定するとその鍵で署名します。
ローカルでは従来の `flutter/android/key.properties` を使います。鍵はコミットしないでください。
ローカルの開発署名とActionsの開発署名も通常は異なります。
署名が違うAPKへ切り替える際は、設定を控えてから個人版をアンインストールして入れ直します。

## 実機で確認する項目・制限

Windowsのメモ帳とブラウザのテキストエリアで、Android側はGboard日本語を選んで確認します。
[確認用HTML](../res/android-personal/check.html)をWindowsのブラウザで開くと、入力文字列・Unicodeの文字数・入力イベント、縦横スクロールとクリック位置を確認できます。
Windows側のIMEは最初は英数モードにし、次に日本語IME有効でも試してください。

1. タップ位置、ダブルクリック、上下・左右スクロール。スクロール開始時に選択やクリックが発生しないこと。
2. 拡大→表示移動→端と中央の小さなボタンをタップ。安全領域、横向き、キーボード表示中も座標が合うこと。
3. スクロール→2本指ピンチ→指を減らす操作。3本指の追加・解除でPC側に操作が漏れないこと。
4. 長押し後のウィンドウ移動、選択範囲のドラッグ。指を離す・追加する・アプリを中断する際にボタンが残らないこと。
5. 「こんにちは」「コンピューター」「は→ば→ぱ」「や→ゃ」「つ→っ」「きょう→今日」。確定前はPCへ文字が出ず、確定後は一度だけ入力されること。
6. 複数候補の選択、直前の確定語の再変換、Backspace長押し、複数文字削除、途中の修正、追加入力。
7. 長文、改行、英数字・記号、通常の絵文字、家族などのZWJ絵文字、結合濁点。
8. Enter、ソフトキーボードと物理キーボードのBackspace、Ctrl+C/V/A、Shift、Tab、矢印キー、入力補助バー。
9. 閲覧専用への切り替え、入力権限の無効化、再接続。従来操作への切り替えも確認。

通信プロトコルを変えずに扱えるのは、Androidの隠し入力欄が保持する文脈です。
Windows側に以前からある文章をAndroid IMEで直接選択して再変換する機能はありません。
Windows側でマウス・別キーボード・アプリが文章やカーソルを変えた場合、その変化はローカルIMEへ逆同期されません。
その場合はいったんキーボードを開き直してください。
Backspaceや左右キーが書記素クラスタを何単位で扱うかはWindowsアプリに依存します。
特に結合文字・ZWJ絵文字の置換と削除、アプリ側の自動補完は実機確認が必要です。
自動テストの成功だけで全アプリの日本語入力が完全に動作するとは確認できません。
IME修正はAndroidからWindows以外へ接続する場合にも適用されますが、それらの接続先の入力は未検証です。

## 変更範囲

- `flutter/lib/mobile/pages/remote_page.dart`: AndroidのソフトIME接続、入力送信、操作切り替え。iOS・物理キー処理は維持。
- `flutter/lib/common/widgets/remote_input.dart`: Android→Windowsかつスマホ操作有効時だけ新ジェスチャーへ分岐。既存の座標変換と入力APIを使用。
- `flutter/lib/models/android_ime_input.dart`: 確定文字列の差分、IMEリスナー。
- `flutter/lib/mobile/widgets/phone_gestures.dart`: 接触列ごとのジェスチャー判定。
- `flutter/android/app/build.gradle` とManifest: 個人ビルド時のアプリID・ラベル・署名・リンク設定。通常ビルドの識別子は維持。
- `flutter/test/android_ime_input_test.dart`、`flutter/test/phone_gestures_test.dart`: 回帰テスト。
- `.github/workflows/android-personal.yml`: 手動の個人APKビルド。
- `res/android-personal/check.html`: Windowsブラウザで開く手動確認用ページ。

接続方式、認証、サーバー、暗号化、映像転送、Rust/ネイティブ入力実装、FFI、通信仕様は変更していません。
共有ファイルへの変更は新経路のフックに限り、スマホ操作を無効にした場合のジェスチャーは元の実装へ戻ります。
