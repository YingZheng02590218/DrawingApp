//
//  DrawingReportListViewController.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/11/15.
//

import UIKit
import UniformTypeIdentifiers
import PDFKit

// 図面調書一覧
class DrawingReportListViewController: UIViewController {

    @IBOutlet var collectionView: UICollectionView!
    
    // iCloud Container に保存しているPDFファイルのパス
    var fileURL: URL?
    // Documents 図面　ファイル
    var drawingReportFiles: [(URL?)] = [] {
        didSet {
            self.pageImages = []
            self.documents = []
            // Documents に保存しているPDFファイルのパス
            for drawingReportFile in drawingReportFiles {
                guard let drawingReportFile = drawingReportFile else { return }
                guard let document = PDFDocumentForList(url: drawingReportFile) else { return }
                self.documents.append(document)
            }
            // サムネイル画像をPDFから取得して、UIに表示させる
            createPageImages()
        }
    }

    /// Current document being displayed
    var documents: [PDFDocumentForList] = []
    
    /// Current page index being displayed
    var currentPageIndex: Int = 0 {
        didSet {
            guard let collectionView = collectionView else { return }
            guard let pageImages = pageImages else { return }
            guard pageImages.count > 0 else { return }
            let curentPageIndexPath = IndexPath(row: currentPageIndex, section: 0)
            if !collectionView.indexPathsForVisibleItems.contains(curentPageIndexPath) {
                collectionView.scrollToItem(at: curentPageIndexPath, at: .centeredHorizontally, animated: true)
            }
            collectionView.reloadData()
        }
    }
    
    /// Calls actions when certain cells have been interacted with
    weak var delegate: PDFThumbnailControllerDelegate?
    
    /// Small thumbnail image representations of the pdf pages
    private var pageImages: [[UIImage]]? = [] {
        didSet {
            DispatchQueue.main.async {
                self.collectionView.reloadData()
            }
        }
    }

    // サムネイル画像をPDFから取得して、UIに表示させる
    func createPageImages() {
        for document in documents {
            DispatchQueue.global(qos: .background).async {
                document.allPageImages(callback: { (images) in
                    DispatchQueue.main.async {
                        self.pageImages?.append(images)
                    }
                })
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // xib読み込み
        let nib = UINib(nibName: "PDFThumbnailCell", bundle: .main)
        collectionView.register(nib, forCellWithReuseIdentifier: "Cell")
        collectionView.delegate = self
        collectionView.dataSource = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // UIをリロード
        reload()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        // 画面の回転に合わせてCellのサイズを変更する
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.reloadData()
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

/// Delegate that is informed of important interaction events with the current thumbnail collection view
protocol PDFThumbnailControllerDelegate: class {
    /// User has tapped on thumbnail
    func didSelectIndexPath(_ indexPath: IndexPath)
}

/// Bottom collection of thumbnails that the user can interact with
extension DrawingReportListViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        print(pageImages?.count)
        return pageImages?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        print("section", section, "row", pageImages?[section].count)
        return pageImages?[section].count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! PDFThumbnailCell
        
        cell.imageView?.image = pageImages?[indexPath.section][indexPath.row]
        cell.alpha = currentPageIndex == indexPath.row ? 1 : 0.2
        
        return cell
    }
    
//    @objc func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: IndexPath) -> CGSize {
//        return PDFThumbnailCell.cellSize
//    }
}

extension DrawingReportListViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.didSelectIndexPath(indexPath)
    }
}

extension DrawingReportListViewController: UICollectionViewDelegateFlowLayout {
    //    //セル間の間隔を指定
    //    private func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimunLineSpacingForSectionAt section: Int) -> CGFloat {
    //        return 20
    //    }
    // セルのサイズ(CGSize)
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // print(collectionView.frame) // (10.0, 10.0, 1346.0, 934.0)
        if UIDevice.current.userInterfaceIdiom == .pad {
            if UIDevice.current.orientation == .landscapeLeft || UIDevice.current.orientation == .landscapeRight {
                return CGSize(width: (collectionView.frame.width / 4) - 0, height: (collectionView.frame.width / 4) - 0)
            } else {
                return CGSize(width: (collectionView.frame.width / 4) - 0, height: (collectionView.frame.width / 4) - 0)
            }
        } else {
            // TableViewCell の高さからCollectionViewCell の高さを割り出す
            if UIDevice.current.orientation == .landscapeLeft || UIDevice.current.orientation == .landscapeRight {
                return CGSize(width: (collectionView.frame.width / 3) - 20, height: (collectionView.frame.height / 2) - 20)
            } else {
                return CGSize(width: collectionView.frame.width - 40, height: (collectionView.frame.height / 2) - 20)
            }
        }
    }
    // 余白の調整（UIImageを拡大、縮小している）
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        // top:ナビゲーションバーの高さ分上に移動
        return UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    }
}
