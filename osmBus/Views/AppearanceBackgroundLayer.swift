import SwiftUI

/// リスト等のコンテンツ背面に重ねるシーン色＋テクスチャ層。
struct AppearanceBackgroundLayer: View {
    var texture: AppTexture
    var colorScheme: ColorScheme
    var sceneColor: Color

    var body: some View {
        ZStack {
            sceneColor
                .opacity(colorScheme == .dark ? 0.70 : 0.92)
            textureOverlay
        }
    }

    @ViewBuilder
    private var textureOverlay: some View {
        switch texture {
        case .paperDefault:
            AppTexturePaperCanvas(colorScheme: colorScheme)
        case .grid:
            AppTextureGridCanvas(colorScheme: colorScheme)
        case .dot:
            AppTextureDotCanvas(colorScheme: colorScheme)
        case .oldMap:
            AppTextureOldMapCanvas(colorScheme: colorScheme)
        case .brick:
            AppTextureBrickCanvas(colorScheme: colorScheme)
        case .diagonalWeave:
            AppTextureDiagonalWeaveCanvas(colorScheme: colorScheme)
        case .waves:
            AppTextureWavesCanvas(colorScheme: colorScheme)
        }
    }
}

// MARK: - Texture canvases

private struct AppTexturePaperCanvas: View {
    var colorScheme: ColorScheme

    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                let step: CGFloat = 28
                let gOp = colorScheme == .dark ? 0.18 : 0.12
                let dOp = colorScheme == .dark ? 0.12 : 0.09

                var grid = Path()
                var x: CGFloat = 0
                while x <= size.width + step {
                    grid.move(to: CGPoint(x: x, y: 0))
                    grid.addLine(to: CGPoint(x: x, y: size.height))
                    x += step
                }
                var y: CGFloat = 0
                while y <= size.height + step {
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                    y += step
                }
                context.stroke(grid, with: .color(Color(red: 0.55, green: 0.45, blue: 0.28).opacity(gOp)),
                               style: StrokeStyle(lineWidth: 0.45, lineCap: .round))

                y = 0
                while y <= size.height + step {
                    x = 0
                    while x <= size.width + step {
                        let r: CGFloat = 0.6
                        context.fill(
                            Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                            with: .color(Color(red: 0.20, green: 0.55, blue: 0.35).opacity(dOp))
                        )
                        x += step
                    }
                    y += step
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct AppTextureGridCanvas: View {
    var colorScheme: ColorScheme

    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                let step: CGFloat = 24
                let op = colorScheme == .dark ? 0.20 : 0.16
                var path = Path()
                var x: CGFloat = 0
                while x <= size.width + step {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    x += step
                }
                var y: CGFloat = 0
                while y <= size.height + step {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    y += step
                }
                context.stroke(path, with: .color(Color(red: 0.40, green: 0.35, blue: 0.25).opacity(op)),
                               style: StrokeStyle(lineWidth: colorScheme == .dark ? 0.40 : 0.55, lineCap: .round))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct AppTextureDotCanvas: View {
    var colorScheme: ColorScheme

    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                let step: CGFloat = 22
                let op = colorScheme == .dark ? 0.18 : 0.14
                var y: CGFloat = 0
                while y <= size.height + step {
                    var x: CGFloat = 0
                    while x <= size.width + step {
                        let r: CGFloat = 0.9
                        context.fill(
                            Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                            with: .color(Color(red: 0.30, green: 0.50, blue: 0.35).opacity(op))
                        )
                        x += step
                    }
                    y += step
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct AppTextureOldMapCanvas: View {
    var colorScheme: ColorScheme

    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                let sepia = Color(red: 0.55, green: 0.42, blue: 0.28)
                let ink   = Color(red: 0.35, green: 0.26, blue: 0.18)
                context.fill(Path(CGRect(origin: .zero, size: size)),
                             with: .color(sepia.opacity(colorScheme == .dark ? 0.16 : 0.24)))

                var coast = Path()
                coast.move(to: CGPoint(x: 0, y: size.height * 0.35))
                coast.addQuadCurve(to: CGPoint(x: size.width * 0.45, y: size.height * 0.42),
                                   control: CGPoint(x: size.width * 0.2, y: size.height * 0.22))
                coast.addQuadCurve(to: CGPoint(x: size.width, y: size.height * 0.38),
                                   control: CGPoint(x: size.width * 0.72, y: size.height * 0.55))
                context.stroke(coast, with: .color(ink.opacity(0.30)),
                               style: StrokeStyle(lineWidth: 1.2, lineCap: .round))

                var river = Path()
                river.move(to: CGPoint(x: size.width * 0.15, y: size.height))
                river.addQuadCurve(to: CGPoint(x: size.width * 0.85, y: 0),
                                   control: CGPoint(x: size.width * 0.35, y: size.height * 0.45))
                context.stroke(river, with: .color(ink.opacity(0.18)),
                               style: StrokeStyle(lineWidth: 0.9, lineCap: .round, dash: [6, 5]))

                let gs: CGFloat = 56
                var grid = Path()
                var gx: CGFloat = 0
                while gx <= size.width + gs {
                    grid.move(to: CGPoint(x: gx, y: 0)); grid.addLine(to: CGPoint(x: gx, y: size.height))
                    gx += gs
                }
                var gy: CGFloat = 0
                while gy <= size.height + gs {
                    grid.move(to: CGPoint(x: 0, y: gy)); grid.addLine(to: CGPoint(x: size.width, y: gy))
                    gy += gs
                }
                context.stroke(grid, with: .color(ink.opacity(0.07)),
                               style: StrokeStyle(lineWidth: 0.35))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct AppTextureBrickCanvas: View {
    var colorScheme: ColorScheme

    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                let bW: CGFloat = 54, bH: CGFloat = 26, joint: CGFloat = 3
                let stroke = Color(red: 0.55, green: 0.38, blue: 0.22).opacity(colorScheme == .dark ? 0.36 : 0.28)
                let accent = Color(red: 0.55, green: 0.28, blue: 0.20).opacity(colorScheme == .dark ? 0.18 : 0.14)
                var row = 0; var y: CGFloat = 0
                while y < size.height + bH {
                    let stagger = CGFloat(row % 2) * (bW + joint) * 0.5
                    var x: CGFloat = -stagger
                    while x < size.width + bW {
                        let rect = CGRect(x: x, y: y, width: bW - joint, height: bH - joint)
                        let path = Path(roundedRect: rect, cornerRadius: 2)
                        context.stroke(path, with: .color(stroke), lineWidth: 1.1)
                        context.stroke(path, with: .color(accent), lineWidth: 0.35)
                        x += bW + joint
                    }
                    y += bH + joint; row += 1
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct AppTextureDiagonalWeaveCanvas: View {
    var colorScheme: ColorScheme

    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                let step: CGFloat = 16
                let c1 = Color(red: 0.25, green: 0.50, blue: 0.38).opacity(colorScheme == .dark ? 0.13 : 0.10)
                let c2 = Color(red: 0.55, green: 0.38, blue: 0.20).opacity(colorScheme == .dark ? 0.11 : 0.09)
                var p1 = Path()
                var s: CGFloat = -size.height
                while s < size.width + size.height {
                    p1.move(to: CGPoint(x: s, y: 0)); p1.addLine(to: CGPoint(x: s + size.height, y: size.height))
                    s += step
                }
                context.stroke(p1, with: .color(c1), lineWidth: 0.55)
                var p2 = Path()
                s = -size.height
                while s < size.width + size.height {
                    p2.move(to: CGPoint(x: s, y: size.height)); p2.addLine(to: CGPoint(x: s + size.height, y: 0))
                    s += step
                }
                context.stroke(p2, with: .color(c2), lineWidth: 0.55)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct AppTextureWavesCanvas: View {
    var colorScheme: ColorScheme

    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                let rowStep: CGFloat = 40, amp: CGFloat = 5, wl: CGFloat = 72
                let lineColor = Color(red: 0.45, green: 0.35, blue: 0.22).opacity(colorScheme == .dark ? 0.18 : 0.14)
                var baseY: CGFloat = 0
                while baseY < size.height + rowStep {
                    var path = Path()
                    let n = max(8, Int(size.width / 6))
                    for i in 0 ... n {
                        let xf = CGFloat(i) / CGFloat(n) * size.width
                        let yf = baseY + amp * sin((xf / wl) * .pi * 2)
                        i == 0 ? path.move(to: CGPoint(x: xf, y: yf)) : path.addLine(to: CGPoint(x: xf, y: yf))
                    }
                    context.stroke(path, with: .color(lineColor),
                                   style: StrokeStyle(lineWidth: 0.85, lineCap: .round, lineJoin: .round))
                    baseY += rowStep
                }
            }
        }
        .allowsHitTesting(false)
    }
}
