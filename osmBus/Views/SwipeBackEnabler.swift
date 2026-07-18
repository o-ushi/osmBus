import SwiftUI
import UIKit

/// `navigationBarBackButtonHidden(true)` も左端スワイプでの「戻る」ジェスチャーを無効化してしまうため、
/// 非表示にしたビューへ付与してジェスチャーだけ復活させる。
private final class SwipeBackEnablerViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }
}

private struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        SwipeBackEnablerViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

extension View {
    /// 画面左上の「<」戻るボタンを消しつつ、スワイプでの戻る操作は維持する。
    func hiddenBackButtonWithSwipe() -> some View {
        navigationBarBackButtonHidden(true)
            .background(SwipeBackEnabler())
    }
}
