import CloudKit
import UIKit

/// Minimal UIKit hook SwiftUI's `App` lifecycle still needs for two CloudKit callbacks: the
/// user accepting a `CKShare` invite (opened from Messages/Mail), and a silent push telling us
/// the shared zone changed. Both hand off to `CareCircleStore` via a static closure set by
/// `HandoffApp` once its `@StateObject`s exist.
final class AppDelegate: NSObject, UIApplicationDelegate {
    static var shareAcceptedHandler: ((CKShare.Metadata) -> Void)?
    static var remoteChangeHandler: (() -> Void)?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        Self.shareAcceptedHandler?(cloudKitShareMetadata)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Self.remoteChangeHandler?()
        completionHandler(.newData)
    }
}
