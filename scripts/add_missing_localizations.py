#!/usr/bin/env python3
"""Append missing localization entries (en/ja/vi). Keys must not use osmBus_ prefix."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "osmBus"
LANGS = ("en", "ja", "vi")
ENTRY = re.compile(r'^"(.+)"\s*=\s*"(.*)"\s*;\s*$')

# en / ja / vi
T: dict[str, tuple[str, str, str]] = {
    "APIキー_Premium限定_タイトル": ("PREMIUM feature", "PREMIUM限定機能", "Tinh nang PREMIUM"),
    "APIキー_Premium限定_説明": (
        "Setting your own Google API key is available on the PREMIUM plan.",
        "Google API キーの設定は PREMIUM プランで利用できます。",
        "Cai khóa Google API riêng có trong gói PREMIUM.",
    ),
    "IAP_再読み込み": ("Reload products", "商品を再読み込み", "Tai lai san pham"),
    "IAP_商品が見つかりません": ("Product not found", "商品が見つかりません", "Khong tim thay san pham"),
    "IAP_商品読み込み中": ("Loading products…", "商品を読み込み中…", "Dang tai san pham…"),
    "IAP_商品読み込み失敗": ("Could not load products", "商品の読み込みに失敗しました", "Khong tai duoc san pham"),
    "IAP_復元失敗": ("Restore failed", "復元に失敗しました", "Khoi phuc that bai"),
    "IAP_購入保留": ("Purchase pending approval", "購入が保留中です", "Giao dich dang cho duyet"),
    "IAP_購入失敗": ("Purchase failed", "購入に失敗しました", "Mua hang that bai"),
    "MapsAPI_エラー_400": ("Bad request. Make sure Maps API is enabled in Google Cloud.", "リクエストが不正です。Google Cloud で Maps API が有効か確認してください。", "Yeu cau loi. Hay bat Maps API tren Google Cloud."),
    "MapsAPI_エラー_401": ("Authentication error. Check your API key and Maps API status.", "認証エラーです。API キーと Maps API の状態を確認してください。", "Loi xac thuc. Kiem tra khóa API va Maps API."),
    "MapsAPI_エラー_429": ("Too many requests. Please wait and try again.", "リクエストが多すぎます。しばらく待ってから再試行してください。", "Qua nhieu yeu cau. Vui long doi va thu lai."),
    "MapsAPI_エラー_500": ("Google servers are temporarily unavailable.", "Google のサーバーが一時的に利用できません。", "May chu Google tam thoi khong kha dung."),
    "MapsAPI_エラー_不明_%@": ("Maps API error: %@", "Maps API エラー: %@", "Loi Maps API: %@"),
    "MapsAPI_エラー_拒否_%@": ("Request denied: %@", "リクエストが拒否されました: %@", "Yeu cau bi tu choi: %@"),
    "MapsAPI_接続成功": ("Connected. Maps API key is valid.", "接続成功。Maps API キーは有効です。", "Ket noi thanh cong. Khóa Maps API hop le."),
    "Maps_お試し残り_%d": ("Map uses remaining this month: %d", "今月の地図利用残り：%d回", "Luot ban do con lai thang nay: %d"),
    "Maps_お試し終了_タイトル": ("Monthly map limit reached", "今月の地図利用枠を使い切りました", "Da het han muc ban do thang nay"),
    "Maps_お試し終了_本文": (
        "Upgrade to PREMIUM or set your own Maps API key in Settings.",
        "PREMIUM にアップグレードするか、設定で Maps API キーを入力してください。",
        "Nang cap PREMIUM hoac cai khóa Maps API trong Cai dat.",
    ),
    "Maps_お試し説明": (
        "Without your own key, FREE plan gets limited monthly map uses via the shared key.",
        "キーなしでは FREE プランは共有キーで毎月一定回数まで地図を利用できます。",
        "Khong co khóa rieng, goi FREE dung khóa chung voi gioi han hang thang.",
    ),
    "Maps_現在の状態": ("Maps status", "Maps の状態", "Trang thai Maps"),
    "Maps_設定に進む": ("Open Settings", "設定を開く", "Mo Cai dat"),
    "Overpass_サーバー_%@": ("Overpass server: %@", "Overpass サーバー: %@", "May chu Overpass: %@"),
    "Overpass_サーバー処理": ("Overpass server is processing. Try again.", "Overpass サーバーが処理中です。再試行してください。", "May chu Overpass dang xu ly. Thu lai."),
    "Overpass_タイムアウト": ("Overpass request timed out.", "Overpass のリクエストがタイムアウトしました。", "Yeu cau Overpass het thoi gian."),
    "Overpass_現在地なし": ("Current location unavailable for route lookup.", "路線検索に現在地が必要です。", "Can vi tri hien tai de tra cuu tuyen."),
    "Overpass_解析失敗": ("Could not parse route data.", "路線データの解析に失敗しました。", "Khong phan tich duoc du lieu tuyen."),
    "Overpass_路線なし": ("No matching bus route found.", "該当するバス路線が見つかりません。", "Khong tim thay tuyen xe phu hop."),
    "Overpass_通信エラー": ("Could not reach Overpass server.", "Overpass サーバーに接続できません。", "Khong ket noi duoc may chu Overpass."),
    "PREMIUM_RoutesAPI_説明": (
        "PREMIUM: unlimited bus checks with the shared key, or use your own Routes API key.",
        "PREMIUM：共有キーでのバス判定は無制限。またはご自身の Routes API キーを設定できます。",
        "PREMIUM: kiem tra xe khong gioi han voi khóa chung, hoac dung khóa Routes API rieng.",
    ),
    "PREMIUM_利用中": ("PREMIUM active", "PREMIUM 利用中", "Dang dung PREMIUM"),
    "RoutesAPI_お試し状況_補足": (
        "Resets on the 1st of each month. PREMIUM users are not limited.",
        "毎月1日にリセットされます。PREMIUM プランは上限がありません。",
        "Dat lai ngay 1 hang thang. Gói PREMIUM khong bi gioi han.",
    ),
    "その他": ("More", "その他", "Khac"),
    "エラー_不明": ("Unknown error", "不明なエラー", "Loi khong xac dinh"),
    "キーフィードバック": ("Keypad feedback", "キーパッドのフィードバック", "Phan hoi ban phim"),
    "キーフィードバック_クリック": ("Click sound", "クリック音", "Am click"),
    "キーフィードバック_バイブ": ("Haptic feedback", "バイブレーション", "Rung"),
    "キーフィードバック_バイブ強さ": ("Haptic intensity", "バイブの強さ", "Cuong do rung"),
    "キーフィードバック_フッター": ("Adjust sound and vibration when tapping the keypad.", "テンキーを押したときの音と振動を調整します。", "Dieu chinh am thanh va rung khi bam ban phim."),
    "キーフィードバック_弱め": ("Light", "弱め", "Nhe"),
    "キーフィードバック_強め": ("Heavy", "強め", "Manh"),
    "キーフィードバック_普通": ("Medium", "普通", "Vua"),
    "キーフィードバック_音量": ("Volume", "音量", "Am luong"),
    "サウンド_アラーム": ("Alarm", "アラーム", "Bao thuc"),
    "サウンド_タック": ("Tick", "タック", "Tach"),
    "サウンド_チャイム": ("Chime", "チャイム", "Chuong"),
    "サウンド_ディン": ("Ding", "ディン", "Ding"),
    "サウンド_プレビュー": ("Preview", "プレビュー", "Nghe thu"),
    "サウンド_メッセージ": ("Message", "メッセージ", "Tin nhan"),
    "サウンド_確認音": ("Confirm", "確認音", "Am xac nhan"),
    "サウンド選択_タイトル": ("Choose sound", "サウンドを選択", "Chon am thanh"),
    "タップで地図": ("Tap to view on map", "タップで地図表示", "Cham de xem tren ban do"),
    "テンキー_判定": ("Bus number keypad", "バス番号テンキー", "Ban phim so xe buyt"),
    "乗ってみる": ("Try boarding", "乗ってみる", "Thu len xe"),
    "乗れるかも": ("Might work?", "乗れるかも？", "Co the len xe?"),
    "乗車中": ("Riding", "乗車中", "Dang di"),
    "乗車中断_中断する": ("Stop riding", "乗車を中断", "Dung theo doi"),
    "乗車中断_確認_タイトル": ("Stop riding?", "乗車を中断しますか？", "Dung theo doi?"),
    "乗車中断_確認_本文": ("Stop tracking this ride?", "この乗車の追跡を終了します。", "Ket thuc theo doi chuyen di nay?"),
    "乗車開始": ("Start riding", "乗車開始", "Bat dau di"),
    "他の系統も乗れるかも": ("Other variants might work too", "他の系統も乗れるかも", "Bien the khac cung co the di duoc"),
    "地図_タップヒント": ("Tap the map to pick a location", "地図をタップして場所を選んでください", "Cham ban do de chon dia diem"),
    "地図_住所取得中": ("Looking up address…", "住所を取得中…", "Dang lay dia chi…"),
    "地図_出発地": ("Origin", "出発地", "Diem di"),
    "地図_手動出発地クリア": ("Clear manual origin", "手動出発地をクリア", "Xoa diem di thu cong"),
    "地図_目的地": ("Destination", "目的地", "Diem den"),
    "地図から選択": ("Pick on map", "地図から選択", "Chon tren ban do"),
    "履歴消去フッター": ("Clear all destination history.", "目的地の履歴をすべて消去します。", "Xoa toan bo lich su dia diem."),
    "検索_失敗": ("Search failed", "検索に失敗しました", "Tim kiem that bai"),
    "残りN停_%d": ("%d stops left", "残り%d停", "Con %d tram"),
    "現在地に移動": ("Go to current location", "現在地に移動", "Ve vi tri hien tai"),
    "系統選択_タイトル": ("Choose route variant", "系統を選択", "Chon bien the tuyen"),
    "設定_アラート_アラーム": ("Alarm alerts", "アラーム通知", "Canh bao chuong"),
    "設定_アラート_サウンド": ("Sound", "サウンド", "Am thanh"),
    "設定_アラート_バイブ": ("Vibration", "バイブレーション", "Rung"),
    "設定_アラート_バイブ強さ": ("Vibration strength", "バイブの強さ", "Cuong do rung"),
    "設定_アラート_通知": ("Notifications", "通知", "Thong bao"),
    "設定_アラート_通知フッター": ("Configure alerts when approaching your stop.", "降車停に近づいたときのアラートを設定します。", "Cau hinh canh bao khi gan tram xuong."),
    "設定_アラート_音量": ("Volume", "音量", "Am luong"),
    "設定_アラート_音量_システム": ("Follow system volume", "システム音量に従う", "Theo am luong he thong"),
    "設定_到着アラート": ("Arrival alerts", "到着アラート", "Canh bao den noi"),
    "設定_距離アラート": ("Distance alerts", "距離アラート", "Canh bao khoang cach"),
    "設定_距離アラート_%d": ("Distance alert %d", "距離アラート %d", "Canh bao khoang cach %d"),
    "設定_距離アラート_フッター": ("Alert when within the set distance of your stop.", "設定した距離以内に入ったらアラートします。", "Canh bao khi trong pham vi khoang cach da dat."),
    "設定_距離アラート_距離": ("Distance (m)", "距離（m）", "Khoang cach (m)"),
    "距離アラート_%d": ("Alert at %d m", "%dm でアラート", "Canh bao o %d m"),
    "距離アラート_タイトル": ("Distance alert", "距離アラート", "Canh bao khoang cach"),
    "路線図": ("Route map", "路線図", "Ban do tuyen"),
    "路線図_OSM出典": ("Route data © OpenStreetMap contributors", "路線データ © OpenStreetMap contributors", "Du lieu tuyen © OpenStreetMap contributors"),
    "路線図_エラー_タイトル": ("Route map error", "路線図エラー", "Loi ban do tuyen"),
    "路線図_クリア": ("Clear", "クリア", "Xoa"),
    "路線図_候補": ("Route candidates", "路線候補", "Tuyen ung vien"),
    "路線図_候補_ヒント": ("Select a route matching your bus number.", "バス番号に一致する路線を選んでください。", "Chon tuyen khop voi so xe buyt."),
    "路線図_現在地なし警告": ("Current location needed to show the route map.", "路線図の表示には現在地が必要です。", "Can vi tri hien tai de hien thi ban do tuyen."),
    "路線図_読込中_%@": ("Loading %@…", "%@ を読込中…", "Dang tai %@…"),
    "逆方向_タイトル": ("Reverse direction?", "逆方向です", "Huong nguoc lai?"),
    "逆方向_本文": (
        "This bus may be going the opposite direction. Check the route before boarding.",
        "このバスは逆方向に走っている可能性があります。乗車前に路線を確認してください。",
        "Xe buyt co the di nguoc huong. Kiem tra tuyen truoc khi len xe.",
    ),
    "降車": ("Get off", "降車", "Xuong xe"),
}


def collect_used_keys() -> set[str]:
    patterns = [
        re.compile(r'AppLocaleString\.(?:text|currentText|formatted|currentFormatted)\(\s*"([^"]+)"'),
        re.compile(r'localized\("([^"]+)"\)'),
        re.compile(
            r'(?:nameKey|titleKey|bodyKey|savedMessageKey|introLeadKey|introSupplementKey|'
            r'roleHeaderKey|beginnerHeaderKey|beginnerWhatTitleKey|beginnerWhatBodyKey|'
            r'beginnerFreeTitleKey|beginnerFreeBodyKey|beginnerStepsTitleKey|beginnerStepsBodyKey|'
            r'deviceStorageBodyKey|googleSendBodyKey|keyInputFooterKey|keyObtainLinkKey|'
            r'activationGuideKey|testFooterKey|deleteKeyKey|premiumOnlyBodyKey|roleTitleKey|roleBodyKey):\s*"([^"]+)"'
        ),
    ]
    used: set[str] = set()
    for path in ROOT.rglob("*.swift"):
        text = path.read_text(encoding="utf-8")
        for pat in patterns:
            used.update(pat.findall(text))
        for m in re.finditer(r'compassDirectionKeys\s*=\s*\[(.*?)\]', text, re.S):
            used.update(re.findall(r'"([^"]+)"', m.group(1)))
        for m in re.finditer(r'case\s+\.\w+:\s*return\s+"([^"]+)"', text):
            k = m.group(1)
            if "_" in k or k.startswith(("help_", "Routes", "Maps", "テンキー", "キーフィードバック", "サウンド")):
                used.add(k)
        for m in re.finditer(r'isTrialExhausted\s*\?\s*"([^"]+)"\s*:\s*"([^"]+)"', text):
            used.update(m.groups())
        for m in re.finditer(r'place == nil \? "([^"]+)" : "([^"]+)"', text):
            used.update(m.groups())
        for m in re.finditer(r'role == \.origin \? "([^"]+)" : "([^"]+)"', text):
            used.update(m.groups())
    used.update({"FREE", "PREMIUM"})
    return used


def append_missing() -> None:
    used = collect_used_keys()
    for lang_idx, lang in enumerate(LANGS):
        path = ROOT / f"Resources/Localization/{lang}.lproj/Localizable.strings"
        existing = set()
        lines = path.read_text(encoding="utf-8").splitlines()
        for line in lines:
            m = ENTRY.match(line.strip())
            if m:
                existing.add(m.group(1))
        missing = sorted(k for k in used if k not in existing)
        if not missing:
            print(f"{lang}: nothing to add")
            continue
        out = lines[:]
        if out and out[-1].strip():
            out.append("")
        added = 0
        for key in missing:
            if key in T:
                val = T[key][lang_idx].replace("\\", "\\\\").replace('"', '\\"')
            elif lang == "ja":
                val = key.replace("\\", "\\\\").replace('"', '\\"')
            elif lang == "en":
                val = key.replace("_", " ").replace("\\", "\\\\").replace('"', '\\"')
            else:
                val = key.replace("\\", "\\\\").replace('"', '\\"')
            out.append(f'"{key}" = "{val}";')
            added += 1
        path.write_text("\n".join(out).rstrip() + "\n", encoding="utf-8")
        print(f"{lang}: added {added} keys")


if __name__ == "__main__":
    append_missing()
