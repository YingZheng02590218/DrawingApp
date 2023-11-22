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

    // MARK: - ライフサイクル

    override func viewDidLoad() {
        super.viewDidLoad()
        // Undo Redo ボタン
        setupUndoRedoButtons()
        // セグメントコントロール
        setupSegmentedControl()
        // 編集するPDFページを表示させる
        setupPdfView()
        // PDF Annotationがタップされたかを監視
        setupAnnotationRecognizer()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        // ボタン　活性状態
        undoButton.isEnabled = undoRedoManager.canUndo()
        redoButton.isEnabled = undoRedoManager.canRedo()
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
    
    // MARK: - 編集するPDFページ

    @IBOutlet weak var pdfView: NonSelectablePDFView!

    var fileURL: URL?
    // ページ番号
    var pageNumber: Int?
    
    // 編集するPDFページを表示させる
    func setupPdfView() {
        // Documents に保存しているPDFファイルのパス
        guard let fileURL = document.fileURL else { return }
        guard let document = PDFDocument(url: fileURL) else { return }
        pdfView.document = document
        // 単一ページのみ
        pdfView.displayMode = .singlePage
        pdfView.autoScales = true
    }
    
    // MARK: - ページサムネイル一覧

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

    // MARK: - 編集モード
    
    // セグメントコントロール
    let segmentedControl = UISegmentedControl(items: ["ビューモード", "移動", "グループ選択", "写真マーカー", "手書き", "直線", "矢印", "四角", "円", "テキスト", "消しゴム"])
    // モード
    var drawingMode: DrawingMode = .viewingMode

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
        let segmentBarButtonItem = UIBarButtonItem(customView: segmentedControl)
        if let _ = navigationItem.rightBarButtonItems {
            navigationItem.rightBarButtonItems?.append(segmentBarButtonItem)
        } else {
            navigationItem.rightBarButtonItem = segmentBarButtonItem
        }
    }
    
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
        
        // 拡大縮小を禁止してマーカーの起点と終点を選択しやすくする
        if drawingMode == .move || drawingMode == .drawing || drawingMode == .line || drawingMode == .arrow || drawingMode == .rectangle || drawingMode == .circle {
            pdfView.maxScaleFactor = pdfView.scaleFactorForSizeToFit
            pdfView.minScaleFactor = pdfView.scaleFactorForSizeToFit
        } else {
            pdfView.maxScaleFactor = 5.0
            pdfView.minScaleFactor = 0.25
        }
    }
    
    // MARK: - アノテーション
    
    // PDF Annotationがタップされたかを監視
    func setupAnnotationRecognizer() {
        // ②PDF Annotationがタップされたかを監視、タップに対する処理を行う
        //　PDFAnnotationがタップされたかを監視する
        NotificationCenter.default.addObserver(self, selector: #selector(action(_:)), name: .PDFViewAnnotationHit, object: nil)
        
        // マーカーを追加する位置を取得する
        let singleTapGesture = UITapGestureRecognizer(target: self, action: #selector(tappedView(_:)))
        singleTapGesture.numberOfTapsRequired = 1
        singleTapGesture.delegate = self
        self.pdfView.addGestureRecognizer(singleTapGesture)
        // 移動
        let panAnnotationGesture = UIPanGestureRecognizer(target: self, action: #selector(didPanAnnotation(sender:)))
        panAnnotationGesture.delegate = self
        pdfView.addGestureRecognizer(panAnnotationGesture)
    }
    
    // Annotationを削除する
    func removeAnotation(annotation: PDFAnnotation) {
        // 現在開いているページを取得
        if let page = pdfView.currentPage {
            // 写真マーカー
            if annotation.isKind(of: PhotoAnnotation.self) && PDFAnnotationSubtype(rawValue: "/\(annotation.type!)") == PDFAnnotationSubtype.freeText.self && ((annotation.contents?.isEmpty) != nil) {
            } else {
                // 写真マーカー　以外
                // 対象のページの注釈を削除
                page.removeAnnotation(annotation)
                
                // Undo Redo 削除
                undoRedoManager.deleteAnnotation(annotation)
                undoRedoManager.showTeamMembers(completion: { didUndoAnnotations in
                    // Undo Redo が可能なAnnotation　を削除して、更新後のAnnotationを表示させる
                    self.reloadPDFAnnotations(didUndoAnnotations: didUndoAnnotations)
                })
                // ボタン　活性状態
                undoButton.isEnabled = undoRedoManager.canUndo()
                redoButton.isEnabled = undoRedoManager.canRedo()
            }
        }
    }
    
    // MARK: PDFAnnotationがタップされた
    @objc
    func action(_ sender: Any) {
        // タップされたPDFAnnotationを取得する
        guard let notification = sender as? Notification,
              let annotation = notification.userInfo?["PDFAnnotationHit"] as? PDFAnnotation else {
            return
        }
        // タップされたPDFAnnotationに対する処理
        if drawingMode == .arrow { // 矢印
            // 現在開いているページを取得
            if let page = self.pdfView.currentPage,
               let linePoints = annotation.annotationKeyValues.filter( {$0.key == PDFAnnotationKey.linePoints as AnyHashable} ).first,
               let lineEndingStyles = annotation.annotationKeyValues.filter( {$0.key == PDFAnnotationKey.lineEndingStyles as AnyHashable} ).first,
               let color = annotation.annotationKeyValues.filter( {$0.key == PDFAnnotationKey.color as AnyHashable} ).first {
                // Create dictionary of annotation properties
                let lineAttributes: [PDFAnnotationKey: Any] = [
                    .linePoints: [(linePoints.value as AnyObject).object(at: 0),
                                  (linePoints.value as AnyObject).object(at: 1),
                                  (linePoints.value as AnyObject).object(at: 2),
                                  (linePoints.value as AnyObject).object(at: 3)],
                    .lineEndingStyles: [(lineEndingStyles.value as AnyObject).object(at: 1),
                                        (lineEndingStyles.value as AnyObject).object(at: 0)],
                    .color: color.value,
                    .border: annotation.border
                ]
                let lineAnnotation = PDFAnnotation(
                    bounds: annotation.bounds,
                    forType: .line,
                    withProperties: lineAttributes
                )
                // UUID
                lineAnnotation.userName = UUID().uuidString
                
                // Annotationを再度作成
                page.addAnnotation(lineAnnotation)
                // 古いものを削除する
                page.removeAnnotation(annotation)
                
                // Undo Redo 更新
                undoRedoManager.updateAnnotation(before: annotation, after: lineAnnotation)
                undoRedoManager.showTeamMembers(completion: { didUndoAnnotations in
                    // Undo Redo が可能なAnnotation　を削除して、更新後のAnnotationを表示させる
                    self.reloadPDFAnnotations(didUndoAnnotations: didUndoAnnotations)
                })
                // ボタン　活性状態
                undoButton.isEnabled = undoRedoManager.canUndo()
                redoButton.isEnabled = undoRedoManager.canRedo()
            }
        } else if drawingMode == .select {
            // 選択したAnnotationの制御点を修正する
        } else if drawingMode == .eraser {
            // Annotationを削除する
            removeAnotation(annotation: annotation)
        } else {
        }
    }

    // MARK: - 移動
    // 選択しているAnnotation
    var currentlySelectedAnnotation: PDFAnnotation?
    
    // マーカーを更新する 移動
    func updateMarkerAnotation() {
        // 現在開いているページを取得
        if let page = pdfView.currentPage {
            // 選択しているAnnotation 移動中のAnnotation
            guard let currentlySelectedAnnotation = currentlySelectedAnnotation else { return }
            // 変更後
            let after = currentlySelectedAnnotation
            after.bounds = currentlySelectedAnnotation.bounds
            after.page = currentlySelectedAnnotation.page
            
            if let before = before {
                after.bounds = CGRect(
                    x: after.bounds.origin.x,
                    y: after.bounds.origin.y,
                    width: after.bounds.size.width,
                    height: after.bounds.size.height
                )
                after.contents = before.contents
                after.color = UIColor.orange.withAlphaComponent(0.5)
                after.page = before.page
                
                // UUID
                after.userName = UUID().uuidString
                // Annotationを再度作成
                page.addAnnotation(after)
                // 古いものを削除する
                page.removeAnnotation(before)
                // 初期化
                self.before = nil
                // Undo Redo 更新
                undoRedoManager.updateAnnotation(before: before, after: after)
                undoRedoManager.showTeamMembers(completion: { didUndoAnnotations in
                    // Undo Redo が可能なAnnotation　を削除して、更新後のAnnotationを表示させる
                    self.reloadPDFAnnotations(didUndoAnnotations: didUndoAnnotations)
                })
                // ボタン　活性状態
                undoButton.isEnabled = undoRedoManager.canUndo()
                redoButton.isEnabled = undoRedoManager.canRedo()
            }
        }
    }
    
    // MARK: - 写真マーカー
    
    // PDF 全てのpageに存在する写真マーカーAnnotationを保持する
    var annotationsInAllPages: [PDFAnnotation] = []
    // 写真マーカー　連番
    var numbersList = Array(1...32767) // Int16    32767
    // TODO: SF Symbols は50までしか存在しない
    //    var numbersList = [0,1,2,3,4,5,6,7,8,9,
    //                       10,11,12,13,14,15,16,17,18,19,
    //                       20,21,22,23,24,25,26,27,28,29,
    //                       30,31,32,33,34,35,36,37,38,39,
    //                       40,41,42,43,44,45,46,47,48,49,
    //                       50]
    // 使用していない連番
    var unusedNumber: Int?
    // PDFのタップされた位置の座標
    var point: CGPoint?
    
    // PDF 全てのpageに存在する写真マーカーAnnotationを保持する
    func getAllAnnotations(completion: @escaping () -> Void) {
        guard let document = pdfView.document else { return }
        // 初期化
        annotationsInAllPages = []
        for i in 0..<document.pageCount {
            if let page = document.page(at: i) {
                // freeText
                let annotations = page.annotations.filter({ "/\($0.type!)" == PDFAnnotationSubtype.freeText.rawValue })
                for annotation in annotations {
                    
                    annotationsInAllPages.append(annotation)
                }
            }
        }
        completion()
    }
    
    // 使用していない連番を取得する
    func getUnusedNumber() -> Int? {
        for number in numbersList {
            if let annotation = self.annotationsInAllPages.first(where: { $0.contents == "\(number)" }) {
                print("annotation.contents", annotation.contents)
            } else {
                return number
            }
        }
        return nil
    }
    
    // マーカーを追加する 写真
    func addMarkerAnotation() {
        // 現在開いているページを取得
        if let page = self.pdfView.currentPage,
           let point = point,
           let unusedNumber = unusedNumber {
            // freeText
            let font = UIFont.systemFont(ofSize: 15)
            let size = "\(unusedNumber)".size(with: font)
            // Create dictionary of annotation properties
            let lineAttributes: [PDFAnnotationKey: Any] = [
                .color: UIColor.green.withAlphaComponent(0.5),
                .contents: "\(unusedNumber)",
            ]
            
            let freeText = PhotoAnnotation(bounds: CGRect(x: point.x, y: point.y, width: size.width + 5, height: size.height + 5), forType: .freeText, withProperties: lineAttributes)
            // UUID
            freeText.userName = UUID().uuidString
            // 対象のページへ注釈を追加
            page.addAnnotation(freeText)
            // Undo Redo
            undoRedoManager.addAnnotation(freeText)
            undoRedoManager.showTeamMembers(completion: { didUndoAnnotations in
                // Undo Redo が可能なAnnotation　を削除して、更新後のAnnotationを表示させる
                self.reloadPDFAnnotations(didUndoAnnotations: didUndoAnnotations)
            })
            // ボタン　活性状態
            undoButton.isEnabled = undoRedoManager.canUndo()
            redoButton.isEnabled = undoRedoManager.canRedo()
        }
    }
    
    // 写真マーカーを削除する
    func removeMarkerAnotation(annotation: PDFAnnotation) {
        // 現在開いているページを取得
        if let page = pdfView.currentPage {
            // 写真マーカー
            if annotation.isKind(of: PhotoAnnotation.self) && PDFAnnotationSubtype(rawValue: "/\(annotation.type!)") == PDFAnnotationSubtype.freeText.self && ((annotation.contents?.isEmpty) != nil)  {
                // 対象のページの注釈を削除
                page.removeAnnotation(annotation)
                
                // Undo Redo 削除
                undoRedoManager.deleteAnnotation(annotation)
                undoRedoManager.showTeamMembers(completion: { didUndoAnnotations in
                    // Undo Redo が可能なAnnotation　を削除して、更新後のAnnotationを表示させる
                    self.reloadPDFAnnotations(didUndoAnnotations: didUndoAnnotations)
                })
                // ボタン　活性状態
                undoButton.isEnabled = undoRedoManager.canUndo()
                redoButton.isEnabled = undoRedoManager.canRedo()
            }
        }
    }
    
    // 破線のパターン
    enum DashPattern {
        case pattern1
        case pattern2
        case pattern3
        case pattern4
        case pattern5
        
        var style: [CGFloat] {
            switch self {
            case .pattern1:
                return [1.0]
            case .pattern2:
                return [30.0, 10.0]
            case .pattern3:
                return [40.0, 20.0]
            case .pattern4:
                return [50.0, 5.0, 5.0, 5.0]
            case .pattern5:
                return [50.0, 5.0, 5.0, 5.0, 5.0, 5.0]
            }
        }
    }
    
    // MARK: - 図形
    
    // 起点
    var beganLocation: CGPoint?
    // 途中点
    var changedLocation: CGPoint?
    // 終点
    var endLocation: CGPoint?
    // 破線のパターン
    var dashPattern: DashPattern = .pattern1
    // 変更前
    var before: PDFAnnotation?
    
    // マーカーを追加する 直線
    func addLineMarkerAnotation() {
        // 現在開いているページを取得
        if let page = self.pdfView.currentPage,
           let beganLocation = beganLocation,
           let changedLocation = changedLocation,
           let endLocation = endLocation {
            
            let boundsX = beganLocation.x > endLocation.x ? endLocation.x : beganLocation.x
            let boundsY = beganLocation.y > endLocation.y ? endLocation.y : beganLocation.y
            
            let width = beganLocation.x > endLocation.x ? beganLocation.x - endLocation.x : endLocation.x - beganLocation.x
            let height = beganLocation.y > endLocation.y ? beganLocation.y - endLocation.y : endLocation.y - beganLocation.y
            
            let border = PDFBorder()
            border.lineWidth = 10
            border.style = dashPattern == .pattern1 ? .solid : .dashed
            border.dashPattern = dashPattern == .pattern1 ? nil : dashPattern.style
            
            // Create dictionary of annotation properties
            let lineAttributes: [PDFAnnotationKey: Any] = [
                .linePoints: [beganLocation.x, beganLocation.y, endLocation.x, endLocation.y],
                .lineEndingStyles: [PDFAnnotationLineEndingStyle.none,
                                    PDFAnnotationLineEndingStyle.none],
                .color: UIColor.red,
                .border: border
            ]
            let lineAnnotation = PDFAnnotation(
                bounds: CGRect(x: boundsX, y: boundsY, width: width, height: height),
                forType: .line,
                withProperties: lineAttributes
            )
            // UUID
            lineAnnotation.userName = UUID().uuidString
            page.addAnnotation(lineAnnotation)
            
            // Undo Redo
            undoRedoManager.addAnnotation(lineAnnotation)
            undoRedoManager.showTeamMembers(completion: { didUndoAnnotations in
                // Undo Redo が可能なAnnotation　を削除して、更新後のAnnotationを表示させる
                self.reloadPDFAnnotations(didUndoAnnotations: didUndoAnnotations)
            })
            // ボタン　活性状態
            undoButton.isEnabled = undoRedoManager.canUndo()
            redoButton.isEnabled = undoRedoManager.canRedo()
        }
    }
    
    // マーカーを追加する 矢印
    func addArrowMarkerAnotation() {
        // 現在開いているページを取得
        if let page = self.pdfView.currentPage,
           let beganLocation = beganLocation,
           let changedLocation = changedLocation,
           let endLocation = endLocation {
            
            let boundsX = beganLocation.x > endLocation.x ? endLocation.x : beganLocation.x
            let boundsY = beganLocation.y > endLocation.y ? endLocation.y : beganLocation.y
            
            let width = beganLocation.x > endLocation.x ? beganLocation.x - endLocation.x : endLocation.x - beganLocation.x
            let height = beganLocation.y > endLocation.y ? beganLocation.y - endLocation.y : endLocation.y - beganLocation.y
            
            let border = PDFBorder()
            border.lineWidth = 10
            border.style = dashPattern == .pattern1 ? .solid : .dashed
            border.dashPattern = dashPattern == .pattern1 ? nil : dashPattern.style
            
            // Create dictionary of annotation properties
            let lineAttributes: [PDFAnnotationKey: Any] = [
                .linePoints: [beganLocation.x, beganLocation.y, endLocation.x, endLocation.y],
                .lineEndingStyles: [PDFAnnotationLineEndingStyle.none,
                                    PDFAnnotationLineEndingStyle.closedArrow],
                .color: UIColor.red,
                .border: border
            ]
            let lineAnnotation = PDFAnnotation(
                bounds: CGRect(x: boundsX, y: boundsY, width: width, height: height),
                forType: .line,
                withProperties: lineAttributes
            )
            // UUID
            lineAnnotation.userName = UUID().uuidString
            page.addAnnotation(lineAnnotation)
            
            // Undo Redo
            undoRedoManager.addAnnotation(lineAnnotation)
            undoRedoManager.showTeamMembers(completion: { didUndoAnnotations in
                // Undo Redo が可能なAnnotation　を削除して、更新後のAnnotationを表示させる
                self.reloadPDFAnnotations(didUndoAnnotations: didUndoAnnotations)
            })
            // ボタン　活性状態
            undoButton.isEnabled = undoRedoManager.canUndo()
            redoButton.isEnabled = undoRedoManager.canRedo()
        }
    }
    
    // マーカーを追加する 四角
    func addRectangleMarkerAnotation() {
        // 現在開いているページを取得
        if let page = self.pdfView.currentPage,
           let beganLocation = beganLocation,
           let changedLocation = changedLocation,
           let endLocation = endLocation {
            
            let boundsX = beganLocation.x > endLocation.x ? endLocation.x : beganLocation.x
            let boundsY = beganLocation.y > endLocation.y ? endLocation.y : beganLocation.y
            
            let width = beganLocation.x > endLocation.x ? beganLocation.x - endLocation.x : endLocation.x - beganLocation.x
            let height = beganLocation.y > endLocation.y ? beganLocation.y - endLocation.y : endLocation.y - beganLocation.y
            
            let border = PDFBorder()
            border.lineWidth = 5.0
            border.style = dashPattern == .pattern1 ? .solid : .dashed
            border.dashPattern = dashPattern == .pattern1 ? nil : dashPattern.style
            
            // Create dictionary of annotation properties
            let lineAttributes: [PDFAnnotationKey: Any] = [
                .color: UIColor.green,
                .border: border
            ]
            
            // Create an annotation to add to a page (empty)
            let newAnnotation = PDFAnnotation(
                bounds: CGRect(x: boundsX, y: boundsY, width: width, height: height),
                forType: .square,
                withProperties: lineAttributes
            )
            // UUID
            newAnnotation.userName = UUID().uuidString
            page.addAnnotation(newAnnotation)
            
            // Undo Redo
            undoRedoManager.addAnnotation(newAnnotation)
            undoRedoManager.showTeamMembers(completion: { didUndoAnnotations in
                // Undo Redo が可能なAnnotation　を削除して、更新後のAnnotationを表示させる
                self.reloadPDFAnnotations(didUndoAnnotations: didUndoAnnotations)
            })
            // ボタン　活性状態
            undoButton.isEnabled = undoRedoManager.canUndo()
            redoButton.isEnabled = undoRedoManager.canRedo()
        }
    }
    
    // マーカーを追加する 円
    func addCircleMarkerAnotation() {
        // 現在開いているページを取得
        if let page = self.pdfView.currentPage,
           let beganLocation = beganLocation,
           let changedLocation = changedLocation,
           let endLocation = endLocation {
            
            let boundsX = beganLocation.x > endLocation.x ? endLocation.x : beganLocation.x
            let boundsY = beganLocation.y > endLocation.y ? endLocation.y : beganLocation.y
            
            let width = beganLocation.x > endLocation.x ? beganLocation.x - endLocation.x : endLocation.x - beganLocation.x
            let height = beganLocation.y > endLocation.y ? beganLocation.y - endLocation.y : endLocation.y - beganLocation.y
            
            let border = PDFBorder()
            border.lineWidth = 2.0
            border.style = dashPattern == .pattern1 ? .solid : .dashed
            border.dashPattern = dashPattern == .pattern1 ? nil : dashPattern.style
            
            // Create dictionary of annotation properties
            let lineAttributes: [PDFAnnotationKey: Any] = [
                .color: UIColor.green,
                .border: border
            ]
            
            // Create an annotation to add to a page (empty)
            let newAnnotation = PDFAnnotation(
                bounds: CGRect(x: boundsX, y: boundsY, width: width, height: height),
                forType: .circle,
                withProperties: lineAttributes
            )
            // UUID
            newAnnotation.userName = UUID().uuidString
            page.addAnnotation(newAnnotation)
            
            // Undo Redo
            undoRedoManager.addAnnotation(newAnnotation)
            undoRedoManager.showTeamMembers(completion: { didUndoAnnotations in
                // Undo Redo が可能なAnnotation　を削除して、更新後のAnnotationを表示させる
                self.reloadPDFAnnotations(didUndoAnnotations: didUndoAnnotations)
            })
            // ボタン　活性状態
            undoButton.isEnabled = undoRedoManager.canUndo()
            redoButton.isEnabled = undoRedoManager.canRedo()
        }
    }
    
    // MARK: - テキスト
    
    // 編集中のAnnotation
    var isEditingAnnotation: PDFAnnotation?
    
    // マーカーを追加する テキスト
    func addTextMarkerAnotation(inputText: String?, fontSize: CGFloat) {
        // 現在開いているページを取得
        if let page = self.pdfView.currentPage,
           let point = point,
           let inputText = inputText,
           !inputText.isEmpty {
            
            // freeText
            let font = UIFont.systemFont(ofSize: fontSize)
            let size = "\(inputText)".size(with: font)
            // Create dictionary of annotation properties
            let attributes: [PDFAnnotationKey: Any] = [
                .color: UIColor.systemPink.withAlphaComponent(0.1),
                .contents: "\(inputText)",
            ]
            
            let freeText = PDFAnnotation(
                bounds: CGRect(x: point.x, y: point.y, width: size.width + 5, height: size.height + 5),
                forType: .freeText,
                withProperties: attributes
            )
            // UUID
            freeText.userName = UUID().uuidString
            // 対象のページへ注釈を追加
            page.addAnnotation(freeText)
            
            // Undo Redo
            undoRedoManager.addAnnotation(freeText)
            undoRedoManager.showTeamMembers(completion: { didUndoAnnotations in
                // Undo Redo が可能なAnnotation　を削除して、更新後のAnnotationを表示させる
                self.reloadPDFAnnotations(didUndoAnnotations: didUndoAnnotations)
            })
            // ボタン　活性状態
            undoButton.isEnabled = undoRedoManager.canUndo()
            redoButton.isEnabled = undoRedoManager.canRedo()
        }
    }
    
    // マーカーを更新する テキスト
    func updateTextMarkerAnotation(inputText: String?, fontSize: CGFloat) {
        // 現在開いているページを取得
        if let page = pdfView.currentPage {
            
            guard let isEditingAnnotation = isEditingAnnotation else { return }
            // 変更前
            before = isEditingAnnotation
            // 変更後
            let after = isEditingAnnotation.copy() as! PDFAnnotation
            after.bounds = isEditingAnnotation.bounds
            after.page = isEditingAnnotation.page
            
            if let before = before,
               let inputText = inputText,
               !inputText.isEmpty {
                
                // freeText
                let font = UIFont.systemFont(ofSize: fontSize)
                let size = "\(inputText)".size(with: font)
                // 文字列の長さが変化したらboundsも更新しなければならない
                after.bounds = CGRect(
                    x: after.bounds.origin.x,
                    y: after.bounds.origin.y,
                    width: size.width + 5,
                    height: size.height + 5
                )
                after.contents = inputText
                after.setValue(UIColor.yellow.withAlphaComponent(0.5), forAnnotationKey: .color)
                after.page = before.page
                // UUID
                after.userName = UUID().uuidString
                // Annotationを再度作成
                page.addAnnotation(after)
                // 古いものを削除する
                //                    page.removeAnnotation(before)
                // 初期化
                self.before = nil
                // Undo Redo 更新
                undoRedoManager.updateAnnotation(before: before, after: after)
                undoRedoManager.showTeamMembers(completion: { didUndoAnnotations in
                    // Undo Redo が可能なAnnotation　を削除して、更新後のAnnotationを表示させる
                    self.reloadPDFAnnotations(didUndoAnnotations: didUndoAnnotations)
                })
                // ボタン　活性状態
                undoButton.isEnabled = undoRedoManager.canUndo()
                redoButton.isEnabled = undoRedoManager.canRedo()
            }
        }
    }
    
    // MARK: - Undo Redo
    
    var undoButton: UIBarButtonItem!
    var redoButton: UIBarButtonItem!
    // Undo Redo
    let undoRedoManager = UndoRedoManager()
    // Undo Redo が可能なAnnotation
    private var editingAnnotations: [PDFAnnotation]?
    
    // Undo Redo が可能なAnnotation　を削除して、更新後のAnnotationを表示させる
    func reloadPDFAnnotations(didUndoAnnotations: [PDFAnnotation]?) {
        print(#function)
        // Undo Redo が可能なAnnotation　を削除する
        DispatchQueue.main.async {
            if let editingAnnotations = self.editingAnnotations {
                for editingAnnotation in editingAnnotations {
                    // pageを探す
                    guard let document = self.pdfView.document else { return }
                    for i in 0..<document.pageCount {
                        if let page = document.page(at: i),
                           let editingAnnotationPage = editingAnnotation.page {
                            // page が同一か？
                            if document.index(for: page) == document.index(for: editingAnnotationPage) {
                                print("対象のページの注釈を削除", editingAnnotation.contents)
                                // 対象のページの注釈を削除
                                page.removeAnnotation(editingAnnotation)
                            }
                        }
                    }
                }
            }
        }
        // Undo Redo が可能なAnnotation　をUndoする
        DispatchQueue.main.async {
            self.editingAnnotations = nil
            self.editingAnnotations = didUndoAnnotations
            if let editingAnnotations = self.editingAnnotations {
                for editingAnnotation in editingAnnotations {
                    // pageを探す
                    guard let document = self.pdfView.document else { return }
                    for i in 0..<document.pageCount {
                        if let page = document.page(at: i),
                           let editingAnnotationPage = editingAnnotation.page {
                            // page が同一か？
                            if document.index(for: page) == document.index(for: editingAnnotationPage) {
                                print("対象のページの注釈を追加", editingAnnotation.contents)
                                // 対象のページの注釈を追加
                                page.addAnnotation(editingAnnotation)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Undo Redo ボタン
    func setupUndoRedoButtons() {
        redoButton = UIBarButtonItem(barButtonSystemItem: .fastForward, target: self, action: #selector(redoTapped))
        if let _ = navigationItem.rightBarButtonItems {
            navigationItem.rightBarButtonItems?.append(redoButton)
        } else {
            navigationItem.rightBarButtonItem = redoButton
        }
        undoButton = UIBarButtonItem(barButtonSystemItem: .rewind, target: self, action: #selector(undoTapped))
        navigationItem.rightBarButtonItems?.append(undoButton)
    }

    @objc
    func undoTapped() {
        
        undoRedoManager.undo(completion: { didUndoAnnotations in
            // Undo Redo が可能なAnnotation　を削除して、更新後のAnnotationを表示させる
            self.reloadPDFAnnotations(didUndoAnnotations: didUndoAnnotations)
        })
        // ボタン　活性状態
        undoButton.isEnabled = undoRedoManager.canUndo()
        redoButton.isEnabled = undoRedoManager.canRedo()
    }
    
    @objc
    func redoTapped() {
        
        undoRedoManager.redo(completion: { didUndoAnnotations in
            // Undo Redo が可能なAnnotation　を削除して、更新後のAnnotationを表示させる
            self.reloadPDFAnnotations(didUndoAnnotations: didUndoAnnotations)
        })
        // ボタン　活性状態
        undoButton.isEnabled = undoRedoManager.canUndo()
        redoButton.isEnabled = undoRedoManager.canRedo()
    }
    
    // MARK: - PDF ファイル　マークアップ　保存
    
    // マーカーを追加しPDFを上書き保存する
    func save(completion: (() -> Void)) {
        if let fileURL = fileURL {
            // 一時ファイルをiCloud Container に保存しているPDFファイルへ上書き保存する
            let isFinished = pdfView.document?.write(to: fileURL)
            if let isFinished = isFinished,
               isFinished {
                completion()
            }
            
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


extension DrawingReportEditViewController: UINavigationControllerDelegate {
    
}

extension DrawingReportEditViewController: UIGestureRecognizerDelegate {
    
    @objc
    func tappedView(_ sender: UITapGestureRecognizer){
        
        if drawingMode == .photoMarker {
            // ①PDFに対してPDFAnnotationを設定する
            
            // PDF 全てのpageに存在するAnnotationを保持する
            getAllAnnotations() {
                // 現在開いているページを取得
                if let page = self.pdfView.currentPage,
                   // 使用していない連番を取得する
                   let unusedNumber = self.getUnusedNumber() {
                    // 使用していない連番
                    self.unusedNumber = unusedNumber
                    // UIViewからPDFの座標へ変換する
                    let point = self.pdfView.convert(sender.location(in: self.pdfView), to: page) // 座標系がUIViewとは異なるので気をつけましょう。
                    // PDFのタップされた位置の座標
                    self.point = point
                    // マーカーを追加する 写真
                    self.addMarkerAnotation()
                }
            }
        } else if drawingMode == .text {
            // 現在開いているページを取得
            if let page = self.pdfView.currentPage {
                // UIViewからPDFの座標へ変換する
                let point = self.pdfView.convert(sender.location(in: self.pdfView), to: page) // 座標系がUIViewとは異なるので気をつけましょう。
                // PDFのタップされた位置の座標
                self.point = point
                // ポップアップを表示させる
                if let viewController = UIStoryboard(
                    name: "TextInputViewController",
                    bundle: nil
                ).instantiateViewController(
                    withIdentifier: "TextInputViewController"
                ) as? TextInputViewController {
                    viewController.modalPresentationStyle = .overCurrentContext
                    viewController.modalTransitionStyle = .crossDissolve
                    present(viewController, animated: true, completion: nil)
                }
            }
        }
    }
    
    @objc
    func didPanAnnotation(sender: UIPanGestureRecognizer) {
        // 現在開いているページを取得
        if let page = self.pdfView.currentPage {
            // UIViewからPDFの座標へ変換する
            let locationOnPage = pdfView.convert(sender.location(in: pdfView), to: page)
            
            if drawingMode == .photoMarker { // 写真マーカー
                
            } else if drawingMode == .drawing {// 手書き
                
            } else if drawingMode == .arrow { // 矢印
                switch sender.state {
                case .began:
                    // 起点
                    beganLocation = locationOnPage
                    print("起点　", beganLocation)
                case .changed:
                    // 途中点
                    changedLocation = locationOnPage
                    print("途中点", changedLocation)
                case .ended:
                    // 終点
                    endLocation = locationOnPage
                    print("終点　", endLocation)
                    // マーカーを追加する 矢印
                    addArrowMarkerAnotation()
                case .cancelled, .failed:
                    break
                default:
                    break
                }
            } else if drawingMode == .line { // 直線
                switch sender.state {
                case .began:
                    // 起点
                    beganLocation = locationOnPage
                    print("起点　", beganLocation)
                case .changed:
                    // 途中点
                    changedLocation = locationOnPage
                    print("途中点", changedLocation)
                case .ended:
                    // 終点
                    endLocation = locationOnPage
                    print("終点　", endLocation)
                    // マーカーを追加する 直線
                    addLineMarkerAnotation()
                case .cancelled, .failed:
                    break
                default:
                    break
                }
            } else if drawingMode == .rectangle { // 四角
                switch sender.state {
                case .began:
                    // 起点
                    beganLocation = locationOnPage
                    print("起点　", beganLocation)
                case .changed:
                    // 途中点
                    changedLocation = locationOnPage
                    print("途中点", changedLocation)
                case .ended:
                    // 終点
                    endLocation = locationOnPage
                    print("終点　", endLocation)
                    // マーカーを追加する 四角
                    addRectangleMarkerAnotation()
                case .cancelled, .failed:
                    break
                default:
                    break
                }
                
            } else if drawingMode == .circle { // 円
                switch sender.state {
                case .began:
                    // 起点
                    beganLocation = locationOnPage
                    print("起点　", beganLocation)
                case .changed:
                    // 途中点
                    changedLocation = locationOnPage
                    print("途中点", changedLocation)
                case .ended:
                    // 終点
                    endLocation = locationOnPage
                    print("終点　", endLocation)
                    // マーカーを追加する 円
                    addCircleMarkerAnotation()
                case .cancelled, .failed:
                    break
                default:
                    break
                }
            } else if drawingMode == .move { // 移動
                switch sender.state {
                case .began:
                    guard let annotation = page.annotation(at: locationOnPage) else { return }
                    currentlySelectedAnnotation = annotation
                    // 変更前
                    if let copy = annotation.copy() as? PDFAnnotation {
                        before = copy
                        copy.bounds = annotation.bounds
                        copy.page = annotation.page
                    }
                    if let copy = annotation.copy() as? PhotoAnnotation {
                        before = copy
                        copy.bounds = annotation.bounds
                        copy.page = annotation.page
                    }
                    if let copy = annotation.copy() as? ImageAnnotation {
                        before = copy
                        copy.bounds = annotation.bounds
                        copy.page = annotation.page
                    }
                case .changed:
                    guard let annotation = currentlySelectedAnnotation else {return }
                    let initialBounds = annotation.bounds
                    // Set the center of the annotation to the spot of our finger
                    annotation.bounds = CGRect(x: locationOnPage.x - (initialBounds.width / 2), y: locationOnPage.y - (initialBounds.height / 2), width: initialBounds.width, height: initialBounds.height)
                case .ended, .cancelled, .failed:
                    // マーカーを更新する 移動
                    updateMarkerAnotation()
                    
                    currentlySelectedAnnotation = nil
                default:
                    break
                }
            }
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

enum Colors: Int, CaseIterable {
    case black
    case systemRed
    case systemYellow
    case systemGreen
    case systemBlue
    case blue
    case systemPink
    
//    case babyBlue
//    case buttercup
//    case lilac
//    case meadow
//    case rose
    
    func getColor() -> UIColor {
        switch self {
        case .black:
            return UIColor.darkGray
        case .systemRed:
            return UIColor.systemRed
        case .systemYellow:
            return UIColor.systemYellow
        case .systemGreen:
            return UIColor.systemGreen
        case .systemBlue:
            return UIColor.systemBlue
        case .blue:
            return UIColor.blue
        case .systemPink:
            return UIColor.systemPink

//        case .babyBlue:
//            return UIColor(named: "BabyBlue")!
//        case .buttercup:
//            return UIColor(named: "Buttercup")!
//        case .lilac:
//            return UIColor(named: "Lilac")!
//        case .meadow:
//            return UIColor(named: "Meadow")!
//        case .rose:
//            return UIColor(named: "Rose")!
        }
    }
}

enum ColorsDark: Int, CaseIterable {
    case blackDark
    case systemRedDark
    case systemYellowDark
    case systemGreenDark
    case systemBlueDark
    case blueDark
    case systemPinkDark
    
    func getColor() -> UIColor {
        switch self {
        case .blackDark:
            return UIColor.darkGray.dark(brightnessRatio: 0.8)
        case .systemRedDark:
            return UIColor.systemRed.dark(brightnessRatio: 0.8)
        case .systemYellowDark:
            return UIColor.systemYellow.dark(brightnessRatio: 0.8)
        case .systemGreenDark:
            return UIColor.systemGreen.dark(brightnessRatio: 0.8)
        case .systemBlueDark:
            return UIColor.systemBlue.dark(brightnessRatio: 0.8)
        case .blueDark:
            return UIColor.blue.dark(brightnessRatio: 0.8)
        case .systemPinkDark:
            return UIColor.systemPink.dark(brightnessRatio: 0.8)
        }
    }
}

enum Alpha: Int, CaseIterable {
    case alpha01
    case alpha02
    case alpha03
    case alpha04
    case alpha05
    case alpha06
    case alpha07

    var alpha: CGFloat {
        switch self {
        case .alpha01:
            return 0.4
        case .alpha02:
            return 0.5
        case .alpha03:
            return 0.6
        case .alpha04:
            return 0.7
        case .alpha05:
            return 0.8
        case .alpha06:
            return 0.9
        case .alpha07:
            return 1
        }
    }
}

extension UIButton {
    func makeRounded(_ cornerSize: CGFloat, borderWidth: CGFloat, borderColor: UIColor) {
        layer.cornerRadius = cornerSize
        layer.borderWidth = borderWidth
        layer.borderColor = borderColor.cgColor
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
