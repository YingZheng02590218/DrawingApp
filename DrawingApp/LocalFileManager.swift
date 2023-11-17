//
//  LocalFileManager.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/11/15.
//

import Foundation

// FileManagerを使ってファイルやフォルダを保存する
// https://qiita.com/Hyperbolic_____/items/a4581ed08cec4c7df9ea

// Sandbox ファイル・ディレクトリ Documentsフォルダへファイルを読み書きする
class LocalFileManager {
    
    static let shared = LocalFileManager()
    
    private init() {
        // 作業用のディレクトリを構築する
        createFolders()
    }
   
    // File Managerでデータを書き込む、読み出す、削除する
    // https://qiita.com/john-rocky/items/32c6c17c937007350ce3
    
    //引数の説明
    //for: SearchPathDirectory // ディレクトリの種類。検索する一番下位。
    //    .documentDirectory // ホームディレクトリ　（/Document）
    //    .cachesDirectory // （Library/Caches）
    //    ... // まだいっぱいある。存在してかつアクセス可能なディレクトリを与えないとnilが返ってくる。
    //
    //in: SearchPathDomainMask // ディレクトリパスの一番上位の分岐（多分）。.userDomainMaskしか使ったことない。
    //    .userDomainMask // 現在の使用ユーザーのホームディレクトリ (~/)
    //    .localDomainMask // ユーザーアカウント関係なく利用できる
    //    .networkDomainMask // ネットワーク上で利用可能なアイテムをインストールする場所 (/network)
    //    .systemDomainMask // Appleが提供するシステムファイルのディレクトリ（/System）
    //    .allDomainMask // 全てのドメインを検索できる
    //appropriateFor: URL // 多分一時ディレクトリの場所を特定するために与えるファイルURL。よくわかっていないのでいつもnil
    //create: Bool 宛先URLが存在しない場合、新たに作るか
        
    // MARK: フォルダ
    
    // 作業用のディレクトリを構築する
    func createFolders() {
        do {
            // Documentsのフォルダ作成
            if FileManager.default.fileExists(atPath: documentsFolderUrl.path) {
                print(documentsFolderUrl.path)
                // /var/mobile/Containers/Data/Application/32D3348F-67EF-449B-A804-9BB3FFEA0D04/Documents
            } else {
                print(documentsFolderUrl.path)
                try FileManager.default.createDirectory(atPath: documentsFolderUrl.path, withIntermediateDirectories: true)
            }
            /// 作業中のフォルダ作成
            if FileManager.default.fileExists(atPath: WorkingDirectoryFolderUrl.path) {
                print(WorkingDirectoryFolderUrl.path)
                // /var/mobile/Containers/Data/Application/32D3348F-67EF-449B-A804-9BB3FFEA0D04/Documents/WorkingDirectory
            } else {
                print(WorkingDirectoryFolderUrl.path)
                try FileManager.default.createDirectory(atPath: WorkingDirectoryFolderUrl.path, withIntermediateDirectories: false)
            }
            /// Zumen のフォルダ作成
            if FileManager.default.fileExists(atPath: zumenFolderUrl.path) {
                print(zumenFolderUrl.path)
            } else {
                print(zumenFolderUrl.path)
                try FileManager.default.createDirectory(atPath: zumenFolderUrl.path, withIntermediateDirectories: false)
            }
            /// Report のフォルダ作成
            if FileManager.default.fileExists(atPath: reportFolderUrl.path) {
                print(reportFolderUrl.path)
            } else {
                print(reportFolderUrl.path)
                try FileManager.default.createDirectory(atPath: reportFolderUrl.path, withIntermediateDirectories: false)
            }
            /// Photos のフォルダ作成
            if FileManager.default.fileExists(atPath: photosFolderUrl.path) {
                print(photosFolderUrl.path)
            } else {
                print(photosFolderUrl.path)
                try FileManager.default.createDirectory(atPath: photosFolderUrl.path, withIntermediateDirectories: false)
            }
        } catch {
            print(error.localizedDescription)
        }
    }
    
    // ディレクトリのURL
    func getURL(for directory: AppDirectories) -> URL {
        switch directory
        {
        case .Documents:
            return documentsFolderUrl
        case .WorkingDirectory:
            return WorkingDirectoryFolderUrl
        case .Zumen:
            return zumenFolderUrl
        case .Report:
            return reportFolderUrl
        case .Photos:
            return photosFolderUrl
        }
    }
    
    // MARK: フォルダ　ファイル　URL
    
    /// Documents のURL
    private var documentsFolderUrl: URL {
        // iCloud Driveのパスは、ローカルと同じように、FileManagerでとれます。
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    /// 作業中のフォルダ のURL
    private var WorkingDirectoryFolderUrl: URL {
        let folderName = "WorkingDirectory" // 作業中のフォルダ
        return documentsFolderUrl.appendingPathComponent(folderName, isDirectory: true)
    }

    /// Zumen のフォルダ のURL
    private var zumenFolderUrl: URL {
        let folderName = "Zumen" // Zumen のフォルダ
        return WorkingDirectoryFolderUrl.appendingPathComponent(folderName, isDirectory: true)
    }
    
    /// Report のフォルダ のURL
    private var reportFolderUrl: URL {
        let folderName = "Report" // Report のフォルダ
        return WorkingDirectoryFolderUrl.appendingPathComponent(folderName, isDirectory: true)
    }
    
    /// Photos のフォルダ のURL
    private var photosFolderUrl: URL {
        let folderName = "Photos" // Photos のフォルダ
        return WorkingDirectoryFolderUrl.appendingPathComponent(folderName, isDirectory: true)
    }

    // MARK: ファイル　インポート

    /// ファイルを Documents - WorkingDirectory - 各フォルダ にコピー
    func inportFile(directory: AppDirectories, fileURL: URL? = nil, modifiedContentsURL: URL, completion: @escaping () -> Void, errorHandler: @escaping () -> Void) {
        if let fileURL = fileURL { // 編集
            // フォルダは作成しない
        } else { // 新規作成
            // 作業用のディレクトリを構築する
            createFolders()
        }
        // 既存バックアップファイル（iCloud）の削除
        //            deleteBackup()
        
        // バックアップファイル名
        let fileName = modifiedContentsURL.lastPathComponent
        // バックアップファイルの格納場所
        let fileUrl = fileURL ?? getURL(for: directory).appendingPathComponent(fileName)
        // PDFファイルを Documents - WorkingDirectory - 各フォルダ に保存する
        if let fileName = saveToDocumentsDirectory(backupFileUrl: fileUrl, modifiedContentsURL: modifiedContentsURL) {
            print(fileName)
            completion()
        } else {
            errorHandler()
        }
    }
    
    // PDFファイルを Documents - WorkingDirectory - 各フォルダ に保存する
    func saveToDocumentsDirectory(backupFileUrl: URL, modifiedContentsURL: URL) -> URL? {
        do {
            // ファイル一覧を取得
            let directoryContents = try FileManager.default.contentsOfDirectory(
                at: modifiedContentsURL.deletingLastPathComponent(),
                includingPropertiesForKeys: nil
            )
            // if you want to filter the directory contents you can do like this:
            let pdfFiles = directoryContents.filter { $0.pathExtension == "pdf" }
            print("pdf urls: ", pdfFiles)
            let pdfFileNames = pdfFiles.map { $0.deletingPathExtension().lastPathComponent }
            print("pdf list: ", pdfFileNames)
        } catch {
            print(error)
            // Desktop のPDFファイルを共有しようとすると、エラーが発生する → USBメモリなど外部記憶装置内のファイルにアクセスするにはセキュリティで保護されたリソースへのアクセス許可が必要 url.startAccessingSecurityScopedResource()
        }
        do {
            // コピーの前にはチェック&削除が必要
            if FileManager.default.fileExists(atPath: backupFileUrl.path) {
                // すでに backupFileUrl が存在する場合はファイルを削除する
                try FileManager.default.removeItem(at: backupFileUrl)
            }
            
            try FileManager.default.copyItem(at: modifiedContentsURL, to: backupFileUrl)
            
            print("modifiedContentsURL", modifiedContentsURL)
            // modifiedContentsURL file:///private/var/mobile/Library/Mobile%20Documents/com~apple~CloudDocs/Desktop/douroaisyo.pdf
            print("backupFileUrl      ", backupFileUrl)
            // backupFileUrl       file:///var/mobile/Containers/Data/Application/32D3348F-67EF-449B-A804-9BB3FFEA0D04/Documents/WorkingDirectory/zumen/douroaisyo.pdf
            return backupFileUrl
        } catch {
            print(error.localizedDescription)
            // ファイルアプリからPDFファイルを共有しようとすると、エラーとなる　→ Lucidchart　アプリがアクセスを許可していないことが原因と思われる。 → USBメモリなど外部記憶装置内のファイルにアクセスするにはセキュリティで保護されたリソースへのアクセス許可が必要 url.startAccessingSecurityScopedResource()
            return nil
        }
    }

    // MARK: ファイル　取得

    func readFiles(directory: AppDirectories, completion: @escaping ([(URL)]) -> Void) {
        // 読み出し
        var backupFiles: [(URL)] = []
        // ディレクトリ内にあるコンテンツの検索
        do {
            let urls = try FileManager.default.contentsOfDirectory(at: getURL(for: directory), includingPropertiesForKeys: nil)
            print(urls)
            for url in urls {
                // ファイルのURL
                backupFiles.append((url))
            }
        } catch let error {
            print(error)
        }
        completion(backupFiles)
    }
}

enum AppDirectories : String {
    case Documents = "Documents"
    case WorkingDirectory = "WorkingDirectory"
    case Zumen = "Zumen"
    case Report = "Report"
    case Photos = "Photos"
}
