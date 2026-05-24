import Observation
import SwiftUI
import UIKit

enum ColorTheme: String, CaseIterable, Identifiable {
    case standard
    case chic
    case pop
    case monochrome

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: return "標準"
        case .chic: return "シック"
        case .pop: return "ポップ"
        case .monochrome: return "モノクロ"
        }
    }

    var themeDescription: String {
        switch self {
        case .standard: return "iOSデフォルトの配色"
        case .chic: return "落ち着いたアースカラー"
        case .pop: return "明るくビビッドな配色"
        case .monochrome: return "モノクローム配色"
        }
    }

    var accentColor: Color {
        switch self {
        case .standard: return .blue
        case .chic: return Color(red: 0.30, green: 0.35, blue: 0.42)
        case .pop: return Color(red: 0.98, green: 0.25, blue: 0.55)
        case .monochrome: return Color(white: 0.30)
        }
    }

    var starColor: Color {
        switch self {
        case .standard: return .orange
        case .chic: return Color(red: 0.72, green: 0.55, blue: 0.25)
        case .pop: return Color(red: 1.0, green: 0.82, blue: 0.0)
        case .monochrome: return Color(white: 0.50)
        }
    }

    var pinColor: Color {
        switch self {
        case .standard: return Color(red: 0.92, green: 0.22, blue: 0.14)
        case .chic: return Color(red: 0.35, green: 0.28, blue: 0.22)
        case .pop: return Color(red: 0.15, green: 0.72, blue: 0.88)
        case .monochrome: return Color(white: 0.22)
        }
    }

    var previewColors: [Color] { [accentColor, starColor, pinColor] }

    var sceneColor: Color {
        switch self {
        case .standard:   return Color(red: 253/255, green: 252/255, blue: 240/255)
        case .chic:       return Color(red: 0.96, green: 0.93, blue: 0.88)
        case .pop:        return Color(red: 1.0, green: 0.93, blue: 0.97)
        case .monochrome: return Color(white: 0.93)
        }
    }

    var navigationBarBackground: Color? {
        self == .standard ? nil : sceneColor
    }

    var navigationBarScheme: ColorScheme { .light }
}

extension View {
    @ViewBuilder
    func themedNavigationBar(_ theme: ColorTheme) -> some View {
        if let bg = theme.navigationBarBackground {
            self
                .toolbarBackground(bg, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(theme.navigationBarScheme, for: .navigationBar)
        } else {
            self
        }
    }

    /// タブバーの背景をシーン色で固定し、輝度に応じた ColorScheme を設定する。
    /// standard テーマでは何もしない（システム既定のまま）。
    @ViewBuilder
    func themedTabBar(_ theme: ColorTheme, sceneColor: Color) -> some View {
        if theme == .standard {
            self
        } else {
            // 輝度 0.18 を境に明暗を判定（WCAG AA 基準と整合）
            let scheme: ColorScheme = sceneColor.relativeLuminance > 0.18 ? .light : .dark
            self
                .toolbarBackground(sceneColor, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarColorScheme(scheme, for: .tabBar)
        }
    }
}

@Observable
final class ColorThemeManager {
    static let shared = ColorThemeManager()

    private(set) var currentTheme: ColorTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "osmBus.colorTheme")
        }
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: "osmBus.colorTheme"),
           let theme = ColorTheme(rawValue: saved) {
            currentTheme = theme
        } else {
            currentTheme = .standard
        }
    }

    func changeTheme(to theme: ColorTheme) {
        currentTheme = theme
    }
}
