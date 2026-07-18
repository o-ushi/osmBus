# App Storeプライバシー提出チェックリスト

## 公開前の差し替え

- [ ] App Store ConnectのプライバシーポリシーURLを **[公開した `privacy-policy-ja.md` のHTTPS URL]** に差し替える
- [ ] `privacy-policy-ja.md` の問い合わせ先を実在するサポートメールへ差し替える
- [ ] Google、Apple、各Overpass運営者の最新ポリシーへのリンクを公開ページに追加する
- [ ] App Store ConnectのサポートURLを **[公開サポートURL]** に差し替える

## App Privacy回答案（提出時にSDK最新版と照合）

- 位置情報（Precise Location）: アプリ機能。経路検索・地図・到着通知に利用。ユーザーのIDへのリンクやトラッキングはしない。
- ユーザーコンテンツ（Other User Content / Search History相当）: 場所検索語、出発地・目的地、バス番号を機能提供のため処理する。Appleの定義と提出UIの選択肢を確認し、外部送信される項目を過少申告しない。
- 購入（Purchases）: StoreKitで購入資格を処理。Appleが決済を処理し、アプリはカード情報を取得しない。
- Identifiers / Diagnostics: アプリ独自実装では広告ID、独自アカウントID、分析SDK、クラッシュ送信を使用していない。ただしGoogle Maps SDK最新版のPrivacy ManifestおよびApp Privacy回答ガイドをアーカイブ時に確認する。
- Tracking: アプリ独自実装では追跡目的の利用、他社データとの結合、広告を行わない。ATTを要求しない。

「収集」のApple定義は、端末外へ送信され、事業者または第三者が一時的処理を超えて保持する場合を含み得ます。Overpass運営者やGoogle/Appleのログ保持を確認し、App Store Connectでは保守的かつ実態どおりに回答してください。

## 審査ノート案

> バージョン1の外部送信同意を初回送信前に表示します。画面にはGoogle LLC（Routes API / Maps SDK / Geocoding）、Apple Inc.（MapKit検索 / ジオコード）、OpenStreetMap Overpass APIの複数運営者と、各送信項目・目的を明記しています。「同意しない」を選ぶと対象サービスへの送信は行われず、通信を必要とする検索・地図・経路機能のみ制限されます。  
> 同意は Settings > プライバシーとデータ、または Help > プライバシーとデータからいつでも撤回・再設定できます。同画面の「すべてのデータを削除」で、目的地、履歴、登録地、Google APIキー、同意を削除できます。APIキーはKeychainに保存され、旧UserDefaults値は起動時に互換移行されます。  
> アプリはiPhone専用・縦向きです。Google APIキー未設定時はプランに応じた共有キー/試用枠がありますが、外部送信同意がない状態では共有キーを含め通信しません。

## 提出直前

- [ ] 初回起動、拒否、同意、撤回、再同意、全データ削除を実機で確認
- [ ] 通信プロキシまたはNetwork Instrumentsで拒否時に対象ホストへ送信されないことを確認
- [ ] ArchiveのPrivacy ReportでGoogle Maps SDKを含む収集・Required Reason API宣言を確認
- [ ] App Store Connect回答を公開ポリシーとアプリ内文言に一致させる
- [ ] スクリーンショットと審査手順を現行UIに合わせる

## PrivacyInfo.xcprivacy

アプリ独自コードについて、現時点で根拠を確認できないRequired Reason API宣言は追加していません。提出に使うXcodeのArchive Privacy ReportとAppleの最新Required Reason API一覧を照合し、アプリ自身が対象APIを使用していると確認できた場合だけ、該当理由コードを追加してください。Google Maps SDKのマニフェストは採用SDKバージョンに同梱される内容を確認します。
