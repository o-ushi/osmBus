import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  /// Flutter は裏に回るとき、シーン構成の名前を種類にした NSUserActivity を作る。
  /// iOS 27 はその種類が Info.plist の NSUserActivityTypes に無いと例外で落とすので、
  /// 乗車中に画面を切っただけでアプリが終わっていた。状態の復元は使っていないので作らない
  /// （乗車はアプリ側で保存して戻す）。
  override func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
    nil
  }
}
