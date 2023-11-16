//
//  DrawingReportListViewController.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/11/15.
//

import UIKit
import UniformTypeIdentifiers

// 図面調書一覧
class DrawingReportListViewController: UIViewController {

    // コンテナ　ファイル
    var drawingReportFiles: [(URL?)] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // UIをリロード
        reload()
    }
    // UIをリロード
    func reload() {
        DispatchQueue.main.async {
            LocalFileManager.shared.readFiles {
                print($0)
                self.drawingReportFiles = $0
            }
        }
    }

    // MARK: 図面PDFファイルを取り込む　iCloud Container にプロジェクトフォルダを作成

    // ファイル選択画面を表示させる
    func showDocumentPicker() {
        // PDFのみ選択できるドキュメントピッカーを作成
        if #available(iOS 14.0, *) {
            let documentPicker = UIDocumentPickerViewController(
                forOpeningContentTypes: [.pdf] // PDFファイルのみを対象とする
            )
            documentPicker.delegate = self
            DispatchQueue.main.async {
                self.present(documentPicker, animated: false, completion: nil)
            }
        } else {
            let documentPicker = UIDocumentPickerViewController(documentTypes: [UTType.pdf.description], in: .open)
            
            documentPicker.delegate = self
            DispatchQueue.main.async {
                self.present(documentPicker, animated: false, completion: nil)
            }
        }
    }

}

// MARK: 図面PDFファイルを取り込む　iCloud Container にプロジェクトフォルダを作成

/// UIDocumentPickerDelegate
extension DrawingReportListViewController: UIDocumentPickerDelegate {
    /// ファイル選択後に呼ばれる
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        // URLを取得
        guard let url = urls.first else { return }
        print(url)
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
        
        /// PDFファイルを Documents - WorkingDirectory - zumen にコピー
        LocalFileManager.shared.inportFile(
            fileURL: nil, // プロジェクトフォルダを新規作成する
            modifiedContentsURL: url,
            completion: {
                // tableViewをリロード
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
