import SwiftUI

/// メイン画面背面のシーン色＋方眼ドットテクスチャ。
struct SceneBackgroundLayer: View {
    var colorScheme: ColorScheme
    var sceneColor: Color

    var body: some View {
        ZStack {
            sceneColor
                .opacity(colorScheme == .dark ? 0.70 : 0.92)
            PaperGridDotCanvas(colorScheme: colorScheme)
        }
    }
}

private struct PaperGridDotCanvas: View {
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
    }
}
