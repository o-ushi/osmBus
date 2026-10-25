# 実装メモ（docs/spec_migration.md からの差分）

パッケージはすべて仕様の名前のまま現行安定版で解決できた（置き換えなし）。座標型に `latlong2`、HTTP に `http`、l10n に `flutter_localizations` / `intl` を追加している。

- §8.4 乗換 2 回: 文字どおり「B の降車停留所（＝目的地 550m 以内）から C へ乗り換える」と意味のない経路になるため、A→B の接続（B が目的地へ届かなくてよい）のうち徒歩が短い B を最大 5 本取り、B の U 以降の停留所から目的地へ届く C を 1 段探す形にした。比較回数 2000 の打ち切りは路線 A ごと。
- §8.3 / §8.4 乗換: 直通で目的地に着く路線 A からは乗換案を探さない。仕様では「同じ番号が直通にも乗換にも出ることがある」を許すが、並行して走る路線どうし（例: 35A→35B）の乗り継ぎが「1」「2+」列に並んで表が読みにくくなるため。届かない路線から直通路線への乗換は従来どおり出る。
- §4.2 停留所: Swift の `parseDetails` に合わせ、road-side（`stop` / `stop_entry_only` / `stop_exit_only` / `stop_entry` / `stop_exit`）を優先し、無いときだけ platform 系 role と role 空の `highway=bus_stop` 節を使う（和集合にすると同じ停留所が二重になるため）。
- §4.2 形状: Swift は way ごとに別セグメントだが、端点がつながる way は向きを揃えて 1 セグメントに連結し、途切れたら別セグメントにした（各 way の 400 点間引きは Swift と同じ）。
- §3.4 置き換え読み込み: `schemaVersion` が無いファイルは Swift 版の書き出しとみなして受け付ける。1 以外の値は拒否。
- §5.3 保存直後の同期: ダウンロード中は塊ごとに保存されるため、最後の保存から 2 秒後にまとめて `mergeAndPush` する。
- 同意: 設定のスイッチをオフにすると非表示のみ（ファイルは残す）。ファイル削除は別ボタン「同意を撤回してデータを削除」。
- 番号表の純粋ロジックは `lib/models/bus_matrix.dart`、テスト用の路線生成は `test/fixtures.dart` に置いた（仕様の配置表に無いファイル）。
- Dart のパッケージ名は小文字のみのため `osmbus`。Android の `namespace` も `com.osamushikubo.osmbus` のままで、`applicationId` と iOS の Bundle ID は `com.osamushikubo.osmBus`。
- `Runner.entitlements` には仕様の 2 キーに加え、iCloud Documents に必要な `com.apple.developer.ubiquity-container-identifiers` も入れた。
- §11 UI: 仕様は Material 3 だが、利用者の指示で Swift 版の見た目に合わせた（クリーム地の方眼、オレンジ枠のカード、青い番号バッジ、乗車中はオレンジ）。画面は Swift と同じく「マトリクス（番号表）」と「番号入力（判定＋テンキー）」の 2 つで、右上「…」メニューか左端からの右スワイプで切り替える。設定と目的地選びはシート。
- §11 判定の色: Swift と同じく「◯◯だったら乗ってください！」は黄、見送りは赤、乗車中は緑。概算到着の 1 行は仕様どおり残した。
- §11 同意: Swift 版（同じバンドル ID）が接頭辞なしの UserDefaults に書いた `privacy.thirdPartyConsent.version` を起動時に引き継ぎ、Flutter 側で変えたときも同じキーへ書き戻す。
- UI テスト用に `TripController.requestsLocationOnLaunch` と `debugSetOrigin` を足した（`integration_test/app_flow_test.dart`）。


- **路線の保管庫（仕様外の追加）**：正本とは別に `Documents/osmBus/bus-route-archive.json` を持つ。保存のたびに形状付きの路線をここへ足し、消すことはない（置き換え読み込み・同意撤回・OSM 版更新による形状の取り消しでも残る）。正本が壊れていたら `.corrupt-<日時>` として脇へ移し、保管庫から立て直す。再取得時は OSM の版が同じ路線の形状を保管庫から戻し、通信を省く。形式は正本と同じなので、そのままバックアップとして読み込める。`UIFileSharingEnabled` / `LSSupportsOpeningDocumentsInPlace` により「ファイル」アプリから見える。設定に件数・復元・書き出しを追加。アプリ削除では消えるため、外へ残すには書き出しを使う。
- §10 番号表の重複除去: 仕様のキーは「方位|列|番号」だが、同じ番号が乗換1と2+の両方に並ぶため「方位|番号」にした。乗換の少ない列を優先し、同じ列なら徒歩合計→乗車距離の小さい方を残す（フラット表示も同じ）。
- 地図タイルと地名検索の予備: 回線の DNS が `tile.openstreetmap.org` / `nominatim.openstreetmap.org` を引けない環境（ベトナムの VNPT 回線で確認）では地図が空白になるため、タイルは OSM France（`tile.openstreetmap.fr/osmfr`）を `fallbackUrl` に、検索は Photon（`photon.komoot.io`）を予備にした。CARTO はアプリからだと API キーを要求されるため使わない。
- 出発地の手動指定（Swift の manualOrigin と同じ）: 現在地の行の地図ボタン／行のタップで地図シートを出発地モードで開く。シート上部で出発地／目的地を切り替えられる。手動出発地は「出発地: 地名」と緑のピンで表示し、×で現在地に戻す。保存はしない。番号表・判定・ダウンロードは手動出発地を優先し、乗車中の「あと」は GPS で測る。
