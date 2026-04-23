// MARK: - SceneDelegate.swift

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        window = UIWindow(windowScene: windowScene)
        let nav = UINavigationController(rootViewController: TaskViewController())
        window?.rootViewController = nav
        window?.makeKeyAndVisible()
    }
}
