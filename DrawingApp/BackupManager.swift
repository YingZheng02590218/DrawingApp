//
//  BackupManager.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/09/26.
//

import Foundation

class BackupManager {
    
    static let shared = BackupManager()
    // iCloudが有効かどうかの判定
    public var isiCloudEnabled: Bool {
        (FileManager.default.ubiquityIdentityToken != nil)
    }
    
    private init() {
        fileNameDateformater.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        fileNameDateformater.locale = Locale(identifier: "en_US_POSIX")
        
        folderNameDateformater.dateFormat = "yyyyMMddHHmm"
        folderNameDateformater.locale = Locale(identifier: "en_US_POSIX")
        
        metadataQuery = NSMetadataQuery()
    }
    
    let fileNameDateformater = DateFormatter()
    let folderNameDateformater = DateFormatter()
    
    /// バックアップフォルダURL
    private var backupFolderUrl: URL {
        let folderName = folderNameDateformater.string(from: Date()) // 日付
        // iCloud Driveのパスは、ローカルと同じように、FileManagerでとれます。
        return FileManager.default.url(forUbiquityContainerIdentifier: nil)!
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent(folderName, isDirectory: true)
    }
    /// iCloud Driveのパス
    private var documentsFolderUrl: URL {
        // iCloud Driveのパスは、ローカルと同じように、FileManagerでとれます。
        return FileManager.default.url(forUbiquityContainerIdentifier: nil)!
            .appendingPathComponent("Documents", isDirectory: true)
    }
    /// バックアップファイル名（前部）
    private let mBackupFileNamePre = "drawing_"
    
    // MARK: バックアップ
    
    /// バックアップデータ作成処理
    /// RealmのデータをiCloudにコピー
    func backup(fileURL: URL? = nil, modifiedContentsURL: URL, completion: @escaping () -> Void, errorHandler: @escaping () -> Void) {
        do {
            // iCloud Drive / DrawingApp フォルダ作成　ユーザーがFileアプリから削除したケースに対応
            if FileManager.default.fileExists(atPath: documentsFolderUrl.path) {
                print(documentsFolderUrl.path)
                // /private/var/mobile/Library/Mobile Documents/iCloud~com~ikingdom778~DrawingApp/Documents
            } else {
                print(documentsFolderUrl.path)
                // /private/var/mobile/Library/Mobile Documents/iCloud~com~ikingdom778~AccountantSTG/Documents
                try FileManager.default.createDirectory(atPath: documentsFolderUrl.path, withIntermediateDirectories: true)
            }
            /// iCloudにフォルダ作成
            if FileManager.default.fileExists(atPath: backupFolderUrl.path) {
                print(backupFolderUrl.path)
            } else {
                print(backupFolderUrl.path)
                // /private/var/mobile/Library/Mobile Documents/iCloud~com~ikingdom778~DrawingApp/Documents/202309281822
                try FileManager.default.createDirectory(atPath: backupFolderUrl.path, withIntermediateDirectories: false)
            }
            // 既存バックアップファイル（iCloud）の削除
            deleteBackup()
            
            // バックアップファイル名
            let fileName = mBackupFileNamePre + fileNameDateformater.string(from: Date()) + ".pdf" // 日付
            // バックアップファイルの格納場所
            let fileUrl = fileURL ?? backupFolderUrl.appendingPathComponent(fileName)
            // PDFファイルを iCloud Container に保存する
            if let fileName = saveToDocumentsDirectory(backupFileUrl: fileUrl, modifiedContentsURL: modifiedContentsURL) {
                print(fileName)
                completion()
            }
        } catch {
            print(error.localizedDescription)
            errorHandler()
        }
    }
    
    // PDFファイルを iCloud Container に保存する
    func saveToDocumentsDirectory(backupFileUrl: URL, modifiedContentsURL: URL) -> URL? {
        do {
            let directoryContents = try FileManager.default.contentsOfDirectory(at: modifiedContentsURL.deletingLastPathComponent(), includingPropertiesForKeys: nil) // ファイル一覧を取得
            // if you want to filter the directory contents you can do like this:
            let pdfFiles = directoryContents.filter { $0.pathExtension == "pdf" }
            print("pdf urls: ", pdfFiles)
            let pdfFileNames = pdfFiles.map { $0.deletingPathExtension().lastPathComponent }
            print("pdf list: ", pdfFileNames)
        } catch {
            print(error)
            // Desktop のPDFファイルを共有しようとすると、エラーが発生する → USBメモリなど外部記憶装置内のファイルにアクセスするにはセキュリティで保護されたリソースへのアクセス許可が必要 url.startAccessingSecurityScopedResource()
//            Error Domain=NSCocoaErrorDomain Code=257 "The file “Desktop” couldn’t be opened because you don’t have permission to view it." UserInfo={NSURL=file:///private/var/mobile/Library/Mobile%20Documents/com~apple~CloudDocs/Desktop/, NSFilePath=/private/var/mobile/Library/Mobile Documents/com~apple~CloudDocs/Desktop, NSUnderlyingError=0x280072850 {Error Domain=NSPOSIXErrorDomain Code=1 "Operation not permitted"}}
        }
        let filePath = backupFileUrl.appendingPathComponent(modifiedContentsURL.lastPathComponent)
        do {
            // コピーの前にはチェック&削除が必要
            if FileManager.default.fileExists(atPath: backupFileUrl.path) {
                // すでに backupFileUrl が存在する場合はファイルを削除する
                try FileManager.default.removeItem(at: backupFileUrl)
            }
            
            try FileManager.default.copyItem(at: modifiedContentsURL, to: backupFileUrl)
            // try FileManager.default.moveItem(at: modifiedContentsURL, to: backupFileUrl)
            
            print("modifiedContentsURL", modifiedContentsURL)
            print("backupFileUrl      ", backupFileUrl)
            print("filePath           ", filePath)
            // Automatically manage signing
            // modifiedContentsURL file:///private/var/mobile/Containers/Data/Application/FC5BE300-65E8-45F7-B42D-DD5DC5C97D79/tmp/NSIRD_DrawingApp_Ioiurc/2023-Journals.pdf
            // backupFileUrl       file:///private/var/mobile/Library/Mobile%20Documents/iCloud~com~ikingdom778~DrawingApp/Documents/202309271256/
            // filePath            file:///private/var/mobile/Library/Mobile%20Documents/iCloud~com~ikingdom778~DrawingApp/Documents/202309271256/2023-Journals.pdf
            // 証明書を作成した
            // modifiedContentsURL file:///private/var/mobile/Containers/Data/Application/E757278E-F8CD-4FF0-A5EC-9330FF5ACC3E/tmp/NSIRD_DrawingApp_LMD5Ry/2023-Journals.pdf
            // backupFileUrl       file:///var/mobile/Containers/Data/Application/E757278E-F8CD-4FF0-A5EC-9330FF5ACC3E/Documents/202309271729/drawing_2023-09-27-17-29-05.pdf
            // filePath            file:///var/mobile/Containers/Data/Application/E757278E-F8CD-4FF0-A5EC-9330FF5ACC3E/Documents/202309271729/drawing_2023-09-27-17-29-05.pdf/2023-Journals.pdf
            return backupFileUrl
        } catch {
            print(error.localizedDescription)
            // ファイルアプリからPDFファイルを共有しようとすると、エラーとなる　→ Lucidchart　アプリがアクセスを許可していないことが原因と思われる。 → USBメモリなど外部記憶装置内のファイルにアクセスするにはセキュリティで保護されたリソースへのアクセス許可が必要 url.startAccessingSecurityScopedResource()
//            Error Domain=NSCocoaErrorDomain Code=257 "The file “20200211” couldn’t be opened because you don’t have permission to view it." UserInfo={NSURL=file:///private/var/mobile/Library/Mobile%20Documents/com~apple~CloudDocs/Lucidchart/20200211/, NSFilePath=/private/var/mobile/Library/Mobile Documents/com~apple~CloudDocs/Lucidchart/20200211, NSUnderlyingError=0x280ef38d0 {Error Domain=NSPOSIXErrorDomain Code=1 "Operation not permitted"}}
             
            return nil
        }
    }
    /// ファイル情報を取得する
    /// - Parameter path: 対象ファイルパス
    /// - Returns: 対象ファイルの情報（作成日など）
    func attributesOfItem(atPath path: URL) -> [FileAttributeKey : Any] {
        do {
            return try FileManager.default.attributesOfItem(atPath: path.path)
        } catch let error {
            print(error.localizedDescription)
            return [:]
        }
    }
    /// プロジェクトフォルダ削除
    func deleteBackupFolder(folderName: String? = nil) {
        let (exists, files) = isBackupFileExists(folderName: folderName)
        if exists {
            do {
                if let folderName = folderName {
                    try FileManager.default.removeItem(at: documentsFolderUrl.appendingPathComponent(folderName))
                }
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    /// バックアップファイル削除
    func deleteBackup() {
        let (exists, files) = isBackupFileExists()
        if exists {
            do {
                for file in files {
                    try FileManager.default.removeItem(at: backupFolderUrl.appendingPathComponent(file))
                }
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    /// バックアップフォルダにバックアップファイルがあるか、ある場合、そのファイル名を取得
    /// - Returns: バックアップファイルの有無、そのファイル名
    private func isBackupFileExists(folderName: String? = nil) -> (Bool, [String]) {
        var exists = false
        var files: [String] = []
        var allFiles: [String] = []
        // バックアップフォルダのファイル取得
        do {
            if let folderName = folderName {
                // バックアップファイルの格納場所
                let folderUrl = documentsFolderUrl.appendingPathComponent(folderName)
                // ダウンロードする前にiCloudとの同期を行う
                try FileManager.default.startDownloadingUbiquitousItem(at: folderUrl)
                allFiles = try FileManager.default.contentsOfDirectory(atPath: folderUrl.path)
            } else {
                allFiles = try FileManager.default.contentsOfDirectory(atPath: backupFolderUrl.path)
                // fileName    String    ".default.realm_bk_2023-02-02-10-30-00.icloud"
            }
        } catch {
            return (exists, files)
        }
        // バックアップファイル名を選別
        for file in allFiles where file.contains(mBackupFileNamePre) {
            exists = true
            files.append(file)
        }
        return (exists, files)
    }
    
    /// 写真フォルダに写真ファイルがあるか、ある場合、そのファイル名を取得
    /// - Returns: 写真ファイルの有無、そのファイル名
    func photosIsExists(folderName: String, completion: @escaping (Bool, [String]) -> Void) {
        var exists = false
        var files: [String] = []
        var allFiles: [String] = []
        // 写真フォルダのファイル取得
        do {
            // 写真ファイルの格納場所
            let folderUrl = documentsFolderUrl.appendingPathComponent(folderName).appendingPathComponent("Photos")
            // ダウンロードする前にiCloudとの同期を行う
            try FileManager.default.startDownloadingUbiquitousItem(at: folderUrl)
            allFiles = try FileManager.default.contentsOfDirectory(atPath: folderUrl.path)
        } catch {
            completion(exists, files)
        }
        // 写真ファイル名を選別
        for file in allFiles {
            exists = true
            files.append(file)
        }
        completion(exists, files)
    }
    
    // MARK: バックアップファイル取得
    private var metadataQuery: NSMetadataQuery // 参照を保持するため、メンバとして持っておく。load()内のローカル変数にするとうまく動かない。
    
    /// バックアップファイル
    func getBackup(folderName: String) -> String {
        let (exists, files) = isBackupFileExists(folderName: folderName)
        if exists {
            if let file = files.first {
                return file
            }
        }
        return ""
    }
    
    func load(completion: @escaping ([(String, NSNumber?, Bool, URL)]) -> Void) {
        metadataQuery = NSMetadataQuery()
        // フォルダとファイルを取得して、ファイルのサイズを取得するため、絞り込まない
        // metadataQuery.predicate = NSPredicate(format: "%K like 'public.folder'", NSMetadataItemContentTypeKey)
        metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        metadataQuery.sortDescriptors = [
            NSSortDescriptor(key: NSMetadataItemFSContentChangeDateKey, ascending: false) // 効いていない
        ]
        
        NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: metadataQuery, queue: nil) { notification in
            if let query = notification.object as? NSMetadataQuery {
                
                var backupFiles: [(String, NSNumber?, Bool, URL)] = []
                // Documents内のフォルダとファイルにアクセス
                for result in query.results {
                    // print((result as AnyObject).values(forAttributes: [NSMetadataItemFSContentChangeDateKey, NSMetadataItemDisplayNameKey, NSMetadataItemFSNameKey, NSMetadataItemContentTypeKey, NSMetadataItemFSSizeKey, NSMetadataItemPathKey]))
                    // フォルダの場合
                    let contentType = (result as AnyObject).value(forAttribute: NSMetadataItemContentTypeKey) as! String
                    if contentType == "public.folder" {
                        // フォルダ名
                        let dysplayName = (result as AnyObject).value(forAttribute: NSMetadataItemDisplayNameKey) as! String
                        // フォルダ内のファイルのファイル名
                        let fileName = self.getBackup(folderName: dysplayName)
                        // fileName    String    ".default.realm_bk_2023-02-02-10-30-00.icloud"
                        // Documents内のフォルダとファイルにアクセス
                        for result in query.results {
                            // 同名のファイルからサイズを取得
                            let name = (result as AnyObject).value(forAttribute: NSMetadataItemFSNameKey) as! String
                            // name    String    "default.realm_bk_2023-02-02-10-30-00"
                            if fileName == name {
                                let size = (result as AnyObject).value(forAttribute: NSMetadataItemFSSizeKey) as? NSNumber
                                let isOniCloud = false
                                // サムネイル　URL
                                let url = (result as AnyObject).value(forAttribute: NSMetadataItemURLKey) as! URL
                                // フォルダ名、ファイルサイズ
                                backupFiles.append((dysplayName, size, isOniCloud, url))
                            }
                            // デバイス間の共有　iCloud経由の場合、ファイル名が変わる！！！復元する際に、ダウンロードをしないと復元できない。
                            if fileName == "." + name + ".icloud" {
                                print("." + name + ".icloud", "加工した　.icloud　です。")
                                let size = (result as AnyObject).value(forAttribute: NSMetadataItemFSSizeKey) as? NSNumber
                                let isOniCloud = true
                                // サムネイル　URL
                                let url = (result as AnyObject).value(forAttribute: NSMetadataItemURLKey) as! URL
                                // フォルダ名、ファイルサイズ、iCloudからダウンロードされていないか
                                backupFiles.append((dysplayName, size, isOniCloud, url))
                            }
                        }
                    }
                }
                // 並べ替え
                completion(backupFiles.sorted { $0.0 < $1.0 })
            }
        }
        
        metadataQuery.start()
    }
    
    /// Realmのデータを復元
    func restore(folderName: String, completion: @escaping (URL) -> Void) {
        // バックアップファイルの格納場所
        let folderUrl = documentsFolderUrl.appendingPathComponent(folderName)
        // iCloudからファイルをダウンロード
        downloadFileFromiCloud(folderName: folderName, completion: {
            // バックアップファイルの有無チェック
            let (exists, files) = self.isBackupFileExists(folderName: folderName)
            if exists {
                do {
//                    let config = Realm.Configuration()
//                    // 既存Realmファイル削除
//                    let realmURLs = [
//                        realmURL,
//                        realmURL.appendingPathExtension("lock"), // 排他アクセス等に使われていて、実行中以外は、削除等しても構いませんと説明されています。
//                        realmURL.appendingPathExtension("note"), // 排他アクセス等に使われていて、実行中以外は、削除等しても構いませんと説明されています。
//                        realmURL.appendingPathExtension("management")
//                    ]
//                    for URL in realmURLs {
//                        do {
//                            try FileManager.default.removeItem(at: URL)
//                            // URL"file:///var/mobile/Containers/Data/Application/C7E1E626-E114-4402-83EC-834AE43292F9/Documents/default.realm"
//                        } catch {
//                            print(error.localizedDescription)
//                        }
//                    }
//                    // バックアップファイルをRealmの位置にコピー
//                    print(files[files.count - 1])
//                    try FileManager.default.copyItem(
//                        at: folderUrl.appendingPathComponent(files[files.count - 1]),
//                        to: realmURL
//                    )
//                    Realm.Configuration.defaultConfiguration = config
//                    print(config) // schemaVersion を確認できる
                    Thread.sleep(forTimeInterval: 0.3)
                    print(folderUrl.appendingPathComponent(files[files.count - 1]))
                    // 編集するPDFファイルのパスを返す
                    completion(folderUrl.appendingPathComponent(files[files.count - 1]))
                    //　abort()   // 既存のRealmを開放させるため
                } catch {
                    print(error.localizedDescription)
                }
            }
        })
    }
    // iCloudからファイルをダウンロード
    func downloadFileFromiCloud(folderName: String, completion: @escaping () -> Void) {
        // If it’s a background function, I advise you to put this function in another DispatchQueue than the main one.
        DispatchQueue.global(qos: .utility).async {
            
            let fileManager = FileManager.default
            // Browse your icloud container to find the file you want
            if let icloudFolderURL = fileManager.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents").appendingPathComponent(folderName),
               var urls = try? fileManager.contentsOfDirectory(at: icloudFolderURL, includingPropertiesForKeys: nil, options: []) {
                // 先に写真をダウンロードする 降順
                urls.sort { $0.lastPathComponent > $1.lastPathComponent }
                // Here select the file url you are interested in (for the exemple we take the first)
                print(urls)
                for myURL in urls {
                    // We have our url
                    var lastPathComponent = myURL.lastPathComponent
                    print(lastPathComponent)
                    // 写真
                    if lastPathComponent == "Photos" {
                        if let urls = try? fileManager.contentsOfDirectory(at: myURL, includingPropertiesForKeys: nil, options: []) {
                            for myURL in urls {
                                // ダウンロードする前にiCloudとの同期を行う
                                // This simple code launch the download
                                do {
                                    try FileManager.default.startDownloadingUbiquitousItem(at: myURL)
                                } catch {
                                    print("Unexpected error: \(error).")
                                }
                                var lastPathComponent = myURL.lastPathComponent
                                print(lastPathComponent)
                                if lastPathComponent.contains(".icloud") {
                                    // Delete the "." which is at the beginning of the file name
                                    lastPathComponent.removeFirst()
                                    let folderPath = myURL.deletingLastPathComponent().path
                                    let downloadedFilePath = folderPath + "/" + lastPathComponent.replacingOccurrences(of: ".icloud", with: "")
                                    var isDownloaded = false
                                    while !isDownloaded {
                                        if fileManager.fileExists(atPath: downloadedFilePath) {
                                            isDownloaded = true
                                        }
                                    }
                                    // Do what you want with your downloaded file at path contains in variable "downloadedFilePath"
                                } else {
                                    // ダウンロード済みの場合
                                }
                            }
                        }
                    } else {
                        // ダウンロードする前にiCloudとの同期を行う
                        // This simple code launch the download
                        do {
                            try FileManager.default.startDownloadingUbiquitousItem(at: myURL)
                        } catch {
                            print("Unexpected error: \(error).")
                        }
                    }
                    // PDF
                    if lastPathComponent.contains(".icloud") {
                        // Delete the "." which is at the beginning of the file name
                        lastPathComponent.removeFirst()
                        let folderPath = myURL.deletingLastPathComponent().path
                        let downloadedFilePath = folderPath + "/" + lastPathComponent.replacingOccurrences(of: ".icloud", with: "")
                        var isDownloaded = false
                        while !isDownloaded {
                            if fileManager.fileExists(atPath: downloadedFilePath) {
                                isDownloaded = true
                            }
                        }
                        // Do what you want with your downloaded file at path contains in variable "downloadedFilePath"
                        completion()
                    } else {
                        // ダウンロード済みの場合
                        completion()
                    }
                }
            }
        }
    }
    
    // MARK: 写真
    
    // 写真を iCloud Container に保存する URLから
    func savePhotoToDocumentsDirectory(unusedNumber: Int, fileURL: URL? = nil, modifiedContentsURL: URL) -> URL? {
        // iCloud Drive / DrawingApp / Photos フォルダ作成 PDFファイルの格納場所 に写真フォルダを作成する
        guard let fileURL = fileURL else { return nil }
        let photosDirectory = fileURL.deletingLastPathComponent().appendingPathComponent("Photos", isDirectory: true)
        if FileManager.default.fileExists(atPath: photosDirectory.path) {
            print(photosDirectory.path)
        } else {
            do {
                try FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("失敗した")
            }
        }
        
        // 写真名
        let fileExtension = modifiedContentsURL.pathExtension
        let fileName = "\(unusedNumber)" + ".\(fileExtension)"
        let fileUrl = photosDirectory.appendingPathComponent(fileName)

        do {
            // コピーの前にはチェック&削除が必要
            if FileManager.default.fileExists(atPath: fileUrl.path) {
                // すでに fileUrl が存在する場合はファイルを削除する
                try FileManager.default.removeItem(at: fileUrl)
            }
            
            try FileManager.default.copyItem(at: modifiedContentsURL, to: fileUrl)
            // try FileManager.default.moveItem(at: modifiedContentsURL, to: backupFileUrl)
            
            print("modifiedContentsURL", modifiedContentsURL)
            print("fileUrl            ", fileUrl)
            return fileUrl
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
    
    // 写真を iCloud Container に保存する Dataから
    func savePhotoToDocumentsDirectory(unusedNumber: Int, fileURL: URL? = nil, modifiedContentsURL: URL, photoData: Data) -> URL? {
        // iCloud Drive / DrawingApp / Photos フォルダ作成 PDFファイルの格納場所 に写真フォルダを作成する
        guard let fileURL = fileURL else { return nil }
        let photosDirectory = fileURL.deletingLastPathComponent().appendingPathComponent("Photos", isDirectory: true)
        if FileManager.default.fileExists(atPath: photosDirectory.path) {
            print(photosDirectory.path)
        } else {
            do {
                try FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("失敗した")
            }
        }
        
        // 写真名
        let fileExtension = modifiedContentsURL.pathExtension
        // スクリーンショット png形式
        // Live Photos HEIC形式
        let fileName = "\(unusedNumber)" + ".\(fileExtension)"
        let fileUrl = photosDirectory.appendingPathComponent(fileName)

        do {
            // コピーの前にはチェック&削除が必要
            if FileManager.default.fileExists(atPath: fileUrl.path) {
                // すでに fileUrl が存在する場合はファイルを削除する
                try FileManager.default.removeItem(at: fileUrl)
            }
            
            // 画像の保存 PHPickerViewController の場合、URLから写真データへアクセスする権限がないため、URLからURLへ copyItem ができない。
            try photoData.write(to: fileUrl)
            
            print("modifiedContentsURL", modifiedContentsURL)
            print("fileUrl            ", fileUrl)
            return fileUrl
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }

    // 写真を iCloud Container から取得する
    func getPhotoFromDocumentsDirectory(contents: String, fileURL: URL) -> URL? {
        // iCloud Drive / DrawingApp / Photos フォルダ作成 PDFファイルの格納場所 に写真フォルダを作成する
        let photosDirectory = fileURL.deletingLastPathComponent().appendingPathComponent("Photos", isDirectory: true)
        if FileManager.default.fileExists(atPath: photosDirectory.path) {
            print(photosDirectory.path)
        } else {
            do {
                try FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("失敗した")
            }
        }
        
        // 写真名
        let fileName = "\(contents)"

        do {
            // ファイル一覧を取得
            let directoryContents = try FileManager.default.contentsOfDirectory(at: photosDirectory, includingPropertiesForKeys: nil)
            // if you want to filter the directory contents you can do like this:
            let photoFiles = directoryContents.filter { $0.deletingPathExtension().lastPathComponent == fileName }
            print("Photos urls: ", photoFiles)
            let photoFileNames = photoFiles.map { $0.deletingPathExtension().lastPathComponent }
            print("Photos list: ", photoFileNames)
            let fileUrl = photoFiles.first
            print("fileUrl            ", fileUrl?.path)
            return fileUrl
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }

    // 写真を iCloud Container から削除する
    func deletePhotoFromDocumentsDirectory(contents: String, fileURL: URL? = nil) -> Bool {
        // iCloud Drive / DrawingApp / Photos フォルダ作成 PDFファイルの格納場所 に写真フォルダを作成する
        guard let fileURL = fileURL else { return false }
        let photosDirectory = fileURL.deletingLastPathComponent().appendingPathComponent("Photos", isDirectory: true)
        if FileManager.default.fileExists(atPath: photosDirectory.path) {
            print(photosDirectory.path)
        } else {
            do {
                try FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("失敗した")
            }
        }
        
        // 写真名
        let fileName = "\(contents)"
        do {
            // ファイル一覧を取得
            let directoryContents = try FileManager.default.contentsOfDirectory(at: photosDirectory, includingPropertiesForKeys: nil)
            // if you want to filter the directory contents you can do like this:
            let photoFiles = directoryContents.filter { $0.deletingPathExtension().lastPathComponent == fileName }
            print("Photos urls: ", photoFiles)
            let photoFileNames = photoFiles.map { $0.deletingPathExtension().lastPathComponent }
            print("Photos list: ", photoFileNames)
            for photo in photoFiles {
                print("fileUrl            ", photo.path)
                // コピーの前にはチェック&削除が必要
                if FileManager.default.fileExists(atPath: photo.path) {
                    print("fileUrl            ", photo.path)
                    // すでに fileUrl が存在する場合はファイルを削除する
                    try FileManager.default.removeItem(at: photo)
                }
            }
            return true
        } catch {
            print(error.localizedDescription)
            return false
        }
    }

}
