//
//  PhotoLisViewController.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/11/17.
//

import UIKit
import UniformTypeIdentifiers

// 撮影写真一覧
class PhotoLisViewController: UIViewController {

    @IBOutlet var collectionView: UICollectionView!
    private var layout: UICollectionViewFlowLayout!

    // Documents に保存しているPDFファイルのパス
    var fileURL: URL?
    // Documents 図面　ファイル
    var drawingReportFiles: [(URL?)] = [] {
        didSet {
            collectionView.reloadData()
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
            navigationController.navigationItem.title = "撮影写真一覧"
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
            LocalFileManager.shared.readFiles(directory: .Photos) {
                print($0)
                self.drawingReportFiles = $0
            }
        }
    }
    
    // 撮影写真確認画面を表示させる
    func showEditingView(pageNumber: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            
//            if let viewController = UIStoryboard(
//                name: "DrawingReportEditViewController",
//                bundle: nil
//            ).instantiateInitialViewController() as? DrawingReportEditViewController {
//                viewController.pageNumber = pageNumber
//                
//                if let navigator = self.navigationController {
//                    navigator.pushViewController(viewController, animated: true)
//                } else {
//                    let navigation = UINavigationController(rootViewController: viewController)
//                    navigation.modalPresentationStyle = .fullScreen
//                    self.present(navigation, animated: true, completion: nil)
//                }
//            }
        }
    }
    
    // マーカーに紐付けされた画像
    func getThumbnailImage(url: URL, completion: @escaping (_ image: UIImage?) -> Void) {
        do {
            let data = try Data(contentsOf: url)
            let image = UIImage(data: data)
            completion(image)
        } catch let err {
            print("Error : \(err.localizedDescription)")
        }
        completion(nil)
    }
}

/// Bottom collection of thumbnails that the user can interact with
extension PhotoLisViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        print("row", drawingReportFiles.count)
        return drawingReportFiles.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! PDFThumbnailCell
        
        if let photoUrl = drawingReportFiles[indexPath.row] {
            cell.imageView?.image = nil
            // マーカーに紐付けされた画像
            getThumbnailImage(url: photoUrl) { image in
                if let image = image {
                    DispatchQueue.main.async {
                        cell.imageView?.image = image
                    }
                }
            }
        }
        
        return cell
    }
}

extension PhotoLisViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // 撮影写真確認画面を表示させる
        showEditingView(pageNumber: indexPath.row)
    }
}
