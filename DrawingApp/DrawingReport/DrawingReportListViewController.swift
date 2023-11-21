//
//  DrawingReportListViewController.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/11/15.
//

import UIKit
import PDFKit

// 図面調書一覧
class DrawingReportListViewController: UIViewController {

    @IBOutlet var collectionView: UICollectionView!
    private var layout: UICollectionViewFlowLayout!

    // Documents に保存しているPDFファイルのパス
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
        
    /// Small thumbnail image representations of the pdf pages
    private var pageImages: [[UIImage]]? = [] {
        didSet {
            collectionView.reloadData()
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
        // UICollectionViewFlowLayoutをインスタンス化
        layout = UICollectionViewFlowLayout()
        // UICollectionViewを初期化
        collectionView.collectionViewLayout = layout
        
        // UIをリロード
        reload()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let navigationController = self.navigationController {
            self.title = "図面調書一覧"
            navigationController.navigationBar.backgroundColor = .brown // .systemBackground
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        // レイアウト関連は、ここでやる
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        let itemCount: CGFloat = 4
        let itemWidth: CGFloat = collectionView.bounds.width / itemCount
        print(collectionView.frame.width)
        print(collectionView.bounds.width)
        print(itemWidth)
        layout.itemSize = CGSize(width: itemWidth, height: itemWidth)

        // 画面の回転に合わせてCellのサイズを変更する
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.reloadData()
    }
    
    // UIをリロード
    func reload() {
        DispatchQueue.main.async {
            LocalFileManager.shared.readFiles(directory: .Zumen) {
                print($0)
                self.drawingReportFiles = $0
            }
        }
    }

    // PDF編集画面を表示させる
    func showEditingView(document: PDFDocumentForList, pageNumber: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            
            if let viewController = UIStoryboard(
                name: "DrawingReportEditViewController",
                bundle: nil
            ).instantiateInitialViewController() as? DrawingReportEditViewController {
                // Documents に保存しているPDFファイルのパス
                viewController.document = document
                viewController.pageNumber = pageNumber
                
                if let navigator = self.navigationController {
                    navigator.pushViewController(viewController, animated: true)
                } else {
                    let navigation = UINavigationController(rootViewController: viewController)
                    navigation.modalPresentationStyle = .fullScreen
                    self.present(navigation, animated: true, completion: nil)
                }
            }
        }
    }
    // マーカー画面を表示させる
    func showMarkerView(document: PDFDocumentForList) {
        if BackupManager.shared.isiCloudEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // PDFKit のパターン
                if let viewController = UIStoryboard(
                    name: "DrawingViewController",
                    bundle: nil
                ).instantiateInitialViewController() as? DrawingViewController {
                    // iCloud Container に保存しているPDFファイルのパス
                    viewController.fileURL = document.fileURL

                    if let navigator = self.navigationController {
                        navigator.pushViewController(viewController, animated: true)
                    } else {
                        let navigation = UINavigationController(rootViewController: viewController)
                        navigation.modalPresentationStyle = .fullScreen
                        self.present(navigation, animated: true, completion: nil)
                    }
                }

            }
        }
    }

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
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as? PDFThumbnailCell else {
            return UICollectionViewCell()
        }
        
        if let image = pageImages?[indexPath.section][indexPath.row] {
            // cell.alpha = currentPageIndex == indexPath.row ? 1 : 0.2
            cell.imageView?.image = nil
            cell.imageView?.image = image
            // NOTE: 処理が重たい　画像がチカチカする
//            let thumbnailSize = CGSize(width: (collectionView.frame.width / 4) - 10, height: (collectionView.frame.width / 4) - 10) // imageViewの余白をマイナスする
//            image.prepareThumbnail(of: thumbnailSize) { thumbnail in
//                DispatchQueue.main.async {
//                    cell.imageView?.image = thumbnail
//                }
//            }
        }
        // ページ番号
        cell.pageNumberLabel.text = "\(indexPath.row)"

        return cell
    }
}

extension DrawingReportListViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as? PDFThumbnailCell else {
            return
        }
        // セルの枠線の太さを変える
        cell.isSelected = false
//        // TODO: 動作確認
//        if indexPath.section == 0 {
        // PDF編集画面を表示させる
        showEditingView(document: documents[indexPath.section], pageNumber: indexPath.row)
//        } else {
//            // マーカー画面を表示させる
//            showMarkerView(document: documents[indexPath.section])
//        }
    }
}
