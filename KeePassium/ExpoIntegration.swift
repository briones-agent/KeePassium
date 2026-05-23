//  KeePassium + Expo Brownfield demo
//  Brownfield integration glue: publishes mock vault state into the
//  expo-brownfield shared-state KV store, listens for messages coming back
//  from the React Native side, and exposes an entry-point for the Expo
//  Vault Inspector screen.

import Foundation
import UIKit
import KeePassiumExpo

enum ExpoIntegration {
    private static let vaultName = "Demo Vault.kdbx"
    private static let entryCount = 27
    private static var messagingListenerId: String?

    /// Call from AppDelegate.didFinishLaunching to wire up the brownfield demo.
    /// Initializes the React Native host, seeds shared state, and subscribes
    /// to messages from RN (currently: re-roll the session token).
    static func bootstrap() {
        ReactNativeHostManager.shared.initialize()
        seedSharedState()
        registerMessageHandlers()
    }

    /// Returns a navigation controller hosting the Expo Vault Inspector RN
    /// screen, ready to be presented from any UIViewController.
    static func makeInspectorViewController() -> UIViewController {
        let rn = ReactNativeViewController(moduleName: "main")
        rn.title = "Vault Inspector"
        let nav = UINavigationController(rootViewController: rn)
        nav.modalPresentationStyle = .fullScreen
        let doneItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: nav,
            action: #selector(UIViewController.dismissExpoInspector)
        )
        rn.navigationItem.rightBarButtonItem = doneItem
        return nav
    }

    /// Demo helper: when launched with `-KeePassiumExpoAutoPresent YES` (or
    /// `defaults write com.keepassium.ios KeePassiumExpoAutoPresent -bool YES`),
    /// dismiss anything KeePassium has already presented (onboarding, app-lock)
    /// and replace the root view controller with the Expo Vault Inspector so
    /// the integration is trivially recordable without UI automation.
    static func scheduleAutoPresentIfRequested() {
        guard UserDefaults.standard.bool(forKey: "KeePassiumExpoAutoPresent") else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            takeOverWindow()
        }
    }

    private static func takeOverWindow() {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first else {
            return
        }
        window.rootViewController = makeInspectorViewController()
        window.makeKeyAndVisible()
    }

    /// Present the Vault Inspector on top of the host's existing UI. Used by
    /// production flows (e.g. a future menu item) that want a sheet rather
    /// than a takeover.
    static func present(from base: UIViewController?) {
        guard var presenter = base else { return }
        while let next = presenter.presentedViewController { presenter = next }
        presenter.present(makeInspectorViewController(), animated: true)
    }

    private static func seedSharedState() {
        BrownfieldState.set("vaultName", vaultName)
        BrownfieldState.set("entryCount", entryCount)
        BrownfieldState.set("sessionToken", newToken())
        BrownfieldState.set("lastUnlocked", ISO8601DateFormatter().string(from: Date()))
    }

    private static func registerMessageHandlers() {
        messagingListenerId = BrownfieldMessaging.addListener { message in
            guard let type = message["type"] as? String else { return }
            switch type {
            case "REROLL_TOKEN":
                handleReRollToken()
            default:
                break
            }
        }
    }

    private static func handleReRollToken() {
        BrownfieldState.set("sessionToken", newToken())
        BrownfieldState.set("lastUnlocked", ISO8601DateFormatter().string(from: Date()))
        BrownfieldMessaging.sendMessage([
            "type": "TOKEN_REROLLED",
            "at": ISO8601DateFormatter().string(from: Date())
        ])
    }

    private static func newToken() -> String {
        UUID().uuidString
    }

    private static func keyWindowRoot() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .rootViewController
    }
}

private extension UIViewController {
    @objc func dismissExpoInspector() {
        self.dismiss(animated: true)
    }
}
