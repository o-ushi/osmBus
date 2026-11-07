# osmBus Flutter 移行仕様（オフラインファースト）

この文書は Swift 版 `osmBus`（バンドル ID `com.osamushikubo.osmBus`）を、iOS / Android の Flutter アプリへ移すときの実装仕様である。作業員は本書だけを読んで、モデル・サービス・UI・単体テストを一気に実装する。

Swift ターゲットは残す。削除・移動・リファクタをしない。新規コードはリポジトリ直下の `flutter/` に置く。

## 1. 今回作るもの / 作らないもの

### 作る

1. Flutter アプリ（iOS / Android）。縦向き。表示言語は日本語・英語・ベトナム語。
2. Overpass から取得したバス路線を端末内 JSON に保持する。バックアップの書き出しと読み込みができる。
3. iOS ではその JSON を iCloud Drive（ubiquity container）のファイルとして同期する。Android では同じファイルを書き出し／読み込みで受け渡す。
4. 番号入力の乗車可否は、保持している路線の停留所列から計算する。Google へは出さない。
5. トップのバス番号表（マトリクス）も、同じローカル計算の結果を描画する。Google の経路は使わない。

### 作らない（この作業では着手しない）

- Swift 画面の全面移植（課金、Google API キー、バックグラウンド到着アラート、音声、既存の乗車トラッカーの誤方向検知）。
- Google Routes API / Places API の呼び出し。
- CloudKit のレコード API。路線形状は 1 レコードの上限（1MB）を超える。同期はファイルで行う。
- App Store / Play への提出作業。

乗車状態は「この番号で乗車中」のフラグと降車停留所名の表示までに留める。バックグラウンド測位はしない。

## 2. 配置

```
flutter/
  pubspec.yaml
  lib/
    main.dart
    app.dart
    l10n/app_ja.arb
    l10n/app_en.arb
    l10n/app_vi.arb
    models/route_catalog.dart
    models/bus_identifier.dart
    models/local_itinerary.dart
    models/boarding_decision.dart
    services/geo.dart
    services/overpass_api.dart
    services/route_catalog_store.dart
    services/route_catalog_downloader.dart
    services/catalog_sync.dart
    services/local_planner.dart
    state/trip_controller.dart
    ui/top_screen.dart
    ui/bus_number_table.dart
    ui/keypad.dart
    ui/result_banner.dart
    ui/settings_screen.dart
    ui/destination_picker_screen.dart
    ui/route_map_screen.dart
  test/
    bus_identifier_test.dart
    catalog_merge_test.dart
    local_planner_test.dart
    local_boarding_test.dart
    local_matrix_test.dart
ios/Runner/Runner.entitlements   # iCloud Documents。下記 §5
```

アプリケーション ID は iOS / Android とも `com.osamushikubo.osmBus`。表示名は `osmBus`。

依存の目安（解決できない版があれば、同じ役割の現行安定版に置き換え、`flutter/IMPLEMENTATION.md` に 1 行残す）:

| 役割 | パッケージ |
|---|---|
| 地図 | `flutter_map` + OSM タイル |
| 位置 | `geolocator` |
| パス | `path_provider` |
| 設定 | `shared_preferences` |
| 書き出し | `share_plus` |
| 読み込み | `file_picker` |
| iOS iCloud ファイル | `icloud_storage` |

地図タイルは `https://tile.openstreetmap.org/{z}/{x}/{y}.png`。User-Agent に `osmBus` を付ける。

## 3. データの保持

### 3.1 ファイル

端末内の正本は 1 ファイル。

- パス: アプリサポートディレクトリ `osmBus/bus-route-catalog.json`
- 形式: UTF-8 JSON
- 書き込み: 一時ファイルへ書いてから置換する（書き込み中の欠落を残さない）
- 読み書きは単一のロック（ミューテックス）で直列化する
- 同意がオフのあいだ、UI へ路線を出さない。ファイル自体は消さない。同意撤回の操作をしたときだけファイルを削除する（Swift の `ThirdPartyDataConsent` と同じ）

メモリ上に最後に読んだスナップショットをキャッシュしてよい。保存のたびにキャッシュを更新する。

### 3.2 エンベロープ

```json
{
  "schemaVersion": 1,
  "dateEncoding": "iso8601",
  "syncedAt": "2026-10-25T09:00:00Z",
  "routes": []
}
```

`syncedAt` はファイル全体を保存した時刻。路線ごとの新旧は `updatedAt` で決める。

Swift 版が書いたファイルも読めること。Swift の `JSONEncoder` 既定では `syncedAt` が **2001-01-01 UTC からの秒（数値）** になる。数値が来たらその基準で `DateTime` にする。`schemaVersion` と `dateEncoding` が無くても読む。未知のキーは無視する。

### 3.3 路線レコード

Swift の `BusRouteCatalogStore.Record` を上位互換で保持する。

| フィールド | 型 | 必須 | 意味 |
|---|---|---|---|
| `relationId` | int | yes | OSM relation id。主キー |
| `ref` | string | yes | 系統番号。例: `35A` |
| `name` | string | yes | OSM `name` |
| `from` | string \| null | yes | OSM `from` |
| `to` | string \| null | yes | OSM `to` |
| `osmTimestamp` | string \| null | yes | Overpass の `timestamp` |
| `stops` | array | yes | 停留所。relation の並び順 |
| `polylineSegments` | array | yes | 形状。`[{latitude, longitude}]` の配列の配列 |
| `hasGeometry` | bool | yes | 停留所と形状を取り込み済みか |
| `updatedAt` | string \| null | no | このレコードを最後に変更した時刻（ISO8601）。Swift ファイルには無い |
| `anchorLatitude` | number \| null | no | この路線を取り込んだときの緯度。圏外削除の判定に使う |
| `anchorLongitude` | number \| null | no | 同上、経度 |

停留所:

```json
{ "id": 123, "name": "Ben xe", "latitude": 21.02, "longitude": 105.84 }
```

形状が付いたとき、アンカーが空なら停留所列の中央の停留所座標をアンカーにする。停留所が無いときはダウンロード時の現在地をアンカーにする。

`ref` が空の路線は保存しない。

### 3.4 バックアップ

設定画面から行う。

- **書き出し**: 正本と同じ JSON を `osmBus-routes-YYYYMMDD.json` として共有シートへ渡す。同期用の別形式は作らない。
- **読み込み**: ユーザーが「置き換え」か「統合」を選ぶ。
  - 置き換え: ファイル内容を検証したあと正本をその内容にする。`schemaVersion` が 1 以外、または `routes` が配列でなければ拒否し、正本は触らない。
  - 統合: §5.4 のマージ。読み込み側を「相手」、端末を「手元」とする。
- 検証に失敗したときは理由を表示し、正本を変更しない。

## 4. 取得（Overpass）

同意がオンのときだけ通信する。エンドポイントは Swift と同じ順で試し、失敗したら次へ進む。

1. `https://overpass-api.de/api/interpreter`
2. `https://overpass.kumi.systems/api/interpreter`
3. `https://maps.mail.ru/osm/tools/overpass/api/interpreter`

### 4.1 見出し

現在地の半径 80km。タイムアウト 90 秒。

```
[out:json][timeout:90];
relation["type"="route"]["route"~"bus|trolleybus"](around:80000,{lat},{lon});
out tags meta;
```

各 relation から `id`, `ref`, `name`, `from`, `to`, `timestamp` を取る。`ref` が空なら捨てる。

### 4.2 形状

見出し適用後、`hasGeometry == false` の id だけを取る。4 件ずつ。

```
[out:json][timeout:90];
relation(id:{id,id,...});
out body;
>;
out body;
```

塊が失敗し、塊のサイズが 2 以上なら 1 件ずつ再試行する。1 件も失敗したらその id は `hasGeometry: false` のまま残し、全体は失敗にしない。塊のあいだに 400ms 空ける。キャンセルできること。

停留所は relation の member 順。`role` が `platform` の節は停留所として採用する（Swift のパースに合わせ、`stop` / `stop_entry` / `stop_exit` と、highway=`bus_stop` の節も含める）。形状は member の way を順に座標列へ展開し、途切れたら別セグメントにする。詳細は Swift の `OverpassAPIService.parseDetails` の並びを崩さない。

### 4.3 見出しの取り込み

`downloadAll` は `dropMissing: false`。`update` は `dropMissing: true`。

共通:

- 同一 `relationId` は 1 レコード。
- 既存があり `osmTimestamp` が変わった、または形状が無いときは、形状・停留所を捨て `hasGeometry = false` に戻して取り直す対象にする。`ref` / `name` / `from` / `to` は新しい見出しで上書きする。
- 新規は形状なしで追加する。`anchorLatitude/Longitude` は今回の現在地。`updatedAt` は今。
- タイムスタンプが同じで形状があるレコードは、見出し文字が変わったときだけ `updatedAt` を進め、形状は維持する。

`dropMissing: true` のとき削除してよいのは次をすべて満たすレコードだけ。

- アンカーが今回の現在地から **80km 以内**（アンカーが無いレコードは削除しない）
- 今回の見出しにその `relationId` が無い

圏外の路線は残す。これで、別都市のデータを同期したあとに現在地で「更新」しても、圏外の路線が消えない。

`dropMissing: false` では削除しない。

保存後、形状の無い id をダウンロードする。進捗は `done/total`。完了文は件数。見出しが 0 件なら失敗「周辺に路線がない」。

## 5. バックアップと iCloud 同期

### 5.1 なぜファイルか

正本は §3 の JSON ひとつ。iOS の同期先も同じ JSON ファイル。CloudKit レコードには載せない。

- コンテナ ID: `iCloud.com.osamushikubo.osmBus`
- 相対パス: `Documents/bus-route-catalog.json`
- サービス: iCloud Documents（CloudDocuments）。CloudKit データベースは使わない。

`ios/Runner/Runner.entitlements`:

```xml
<key>com.apple.developer.icloud-services</key>
<array>
  <string>CloudDocuments</string>
</array>
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
  <string>iCloud.com.osamushikubo.osmBus</string>
</array>
```

Developer ポータルでコンテナを作る作業は人間が行う。アプリはコンテナが無い、未サインイン、Android、のいずれかでも起動し、設定に理由を出す。クラッシュさせない。

### 5.2 プラットフォーム

`CatalogSync` インターフェース:

- `bool get isSupported` — iOS かつ iCloud が使えるときだけ true。Android は false。
- `Future<void> pushLocal()` — 正本をコンテナへコピー。
- `Future<CatalogSnapshot?> pullRemote()` — リモートが無ければ null。
- `Future<CatalogSnapshot> mergeAndPush()` — §5.4 で統合し、正本とリモートの両方を結果にする。

パッケージは `icloud_storage`。Android ではこの実装を呼ばない。

### 5.3 いつ同期するか

設定に「iCloud 同期」スイッチを置く（Android では無効、説明文「iCloud は iOS のみ」）。

オンのとき:

- 路線の保存が成功した直後に `mergeAndPush`。
- アプリが前面に戻ったときに `mergeAndPush`。
- 設定の「今すぐ同期」。

オフのときはリモートを読まない・書かない。ローカルの正本はそのまま。

同期失敗は設定の状態行に出す。判定と番号表はローカルだけで動き続ける。

### 5.4 マージ

両側の `routes` を `relationId` で突合する。

- 片方にしか無い id は残す（和集合）。都市をまたいでも消さない。
- 両方にあるときは `updatedAt` が新しい方を残す。
- 片方の `updatedAt` が無いときは、`hasGeometry == true` の方を優先する。それでも決まらなければ `osmTimestamp` の文字列比較で新しい方。それでも同じなら手元を残す。
- 結果の `syncedAt` はマージした今。

「更新」の圏外保護（§4.3）を先にローカルへ適用し、そのあとこのマージを行う。マージ自体は圏外削除をしない。

## 6. 地理計算

Swift の `GoogleRoutesAPIService` と合わせる。判定はこの関数だけを使う。

距離（メートル）: 地球半径 6_371_000。Haversine。

```
φ1, φ2, Δφ, Δλ はラジアン
a = sin²(Δφ/2) + cos φ1 · cos φ2 · sin²(Δλ/2)
d = 2 · atan2(√a, √(1−a)) · R
```

方位角（度、北 0、時計回り 0〜360）:

```
y = sin(Δλ) · cos φ2
x = cos φ1 · sin φ2 − sin φ1 · cos φ2 · cos Δλ
bearing = (atan2(y, x) · 180/π + 360) mod 360
```

ポリライン長は隣接点間の距離の和。点が 2 未満なら 0。

8 方位の添字: `floor((bearing + 22.5) / 45) mod 8`。順に N, NE, E, SE, S, SW, W, NW。表示は l10n（ja: 北, 北東, 東, 南東, 南, 南西, 西, 北西）。

## 7. 番号の正規化

Swift の `parseBusIdentifierParts` / `extractBusTokens` / `busNumberVariants` / `containsBusNumber` を Dart で同じ結果にする。

トークン抽出の正規表現: `([A-Z]{0,3}\d{1,4}[A-Z]{0,3})`。入力は trim + 大文字化。

トークン分解: `^([A-Z]{0,3})(\d{1,4})([A-Z]{0,3})$`。`compactNumber` は数字部の先頭ゼロを除いた整数の十進表記（`05` → `5`）。整数化できないときは採用しない。

ソート: compactNumber の数値昇順、同じなら prefix、同じなら suffix。

完全一致のゆれ: 大文字化したあと、`^([A-Z]*?)0+([1-9]\d*)([A-Z]*)$` に合うならゼロ無し形もバリアントに入れる。`05A` は `5A` も候補。

包含: テキスト全体が番号と等しい、または `(?<![0-9A-Z])番号(?![0-9A-Z])` に合う。

トップのテンキーは **数字のみ、最大 4 桁**（Swift の `BusNumberInput`）。英字はユーザーが打たない。`35` と打つと compactNumber が `35` の系統（`35`, `35A`, `E35`）が候補になる。

## 8. ローカル旅程（乗車判定と番号表の共通計算）

Google は呼ばない。乗車判定と番号表は同じ `LocalPlanner` の出力を使う。出発地と目的地が同じあいだ結果をキャッシュする。出発地が 150m 以上動いた、目的地が変わった、カタログが変わった、ときだけ計算し直す。計算は UI スレッドの外で行う。

### 8.1 定数（Swift の代替乗車に合わせる）

| 名前 | 値 | 意味 |
|---|---|---|
| `boardRadiusMeters` | 700 | 出発地から乗車停留所まで |
| `alightRadiusMeters` | 550 | 目的地から降車停留所まで |
| `transferRadiusMeters` | 280 | 乗換同士の停留所間隔 |
| `minRideFromOriginMeters` | 250 | これより手前の停留所では降りない（乗り始めたばかり） |

対象路線は `hasGeometry == true` かつ停留所 2 つ以上。

停留所の最近傍は、半径内で距離最小の添字。同距離なら添字が小さい方。

### 8.2 直通（乗換 0）

路線の停留所列は進行方向である。乗車添字 `<` 降車添字のときだけ採用する。逆向きの relation はここでは乗らない（逆方向は別 relation としてデータに入っている前提）。

1. 出発地から `boardRadiusMeters` 以内の最近傍を乗車停留所にする。無ければこの路線は直通でない。
2. それより後ろの停留所のうち、目的地から `alightRadiusMeters` 以内で最も近いものを降車停留所にする。無ければ直通でない。
3. 徒歩合計 = 出発地→乗車 + 降車→目的地。乗換徒歩は 0。
4. 乗車距離 = 乗車停留所から降車停留所までのポリライン長。形状が使えなければ両停留所間の直線距離。

ポリラインの切り出し: 全セグメントを連結し、乗車停留所座標に最も近い頂点から、降車停留所座標に最も近い頂点まで。終点添字が始点以下なら、両停留所を結ぶ 2 点にする。

### 8.3 乗換 1 回

グリッドは 0.003 度（約 300m）。各停留所を、そのセルと隣接 8 セルへ登録する。検索は停留所座標のセルと隣接を見て、`transferRadiusMeters` 以内だけ残す。

各路線 A について、§8.2 と同じ乗車停留所があるものだけ進める。乗車停留所より後ろで、出発地から `minRideFromOriginMeters` 以上離れた停留所 T を乗換候補にする。停留所が 80 を超える路線は、乗車停留所以降を均等に 80 点まで間引く。

T の近傍に、別路線 B の停留所 U があるとき:

- B の U より後ろに、目的地から `alightRadiusMeters` 以内の降車停留所がある
- 徒歩 = 出発地→A乗車 + T→U + B降車→目的地
- 乗車距離 = A の乗車〜T のポリライン長 + B の U〜降車のポリライン長

路線 A ごとに、徒歩が最小、同値なら乗車距離が最小の組を 1 つだけ残す。

最初に乗る系統は A の `ref`。番号表の「1」列に出す番号は A の番号である。

### 8.4 乗換 2 回以上

各路線 A の乗換 1 回候補のうち徒歩が短い順に最大 5 つを取る。その B の降車停留所を新たな T とみなし、第三の路線 C へ §8.3 と同じ接続を 1 段だけ探す。A ごとに最良 1 件。見つからなければ「2+」列は空でよい。処理を打ち切ってよい上限は、比較回数 2000。超えたらそこまでの最良を使う。

直通がある系統を、より悪い乗換案で上書きしない。列が違うので別セルに出る。同じ番号が直通にも乗換にも出ることがある。Swift もそうなっている。

### 8.5 方位

第 1 レグの乗車停留所から、そのレグのポリラインの添字 `min(n-1, max(1, n/5))` の点への方位。点が無ければ降車停留所への方位。8 方位へ量子化する。これが行の方向である。

複数レグの旅程でも、行の方向は最初のバスの方位だけを使う（Swift の `routeDirectionText` が最初のバスステップだけを見ているのと同じ）。

### 8.6 概算時間

判定の成否には使わない。表示だけ。

- 徒歩速度 1.25 m/s（4.5 km/h）
- バス速度 5.56 m/s（20 km/h）
- 分 = `max(1, round((徒歩合計 / 1.25 + 乗車距離 / 5.56) / 60))`

時刻表は持たない。到着時刻は「いま + 概算分」とし、文言は概算だと分かるものにする。運賃は持たない。最安かどうかは常に true とし、最安バッジは出さない。

## 9. 乗車可否

入力はテンキーの数字列。出発地は GPS。手動の出発地は今回は作らない。GPS が無ければ「現在地がありません」。目的地が無ければ「目的地を設定」。形状付き路線が 0 なら「路線データがありません」（Google へフォールバックしない）。

`LocalPlanner` の旅程のうち、第 1 レグの `ref` から抽出したトークンの `compactNumber` が、入力の `compactNumber` と等しいものを残す。`ref` にトークンが複数あるときは、いずれかが一致すれば採用する。

残った旅程が 0 なら `doNotBoard`（見送る）。

残ったとき、直通がある ref を、乗換だけの ref より先に採用する。同じ ref が複数旅程なら、徒歩合計が小さい方、同値なら乗車距離が小さい方。

系統 ref の集合を §7 のソートで並べる。

- 集合が 1 つ: `boardIfVariant`。名前はその ref ひとつ。Swift の数字入力は 1 件でも variant 経路になる。
- 集合が 2 つ以上: `boardIfVariant`。名前は並び順のすべての ref。
- 降車停留所名は、採用した旅程の第 1 レグの降車停留所。直通なら目的地側、乗換なら乗換停留所。
- 方位ヒント: 採用集合の各旅程の方位角を集める。2 つ以上あり、円周上の最大開きが 120 度を超えるなら「向きはどちらでも可」。そうでなければ円周平均の 8 方位。「参考：北向き」の形。平均は sin/cos の和の `atan2`。負なら 360 を足す。

入力のたびにネットワークへ出ない。デバウンスは 200ms だけでよい。

## 10. 番号表

入力は §8 の全旅程（番号で絞らない）。目的地が無いときは「目的地を設定」。計算中は「計算中」。旅程 0 は「ルートなし」。取得失敗は取得の状態であり、表の空欄理由には使わない。既に旅程があれば、取得が失敗していても表を出す。

### 10.1 セルに出す番号

第 1 レグの `ref` から、表示用トークンを 1 つ取る。`ref` 自体が 10 文字以下で空白を含まなければ `ref`。そうでなければ §7 のトークンのうち、prefix か suffix があるものを優先し、無ければ先頭トークン。トークンが無ければ `ref`。

乗換回数:

| バスレグ数 | 列 |
|---|---|
| 1 | 直通 `0` |
| 2 | 乗換 `1` |
| 3 以上 | 乗換 `2+` |

### 10.2 方向基準（既定）

行は方位。列は直通 / 1 / 2+。行の並びは、旅程を `relationId` 昇順で走査して方位が最初に現れた順。

同一方位・同一列・同一番号は 1 つ。残すのは徒歩合計が小さい方。同値なら乗車距離が小さい方。値が無いものは無限大として後ろ。セル内の並びも同じ比較。

ヘッダはアイコンと短い数字（0 / 1 / 2+）。VoiceOver は「方向」「直通」「乗換1」「乗換2+」。

### 10.3 フラット表示

設定で切り替える。キーは `方位|列|最初の番号`。同じキーは §10.2 と同じ比較で 1 つ。

- 距離基準: 行にまとめない。既定の測り方は徒歩合計、同値なら乗車距離。設定が「合計距離」のときは徒歩合計 + 乗車距離。どちらか欠けたら末尾。
- 乗換回数基準: 列の値（0, 1, 2）の昇順。同値のタイブレークは常に徒歩優先（合計距離設定は使わない）。

各行は方位、乗換数、番号の列。乗換がある行は第 1 レグ以降の番号を `→` でつなぐ。

### 10.4 操作

- タップ: その旅程の地図。第 1 レグのポリライン、乗車停留所、降車停留所。
- 長押し: その番号の乗車開始／終了。乗車中はその番号を強調する。
- 再読み込み: キャッシュを捨てて `LocalPlanner` を再実行する。通信しない。

## 11. UI

Material 3。トップは上から、目的地、番号表、判定結果、テンキー。

- 目的地: 名前と、未設定なら誘導。タップで地図。地図の長押しで座標を確定。オンラインなら Nominatim（`https://nominatim.openstreetmap.org/search`）で地名検索してよい。User-Agent は `osmBus`。結果のタップで目的地にする。オフラインでも地図の長押しだけで設定できる。Google の地名検索は使わない。
- 現在地: 画面表示時に許可を求める。拒否時は設定で理由を出す。
- 判定: 乗車可は緑、見送りは赤。variant のときは系統名を列挙する。概算の到着と降車停留所名を添える。
- テンキー: 0–9、消去、決定。決定は待たずに、数字の変化で §9 を走らせる（Swift は入力のたびに判定する）。
- 設定: OSM 同意、路線件数、形状件数、最終保存時刻、全件ダウンロード、更新、進捗、バックアップ書き出し、読み込み、iCloud スイッチ、最終同期、同期エラー。番号表の並び（方向 / 距離 / 乗換回数）と、距離基準のときの測り方（徒歩優先 / 合計）。
- 同意がオフのときはダウンロードボタンを押せない。番号表と判定は空（保存データがあっても出さない）。

文字列は arb の 3 言語を同時に書く。日本語を既定にする。

## 12. テスト

ネットワークも端末も使わない。`flutter test` が通ること。

1. **番号**: `35` の compactNumber は `35`。`05` と `5` は同じ compactNumber。`BRT01` は prefix `BRT` number `01`。`35A` と `35B` のソートは A が先。`05A` のバリアントに `5A` が入る。
2. **直通**: 停留所 4 つの路線。出発地が停留所 0 の 100m、目的地が停留所 3 の 100m → 乗換 0 の旅程が 1 つ。停留所順が目的地→出発地の向きだけの路線は旅程に出ない。
3. **数字判定**: 上記に加え `ref` が `35A` と `35B` の 2 路線がどちらも条件を満たす → `boardIfVariant` の名前が `35A`, `35B`。どちらも半径外 → `doNotBoard`。
4. **乗換**: 路線 A は目的地に届かないが停留所 T を持つ。路線 B の停留所が T から 100m で、その後ろが目的地から 100m → 乗換 1。番号表の「1」列の番号は A の ref。
5. **重複**: 同じ方位・同じ列・同じ番号が 2 旅程。徒歩が短い方が残る。
6. **マージ**: 都市 A の路線と都市 B の路線の和は両方残る。同じ id は `updatedAt` が新しい形状を残す。アンカーが現在地から 80km を超える路線は、見出しに無くても `dropMissing` で消えない。80km 以内で見出しに無い路線は消える。
7. **Swift 日付**: `syncedAt` が数値 `600000000` の JSON を読め、クラッシュしない。`updatedAt` が無いレコードも読める。

## 13. 完了条件

- `flutter/` で `flutter test` が成功する。
- `flutter analyze` で error が無い。
- 飛行機モードでも、保存済み JSON があれば番号判定と番号表が出る。その経路のコードに Google のホスト名が無い。
- 設定から JSON を書き出し、統合で読み戻すと relation が欠けない。
- iOS 以外で iCloud を呼んでも落ちない。
- Swift のソースと Xcode プロジェクトを変更していない。
