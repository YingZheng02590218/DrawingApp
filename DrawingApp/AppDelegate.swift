//
//  AppDelegate.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/09/21.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }
    
    // MARK: 他アプリからPDFファイルを受け取る　アプリ外部から共有された場合　図面PDFファイルを取り込む　iCloud Container にプロジェクトフォルダを作成　iOS12まで

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // ここで url.path を参照すると渡されたファイルの場所がわかる
        print(url.path)
        // url.pathを見てみると「インボックス」と呼ばれる端末上のファイル置き場にあるファイルパスが取得できるので、 FileManagerを使用してファイルを然るべき場所にコピーします。
        // 渡されたファイルを使ってそのまま破棄するのであれば「一時ディレクトリ」、恒久的に保存するのであれば「ドキュメントディレクトリ」などが適しているかと思います。
        
        // この手法でアプリが起動した場合はoptionsにUIApplication.OpenURLOptionsKey.openInPlaceというキーで値が入っているので、別の処理と混合しないようにこれを使ってうまく切り分けてやる必要もありそうです。
        if let _ = options[.openInPlace] {
            // ファイルが共有されたときの処理
            
            // 拡張子の取得
            print(url.pathExtension)
            
            if url.pathExtension == "pdf" {
                // url.pathを見てみると「インボックス」と呼ばれる端末上のファイル置き場にあるファイルパスが取得できるので、 FileManagerを使用してファイルを然るべき場所にコピーします。
                // 渡されたファイルを使ってそのまま破棄するのであれば「一時ディレクトリ」、恒久的に保存するのであれば「ドキュメントディレクトリ」などが適しているかと思います。
                
                // USBメモリなど外部記憶装置内のファイルにアクセスするにはセキュリティで保護されたリソースへのアクセス許可が必要
                guard url.startAccessingSecurityScopedResource() else {
                    // ここで選択したURLでファイルを処理する
                    return false
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
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

