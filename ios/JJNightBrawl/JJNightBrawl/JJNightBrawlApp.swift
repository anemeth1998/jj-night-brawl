import SwiftUI
import UIKit

/// Locks the app to landscape so the Simulator / device rotates between left & right.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Paint any early windows black (system default is white → flash / “white screen”).
        Self.paintWindowsBlack()
        return true
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        .landscape
    }

    /// Call from scene/window lifecycle so late-created windows are also black.
    static func paintWindowsBlack() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.backgroundColor = .black
                window.rootViewController?.view.backgroundColor = .black
            }
        }
    }
}

@main
struct JJNightBrawlApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .background(Color.black.ignoresSafeArea())
                .onAppear {
                    AppDelegate.paintWindowsBlack()
                }
        }
    }
}
