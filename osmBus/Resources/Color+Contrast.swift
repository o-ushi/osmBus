import SwiftUI
import UIKit

extension Color {
    /// WCAG 相対輝度（0〜1）
    var relativeLuminance: Double {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return 0 }
        func lin(_ c: CGFloat) -> Double {
            let v = Double(c)
            return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    /// WCAG コントラスト比（1〜21）
    func contrastRatio(against other: Color) -> Double {
        let l1 = relativeLuminance, l2 = other.relativeLuminance
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    /// 指定した背景色に対してコントラスト比が minimumContrast 未満のとき、
    /// 輝度を段階的に調整して可読性を確保した色を返す。
    func readable(against background: Color, minimumContrast: Double = 3.0) -> Color {
        guard contrastRatio(against: background) < minimumContrast else { return self }
        let bgLum = background.relativeLuminance
        let goLight = bgLum <= 0.18
        let ui = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        if s > 0.02 {
            var newB = b
            for _ in 0..<26 {
                newB = goLight ? min(1.0, newB + 0.04) : max(0.0, newB - 0.04)
                let candidate = Color(hue: Double(h), saturation: Double(s),
                                      brightness: Double(newB), opacity: Double(a))
                if candidate.contrastRatio(against: background) >= minimumContrast { return candidate }
                if (goLight && newB >= 1.0) || (!goLight && newB <= 0.0) { break }
            }
            return Color(hue: Double(h), saturation: Double(s),
                         brightness: goLight ? 1.0 : 0.0, opacity: Double(a))
        } else {
            var w: CGFloat = 0
            _ = ui.getWhite(&w, alpha: &a)
            return goLight ? Color(white: 1.0, opacity: Double(a)) : Color(white: 0.0, opacity: Double(a))
        }
    }
}
