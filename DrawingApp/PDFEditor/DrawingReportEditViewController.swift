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
        // Xボタン 戻るボタン
        setupButtons()
        // Undo Redo ボタン
        setupUndoRedoButtons()
        // セグメントコントロール
        setupSegmentedControl()
        // 編集するPDFページを表示させる
        setupPdfView()
        // PDF Annotationがタップされたかを監視
        setupAnnotationRecognizer()
        // 手書きパレット
        createButtons()
        // JSONファイル　状態管理
        setupPdfStateFromJsonFile()
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
    
    // MARK: - JSONファイル

    // プロジェクト
    var project: Project?
    
    // JSONファイル　状態管理
    func setupPdfStateFromJsonFile() {
        // JSONファイル　状態管理
        project = JsonFileManager.shared.readSavedJson()
        if let prject = project {
            
        } else {
            // プロジェクトに写真マーカーを設定
            project = Project(
                version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0.0",
                markers: []
            )
        }
        print(project.debugDescription)
        // Undo Redo 初期値
        undoRedoManager.setup(makers: project?.markers)

        // PDF 全てのpageに存在するAnnotationを削除する
        deleteAllAnnotations()
        // PDF 全てのpageに存在するAnnotationをJSONファイルから生成する
        createAllAnnotations()
    }
    
    // PDF 全てのpageに存在するAnnotationを削除する
    func deleteAllAnnotations() {
        guard let document = pdfView.document else { return }
        for i in 0..<document.pageCount {
            if let page = document.page(at: i) {
                //
                let annotations = page.annotations
                for annotation in annotations {
                    page.removeAnnotation(annotation)
                }
            }
        }
    }
 
    // PDF 全てのpageに存在するAnnotationをJSONファイルから生成する
    func createAllAnnotations() {
        DispatchQueue.main.async {
            guard let document = self.pdfView.document else { return }
            if let markers = self.project?.markers {
                for marker in markers {
                    // pageを探す
                    for i in 0..<document.pageCount {
                        if let page = document.page(at: i) {
                            if marker.data.annotationType == .photoAnnotation {
                                // PhotoAnnotation 作成
                                let annotation = self.createMarkerAnnotation(marker: marker)
                                // page が同一か？
                                if page.label == marker.data.pageLabel {
                                    // 対象のページの注釈を追加
                                    page.addAnnotation(annotation)
                                }
                            }
                            if marker.data.annotationType == .drawingAnnotation {
                                // DrawingAnnotation 作成
                                if let annotation = self.createDrawingAnnotation(marker: marker) {
                                    // page が同一か？
                                    if page.label == marker.data.pageLabel {
                                        // 対象のページの注釈を追加
                                        page.addAnnotation(annotation)
                                    }
                                }
                            }
                            //                                if let annotation = editingAnnotation as? DrawingAnnotation {
                            //                                    print(annotation.bounds)
                            //                                    print(annotation.path.bounds)
                            //                                    annotation.path = annotation.path.fit(into: annotation.bounds)
                            //                                    print(annotation.bounds)
                            //                                    print(annotation.path.bounds)
                            //                                    // page が同一か？
                            //                                    if page.label == marker.data.pageLabel {
                            //                                        // 対象のページの注釈を追加
                            //                                        page.addAnnotation(annotation)
                            //                                    }
                            //                                } else {
                        }
                    }
                }
            }
        }
    }

    // MARK: - Xボタン
    
    // Xボタン 戻るボタン
    func setupButtons() {
        
        // Xボタン　戻るボタン
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeScreen))
    }
    
    // MARK: - 戻るボタン
    
    // Xボタン　戻るボタン
    @objc
    func closeScreen() {
        // 戻るボタンの動作処理
        // マーカーを追加しPDFを上書き保存する
        save(completion: {
            self.navigationController?.popViewController(animated: true)
        })
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
    let segmentedControl = UISegmentedControl(items: ["ビューモード", "移動", "グループ選択", "写真マーカー", "手書き", "直線", "矢印", "四角", "円", "テキスト", "損傷マーカー", "消しゴム"])
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
        
        if drawingMode == .drawing {
            pdfView.addGestureRecognizer(pdfDrawingGestureRecognizer)
            pdfDrawingGestureRecognizer.drawingDelegate = pdfDrawer
            pdfDrawer.pdfView = pdfView
            pdfDrawer.color = selectedColor.withAlphaComponent(selectedAlpha.alpha)
            // 手書きのアノテーションを追加する処理
            pdfDrawer.drawingManageAnnotationDelegate = self
            
            pdfDrawer.isActive = true
        } else {
            pdfView.removeGestureRecognizer(pdfDrawingGestureRecognizer)
            // 手書きのアノテーションを追加する処理
            pdfDrawer.drawingManageAnnotationDelegate = nil
            
            pdfDrawer.isActive = false
        }
        
        if drawingMode == .photoMarker || drawingMode == .drawing || drawingMode == .line || drawingMode == .arrow || drawingMode == .rectangle || drawingMode == .circle || drawingMode == .text || drawingMode == .damageMarker {
            propertyEditorScrollView?.isHidden = false
            propertyEditorCloseButtonView.isHidden = false
            
            if drawingMode == .photoMarker || drawingMode == .drawing || drawingMode == .line || drawingMode == .arrow || drawingMode == .rectangle || drawingMode == .circle || drawingMode == .text || drawingMode == .damageMarker {
                
                if drawingMode == .drawing || drawingMode == .line || drawingMode == .arrow || drawingMode == .rectangle || drawingMode == .circle {
                    colorLineStyleView.isHidden = false
                    sliderView.isHidden = false
                } else {
                    colorLineStyleView.isHidden = true
                    sliderView.isHidden = true
                }
                if drawingMode == .photoMarker || drawingMode == .damageMarker {
                    photoMarkerSliderView.isHidden = false
                } else {
                    photoMarkerSliderView.isHidden = true
                }
                if drawingMode == .damageMarker {
                    colorPaletteView.isHidden = true
                    alphaPaletteView.isHidden = true
                    damageMarkerStyleView.isHidden = false
                } else {
                    colorPaletteView.isHidden = false
                    alphaPaletteView.isHidden = false
                    damageMarkerStyleView.isHidden = true
                }
            } else {
                colorPaletteView.isHidden = true
                alphaPaletteView.isHidden = true
            }
        } else {
            propertyEditorScrollView?.isHidden = true
            propertyEditorCloseButtonView.isHidden = true
            colorPaletteView.isHidden = true
            alphaPaletteView.isHidden = true
            colorLineStyleView.isHidden = true
            damageMarkerStyleView.isHidden = true
            sliderView.isHidden = true
            photoMarkerSliderView.isHidden = true
        }
    }
    
    // MARK: - アノテーション
    
    // 長押し検知用のView
    @IBOutlet weak var longPressView: UIView!
    
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
        // 長押し
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPress(_:)))
        longPressGesture.delegate = self
        // longPressGesture.numberOfTapsRequired = 1　これがあると反応しなくなる
        longPressGesture.minimumPressDuration = 0.3
        longPressView.addGestureRecognizer(longPressGesture)
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
            }
            if let annotationPage = annotation.page {
                // 対象のページの注釈を削除
                page.removeAnnotation(annotation)
                // iOS17対応　PDFAnnotationのpageが消えてしまう現象
                annotation.page = annotationPage
            }
            
            if let oldId = annotation.userName {
                
                if let marker = project?.markers?.filter { $0.data.id == oldId }.first {
                    // Undo Redo 削除
                    undoRedoManager.deleteAnnotation(marker)
                    undoRedoManager.showTeamMembers(completion: { didUndoAnnotations in
                        // Undo Redo が可能なAnnotation　を削除して、更新後のAnnotationを表示させる
                        reloadPDFAnnotations(didUndoAnnotations: didUndoAnnotations)
                    })
                    // ボタン　活性状態
                    undoButton.isEnabled = undoRedoManager.canUndo()
                    redoButton.isEnabled = undoRedoManager.canRedo()
                    // JSONファイル　状態管理
                    project?.markers?.removeAll(where: { $0.data.id == oldId } )
                }
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
        if drawingMode == .photoMarker { // 写真マーカー
            // Annotationを削除する
            removeAnotation(annotation: annotation)
        }
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
                if let annotationPage = annotation.page {
                    // 古いものを削除する
                    page.removeAnnotation(annotation)
                    // iOS17対応　PDFAnnotationのpageが消えてしまう現象
                    annotation.page = annotationPage
                }
                // Undo Redo 更新
//                undoRedoManager.updateAnnotation(before: annotation, after: lineAnnotation)
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
    var currentlySelectedImageAnnotation: ImageAnnotation?
    var currentlySelectedDrawingAnnotation: DrawingAnnotation?

    // マーカーを更新する 移動
    func updateMarkerAnotation() {
        // 現在開いているページを取得
        if let page = pdfView.currentPage {
            
            if let before = before,
               let contents = before.contents,
//               let contents = Int(contents), // TODO: 写真マーカーのみ使用
               let oldId = before.userName,
               let page = before.page,
               // 選択しているAnnotation 移動中のAnnotation
               let currentlySelectedAnnotation = currentlySelectedAnnotation {
                // 変更後
                let marker = Marker(imageId: "",
                                    data: Marker.MarkerInfo(id: UUID().uuidString,
                                                            annotationType: .pdfAnnotation, // TODO: photoAnnotation
                                                            size: selectedPhotoMarkerSize,
                                                            x: currentlySelectedAnnotation.bounds.origin.x,
                                                            y: currentlySelectedAnnotation.bounds.origin.y,
                                                            color: ColorRGBA(color: before.color),
                                                            pageLabel: page.label,
                                                            text: contents)
                )
                // PhotoAnnotation 作成
                let after = currentlySelectedAnnotation//self.createMarkerAnnotation(marker: marker)
                
                after.page = before.page
                if let afterPage = after.page {
                    // Annotationを再度作成
                    afterPage.addAnnotation(after)
                }
                if let beforePage = before.page {
                    // 古いものを削除する
                    beforePage.removeAnnotation(before)
                    // iOS17対応　PDFAnnotationのpageが消えてしまう現象
                    before.page = beforePage
                }
                // 初期化
                self.before = nil
                
                if let before = project?.markers?.filter { $0.data.id == oldId }.first {
                    // Undo Redo 更新
                    undoRedoManager.updateAnnotation(before: before, after: marker)
                    undoRedoManager.showTeamMembers(completion: { didUndoAnnotations in
                        // Undo Redo が可能なAnnotation　を削除して、更新後のAnnotationを表示させる
                        reloadPDFAnnotations(didUndoAnnotations: didUndoAnnotations)
                    })
                    // ボタン　活性状態
                    undoButton.isEnabled = undoRedoManager.canUndo()
                    redoButton.isEnabled = undoRedoManager.canRedo()
                    // JSONファイル　状態管理
                    project?.markers?.removeAll(where: { $0.data.id == oldId } )
                    project?.markers?.append(marker)
                }
            }
            // 損傷マーカー
            if let before = beforeImageAnnotation,
               let currentlySelectedAnnotation = currentlySelectedImageAnnotation {
                // 選択しているAnnotation 移動中のAnnotation
                // 変更後
                let after = currentlySelectedAnnotation
                after.bounds = currentlySelectedAnnotation.bounds
                after.page = currentlySelectedAnnotation.page
                after.image = before.image
                
                after.bounds = CGRect(
                    x: after.bounds.origin.x,
                    y: after.bounds.origin.y,
                    width: after.bounds.size.width,
                    height: after.bounds.size.height
                )
                after.contents = before.contents
                after.color = UIColor.orange.withAlphaComponent(0.5)
                after.page = before.page
                after.image = before.image
                
                // UUID
                after.userName = UUID().uuidString
                if let annotationPage = before.page {
                    // 古いものを削除する
                    page.removeAnnotation(before)
                    // iOS17対応　PDFAnnotationのpageが消えてしまう現象
                    before.page = annotationPage
                }
                // Annotationを再度作成
                page.addAnnotation(after)

                // 初期化
                self.beforeImageAnnotation = nil
                // Undo Redo 更新
//                undoRedoManager.updateAnnotation(before: before, after: after)
                undoRedoManager.showTeamMembers(completion: { didUndoAnnotations in
                    // Undo Redo が可能なAnnotation　を削除して、更新後のAnnotationを表示させる
                    self.reloadPDFAnnotations(didUndoAnnotations: didUndoAnnotations)
                })
                // ボタン　活性状態
                undoButton.isEnabled = undoRedoManager.canUndo()
                redoButton.isEnabled = undoRedoManager.canRedo()
            }
            // 手書き
            if let before = beforeDrawingAnnotation,
               let currentlySelectedAnnotation = currentlySelectedDrawingAnnotation {
                // 選択しているAnnotation 移動中のAnnotation
                // 変更後
                let after = currentlySelectedAnnotation
                after.bounds = currentlySelectedAnnotation.bounds
                after.page = currentlySelectedAnnotation.page

                after.bounds = CGRect(
                    x: after.bounds.origin.x,
                    y: after.bounds.origin.y,
                    width: before.bounds.size.width,
                    height: before.bounds.size.height
                )
                after.contents = before.contents
                after.color = UIColor.orange.withAlphaComponent(0.5)
                after.page = before.page
                after.path = before.path
                after.path = after.path.fit(into: after.bounds)

                // UUID
                after.userName = UUID().uuidString
                if let annotationPage = before.page {
                    // 古いものを削除する
                    page.removeAnnotation(before)
                    // iOS17対応　PDFAnnotationのpageが消えてしまう現象
                    before.page = annotationPage
                }
                // Annotationを再度作成
                page.addAnnotation(after)

                // 初期化
                self.beforeDrawingAnnotation = nil
                // Undo Redo 更新
//                undoRedoManager.updateAnnotation(before: before, after: after)
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
    
    // MARK: - 長押しメニュー
    // マーカーを更新する 長押しメニュー　編集
    func updateMarkerColorAnotation() {
        // 現在開いているページを取得
        if let page = pdfView.currentPage {
            
            if let before = before,
               let contents = before.contents,
//               let contents = Int(contents), // TODO: 写真マーカーのみ使用
               let oldId = before.userName,
               let page = before.page,
               // 選択しているAnnotation 移動中のAnnotation
               let currentlySelectedAnnotation = currentlySelectedAnnotation {
                // 変更後
                let marker = Marker(imageId: "",
                                    data: Marker.MarkerInfo(id: UUID().uuidString,
                                                            annotationType: .pdfAnnotation, // TODO: photoAnnotation
                                                            size: selectedPhotoMarkerSize,
                                                            x: currentlySelectedAnnotation.bounds.origin.x,
                                                            y: currentlySelectedAnnotation.bounds.origin.y,
                                                            color: ColorRGBA(color: selectedColor.withAlphaComponent(selectedAlpha.alpha)),
                                                            pageLabel: page.label,
                                                            text: contents)
                                    )
                // PhotoAnnotation 作成
                let after = currentlySelectedAnnotation//self.createMarkerAnnotation(marker: marker)
                after.color = selectedColor.withAlphaComponent(selectedAlpha.alpha)

                after.page = before.page
                if let afterPage = after.page {
                    // Annotationを再度作成
                    afterPage.addAnnotation(after)
                }
                if let beforePage = before.page {
                    // 古いものを削除する
                    beforePage.removeAnnotation(before)
                    // iOS17対応　PDFAnnotationのpageが消えてしまう現象
                    before.page = beforePage
                }
                // 初期化
//                self.before = nil

                if let before = project?.markers?.filter { $0.data.id == oldId }.first {
                    
                    // Undo Redo 更新
                    undoRedoManager.updateAnnotation(before: before, after: marker)
                    undoRedoManager.showTeamMembers(completion: { didUndoAnnotations in
                        // Undo Redo が可能なAnnotation　を削除して、更新後のAnnotationを表示させる
                        reloadPDFAnnotations(didUndoAnnotations: didUndoAnnotations)
                    })
                    // ボタン　活性状態
                    undoButton.isEnabled = undoRedoManager.canUndo()
                    redoButton.isEnabled = undoRedoManager.canRedo()
                    // JSONファイル　状態管理
                    project?.markers?.removeAll(where: { $0.data.id == oldId } )
                    project?.markers?.append(marker)
                }
            }
            // テキスト
            if let before = before,
               let isEditingAnnotation = isEditingAnnotation {
                // 変更後
                let after = isEditingAnnotation
                after.bounds = isEditingAnnotation.bounds
                after.page = isEditingAnnotation.page

                after.contents = before.contents
                after.setValue(UIColor.yellow.withAlphaComponent(0.5), forAnnotationKey: .color)
                // 左寄せ
                after.alignment = before.alignment
                // フォントサイズ
                after.font = before.font
                after.fontColor = selectedColor.withAlphaComponent(selectedAlpha.alpha)
                // UUID
                after.userName = UUID().uuidString
                if let annotationPage = before.page {
                    // 古いものを削除する
                    page.removeAnnotation(before)
                    // iOS17対応　PDFAnnotationのpageが消えてしまう現象
                    before.page = annotationPage
                }
                // Annotationを再度作成
                page.addAnnotation(after)
                // 初期化
//                    self.before = nil
                // Undo Redo 更新
//                undoRedoManager.updateAnnotation(before: before, after: after)
                undoRedoManager.showTeamMembers(completion: { didUndoAnnotations in
                    // Undo Redo が可能なAnnotation　を削除して、更新後のAnnotationを表示させる
                    self.reloadPDFAnnotations(didUndoAnnotations: didUndoAnnotations)
                })
                // ボタン　活性状態
                undoButton.isEnabled = undoRedoManager.canUndo()
                redoButton.isEnabled = undoRedoManager.canRedo()
            }
            // 損傷マーカー
            if let before = beforeImageAnnotation,
               let currentlySelectedAnnotation = currentlySelectedImageAnnotation {
                // 選択しているAnnotation 移動中のAnnotation
                // 変更後
                let after = currentlySelectedAnnotation
                after.bounds = currentlySelectedAnnotation.bounds
                after.page = currentlySelectedAnnotation.page
                after.image = before.image
                // オリジナル画像のサイズからアスペクト比を計算
                let aspectScale = after.image.size.height / after.image.size.width
                // widthからアスペクト比を元にリサイズ後のサイズを取得
                let resizedSize = CGSize(width: selectedPhotoMarkerSize, height: selectedPhotoMarkerSize * Double(aspectScale))

                after.bounds = CGRect(
                    x: after.bounds.origin.x,
                    y: after.bounds.origin.y,
                    width: resizedSize.width,
                    height: resizedSize.height
                )
                after.contents = before.contents
                after.color = selectedColor.withAlphaComponent(selectedAlpha.alpha)
                after.page = before.page
                
                // UUID
                after.userName = UUID().uuidString
                if let annotationPage = before.page {
                    // 古いものを削除する
                    page.removeAnnotation(before)
                    // iOS17対応　PDFAnnotationのpageが消えてしまう現象
                    before.page = annotationPage
                }
                // Annotationを再度作成
                page.addAnnotation(after)

                // 初期化
//                self.beforeImageAnnotation = nil
                // Undo Redo 更新
//                undoRedoManager.updateAnnotation(before: before, after: after)
                undoRedoManager.showTeamMembers(completion: { didUndoAnnotations in
                    // Undo Redo が可能なAnnotation　を削除して、更新後のAnnotationを表示させる
                    self.reloadPDFAnnotations(didUndoAnnotations: didUndoAnnotations)
                })
                // ボタン　活性状態
                undoButton.isEnabled = undoRedoManager.canUndo()
                redoButton.isEnabled = undoRedoManager.canRedo()
            }
            // 手書き
            if let before = beforeDrawingAnnotation {
                // 選択しているAnnotation 移動中のAnnotation
                guard let currentlySelectedAnnotation = currentlySelectedDrawingAnnotation else { return }
                // 変更後
                let after = currentlySelectedAnnotation
                after.bounds = currentlySelectedAnnotation.bounds
                after.page = currentlySelectedAnnotation.page

                after.bounds = CGRect(
                    x: after.bounds.origin.x,
                    y: after.bounds.origin.y,
                    width: before.bounds.size.width,
                    height: before.bounds.size.height
                )
                after.contents = before.contents
                after.color = selectedColor.withAlphaComponent(selectedAlpha.alpha)
                after.page = before.page
                after.path = before.path
                after.path = after.path.fit(into: after.bounds)

                // UUID
                after.userName = UUID().uuidString
                if let annotationPage = before.page {
                    // 古いものを削除する
                    page.removeAnnotation(before)
                    // iOS17対応　PDFAnnotationのpageが消えてしまう現象
                    before.page = annotationPage
                }
                // Annotationを再度作成
                page.addAnnotation(after)

                // 初期化
//                self.beforeDrawingAnnotation = nil
                // Undo Redo 更新
//                undoRedoManager.updateAnnotation(before: before, after: after)
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
    // PDF 現在のpageに存在する写真マーカーAnnotationを保持する
    var annotationsOnPage: [PDFAnnotation] = []
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
                var annotations = page.annotations.filter({ "/\($0.type!)" == PDFAnnotationSubtype.freeText.rawValue })
                annotations = annotations.filter({ Int($0.contents ?? "a") != nil })
                for annotation in annotations {
                    
                    annotationsInAllPages.append(annotation)
                }
            }
        }
        completion()
    }
    
    // PDF 現在のpageに存在する写真マーカーAnnotationを保持する
    func getAnnotationsOnPage(completion: @escaping () -> Void) {
        // 初期化
        annotationsOnPage = []
        if let page = pdfView.currentPage {
            // freeText
            var annotations = page.annotations.filter({ "/\($0.type!)" == PDFAnnotationSubtype.freeText.rawValue })
            annotations = annotations.filter({ Int($0.contents ?? "a") != nil })
            for annotation in annotations {
                
                annotationsOnPage.append(annotation)
            }
        }
        print(annotationsOnPage.count)
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
    
    // PhotoAnnotation 作成
    func createMarkerAnnotation(marker: Marker) -> PhotoAnnotation {
        // freeText
        let font = UIFont.systemFont(ofSize: marker.data.size)
        let size = "\(marker.data.text)".size(with: font)
        // Create dictionary of annotation properties
        let lineAttributes: [PDFAnnotationKey: Any] = [
            .color: marker.data.color.toUIColor(),
            .contents: "\(marker.data.text)",
        ]
        
        let freeText = PhotoAnnotation(bounds: CGRect(x: marker.data.x, y: marker.data.y, width: size.width * 1.1 + 5, height: size.height + 5), forType: .freeText, withProperties: lineAttributes)
        // 中央寄せ
        freeText.alignment = .center
        // フォントサイズ
        freeText.font = font
        freeText.fontColor = .white
        // UUID
        freeText.userName = marker.data.id

        return freeText
    }
    
    // DrawingAnnotation 作成
    func createDrawingAnnotation(marker: Marker) -> DrawingAnnotation? {
        if let points = marker.data.points,
           let lineWidth = marker.data.lineWidth,
           let dashPattern = marker.data.dashPattern {
            
            let path = UIBezierPath(cgPath: convert(elements: points))
            
            let border = PDFBorder()
            border.lineWidth = lineWidth
            border.style = dashPattern == .pattern1 ? .solid : .dashed
            border.dashPattern = dashPattern == .pattern1 ? nil : dashPattern.style(width: lineWidth)
            
            let bounds = CGRect(x: path.bounds.origin.x,
                                y: path.bounds.origin.y,
                                width: path.bounds.size.width,
                                height: path.bounds.size.height)
            path.lineCapStyle = .square
            path.lineJoinStyle = .round
            path.lineWidth = lineWidth
            
            if dashPattern == .pattern1 {
                
            } else {
                // 第一引数 点線の大きさ, 点線間の間隔
                // 第二引数 第一引数で指定した配列の要素数
                // 第三引数 開始位置
                path.setLineDash(dashPattern.style(width: lineWidth), count: dashPattern.style(width: lineWidth).count, phase: 0)
            }
            let annotation = DrawingAnnotation(bounds: bounds, forType: .ink, withProperties: nil)
            annotation.color = marker.data.color.toUIColor()
            annotation.border = border
            // 効かない
            // annotation.add(path)
            annotation.path = path
            //        page.addAnnotation(annotation)
            return annotation
        }
        return nil
    }

    // マーカーを追加する 写真
    func addMarkerAnotation() {
        // 現在開いているページを取得
        if let page = self.pdfView.currentPage,
           let point = point,
           let unusedNumber = unusedNumber {
            
            let marker = Marker(imageId: "",
                                data: Marker.MarkerInfo(id: UUID().uuidString,
                                                        annotationType: .photoAnnotation,
                                                        size: selectedPhotoMarkerSize,
                                                        x: point.x,
                                                        y: point.y,
                                                        color: ColorRGBA(color: selectedColor.withAlphaComponent(selectedAlpha.alpha)),
                                                        pageLabel: page.label,
                                                        text: "\(unusedNumber)")
                                )
            // PhotoAnnotation 作成
            let annotation = self.createMarkerAnnotation(marker: marker)
            //            // ページ
            //            freeText.page = page
            // 対象のページへ注釈を追加
            page.addAnnotation(annotation)
            
            // JSONファイル　状態管理
            project?.markers?.append(marker)
            
            // Undo Redo
            undoRedoManager.addAnnotation(marker)
            undoRedoManager.showTeamMembers(completion: { didUndoAnnotations in
                // Undo Redo が可能なAnnotation　を削除して、更新後のAnnotationを表示させる
                reloadPDFAnnotations(didUndoAnnotations: didUndoAnnotations)
            })
            // ボタン　活性状態
            undoButton.isEnabled = undoRedoManager.canUndo()
            redoButton.isEnabled = undoRedoManager.canRedo()
        }
    }
    
    // 写真マーカーを更新する
    func updatePhotoMarkerAnotation() {
        // PDF 現在のpageに存在する写真マーカーAnnotationを保持する
        getAnnotationsOnPage() { [self] in
            for annotation in self.annotationsOnPage {
                // 変更前
                before = annotation
                
                if let before = before,
                   let contents = before.contents,
//                   let contents = Int(contents), // TODO: 写真マーカーのみ使用
                   let oldId = before.userName,
                   let page = before.page {
                    // 変更後
                    let marker = Marker(imageId: "",
                                        data: Marker.MarkerInfo(id: UUID().uuidString,
                                                                annotationType: .photoAnnotation,
                                                                size: selectedPhotoMarkerSize,
                                                                x: before.bounds.origin.x,
                                                                y: before.bounds.origin.y,
                                                                color: ColorRGBA(color: before.color),
                                                                pageLabel: page.label,
                                                                text: contents)
                                        )
                    // PhotoAnnotation 作成
                    let after = self.createMarkerAnnotation(marker: marker)
                    
                    after.page = before.page
                    if let afterPage = after.page {
                        // Annotationを再度作成
                        afterPage.addAnnotation(after)
                    }
                    if let beforePage = before.page {
                        // 古いものを削除する
                        beforePage.removeAnnotation(before)
                        // iOS17対応　PDFAnnotationのpageが消えてしまう現象
                        before.page = beforePage
                    }
                    // 初期化
                    self.before = nil

                    if let before = project?.markers?.filter { $0.data.id == oldId }.first {
                        // Undo Redo 更新
                        undoRedoManager.updateAnnotation(before: before, after: marker)
                        undoRedoManager.showTeamMembers(completion: { didUndoAnnotations in
                            // Undo Redo が可能なAnnotation　を削除して、更新後のAnnotationを表示させる
                            reloadPDFAnnotations(didUndoAnnotations: didUndoAnnotations)
                        })
                        // ボタン　活性状態
                        undoButton.isEnabled = undoRedoManager.canUndo()
                        redoButton.isEnabled = undoRedoManager.canRedo()
                        // JSONファイル　状態管理
                        project?.markers?.removeAll(where: { $0.data.id == oldId } )
                        project?.markers?.append(marker)
                    }
                }
            }
        }
    }
    
    // MARK: - 手書きパレット
    
    private let pdfDrawer = PDFDrawer()
    let pdfDrawingGestureRecognizer = DrawingGestureRecognizer()
    
    // MARK: - プロパティ変更パネル

    // プロパティ変更パネル
    @IBOutlet var propertyEditorScrollView: UIScrollView!
    // プロパティ変更パネル
    @IBOutlet var propertyEditorStackView: UIStackView!
    // 手書き　カラーパレット
    var colorPaletteView = UIView()
    // 手書き　カラー
    var colorStackView: UIStackView?
    // 手書き　ダークカラー
    var colorDarkStackView: UIStackView?

    // 手書き　カラーパレット 透明度
    var alphaPaletteView = UIView()
    var colorAlphaStackView: UIStackView?

    // 手書き　書式　線のスタイル
    var colorLineStyleView = UIView()
    var lineStyleStackView: UIStackView?

    // 損傷マーカー
    var damageMarkerStyleView = UIView()
    var damageMarkerStyleStackView: UIStackView?

    // 手書き　書式　線の太さ
    var sliderView = UIView()
    var sliderStackView: UIStackView?
    var slider: UISlider?
    var fontSizeLabel = UILabel()
    
    // 手書き　書式　写真マーカーサイズ
    var photoMarkerSliderView = UIView()
    var photoMarkerSliderStackView: UIStackView?
    var photoMarkerSlider: UISlider?
    var photoMarkerFontSizeLabel = UILabel()

    // 手書き プロパティ変更パネル 閉じる
    var propertyEditorCloseButtonView = UIView()

    // 選択されたカラー
    var selectedColor: UIColor = .darkGray.dark(brightnessRatio: 1.0)
    // 選択された透明度
    var selectedAlpha: Alpha = .alpha07
    // 選択された線の太さ
    var selectedLineWidth: CGFloat = 15.0 {
        didSet {
            fontSizeLabel.text = "\(Int(selectedLineWidth)) px"
        }
    }
    // 選択された損傷マーカー
    var selectedDamage: DamagePattern = .uki
    // 選択された写真マーカーサイズ
    var selectedPhotoMarkerSize: CGFloat = 15.0 {
        didSet {
            photoMarkerFontSizeLabel.text = "\(Int(selectedPhotoMarkerSize)) px"
        }
    }

    // 手書きパレット
    func createButtons() {
        // 手書きパレット カラー
        createColorButtons()
        // 手書きパレット ダーク
        createDarkButtons()
        // 手書きパレット 透明度
        createAlphaButtons()
        // 手書き 書式　線のスタイル
        createLineStylesButtons()
        // 図形　線の太さ
        createLineWidthSlider()
        // 損傷マーカー
        createDamageStylesButtons()
        // 図形　写真マーカーサイズ
        createTextSizeSlider()
        // 手書き プロパティ変更パネル 閉じる
        createPropertyEditorCloseButton()
    }
    
    // 手書きパレット カラー
    func createColorButtons() {
        // ラベル
        let label = UILabel()
        label.text = "色の選択"
        label.backgroundColor = UIColor.systemPink.withAlphaComponent(0.3)
        // LabelをaddSubview
        colorPaletteView.addSubview(label)
        colorPaletteView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.3)
        // labelが左上に配置されるように制約を追加
        label.translatesAutoresizingMaskIntoConstraints = false
        label.topAnchor.constraint(equalTo: colorPaletteView.topAnchor, constant: 10.0).isActive = true
        label.leadingAnchor.constraint(equalTo: colorPaletteView.leadingAnchor, constant: 10.0).isActive = true
        
        //Create the color palette
        var buttons: [UIButton] = []
        for color in Colors.allCases {
            let button = UIButton(
                primaryAction: UIAction(handler: { action in
                    self.updatePens(sender: action.sender)
                })
            )
            button.heightAnchor.constraint(equalToConstant: 50.0).isActive = true
            button.widthAnchor.constraint(equalToConstant: 50.0).isActive = true
            button.makeRounded(25, borderWidth: 3, borderColor: .black)
            button.backgroundColor = color.getColor()
            button.tag = color.rawValue
            buttons.append(button)
        }
        // 色の選択
        colorStackView = UIStackView(arrangedSubviews: buttons)
        colorStackView?.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.3)
        if let colorStackView = colorStackView {
            colorStackView.axis = .horizontal
            colorStackView.distribution = .equalSpacing
            colorStackView.alignment = .center
            
            colorPaletteView.addSubview(colorStackView)
            colorPaletteView.heightAnchor.constraint(equalToConstant: label.bounds.height + 170).isActive = true

            colorStackView.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                colorStackView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 0),
                colorStackView.centerXAnchor.constraint(equalTo: colorPaletteView.centerXAnchor),
                colorStackView.widthAnchor.constraint(greaterThanOrEqualToConstant: colorPaletteView.bounds.width),
                colorStackView.heightAnchor.constraint(equalToConstant: 70)
            ])
            //            // stackViewにnewViewを追加する
            //            propertyEditorStackView.addArrangedSubview(colorPaletteView)
            //            // これだとダメ
            //            //stackView.addSubview(newView)
        }
    }
    
    // 手書きパレット ダーク
    func createDarkButtons() {
        //Create the color palette ダーク
        var buttonsDark: [UIButton] = []
        
        for color in ColorsDark.allCases {
            let button = UIButton(
                primaryAction: UIAction(handler: { action in
                    self.updateDarkPens(sender: action.sender)
                })
            )
            button.heightAnchor.constraint(equalToConstant: 50.0).isActive = true
            button.widthAnchor.constraint(equalToConstant: 50.0).isActive = true
            button.makeRounded(25, borderWidth: 3, borderColor: .black)
            button.backgroundColor = color.getColor()
            button.tag = color.rawValue
            buttonsDark.append(button)
        }
        // 色の選択 ダーク
        colorDarkStackView = UIStackView(arrangedSubviews: buttonsDark)
        colorDarkStackView?.backgroundColor = UIColor.blue.withAlphaComponent(0.3)
        if let colorStackView = colorStackView,
           let colorDarkStackView = colorDarkStackView {
            colorDarkStackView.axis = .horizontal
            colorDarkStackView.distribution = .equalSpacing
            colorDarkStackView.alignment = .center
            
            colorPaletteView.addSubview(colorDarkStackView)
            
            colorDarkStackView.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                colorDarkStackView.topAnchor.constraint(equalTo: colorStackView.bottomAnchor, constant: 0),
                colorDarkStackView.centerXAnchor.constraint(equalTo: colorPaletteView.centerXAnchor),
                colorDarkStackView.widthAnchor.constraint(greaterThanOrEqualToConstant: colorPaletteView.bounds.width),
                colorDarkStackView.heightAnchor.constraint(equalToConstant: 70)
            ])
            // stackViewにnewViewを追加する
            propertyEditorStackView.addArrangedSubview(colorPaletteView)
            // これだとダメ
            //stackView.addSubview(newView)
        }
    }
    
    // 手書きパレット 透明度
    func createAlphaButtons() {
        let label = UILabel()
        label.text = "透明度の選択"
        label.backgroundColor = UIColor.systemPink.withAlphaComponent(0.3)
        // LabelをaddSubview
        alphaPaletteView.addSubview(label)
        alphaPaletteView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.3)
        // labelが左上に配置されるように制約を追加
        label.translatesAutoresizingMaskIntoConstraints = false
        label.topAnchor.constraint(equalTo: alphaPaletteView.topAnchor, constant: 10.0).isActive = true
        label.leadingAnchor.constraint(equalTo: alphaPaletteView.leadingAnchor, constant: 10.0).isActive = true

        //Create the color palette 透明度
        var buttonsAlpha: [UIButton] = []
        
        for alpha in Alpha.allCases {
            let button = UIButton(
                primaryAction: UIAction(handler: { action in
                    self.updateAlphaPens(sender: action.sender)
                })
            )
            button.heightAnchor.constraint(equalToConstant: 50.0).isActive = true
            button.widthAnchor.constraint(equalToConstant: 50.0).isActive = true
            button.makeRounded(25, borderWidth: 3, borderColor: .black)
            button.backgroundColor = selectedColor.withAlphaComponent(alpha.alpha)
            button.tag = alpha.rawValue
            buttonsAlpha.append(button)
        }
        // 色の選択 透明度
        colorAlphaStackView = UIStackView(arrangedSubviews: buttonsAlpha)
        colorAlphaStackView?.backgroundColor = UIColor.orange.withAlphaComponent(0.3)
        if let colorAlphaStackView = colorAlphaStackView {
            colorAlphaStackView.axis = .horizontal
            colorAlphaStackView.distribution = .equalSpacing
            colorAlphaStackView.alignment = .center
            
            alphaPaletteView.addSubview(colorAlphaStackView)
            alphaPaletteView.heightAnchor.constraint(equalToConstant: label.bounds.height + 100).isActive = true

            colorAlphaStackView.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                colorAlphaStackView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 0),
                colorAlphaStackView.centerXAnchor.constraint(equalTo: alphaPaletteView.centerXAnchor),
                colorAlphaStackView.widthAnchor.constraint(greaterThanOrEqualToConstant: alphaPaletteView.bounds.width),
                colorAlphaStackView.heightAnchor.constraint(equalToConstant: 70)
            ])
            // stackViewにnewViewを追加する
            propertyEditorStackView.addArrangedSubview(alphaPaletteView)
            // これだとダメ
            //stackView.addSubview(newView)
        }
    }
    
    // 手書き 書式　線のスタイル
    func createLineStylesButtons() {
        // ラベル
        let label = UILabel()
        label.text = "線のスタイル"
        label.backgroundColor = UIColor.systemPink.withAlphaComponent(0.3)
        // LabelをaddSubview
        colorLineStyleView.addSubview(label)
        colorLineStyleView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.3)
        // labelが左上に配置されるように制約を追加
        label.translatesAutoresizingMaskIntoConstraints = false
        label.topAnchor.constraint(equalTo: colorLineStyleView.topAnchor, constant: 10.0).isActive = true
        label.leadingAnchor.constraint(equalTo: colorLineStyleView.leadingAnchor, constant: 10.0).isActive = true
        
        //Create the color palette
        var buttons: [UIButton] = []
        
        for dashPattern in DashPattern.allCases {
            let button = UIButton(
                primaryAction: UIAction(handler: { action in
                    self.updateDashPattern(sender: action.sender)
                })
            )
            button.heightAnchor.constraint(equalToConstant: 50.0).isActive = true
            button.widthAnchor.constraint(equalToConstant: 50.0).isActive = true
            // button.makeRounded(25, borderWidth: 3, borderColor: .black)
            button.backgroundColor = .clear
            // アイコン画像の色を指定する
            button.tintColor = .black
            button.setImage(dashPattern.getIcon(), for: UIControl.State.normal)
            button.tag = dashPattern.rawValue
            buttons.append(button)
        }
        // 書式の選択　線のスタイル
        lineStyleStackView = UIStackView(arrangedSubviews: buttons)
        lineStyleStackView?.backgroundColor = UIColor.brown.withAlphaComponent(0.3)
        if let lineStyleStackView = lineStyleStackView {
            lineStyleStackView.axis = .horizontal
            lineStyleStackView.distribution = .equalSpacing
            lineStyleStackView.alignment = .center
            
            colorLineStyleView.addSubview(lineStyleStackView)
            colorLineStyleView.heightAnchor.constraint(equalToConstant: label.bounds.height + 100).isActive = true

            lineStyleStackView.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                lineStyleStackView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 0),
                lineStyleStackView.bottomAnchor.constraint(equalTo: colorLineStyleView.bottomAnchor, constant: 0),
                lineStyleStackView.centerXAnchor.constraint(equalTo: colorLineStyleView.centerXAnchor),
                lineStyleStackView.widthAnchor.constraint(equalTo: colorLineStyleView.widthAnchor),
                lineStyleStackView.heightAnchor.constraint(equalToConstant: 70)
            ])
            // stackViewにnewViewを追加する
            propertyEditorStackView.addArrangedSubview(colorLineStyleView)
            // これだとダメ
            //stackView.addSubview(newView)
        }
    }
    
    // 図形　線の太さ
    func createLineWidthSlider() {
        let label = UILabel()
        label.text = "線の太さ"
        label.backgroundColor = UIColor.systemPink.withAlphaComponent(0.3)
        // LabelをaddSubview
        sliderView.addSubview(label)
        sliderView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.3)
        // labelが左上に配置されるように制約を追加
        label.translatesAutoresizingMaskIntoConstraints = false
        label.topAnchor.constraint(equalTo: sliderView.topAnchor, constant: 10.0).isActive = true
        label.leadingAnchor.constraint(equalTo: sliderView.leadingAnchor, constant: 10.0).isActive = true
        
        //Create the color palette 透明度
        var buttons: [UIView] = []
        
        // ボタン
        let smallButton = UIButton(
            primaryAction: UIAction(handler: { action in
                self.thinButtonTapped(action.sender)
            })
        )
        smallButton.heightAnchor.constraint(equalToConstant: 50.0).isActive = true
        smallButton.widthAnchor.constraint(equalToConstant: 50.0).isActive = true
        let image = UIImage(systemName: "arrowtriangle.backward")?.withRenderingMode(.alwaysTemplate) ?? UIImage()
        smallButton.setImage(image, for: UIControl.State.normal)
        smallButton.backgroundColor = UIColor.systemPink.withAlphaComponent(0.3)
        buttons.append(smallButton)
        print(propertyEditorScrollView.bounds.width)
        // スライダー
        slider = UISlider(
            frame: CGRect(x: 50, y: 0, width: propertyEditorScrollView.bounds.width * 2, height: 50.0),
            primaryAction: UIAction(handler: { action in
                self.sliderChanged(action.sender as! UISlider)
            })
        )
        if let slider = slider {
            slider.widthAnchor.constraint(equalToConstant: propertyEditorScrollView.bounds.width * 2).isActive = true
            slider.backgroundColor = UIColor.gray.withAlphaComponent(0.3)
            // スライダーの最小値を設定
            slider.minimumValue = 1.0
            // スライダーの最大値を設定
            slider.maximumValue = 99.0
            // 線の太さ
            slider.value = Float(selectedLineWidth)
            buttons.append(slider)
        }
        
        // ボタン
        let bigButton = UIButton(
            primaryAction: UIAction(handler: { action in
                self.thickButtonTapped(action.sender)
            })
        )
        bigButton.heightAnchor.constraint(equalToConstant: 50.0).isActive = true
        bigButton.widthAnchor.constraint(equalToConstant: 50.0).isActive = true
        let imageForward = UIImage(systemName: "arrowtriangle.forward")?.withRenderingMode(.alwaysTemplate) ?? UIImage()
        bigButton.setImage(imageForward, for: UIControl.State.normal)
        bigButton.backgroundColor = UIColor.systemPink.withAlphaComponent(0.3)
        buttons.append(bigButton)
        
        // UILabelの設定
        fontSizeLabel.textAlignment = NSTextAlignment.right // 横揃えの設定
        fontSizeLabel.text = "px" // テキストの設定
        fontSizeLabel.textColor = UIColor.black // テキストカラーの設定
        fontSizeLabel.backgroundColor = UIColor.gray.withAlphaComponent(0.3)
        // 初期値
        selectedLineWidth = 15.0
        buttons.append(fontSizeLabel)
        
        // 線の太さ
        sliderStackView = UIStackView(arrangedSubviews: buttons)
        sliderStackView?.backgroundColor = UIColor.green.withAlphaComponent(0.3)
        //        sliderStackView?.frame = sliderView.bounds
        
        if let stackView = sliderStackView {
            stackView.axis = .horizontal
            stackView.distribution = .equalSpacing
            stackView.alignment = .center
            stackView.spacing = 0
            sliderView.addSubview(stackView)
            sliderView.heightAnchor.constraint(equalToConstant: label.bounds.height + 100).isActive = true
            
            stackView.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                stackView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 0),
                stackView.bottomAnchor.constraint(equalTo: sliderView.bottomAnchor, constant: 0),
                stackView.centerXAnchor.constraint(equalTo: sliderView.centerXAnchor),
                stackView.widthAnchor.constraint(equalTo: sliderView.widthAnchor),
                stackView.heightAnchor.constraint(equalToConstant: 70)
            ])
            // stackViewにnewViewを追加する
            propertyEditorStackView.addArrangedSubview(sliderView)
            // これだとダメ
            //stackView.addSubview(newView)
        }
    }
    
    // 損傷マーカー
    func createDamageStylesButtons() {
        // ラベル
        let label = UILabel()
        label.text = "損傷マーカー"
        label.backgroundColor = UIColor.systemPink.withAlphaComponent(0.3)
        // LabelをaddSubview
        damageMarkerStyleView.addSubview(label)
        damageMarkerStyleView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.3)
        // labelが左上に配置されるように制約を追加
        label.translatesAutoresizingMaskIntoConstraints = false
        label.topAnchor.constraint(equalTo: damageMarkerStyleView.topAnchor, constant: 10.0).isActive = true
        label.leadingAnchor.constraint(equalTo: damageMarkerStyleView.leadingAnchor, constant: 10.0).isActive = true
        
        //Create the color palette
        var buttons: [UIButton] = []
        
        for dashPattern in DamagePattern.allCases {
            let button = UIButton(
                primaryAction: UIAction(handler: { action in
                    self.updateDamagePattern(sender: action.sender)
                })
            )
            button.heightAnchor.constraint(equalToConstant: 50.0).isActive = true
            button.widthAnchor.constraint(equalToConstant: 50.0).isActive = true
            // button.makeRounded(25, borderWidth: 3, borderColor: .black)
            button.backgroundColor = .clear
            // アイコン画像の色を指定する
            button.tintColor = .black
            button.setImage(dashPattern.getIcon(), for: UIControl.State.normal)
            button.tag = dashPattern.rawValue
            buttons.append(button)
        }
        // 書式の選択　線のスタイル
        damageMarkerStyleStackView = UIStackView(arrangedSubviews: buttons)
        damageMarkerStyleStackView?.backgroundColor = UIColor.brown.withAlphaComponent(0.3)
        if let damageMarkerStyleStackView = damageMarkerStyleStackView {
            damageMarkerStyleStackView.axis = .horizontal
            damageMarkerStyleStackView.distribution = .equalSpacing
            damageMarkerStyleStackView.alignment = .center
            
            damageMarkerStyleView.addSubview(damageMarkerStyleStackView)
            damageMarkerStyleView.heightAnchor.constraint(equalToConstant: label.bounds.height + 100).isActive = true

            damageMarkerStyleStackView.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                damageMarkerStyleStackView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 0),
                damageMarkerStyleStackView.bottomAnchor.constraint(equalTo: damageMarkerStyleView.bottomAnchor, constant: 0),
                damageMarkerStyleStackView.centerXAnchor.constraint(equalTo: damageMarkerStyleView.centerXAnchor),
                damageMarkerStyleStackView.widthAnchor.constraint(equalTo: damageMarkerStyleView.widthAnchor),
                damageMarkerStyleStackView.heightAnchor.constraint(equalToConstant: 70)
            ])
            // stackViewにnewViewを追加する
            propertyEditorStackView.addArrangedSubview(damageMarkerStyleView)
            // これだとダメ
            //stackView.addSubview(newView)
        }
    }

    // 図形　写真マーカーサイズ
    func createTextSizeSlider() {
        let label = UILabel()
        label.text = "マーカーサイズ"
        label.backgroundColor = UIColor.systemPink.withAlphaComponent(0.3)
        // LabelをaddSubview
        photoMarkerSliderView.addSubview(label)
        photoMarkerSliderView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.3)
        // labelが左上に配置されるように制約を追加
        label.translatesAutoresizingMaskIntoConstraints = false
        label.topAnchor.constraint(equalTo: photoMarkerSliderView.topAnchor, constant: 10.0).isActive = true
        label.leadingAnchor.constraint(equalTo: photoMarkerSliderView.leadingAnchor, constant: 10.0).isActive = true
        
        //Create the color palette 透明度
        var buttons: [UIView] = []
        
        // ボタン
        let smallButton = UIButton(
            primaryAction: UIAction(handler: { action in
                self.smallButtonTapped(action.sender)
            })
        )
        smallButton.heightAnchor.constraint(equalToConstant: 50.0).isActive = true
        smallButton.widthAnchor.constraint(equalToConstant: 50.0).isActive = true
        let image = UIImage(systemName: "arrowtriangle.backward")?.withRenderingMode(.alwaysTemplate) ?? UIImage()
        smallButton.setImage(image, for: UIControl.State.normal)
        smallButton.backgroundColor = UIColor.systemPink.withAlphaComponent(0.3)
        buttons.append(smallButton)
        print(propertyEditorScrollView.bounds.width)
        // スライダー
        photoMarkerSlider = UISlider(
            frame: CGRect(x: 50, y: 0, width: propertyEditorScrollView.bounds.width * 2, height: 50.0),
            primaryAction: UIAction(handler: { action in
                self.photoMarkerSizeSliderChanged(action.sender as! UISlider)
            })
        )
        if let slider = photoMarkerSlider {
            slider.widthAnchor.constraint(equalToConstant: propertyEditorScrollView.bounds.width * 2).isActive = true
            slider.backgroundColor = UIColor.gray.withAlphaComponent(0.3)
            // スライダーの最小値を設定
            slider.minimumValue = 10.0
            // スライダーの最大値を設定
            slider.maximumValue = 100.0
            // 線の太さ
            slider.value = Float(selectedLineWidth)
            buttons.append(slider)
        }
        
        // ボタン
        let bigButton = UIButton(
            primaryAction: UIAction(handler: { action in
                self.bigButtonTapped(action.sender)
            })
        )
        bigButton.heightAnchor.constraint(equalToConstant: 50.0).isActive = true
        bigButton.widthAnchor.constraint(equalToConstant: 50.0).isActive = true
        let imageForward = UIImage(systemName: "arrowtriangle.forward")?.withRenderingMode(.alwaysTemplate) ?? UIImage()
        bigButton.setImage(imageForward, for: UIControl.State.normal)
        bigButton.backgroundColor = UIColor.systemPink.withAlphaComponent(0.3)
        buttons.append(bigButton)
        
        // UILabelの設定
        photoMarkerFontSizeLabel.textAlignment = NSTextAlignment.right // 横揃えの設定
        photoMarkerFontSizeLabel.text = "px" // テキストの設定
        photoMarkerFontSizeLabel.textColor = UIColor.black // テキストカラーの設定
        photoMarkerFontSizeLabel.backgroundColor = UIColor.gray.withAlphaComponent(0.3)
        // 初期値
        selectedPhotoMarkerSize = 15.0
        buttons.append(photoMarkerFontSizeLabel)
        
        // 線の太さ
        photoMarkerSliderStackView = UIStackView(arrangedSubviews: buttons)
        photoMarkerSliderStackView?.backgroundColor = UIColor.green.withAlphaComponent(0.3)
        //        sliderStackView?.frame = photoMarkerSliderView.bounds
        
        if let stackView = photoMarkerSliderStackView {
            stackView.axis = .horizontal
            stackView.distribution = .equalSpacing
            stackView.alignment = .center
            stackView.spacing = 0
            photoMarkerSliderView.addSubview(stackView)
            photoMarkerSliderView.heightAnchor.constraint(equalToConstant: label.bounds.height + 100).isActive = true
            
            stackView.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                stackView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 0),
                stackView.bottomAnchor.constraint(equalTo: photoMarkerSliderView.bottomAnchor, constant: 0),
                stackView.centerXAnchor.constraint(equalTo: photoMarkerSliderView.centerXAnchor),
                stackView.widthAnchor.constraint(equalTo: photoMarkerSliderView.widthAnchor),
                stackView.heightAnchor.constraint(equalToConstant: 70)
            ])
            // stackViewにnewViewを追加する
            propertyEditorStackView.addArrangedSubview(photoMarkerSliderView)
            // これだとダメ
            //stackView.addSubview(newView)
        }
    }

    // 手書き プロパティ変更パネル 閉じる
    func createPropertyEditorCloseButton() {
        
        let button = UIButton(
            primaryAction: UIAction(handler: { action in
                self.cloSepropertyEditor(sender: action.sender)
            })
        )
        button.heightAnchor.constraint(equalToConstant: 50.0).isActive = true
        button.widthAnchor.constraint(equalToConstant: 200).isActive = true
        button.setTitle("閉じる", for: .normal)
        button.setTitleColor(.yellow, for: .normal)
        button.setTitleColor(.systemPink, for: .selected)

        button.backgroundColor = .blue
        // アイコン画像の色を指定する
        button.tintColor = .black
        
        propertyEditorCloseButtonView.addSubview(button)
        propertyEditorCloseButtonView.heightAnchor.constraint(equalToConstant: 100).isActive = true

        button.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: propertyEditorCloseButtonView.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: propertyEditorCloseButtonView.centerYAnchor),
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: propertyEditorCloseButtonView.bounds.width),
            button.heightAnchor.constraint(equalToConstant: 70)
        ])
        // stackViewにnewViewを追加する
        propertyEditorStackView.addArrangedSubview(propertyEditorCloseButtonView)
        // これだとダメ
        //stackView.addSubview(newView)
    }
    
    //helper function for creating the tools
    private func createButton(title: String, action: UIAction) -> UIButton {
        let button = UIButton(type: .system, primaryAction: action)
        button.frame = CGRect(x: 0, y: 0, width: 150, height: 50)
        button.setTitle(title, for: .normal)
        button.tintColor = .lightGray
        button.makeRounded(10, borderWidth: 2, borderColor: .black)
        return button
    }
    
    // カラーパレット
    private func updatePens(sender: Any?) {
        if let button = sender as? UIButton,
           let color = Colors(rawValue: button.tag) {
            // 選択されたカラー
            selectedColor = color.getColor()
            // 手書きパレット 透明度
            colorAlphaStackView?.arrangedSubviews.map {
                if let alpha = Alpha(rawValue: $0.tag) {
                    print(alpha)
                    $0.backgroundColor = selectedColor.withAlphaComponent(alpha.alpha)
                }
            }
            pdfDrawer.changeColor(color: selectedColor.withAlphaComponent(selectedAlpha.alpha))
            // マーカーを更新する 長押しメニュー　編集
            updateMarkerColorAnotation()
        }
    }
    
    // カラーパレット ダーク
    private func updateDarkPens(sender: Any?) {
        if let button = sender as? UIButton,
           let color = ColorsDark(rawValue: button.tag) {
            // 選択されたカラー
            selectedColor = color.getColor()
            // 手書きパレット 透明度
            colorAlphaStackView?.arrangedSubviews.map {
                if let alpha = Alpha(rawValue: $0.tag) {
                    print(alpha)
                    $0.backgroundColor = selectedColor.withAlphaComponent(alpha.alpha)
                }
            }
            pdfDrawer.changeColor(color: selectedColor.withAlphaComponent(selectedAlpha.alpha))
            // マーカーを更新する 長押しメニュー　編集
            updateMarkerColorAnotation()
        }
    }
    
    // カラーパレット 透明度
    private func updateAlphaPens(sender: Any?) {
        if let button = sender as? UIButton,
           let alpha = Alpha(rawValue: button.tag) {
            // 選択された透明度
            selectedAlpha = alpha
            pdfDrawer.changeColor(color: selectedColor.withAlphaComponent(selectedAlpha.alpha))
            // マーカーを更新する 長押しメニュー　編集
            updateMarkerColorAnotation()
        }
    }

    // カラーパレット 破線のパターン
    private func updateDashPattern(sender: Any?) {
        if let button = sender as? UIButton,
           let pattern = DashPattern(rawValue: button.tag) {
            // 線のスタイル
            dashPattern = pattern
            pdfDrawer.changeDashPattern(dashPattern: dashPattern)
        }
    }
    
    // 損傷マーカー
    private func updateDamagePattern(sender: Any?) {
        if let button = sender as? UIButton,
           let pattern = DamagePattern(rawValue: button.tag) {
            // 線のスタイル
            selectedDamage = pattern
        }
    }
    
    // 線の太さ
    private func sliderChanged(_ sender: UISlider) {
        selectedLineWidth = CGFloat(sender.value)
        pdfDrawer.changeLineWidth(lineWidth: selectedLineWidth)
    }
    
    private func thinButtonTapped(_ sender: Any) {
        if let slider = slider {
            slider.value -= 1.0
            selectedLineWidth = CGFloat(slider.value)
            pdfDrawer.changeLineWidth(lineWidth: selectedLineWidth)
        }
    }
    
    private func thickButtonTapped(_ sender: Any) {
        if let slider = slider {
            slider.value += 1.0
            selectedLineWidth = CGFloat(slider.value)
            pdfDrawer.changeLineWidth(lineWidth: selectedLineWidth)
        }
    }
    
    // 写真マーカーサイズ
    private func photoMarkerSizeSliderChanged(_ sender: UISlider) {
        selectedPhotoMarkerSize = CGFloat(sender.value)
        
        if drawingMode == .photoMarker { // 写真マーカー
            // 写真マーカーを更新する
            updatePhotoMarkerAnotation()
        } else if drawingMode == .move {
            // マーカーを更新する 長押しメニュー　編集
            updateMarkerColorAnotation()
        }
    }
    
    private func smallButtonTapped(_ sender: Any) {
        if let slider = photoMarkerSlider {
            slider.value -= 1.0
            selectedPhotoMarkerSize = CGFloat(slider.value)
            if drawingMode == .photoMarker { // 写真マーカー
                // 写真マーカーを更新する
                updatePhotoMarkerAnotation()
            } else if drawingMode == .move {
                // マーカーを更新する 長押しメニュー　編集
                updateMarkerColorAnotation()
            }
        }
    }
    
    private func bigButtonTapped(_ sender: Any) {
        if let slider = photoMarkerSlider {
            slider.value += 1.0
            selectedPhotoMarkerSize = CGFloat(slider.value)
            if drawingMode == .photoMarker { // 写真マーカー
                // 写真マーカーを更新する
                updatePhotoMarkerAnotation()
            } else if drawingMode == .move {
                // マーカーを更新する 長押しメニュー　編集
                updateMarkerColorAnotation()
            }
        }
    }

    // 手書き プロパティ変更パネル 閉じる
    private func cloSepropertyEditor(sender: Any?) {
        if let button = sender as? UIButton {
            propertyEditorScrollView?.isHidden = true
                        
            // 編集を終了する
            // 初期化
            self.beforeImageAnnotation = nil
            self.beforeDrawingAnnotation = nil
            self.before = nil
            
            self.currentlySelectedImageAnnotation = nil
            self.currentlySelectedDrawingAnnotation = nil
            self.currentlySelectedAnnotation = nil
        }
    }
    
    // 手書きを追加する
    func addDrawingAnotation(path: UIBezierPath) {
        // 現在開いているページを取得
        if let page = self.pdfView.currentPage {
            
            let marker = Marker(imageId: "",
                                data: Marker.MarkerInfo(id: UUID().uuidString,
                                                        annotationType: .drawingAnnotation,
                                                        size: selectedPhotoMarkerSize,
                                                        x: path.bounds.origin.x,
                                                        y: path.bounds.origin.y,
                                                        color: ColorRGBA(color: selectedColor.withAlphaComponent(selectedAlpha.alpha)),
                                                        pageLabel: page.label,
                                                        text: "",
                                                        points: convert(path: path.cgPath),
                                                        lineWidth: path.lineWidth,
                                                        dashPattern: dashPattern
                                                        )
            )
            // DrawingAnnotation 作成
            if let annotation = self.createDrawingAnnotation(marker: marker) {
                // 対象のページへ注釈を追加
                page.addAnnotation(annotation)
                
                // JSONファイル　状態管理
                project?.markers?.append(marker)
                
                // Undo Redo
                undoRedoManager.addAnnotation(marker)
                undoRedoManager.showTeamMembers(completion: { didUndoAnnotations in
                    // Undo Redo が可能なAnnotation　を削除して、更新後のAnnotationを表示させる
                    reloadPDFAnnotations(didUndoAnnotations: didUndoAnnotations)
                })
                // ボタン　活性状態
                undoButton.isEnabled = undoRedoManager.canUndo()
                redoButton.isEnabled = undoRedoManager.canRedo()
            }
        }
    }
    
    func convert(path: CGPath) -> [PathElement] {
        var elements = [PathElement]()
        
        path.applyWithBlock() { elem in
            let elementType = elem.pointee.type
            let n = numPoints(forType: elementType)
            var points: Array<CGPoint>?
            if n > 0 {
                points = Array(UnsafeBufferPointer(start: elem.pointee.points, count: n))
            }
            elements.append(PathElement(type: Int(elementType.rawValue), points: points))
        }
        return elements
    }

    func convert(elements: [PathElement]) -> CGPath {
        let path = CGMutablePath()
        
        for elem in elements {
            switch elem.type {
            case 0:
                path.move(to: elem.points![0])
            case 1:
                path.addLine(to: elem.points![0])
            case 2:
                path.addQuadCurve(to: elem.points![1], control: elem.points![0])
            case 3:
                path.addCurve(to: elem.points![2], control1: elem.points![0], control2: elem.points![1])
            case 4:
                path.closeSubpath()
            default:
                break
            }
        }
        return path
    }

    func numPoints(forType type: CGPathElementType) -> Int {
        var n = 0
        
        switch type {
        case .moveToPoint:
            n = 1
        case .addLineToPoint:
            n = 1
        case .addQuadCurveToPoint:
            n = 2
        case .addCurveToPoint:
            n = 3
        case .closeSubpath:
            n = 0
        default:
            n = 0
        }
        return n
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
    // 変更前
    var beforeImageAnnotation: ImageAnnotation?
    // 変更前
    var beforeDrawingAnnotation: DrawingAnnotation?

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
            border.lineWidth = selectedLineWidth
            border.style = dashPattern == .pattern1 ? .solid : .dashed
            border.dashPattern = dashPattern == .pattern1 ? nil : dashPattern.style(width: selectedLineWidth)

            // Create dictionary of annotation properties
            let lineAttributes: [PDFAnnotationKey: Any] = [
                .linePoints: [beganLocation.x, beganLocation.y, endLocation.x, endLocation.y],
                .lineEndingStyles: [PDFAnnotationLineEndingStyle.none,
                                    PDFAnnotationLineEndingStyle.none],
                .color: selectedColor.withAlphaComponent(selectedAlpha.alpha),
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
//            undoRedoManager.addAnnotation(lineAnnotation)
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
            border.lineWidth = selectedLineWidth
            border.style = dashPattern == .pattern1 ? .solid : .dashed
            border.dashPattern = dashPattern == .pattern1 ? nil : dashPattern.style(width: selectedLineWidth)

            // Create dictionary of annotation properties
            let lineAttributes: [PDFAnnotationKey: Any] = [
                .linePoints: [beganLocation.x, beganLocation.y, endLocation.x, endLocation.y],
                .lineEndingStyles: [PDFAnnotationLineEndingStyle.none,
                                    PDFAnnotationLineEndingStyle.closedArrow],
                .color: selectedColor.withAlphaComponent(selectedAlpha.alpha),
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
//            undoRedoManager.addAnnotation(lineAnnotation)
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
            border.lineWidth = selectedLineWidth
            border.style = dashPattern == .pattern1 ? .solid : .dashed
            border.dashPattern = dashPattern == .pattern1 ? nil : dashPattern.style(width: selectedLineWidth)

            // Create dictionary of annotation properties
            let lineAttributes: [PDFAnnotationKey: Any] = [
                .color: selectedColor.withAlphaComponent(selectedAlpha.alpha),
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
//            undoRedoManager.addAnnotation(newAnnotation)
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
            border.lineWidth = selectedLineWidth
            border.style = dashPattern == .pattern1 ? .solid : .dashed
            border.dashPattern = dashPattern == .pattern1 ? nil : dashPattern.style(width: selectedLineWidth)

            // Create dictionary of annotation properties
            let lineAttributes: [PDFAnnotationKey: Any] = [
                .color: selectedColor.withAlphaComponent(selectedAlpha.alpha),
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
//            undoRedoManager.addAnnotation(newAnnotation)
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
                bounds: CGRect(x: point.x, y: point.y, width: size.width * 1.1, height: size.height),
                forType: .freeText,
                withProperties: attributes
            )
            // 左寄せ
            freeText.alignment = .left
            // フォントサイズ
            freeText.font = font
            freeText.fontColor = selectedColor.withAlphaComponent(selectedAlpha.alpha)
            // UUID
            freeText.userName = UUID().uuidString
            // 対象のページへ注釈を追加
            page.addAnnotation(freeText)
            
            // Undo Redo
//            undoRedoManager.addAnnotation(freeText)
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
                    x: before.bounds.origin.x,
                    y: before.bounds.origin.y,
                    width: size.width * 1.1,
                    height: size.height
                )
                after.contents = inputText
                after.setValue(UIColor.yellow.withAlphaComponent(0.5), forAnnotationKey: .color)
                // 左寄せ
                after.alignment = .left
                // フォントサイズ
                after.font = font
                after.fontColor = before.fontColor
                // UUID
                after.userName = UUID().uuidString
                // Annotationを再度作成
                page.addAnnotation(after)
                if let annotationPage = before.page {
                    // 古いものを削除する
                    page.removeAnnotation(before)
                    // iOS17対応　PDFAnnotationのpageが消えてしまう現象
                    before.page = annotationPage
                }
                // 初期化
                self.before = nil
                // Undo Redo 更新
//                undoRedoManager.updateAnnotation(before: before, after: after)
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
    
    // MARK: - 損傷マーカー
    
    // マーカーを追加する 損傷マーカー
    func addDamageMarkerAnotation() {
        // 現在開いているページを取得
        if let page = self.pdfView.currentPage,
           let point = point {
            // 画像
            let image = selectedDamage.getIcon()
            // オリジナル画像のサイズからアスペクト比を計算
            let aspectScale = image.size.height / image.size.width
            // widthからアスペクト比を元にリサイズ後のサイズを取得
            let resizedSize = CGSize(width: selectedPhotoMarkerSize, height: selectedPhotoMarkerSize * Double(aspectScale))
            // 中央部に座標を指定
            let imageStamp = ImageAnnotation(with: image, forBounds: CGRect(x: point.x - (resizedSize.width / 2), y: point.y - (resizedSize.height / 2), width: resizedSize.width, height: resizedSize.height), withProperties: [:])
            // UUID
            imageStamp.userName = UUID().uuidString
            // ページ
            imageStamp.page = page
            // 対象のページへ注釈を追加
            page.addAnnotation(imageStamp)
            // Undo Redo
//            undoRedoManager.addAnnotation(imageStamp)
            undoRedoManager.showTeamMembers(completion: { didUndoAnnotations in
                // Undo Redo が可能なAnnotation　を削除して、更新後のAnnotationを表示させる
                self.reloadPDFAnnotations(didUndoAnnotations: didUndoAnnotations)
            })
            // ボタン　活性状態
            undoButton.isEnabled = undoRedoManager.canUndo()
            redoButton.isEnabled = undoRedoManager.canRedo()
        }
    }
    
    // MARK: - Undo Redo
    
    var undoButton: UIBarButtonItem!
    var redoButton: UIBarButtonItem!
    // Undo Redo
    let undoRedoManager = UndoRedoManager()
    // Undo Redo が可能なAnnotation
    private var editingAnnotations: [Any]?
    
    // Undo Redo が可能なAnnotation　を削除して、更新後のAnnotationを表示させる
    func reloadPDFAnnotations(didUndoAnnotations: [Marker]?) {
        print(#function)
        
        project?.markers = didUndoAnnotations
        // PDF 全てのpageに存在するAnnotationを削除する
        deleteAllAnnotations()
        // PDF 全てのpageに存在するAnnotationをJSONファイルから生成する
        createAllAnnotations()
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
        // JSONファイル　状態管理
        JsonFileManager.shared.saveProjectToJson(project: project)
        
        if let fileURL = pdfView.document?.documentURL,
            // PDFファイルへ上書き保存する
            let isFinished = pdfView.document?.write(to: fileURL) {
             
                completion()
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

// 手書きのアノテーションを追加する処理
extension DrawingReportEditViewController: DrawingManageAnnotationDelegate {
    func addAnnotation(_ path: UIBezierPath) {
        
        addDrawingAnotation(path: path)
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
                    present(viewController, animated: true, completion: {
                        viewController.fontSize = 15.0
                    })
                }
            }
        } else if drawingMode == .damageMarker {
            // 現在開いているページを取得
            if let page = self.pdfView.currentPage {
                // UIViewからPDFの座標へ変換する
                let point = self.pdfView.convert(sender.location(in: self.pdfView), to: page) // 座標系がUIViewとは異なるので気をつけましょう。
                // PDFのタップされた位置の座標
                self.point = point
                // マーカーを追加する 損傷マーカー
                addDamageMarkerAnotation()
            }
        }
    }
    
    @objc
    func longPress(_ sender: UILongPressGestureRecognizer) {
        // 現在開いているページを取得
        if let page = self.pdfView.currentPage {
            // UIViewからPDFの座標へ変換する
            let locationOnPage = pdfView.convert(sender.location(in: pdfView), to: page)
            
            switch sender.state {
            case .began:
                guard let annotation = page.annotation(at: locationOnPage) else { return }
                // 変更前
                if let copy = annotation.copy() as? PhotoAnnotation {
                    currentlySelectedAnnotation = annotation
                    before = copy
                    copy.bounds = annotation.bounds
                    copy.page = annotation.page
                    // 長押しメニュー
                    showLongPressDialog(sender.location(in: pdfView), drawingMode: .photoMarker)
                }
                else if let copy = annotation.copy() as? ImageAnnotation {
                    currentlySelectedImageAnnotation = annotation as? ImageAnnotation
                    beforeImageAnnotation = copy
                    copy.bounds = annotation.bounds
                    copy.page = annotation.page
                    copy.image = currentlySelectedImageAnnotation?.image
                    // 長押しメニュー
                    showLongPressDialog(sender.location(in: pdfView), drawingMode: .damageMarker)
                }
                else if let copy = annotation.copy() as? DrawingAnnotation {
                    currentlySelectedDrawingAnnotation = annotation as? DrawingAnnotation
                    beforeDrawingAnnotation = copy
                    copy.bounds = annotation.bounds
                    copy.page = annotation.page
                    copy.path = currentlySelectedDrawingAnnotation!.path
                    copy.path = copy.path.fit(into: copy.bounds)
                    // 長押しメニュー
                    showLongPressDialog(sender.location(in: pdfView), drawingMode: .drawing)
                }
                else if let copy = annotation.copy() as? PDFAnnotation {
                    if PDFAnnotationSubtype(rawValue: "/\(annotation.type!)") == PDFAnnotationSubtype.freeText.self {
                        // 編集中のAnnotation
                        isEditingAnnotation = annotation
                        before = copy
                        copy.bounds = annotation.bounds
                        copy.page = annotation.page
                        // 長押しメニュー
                        showLongPressDialog(sender.location(in: pdfView), drawingMode: .text)
                    } else {
                        currentlySelectedAnnotation = annotation
                        before = copy
                        copy.bounds = annotation.bounds
                        copy.page = annotation.page
                        // 長押しメニュー
                        showLongPressDialog(sender.location(in: pdfView), drawingMode: .move)
                    }
                }
            case .changed:
                break
            case .ended, .cancelled, .failed:
                break
            default:
                break
            }
        }
    }
    
    // 長押しメニュー
    func showLongPressDialog(_ origin: CGPoint, drawingMode: DrawingMode) {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "確認",
                message: "選択されたアイテムの状態を変更しますか？",
                preferredStyle: .actionSheet
            )
            
            let colorAction = UIAlertAction(
                title: "編集",
                style: .default
            ) { _ in
                self.propertyEditorScrollView?.isHidden = false
                self.propertyEditorCloseButtonView.isHidden = false
                
                if drawingMode == .damageMarker {
                    // 編集　損傷マーカー
                    self.colorPaletteView.isHidden = true
                    self.alphaPaletteView.isHidden = true
                } else {
                    self.colorPaletteView.isHidden = false
                    self.alphaPaletteView.isHidden = false
                }
                
                if drawingMode == .damageMarker {
                    // 編集　損傷マーカー
                    self.photoMarkerSliderView.isHidden = false
                } else {
                    self.photoMarkerSliderView.isHidden = true
                }
                alert.dismiss(animated: true)
            }
            alert.addAction(colorAction)

            if drawingMode == .text {
                let textAction = UIAlertAction(
                    title: "文字列の変更",
                    style: .default
                ) { _ in
                    alert.dismiss(animated: true) {
                        if drawingMode == .text {
                            if let isEditingAnnotation = self.isEditingAnnotation {
                                // ポップアップを表示させる
                                if let viewController = UIStoryboard(
                                    name: "TextInputViewController",
                                    bundle: nil
                                ).instantiateViewController(
                                    withIdentifier: "TextInputViewController"
                                ) as? TextInputViewController {
                                    viewController.modalPresentationStyle = .overCurrentContext
                                    viewController.modalTransitionStyle = .crossDissolve
                                    viewController.annotationIsEditing = true
                                    viewController.text = isEditingAnnotation.contents
                                    self.present(viewController, animated: true, completion: {
                                        print(isEditingAnnotation.font)
                                        print(isEditingAnnotation.font?.pointSize)
                                        if let pointSize = isEditingAnnotation.font?.pointSize {
                                            viewController.fontSize = pointSize
                                            // フォントサイズ
                                            viewController.slider.value = Float(pointSize)
                                        }
                                    })
                                }
                            }
                        }
                    }
                }
                alert.addAction(textAction)
            }

            let closeAction = UIAlertAction(
                title: "閉じる",
                style: .default
            ) { _ in
                // 編集を終了する
                // 初期化
                self.beforeImageAnnotation = nil
                self.beforeDrawingAnnotation = nil
                self.before = nil
                
                self.currentlySelectedImageAnnotation = nil
                self.currentlySelectedDrawingAnnotation = nil
                self.currentlySelectedAnnotation = nil
                self.isEditingAnnotation = nil
                
                alert.dismiss(animated: true)
            }
            alert.addAction(closeAction)
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                alert.popoverPresentationController?.sourceView = self.pdfView
                alert.popoverPresentationController?.sourceRect = CGRect(
                    x: origin.x,
                    y: origin.y,
                    width: 0,
                    height: 0
                )

                // iPadの場合、アクションシートの背後の画面をタップできる
            } else {
                // ③表示するViewと表示位置を指定する
                alert.popoverPresentationController?.sourceView = self.pdfView
                alert.popoverPresentationController?.sourceRect = self.view.frame
            }
            self.present(alert, animated: true)
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
                    // 変更前
                    if let copy = annotation.copy() as? PhotoAnnotation {
                        currentlySelectedAnnotation = annotation
                        before = copy
                        copy.bounds = annotation.bounds
                        copy.page = annotation.page
                    }
                    else if let copy = annotation.copy() as? ImageAnnotation {
                        currentlySelectedImageAnnotation = annotation as? ImageAnnotation
                        beforeImageAnnotation = copy
                        copy.bounds = annotation.bounds
                        copy.page = annotation.page
                        copy.image = currentlySelectedImageAnnotation?.image
                    }
                    else if let copy = annotation.copy() as? DrawingAnnotation {
                        currentlySelectedDrawingAnnotation = annotation as? DrawingAnnotation
                        beforeDrawingAnnotation = copy
                        copy.bounds = annotation.bounds
                        copy.page = annotation.page
                        copy.path = currentlySelectedDrawingAnnotation!.path
                        copy.path = copy.path.fit(into: copy.bounds)
                    }
                    else if let copy = annotation.copy() as? PDFAnnotation {
                        currentlySelectedAnnotation = annotation
                        before = copy
                        copy.bounds = annotation.bounds
                        copy.page = annotation.page
                    }
                case .changed:
                    if let annotation = currentlySelectedImageAnnotation {
                        let initialBounds = annotation.bounds
                        // Set the center of the annotation to the spot of our finger
                        annotation.bounds = CGRect(x: locationOnPage.x - (initialBounds.width / 2), y: locationOnPage.y - (initialBounds.height / 2), width: initialBounds.width, height: initialBounds.height)
                    }
                    if let annotation = currentlySelectedDrawingAnnotation {
                        let initialBounds = annotation.bounds
                        // Set the center of the annotation to the spot of our finger
                        annotation.bounds = CGRect(x: locationOnPage.x - (initialBounds.width / 2), y: locationOnPage.y - (initialBounds.height / 2), width: initialBounds.width, height: initialBounds.height)
                        annotation.path = annotation.path.fit(into: annotation.bounds).moveCenter(to: locationOnPage)
                    }
                    if let annotation = currentlySelectedAnnotation {
                        let initialBounds = annotation.bounds
                        // Set the center of the annotation to the spot of our finger
                        annotation.bounds = CGRect(x: locationOnPage.x - (initialBounds.width / 2), y: locationOnPage.y - (initialBounds.height / 2), width: initialBounds.width, height: initialBounds.height)
                    }
                case .ended, .cancelled, .failed:
                    // マーカーを更新する 移動
                    updateMarkerAnotation()
                    
                    currentlySelectedImageAnnotation = nil
                    currentlySelectedDrawingAnnotation = nil
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
    
    func getColor() -> UIColor {
        switch self {
        case .black:
            return UIColor.darkGray.dark(brightnessRatio: 1.0)
        case .systemRed:
            return UIColor.systemRed.dark(brightnessRatio: 1.0)
        case .systemYellow:
            return UIColor.systemYellow.dark(brightnessRatio: 1.0)
        case .systemGreen:
            return UIColor.systemGreen.dark(brightnessRatio: 1.0)
        case .systemBlue:
            return UIColor.systemBlue.dark(brightnessRatio: 1.0)
        case .blue:
            return UIColor.blue.dark(brightnessRatio: 1.0)
        case .systemPink:
            return UIColor.systemPink.dark(brightnessRatio: 1.0)
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

// 破線のパターン
enum DashPattern: Int, CaseIterable, Codable {
    case pattern1
    case pattern2
    case pattern3
    case pattern4
    case pattern5
    
    func style(width: CGFloat) -> [CGFloat] {
        switch self {
        case .pattern1:
            return [width * 1.0]
        case .pattern2:
            return [width * 2.0, width * 2.0]
        case .pattern3:
            return [width * 4.0, width * 4.0]
        case .pattern4:
            return [width * 6.0, width * 1.5, width * 1.0, width * 1.5]
        case .pattern5:
            return [width * 6.0, width * 1.5, width * 1.0, width * 1.5, width * 1.0, width * 1.5]
        }
    }
    
    func getIcon() -> UIImage {
        switch self {
        case .pattern1:
            return UIImage(systemName: "line.diagonal")?.withRenderingMode(.alwaysTemplate) ?? UIImage()
        case .pattern2:
            return UIImage(systemName: "line.diagonal")?.withRenderingMode(.alwaysTemplate) ?? UIImage()
        case .pattern3:
            return UIImage(systemName: "line.diagonal")?.withRenderingMode(.alwaysTemplate) ?? UIImage()
        case .pattern4:
            return UIImage(systemName: "line.diagonal")?.withRenderingMode(.alwaysTemplate) ?? UIImage()
        case .pattern5:
            return UIImage(systemName: "line.diagonal")?.withRenderingMode(.alwaysTemplate) ?? UIImage()
        }
    }
}

enum DamagePattern: Int, CaseIterable, Codable {
    case uki
    case sonota
    case hibiware
    case tekkinrosyutu
    case hakuri
    case yuurihakuseki
    case rousui
    
    func getIcon() -> UIImage {
        switch self {
        case .uki:
            return UIImage(named: "うき")?.withRenderingMode(.alwaysTemplate) ?? UIImage()
        case .sonota:
            return UIImage(named: "その他")?.withRenderingMode(.alwaysTemplate) ?? UIImage()
        case .hibiware:
            return UIImage(named: "ひび割れ")?.withRenderingMode(.alwaysTemplate) ?? UIImage()
        case .tekkinrosyutu:
            return UIImage(named: "鉄筋露出")?.withRenderingMode(.alwaysTemplate) ?? UIImage()
        case .hakuri:
            return UIImage(named: "剥離")?.withRenderingMode(.alwaysTemplate) ?? UIImage()
        case .yuurihakuseki:
            return UIImage(named: "遊離石灰")?.withRenderingMode(.alwaysTemplate) ?? UIImage()
        case .rousui:
            return UIImage(named: "漏水")?.withRenderingMode(.alwaysTemplate) ?? UIImage()
        }
    }
}
// アノテーションの種類
enum AnnotationType: Codable {
    case photoAnnotation
    case pdfAnnotation
    case drawingAnnotation
    case imageAnnotation
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
    case damageMarker
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
            self = .damageMarker
        case 11:
            self = .eraser
        default:
            self = .move
        }
    }
}
