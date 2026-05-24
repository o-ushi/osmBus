import Observation
import SwiftUI
import UIKit

// MARK: - Frame Preset

enum AppFramePreset: String, CaseIterable, Identifiable {
    case pastel, retroCalculator, neon, monotone, hanoiEdition, custom

    var id: String { rawValue }
    static let userDefaultsKey = "osmBus.framePreset"

    static var builtInSelectable: [AppFramePreset] {
        [.pastel, .retroCalculator, .neon, .monotone, .hanoiEdition]
    }

    var displayName: String {
        switch self {
        case .pastel:          return "パステル"
        case .retroCalculator: return "レトロ電卓風"
        case .neon:            return "ネオン"
        case .monotone:        return "モノトーン"
        case .hanoiEdition:    return "ハノイ・エディション"
        case .custom:          return "カスタム"
        }
    }

    var symbolName: String {
        switch self {
        case .pastel:          return "paintpalette.fill"
        case .retroCalculator: return "keyboard.fill"
        case .neon:            return "bolt.fill"
        case .monotone:        return "circle.lefthalf.filled"
        case .hanoiEdition:    return "globe.asia.australia.fill"
        case .custom:          return "slider.horizontal.3"
        }
    }

    func builtInStyle() -> AppFrameResolvedStyle {
        switch self {
        case .pastel:
            return AppFrameResolvedStyle(
                cardFill: Color(red: 1.00, green: 0.98, blue: 0.95),
                cardBorder: Color(red: 0.96, green: 0.78, blue: 0.60),
                borderWidth: 1.0,
                accentStrip: Color(red: 1.00, green: 0.60, blue: 0.20),
                isDarkCard: false
            )
        case .retroCalculator:
            return AppFrameResolvedStyle(
                cardFill: Color(red: 0.14, green: 0.17, blue: 0.12),
                cardBorder: Color(red: 0.78, green: 0.68, blue: 0.38),
                borderWidth: 2.5,
                accentStrip: Color(red: 0.78, green: 0.68, blue: 0.38),
                isDarkCard: true
            )
        case .neon:
            return AppFrameResolvedStyle(
                cardFill: Color(red: 0.05, green: 0.04, blue: 0.12),
                cardBorder: Color(red: 0.40, green: 1.00, blue: 0.95),
                borderWidth: 2.0,
                accentStrip: Color(red: 1.00, green: 0.00, blue: 0.62),
                isDarkCard: true
            )
        case .monotone:
            return AppFrameResolvedStyle(
                cardFill: Color(red: 0.94, green: 0.94, blue: 0.96),
                cardBorder: Color(red: 0.55, green: 0.55, blue: 0.60),
                borderWidth: 1.5,
                accentStrip: Color(red: 0.35, green: 0.35, blue: 0.40),
                isDarkCard: false
            )
        case .hanoiEdition:
            return AppFrameResolvedStyle(
                cardFill: Color(red: 0.99, green: 0.95, blue: 0.88),
                cardBorder: Color(red: 0.76, green: 0.44, blue: 0.30),
                borderWidth: 2.0,
                accentStrip: Color(red: 0.92, green: 0.62, blue: 0.22),
                isDarkCard: false
            )
        case .custom:
            return AppFramePreset.pastel.builtInStyle()
        }
    }
}

struct AppFrameResolvedStyle: Equatable {
    var cardFill: Color
    var cardBorder: Color
    var borderWidth: CGFloat
    var accentStrip: Color
    var isDarkCard: Bool

    var previewSwatches: [Color] { [cardFill, cardBorder, accentStrip] }
}

struct AppFrameCustomColors: Codable, Equatable {
    var cardFillR, cardFillG, cardFillB: Double
    var cardBorderR, cardBorderG, cardBorderB: Double
    var borderWidth: Double
    var accentR, accentG, accentB: Double
    var isDarkCard: Bool

    func resolve() -> AppFrameResolvedStyle {
        AppFrameResolvedStyle(
            cardFill: Color(red: cardFillR, green: cardFillG, blue: cardFillB),
            cardBorder: Color(red: cardBorderR, green: cardBorderG, blue: cardBorderB),
            borderWidth: CGFloat(borderWidth),
            accentStrip: Color(red: accentR, green: accentG, blue: accentB),
            isDarkCard: isDarkCard
        )
    }

    static func from(_ s: AppFrameResolvedStyle) -> AppFrameCustomColors {
        func rgb(_ c: Color) -> (Double, Double, Double) {
            let ui = UIColor(c)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            ui.getRed(&r, green: &g, blue: &b, alpha: &a)
            return (Double(r), Double(g), Double(b))
        }
        let f = rgb(s.cardFill), bd = rgb(s.cardBorder), ac = rgb(s.accentStrip)
        return AppFrameCustomColors(
            cardFillR: f.0, cardFillG: f.1, cardFillB: f.2,
            cardBorderR: bd.0, cardBorderG: bd.1, cardBorderB: bd.2,
            borderWidth: Double(s.borderWidth),
            accentR: ac.0, accentG: ac.1, accentB: ac.2,
            isDarkCard: s.isDarkCard
        )
    }
}

// MARK: - Texture

enum AppTexture: String, CaseIterable, Identifiable {
    case paperDefault, grid, dot, oldMap, brick, diagonalWeave, waves

    var id: String { rawValue }
    static let userDefaultsKey = "osmBus.appTexture"

    var displayName: String {
        switch self {
        case .paperDefault:    return "既定（方眼＋ドット）"
        case .grid:            return "方眼紙"
        case .dot:             return "ドット"
        case .oldMap:          return "古い地図風"
        case .brick:           return "レンガ"
        case .diagonalWeave:   return "斜め格子"
        case .waves:           return "波線"
        }
    }

    var symbolName: String {
        switch self {
        case .paperDefault:    return "doc.plaintext"
        case .grid:            return "square.grid.3x3"
        case .dot:             return "circle.grid.3x3"
        case .oldMap:          return "map"
        case .brick:           return "square.stack.3d.down.right"
        case .diagonalWeave:   return "line.diagonal"
        case .waves:           return "water.waves"
        }
    }
}

// MARK: - Scene Tint

enum AppSceneTint: String, CaseIterable {
    case systemAdaptive, ivory, skyBlue, mint, sand, lavender, terracotta, custom

    static var selectable: [AppSceneTint] {
        [.systemAdaptive, .ivory, .skyBlue, .mint, .sand, .lavender, .terracotta]
    }
    static let namedPresets: [AppSceneTint] = [.ivory, .skyBlue, .mint, .sand, .lavender, .terracotta]

    var displayName: String {
        switch self {
        case .systemAdaptive: return "システムに合わせる"
        case .ivory:          return "アイボリー"
        case .skyBlue:        return "スカイブルー"
        case .mint:           return "ミント"
        case .sand:           return "サンド"
        case .lavender:       return "ラベンダー"
        case .terracotta:     return "テラコッタ"
        case .custom:         return "カスタム"
        }
    }

    var symbolName: String {
        switch self {
        case .systemAdaptive: return "circle.lefthalf.filled"
        case .ivory:          return "square.fill"
        case .skyBlue:        return "cloud.fill"
        case .mint:           return "leaf.fill"
        case .sand:           return "sun.dust.fill"
        case .lavender:       return "sparkles"
        case .terracotta:     return "flame.fill"
        case .custom:         return "slider.horizontal.3"
        }
    }

    fileprivate func rgbTriplet() -> (Double, Double, Double)? {
        switch self {
        case .systemAdaptive, .custom: return nil
        case .ivory:      return (253/255, 252/255, 240/255)
        case .skyBlue:    return (0.88, 0.94, 0.99)
        case .mint:       return (0.90, 0.98, 0.94)
        case .sand:       return (0.96, 0.90, 0.78)
        case .lavender:   return (0.92, 0.88, 0.99)
        case .terracotta: return (0.94, 0.72, 0.62)
        }
    }
}

// MARK: - Store

@Observable
final class AppAppearanceStore {
    static let shared = AppAppearanceStore()

    private static let customFrameKey  = "osmBus.customFrame"
    private static let sceneCustomKey  = "osmBus.sceneCustom"
    private static let sceneRKey       = "osmBus.sceneR"
    private static let sceneGKey       = "osmBus.sceneG"
    private static let sceneBKey       = "osmBus.sceneB"
    private static let eps             = 0.012

    var framePreset: AppFramePreset {
        didSet { UserDefaults.standard.set(framePreset.rawValue, forKey: AppFramePreset.userDefaultsKey) }
    }

    var customFrameColors: AppFrameCustomColors {
        didSet {
            if let data = try? JSONEncoder().encode(customFrameColors) {
                UserDefaults.standard.set(data, forKey: Self.customFrameKey)
            }
        }
    }

    var texture: AppTexture {
        didSet { UserDefaults.standard.set(texture.rawValue, forKey: AppTexture.userDefaultsKey) }
    }

    var usesCustomScene: Bool {
        didSet { UserDefaults.standard.set(usesCustomScene, forKey: Self.sceneCustomKey) }
    }
    private(set) var sceneR: Double { didSet { UserDefaults.standard.set(sceneR, forKey: Self.sceneRKey) } }
    private(set) var sceneG: Double { didSet { UserDefaults.standard.set(sceneG, forKey: Self.sceneGKey) } }
    private(set) var sceneB: Double { didSet { UserDefaults.standard.set(sceneB, forKey: Self.sceneBKey) } }

    private init() {
        let rawF = UserDefaults.standard.string(forKey: AppFramePreset.userDefaultsKey)
        framePreset = rawF.flatMap { AppFramePreset(rawValue: $0) } ?? .pastel

        if let data = UserDefaults.standard.data(forKey: Self.customFrameKey),
           let dec  = try? JSONDecoder().decode(AppFrameCustomColors.self, from: data) {
            customFrameColors = dec
        } else {
            customFrameColors = AppFrameCustomColors.from(AppFramePreset.pastel.builtInStyle())
        }

        let rawT = UserDefaults.standard.string(forKey: AppTexture.userDefaultsKey)
        texture = rawT.flatMap { AppTexture(rawValue: $0) } ?? .paperDefault

        usesCustomScene = UserDefaults.standard.object(forKey: Self.sceneCustomKey) as? Bool ?? false
        if UserDefaults.standard.object(forKey: Self.sceneRKey) == nil {
            sceneR = 253/255; sceneG = 252/255; sceneB = 240/255
        } else {
            sceneR = UserDefaults.standard.double(forKey: Self.sceneRKey)
            sceneG = UserDefaults.standard.double(forKey: Self.sceneGKey)
            sceneB = UserDefaults.standard.double(forKey: Self.sceneBKey)
        }
    }

    func resolvedFrameStyle() -> AppFrameResolvedStyle {
        framePreset == .custom ? customFrameColors.resolve() : framePreset.builtInStyle()
    }

    func applyBuiltInFrame(_ preset: AppFramePreset) {
        guard preset != .custom else { return }
        framePreset = preset
        customFrameColors = AppFrameCustomColors.from(preset.builtInStyle())
    }

    func switchToCustomFrame() {
        customFrameColors = AppFrameCustomColors.from(
            framePreset == .custom ? customFrameColors.resolve() : framePreset.builtInStyle()
        )
        framePreset = .custom
    }

    func resolvedSceneColor(colorScheme: ColorScheme) -> Color {
        if usesCustomScene { return Color(red: sceneR, green: sceneG, blue: sceneB) }
        if colorScheme == .dark { return Color(red: 0.10, green: 0.10, blue: 0.12) }
        return ColorThemeManager.shared.currentTheme.sceneColor
    }

    /// Effective color scheme that matches the rendered scene background.
    /// When a custom scene color is active its lightness determines the scheme,
    /// preventing white-on-light or dark-on-dark text in mismatched system modes.
    func sceneColorScheme(for systemScheme: ColorScheme) -> ColorScheme {
        guard usesCustomScene else { return systemScheme }
        let lum = 0.299 * sceneR + 0.587 * sceneG + 0.114 * sceneB
        return lum > 0.5 ? .light : .dark
    }

    var pickerSeedColor: Color {
        usesCustomScene
            ? Color(red: sceneR, green: sceneG, blue: sceneB)
            : Color(red: 253/255, green: 252/255, blue: 240/255)
    }

    func matchesSceneTint(_ preset: AppSceneTint) -> Bool {
        switch preset {
        case .systemAdaptive: return !usesCustomScene
        case .custom:
            guard usesCustomScene else { return false }
            return !AppSceneTint.namedPresets.contains { p in
                guard let (r, g, b) = p.rgbTriplet() else { return false }
                return near(r, sceneR) && near(g, sceneG) && near(b, sceneB)
            }
        default:
            guard let (r, g, b) = preset.rgbTriplet() else { return false }
            return usesCustomScene && near(r, sceneR) && near(g, sceneG) && near(b, sceneB)
        }
    }

    private func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < Self.eps }

    func applySceneTint(_ preset: AppSceneTint) {
        switch preset {
        case .systemAdaptive: usesCustomScene = false
        case .custom: break
        default:
            guard let (r, g, b) = preset.rgbTriplet() else { return }
            sceneR = r; sceneG = g; sceneB = b; usesCustomScene = true
        }
    }

    func setSceneColor(from color: Color) {
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return }
        sceneR = Double(r); sceneG = Double(g); sceneB = Double(b)
        usesCustomScene = true
    }

    var sceneToken: String { "\(usesCustomScene)_\(sceneR)_\(sceneG)_\(sceneB)" }
}

// MARK: - Card fill color environment key

private struct CardFillColorKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

extension EnvironmentValues {
    /// リスト行のカード塗り色。RecommendStarsDisplay 等が可読性調整に利用する。
    var cardFillColor: Color? {
        get { self[CardFillColorKey.self] }
        set { self[CardFillColorKey.self] = newValue }
    }
}

// MARK: - Color readability

extension Color {
    /// 背景の明暗に応じて、暗すぎる色を読みやすい輝度に自動補正する。
    /// ダークカード背景（isDarkCard=true）上で使う色に適用する。
    func ensuredReadable(on colorScheme: ColorScheme) -> Color {
        guard colorScheme == .dark else { return self }
        let ui = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            guard b < 0.72 else { return self }
            return Color(hue: Double(h), saturation: Double(min(s, 0.75)), brightness: 0.72, opacity: Double(a))
        } else {
            // グレースケール系（白黒・モノクロ）
            var w: CGFloat = 0
            guard ui.getWhite(&w, alpha: &a), w < 0.72 else { return self }
            return Color(white: 0.72, opacity: Double(a))
        }
    }

    // MARK: WCAG contrast

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
    /// 背景が暗ければ明るく、明るければ暗く調整する。
    /// minimumContrast: UI要素の WCAG AA 基準は 3.0、通常テキストは 4.5
    func readable(against background: Color, minimumContrast: Double = 3.0) -> Color {
        guard contrastRatio(against: background) < minimumContrast else { return self }
        let bgLum = background.relativeLuminance
        let goLight = bgLum <= 0.18   // 暗い背景 → テキストを明るく
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
            // グレースケール
            var w: CGFloat = 0
            _ = ui.getWhite(&w, alpha: &a)
            return goLight ? Color(white: 1.0, opacity: Double(a)) : Color(white: 0.0, opacity: Double(a))
        }
    }
}
