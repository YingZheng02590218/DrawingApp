//
//  InportViewController.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/11/17.
//

import UIKit
import UniformTypeIdentifiers

// 図面調書登録　写真調書登録　撮影写真登録
class InportViewController: UIViewController {

    // 保存先のディレクトリ
    var directory: AppDirectories = .Documents

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    // UIをリロード 継承したクラスでオーバーライドする
    func reload() {}
    
    // MARK: ファイルを取り込む　図面PDF、撮影写真

    // ファイル選択画面を表示させる
    func showDocumentPicker() {
        // PDFのみ選択できるドキュメントピッカーを作成
        if #available(iOS 14.0, *) {
            // PDFファイルのみを、もしくは写真のみを対象とする
            let contentTypes: [UTType] = directory == .Zumen || directory == .Report ? [.pdf] : [.jpeg]
            let documentPicker = UIDocumentPickerViewController(
                forOpeningContentTypes: contentTypes
            )
            documentPicker.delegate = self
            DispatchQueue.main.async {
                self.present(documentPicker, animated: false, completion: nil)
            }
        } else {
            // PDFファイルのみを、もしくは写真のみを対象とする
            let contentTypes: [String] = directory == .Zumen || directory == .Report ? [UTType.pdf.description] : [UTType.jpeg.description]
            let documentPicker = UIDocumentPickerViewController(documentTypes: contentTypes, in: .open)
            
            documentPicker.delegate = self
            DispatchQueue.main.async {
                self.present(documentPicker, animated: false, completion: nil)
            }
        }
    }
}

/// UIDocumentPickerDelegate
extension InportViewController: UIDocumentPickerDelegate {
    /// ファイル選択後に呼ばれる
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        // URLを取得
        guard let url = urls.first else { return }
        print(url)
        // file:///private/var/mobile/Library/Mobile%20Documents/com~apple~CloudDocs/Desktop/douroaisyo.pdf
        // iCloud Container のプロジェクトフォルダ内のPDFファイルは受け取れないように弾く
        guard !url.path.contains("iCloud~com~ikingdom778~DrawingApp/Documents") else {
            return
        }
        
        // 選択したURLがディレクトリかどうか
        if url.hasDirectoryPath {
            // ここで読み込む処理
        }
        // USBメモリなど外部記憶装置内のファイルにアクセスするにはセキュリティで保護されたリソースへのアクセス許可が必要
        guard url.startAccessingSecurityScopedResource() else {
            // ここで選択したURLでファイルを処理する
            return
        }

        /// ファイルを Documents - WorkingDirectory - 各フォルダ にコピー
        LocalFileManager.shared.inportFile(
            directory: directory,
            fileURL: nil, // プロジェクトフォルダを新規作成する
            modifiedContentsURL: url,
            completion: {
                // リロード
                self.reload()
            },
            errorHandler: {
                //
            }
        )
        // ファイルの処理が終わったら、セキュリティで保護されたリソースを解放
        defer { url.stopAccessingSecurityScopedResource() }
    }
}
