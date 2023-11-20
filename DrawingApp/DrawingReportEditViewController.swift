//
//  DrawingReportEditViewController.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/11/16.
//

import UIKit
import PDFKit

// 図面調書編集
class DrawingReportEditViewController: UIViewController {

    @IBOutlet weak var pdfView: NonSelectablePDFView!

    /// Height of the thumbnail bar (used to hide/show)
    @IBOutlet private var thumbnailCollectionControllerWidth: NSLayoutConstraint!
    
    /// Distance between the bottom thumbnail bar with bottom of page (used to hide/show)
    @IBOutlet private var thumbnailCollectionControllerLeading: NSLayoutConstraint!
    
    /// Width of the thumbnail bar (used to resize on rotation events)
    @IBOutlet private var thumbnailCollectionControllerHeight: NSLayoutConstraint!

    /// PDF document that should be displayed
    var document: PDFDocumentForList!
    
    /// Current page being displayed
    private var currentPageIndex: Int = 0
    /// Bottom thumbnail controller
    private var thumbnailCollectionController: PDFThumbnailCollectionViewController?
    // ページ番号
    var pageNumber: Int?

    /// Whether or not the thumbnails bar should be enabled
    private var isThumbnailsEnabled = true {
        didSet {
            if thumbnailCollectionControllerWidth == nil {
                _ = view
            }
            if !isThumbnailsEnabled {
                thumbnailCollectionControllerWidth.constant = 0
            }
        }
    }

    // セグメントコントロール
    let segmentedControl = UISegmentedControl(items: ["ビューモード", "移動", "グループ選択", "写真マーカー", "手書き", "直線", "矢印", "四角", "円", "テキスト", "消しゴム"])
    // モード
    var drawingMode: DrawingMode = .viewingMode

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // セグメントコントロール
        setupSegmentedControl()
        
       // NOTE: 下記は不要　CollectionView自体の高さを指定している
//        let numberOfPages = CGFloat(document.pageCount)
//        let cellSpacing = CGFloat(2.0)
//        let totalSpacing = (numberOfPages - 1.0) * cellSpacing
//        let thumbnailHeight = (numberOfPages * PDFThumbnailCell.cellSize.height) + totalSpacing
//        let height = min(thumbnailHeight, view.bounds.height)
//        thumbnailCollectionControllerHeight.constant = height
        
        // Documents に保存しているPDFファイルのパス
        guard let fileURL = document.fileURL else { return }
        guard let document = PDFDocument(url: fileURL) else { return }
        pdfView.document = document
        // 単一ページのみ
        pdfView.displayMode = .singlePage
        pdfView.autoScales = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let navigationController = self.navigationController {
            self.title = "図面調書編集"
            navigationController.navigationBar.backgroundColor = .systemBackground
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        DispatchQueue.main.async {
            // 図面調書編集 図面調書一覧画面で選択したページへジャンプする
            if let pageNumber = self.pageNumber, // ページ番号
               let page = self.pdfView.document?.page(at: pageNumber) {
                self.pdfView.go(to: page)
                // 図面調書編集
                self.currentPageIndex = pageNumber

                self.pageNumber = nil
            }
        }
    }
    
    // セグメントコントロール
    func setupSegmentedControl() {
        segmentedControl.sizeToFit()
        if #available(iOS 13.0, *) {
            segmentedControl.selectedSegmentTintColor = UIColor.red
        } else {
            segmentedControl.tintColor = UIColor.red
        }
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentedControlChanged), for: .valueChanged)
        //        segment.setTitleTextAttributes([NSAttributedString.Key.font : UIFont(name: "ProximaNova-Light", size: 15)!], for: .normal)
        let segmentBarButtonItem = UIBarButtonItem(customView: segmentedControl)
        if let _ = navigationItem.leftBarButtonItems {
            navigationItem.rightBarButtonItems?.append(segmentBarButtonItem)
        } else {
            navigationItem.rightBarButtonItem = segmentBarButtonItem
        }
    }
    
    
    // MARK: - 編集モード

    // セグメントコントロール
    @objc
    func segmentedControlChanged() {
        drawingMode = DrawingMode(index: segmentedControl.selectedSegmentIndex)
        
        // スワイプジェスチャーを禁止
        if drawingMode == .viewingMode {
            NotificationCenter.default.post(name: SegmentedControlPageViewController.needToChangeSwipeEnabledNotification, object: true)
        } else {
            NotificationCenter.default.post(name: SegmentedControlPageViewController.needToChangeSwipeEnabledNotification, object: false)
        }
    }
    
    override public func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let controller = segue.destination as? PDFThumbnailCollectionViewController {
            thumbnailCollectionController = controller
            controller.document = document
            controller.delegate = self
            // 図面調書一覧画面で選択したページへジャンプする
            if let pageNumber = self.pageNumber { // ページ番号
                // サムネイル一覧もスクロールさせる
                controller.pageNumber = pageNumber
            }
        }
    }
}

extension DrawingReportEditViewController: PDFThumbnailControllerDelegate {
    func didSelectIndexPath(_ indexPath: IndexPath) {
        DispatchQueue.main.async {
            // サムネイル一覧で選択したページへジャンプする
            if let page = self.pdfView.document?.page(at: indexPath.row) {
                self.pdfView.go(to: page)
            }
        }
        // 図面調書編集
        currentPageIndex = indexPath.row
        // サムネイル一覧
        thumbnailCollectionController?.currentPageIndex = indexPath.row
    }
}

enum DrawingMode {
    // TODO: ビューモード
    case viewingMode
    case move
    case select
    case photoMarker
    case drawing
    case line
    case arrow
    case rectangle
    case circle
    case text
    case eraser
    // 引数ありコンストラクタ
    init(index: Int) {
        switch index {
        case 0:
            self = .viewingMode
        case 1:
            self = .move
        case 2:
            self = .select
        case 3:
            self = .photoMarker
        case 4:
            self = .drawing
        case 5:
            self = .line
        case 6:
            self = .arrow
        case 7:
            self = .rectangle
        case 8:
            self = .circle
        case 9:
            self = .text
        case 10:
            self = .eraser
        default:
            self = .move
        }
    }
}
