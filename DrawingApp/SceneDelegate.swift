//
//  SceneDelegate.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/09/21.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let _ = (scene as? UIWindowScene) else { return }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }

    // MARK: 他アプリからPDFファイルを受け取る　アプリ外部から共有された場合　図面PDFファイルを取り込む　iCloud Container にプロジェクトフォルダを作成　iOS13から

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        // リクエストURLの取得
        guard let url = URLContexts.first?.url else {
            return
        }
        // ここで url.path を参照すると渡されたファイルの場所がわかる
        print(url.path) // /private/var/mobile/Library/Mobile Documents/com~apple~CloudDocs/Desktop/R5seikatupanfu_kojin.pdf
        
        // この手法でアプリが起動した場合はoptionsにUIApplication.OpenURLOptionsKey.openInPlaceというキーで値が入っているので、別の処理と混合しないようにこれを使ってうまく切り分けてやる必要もありそうです。
        let sourceApplication = URLContexts.first?.options.sourceApplication
        let annotation = URLContexts.first?.options.annotation
        let openInPlace = URLContexts.first?.options.openInPlace
        let eventAttribution = URLContexts.first?.options.eventAttribution
        if let _ = URLContexts.first?.options.openInPlace {
            // ファイルが共有されたときの処理
            
            // 識別子の取得
            guard let components = URLComponents(string: url.absoluteString),
                    let pathExtension = components.url?.pathExtension else {
                return
            }
            print(pathExtension)
            
            if pathExtension == "pdf" {
                // url.pathを見てみると「インボックス」と呼ばれる端末上のファイル置き場にあるファイルパスが取得できるので、 FileManagerを使用してファイルを然るべき場所にコピーします。
                // 渡されたファイルを使ってそのまま破棄するのであれば「一時ディレクトリ」、恒久的に保存するのであれば「ドキュメントディレクトリ」などが適しているかと思います。
                
                // USBメモリなど外部記憶装置内のファイルにアクセスするにはセキュリティで保護されたリソースへのアクセス許可が必要
                guard url.startAccessingSecurityScopedResource() else {
                    // ここで選択したURLでファイルを処理する
                    return
                }
                
                // iCloud Documents にバックアップを作成する
                BackupManager.shared.backup(
                    fileURL: nil, // プロジェクトフォルダを新規作成する
                    modifiedContentsURL: url,
                    completion: {
                        //
                    },
                    errorHandler: {
                        //
                    }
                )
                // ファイルの処理が終わったら、セキュリティで保護されたリソースを解放
                defer { url.stopAccessingSecurityScopedResource() }
            }
        }
    }
}

