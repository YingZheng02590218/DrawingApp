//
//  DrawingViewController.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/10/02.
//

import PDFKit
//import Photos
//import PhotosUI
import UIKit
//import PencilKit

class DrawingViewController: UIViewController {
    
    // MARK: - ライフサイクル
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 編集ボタン Xボタン Annotation表示非表示スイッチ
        setupButtons()
        // Undo Redo ボタン
        setupUndoRedoButtons()
        // セグメントコントロール
        setupSegmentedControl()
        
        // title設定
        navigationItem.title = "マーカーを追加する"
        
        // 編集するPDFページを表示させる
        setupPdfView()
        
        // PDF Annotationがタップされたかを監視
        setupAnnotationRecognizer()
        
        // ページサムネイル一覧
        setupThumbnailView()
        // 手書きパレット
        createButtons()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        // ボタン　活性状態
        undoButton.isEnabled = undoRedoManager.canUndo()
        redoButton.isEnabled = undoRedoManager.canRedo()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 写真のアクセス権限
        // albumAction()
        
        DispatchQueue.main.async {
            // 図面調書一覧画面で選択したページへジャンプする
            if let pageNumber = self.pageNumber, // ページ番号
               let page = self.pdfView.document?.page(at: pageNumber) {
                self.pdfView.go(to: page)
            }
        }
    }
    
    // MARK: - 編集するPDFページ
    
    @IBOutlet weak var pdfView: NonSelectablePDFView!
    // iCloud Container に保存しているPDFファイルのパス
    var fileURL: URL?
    //    // ローカル Container に保存している編集中のPDFファイルのパス
    //    var tempFilePath: URL?
    // ページ番号
    var pageNumber: Int?
    
    // 編集するPDFページを表示させる
    func setupPdfView() {
        // iCloud Container に保存しているPDFファイルのパス
        guard let fileURL = fileURL else { return }
        //        // 一時ファイルを削除する
        //        deleteTempDirectory()
        //        // PDFファイルを一時ディレクトリにコピーする
        //        if let tempFilePath = saveToTempDirectory(fileURL: fileURL) {
        //            // ローカル Container に保存している編集中のPDFファイルのパス
        //            self.tempFilePath = tempFilePath
        //        }
        //
        //        guard let tempFilePath = tempFilePath else { return }
        //        guard let document = PDFDocument(url: tempFilePath) else { return }
        guard let document = PDFDocument(url: fileURL) else { return }
        pdfView.document = document
        // 単一ページのみ
        pdfView.displayMode = .singlePage
        // 現在開いているページ currentPage にのみマーカーを追加
        pdfView.autoScales = true
    }
    
    // MARK: - ページサムネイル一覧
    
    @IBOutlet weak var pdfThumbnailView: PDFThumbnailView!
    
    // ページサムネイル一覧
    func setupThumbnailView() {
        pdfThumbnailView.pdfView = pdfView
        pdfThumbnailView.layoutMode = .vertical
        pdfThumbnailView.backgroundColor = UIColor.gray
        pdfThumbnailView.thumbnailSize = CGSize(width: 40, height: 60)
    }
    
    // MARK: - 編集ボタン Xボタン Annotation表示非表示スイッチ
    
    // 編集ボタン Xボタン Annotation表示非表示スイッチ
    func setupButtons() {
        // setEditingメソッドを使用するため、Storyboard上の編集ボタンを上書きしてボタンを生成する
        editButtonItem.tintColor = .black
        navigationItem.rightBarButtonItem = editButtonItem
        
        // Xボタン　戻るボタン
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeScreen))
        
        // Annotation表示非表示スイッチ 切り替え
        let switchButton = UISwitch(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        switchButton.onTintColor = .green
        switchButton.isOn = true
        switchButton.addTarget(self, action: #selector(switchTriggered), for: .valueChanged)
        let switchBarButtonItem = UIBarButtonItem(customView: switchButton)
        navigationItem.rightBarButtonItems?.append(switchBarButtonItem)
    }
    
    // MARK: - 戻るボタン
    
    // Xボタン　戻るボタン
    @objc
    func closeScreen() {
        // 戻るボタンの動作処理
        // マーカーを追加しPDFを上書き保存する
        save(completion: {
            self.dismiss(animated: true)
        })
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
        //        segment.setTitleTextAttributes([NSAttributedString.Key.font : UIFont(name: "ProximaNova-Light", size: 15)!], for: .normal)
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
        print(drawingMode)
        // スワイプジェスチャーを禁止
        if drawingMode == .viewingMode {
            NotificationCenter.default.post(name: SegmentedControlPageViewController.needToChangeSwipeEnabledNotification, object: true)
        } else {
            NotificationCenter.default.post(name: SegmentedControlPageViewController.needToChangeSwipeEnabledNotification, object: false)
        }
        
        // 拡大縮小を禁止してマーカーの起点と終点を選択しやすくする
        if drawingMode == .move || drawingMode == .drawing || drawingMode == .line || drawingMode == .arrow || drawingMode == .rectangle || drawingMode == .circle {
            print(pdfView.maxScaleFactor) // 5.0
            print(pdfView.minScaleFactor) // 0.25
            print(pdfView.contentScaleFactor) // 1.0
            print(pdfView.scaleFactorForSizeToFit) // 1.2486631016042782
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
            
            //            canvas.isHidden = false
            pdfDrawer.isActive = true
        } else {
            pdfView.removeGestureRecognizer(pdfDrawingGestureRecognizer)
            // 手書きのアノテーションを追加する処理
            pdfDrawer.drawingManageAnnotationDelegate = nil
            
            //            canvas.isHidden = true
            pdfDrawer.isActive = false
        }
        
        if drawingMode == .photoMarker || drawingMode == .drawing || drawingMode == .line || drawingMode == .arrow || drawingMode == .rectangle || drawingMode == .circle || drawingMode == .text {
            propertyEditorScrollView?.isHidden = false
            propertyEditorCloseButtonView.isHidden = false
            if drawingMode == .photoMarker || drawingMode == .drawing || drawingMode == .line || drawingMode == .arrow || drawingMode == .rectangle || drawingMode == .circle || drawingMode == .text {
                colorPaletteView.isHidden = false
                alphaPaletteView.isHidden = false
                if drawingMode == .drawing || drawingMode == .line || drawingMode == .arrow || drawingMode == .rectangle || drawingMode == .circle {
                    colorLineStyleView.isHidden = false
                    sliderView.isHidden = false
                } else {
                    colorLineStyleView.isHidden = true
                    sliderView.isHidden = true
                }
                if drawingMode == .photoMarker {
                    photoMarkerSliderView.isHidden = false
                } else {
                    photoMarkerSliderView.isHidden = true
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
            sliderView.isHidden = true
            photoMarkerSliderView.isHidden = true
        }
    }
    
    // 編集モード切り替え
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        // 編集中
        if isEditing {
            // title設定
            navigationItem.title = "マーカーを削除する"
        } else {
            // title設定
            navigationItem.title = "マーカーを追加する"
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
            print(PDFAnnotationSubtype(rawValue: annotation.type!).rawValue)
            print(PDFAnnotationSubtype.stamp.rawValue.self)
            print(annotation.contents)
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
            // Undo Redo 削除
//            undoRedoManager.deleteAnnotation(annotation)
            undoRedoManager.showTeamMembers(completion: { didUndoAnnotations in
                // Undo Redo が可能なAnnotation　を削除して、更新後のAnnotationを表示させる
                self.reloadPDFAnnotations(didUndoAnnotations: didUndoAnnotations)
            })
            // ボタン　活性状態
            undoButton.isEnabled = undoRedoManager.canUndo()
            redoButton.isEnabled = undoRedoManager.canRedo()
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
        // ダイアログ
        // showDialogForSucceed(message: "/\(annotation.type!) \n\(annotation.bounds)", color: annotation.color, frame: annotation.bounds) // Type: '/Square', Bounds: (214, 530) [78, 59]
        // タップされたPDFAnnotationに対する処理
        // 編集中
        if isEditing {
            if drawingMode == .photoMarker { // 写真マーカー
                // Annotationを削除する
                removeAnotation(annotation: annotation)
                // iCloud Container に保存した写真を削除する
                // removePhotoToProjectFolder(contents: annotation.contents)
            } else if drawingMode == .text {
                // 編集中のAnnotation
                isEditingAnnotation = annotation
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
                    viewController.text = annotation.contents
                    present(viewController, animated: true, completion: {
                        print(annotation.font)
                        print(annotation.font?.pointSize)
                        if let pointSize = annotation.font?.pointSize {
                            viewController.fontSize = pointSize
                        }
                    })
                }
            }
        } else { // 編集中ではない
            if drawingMode == .arrow { // 矢印
                print(annotation)
                // 現在開いているページを取得
                if let page = self.pdfView.currentPage,
                   let linePoints = annotation.annotationKeyValues.filter( {$0.key == PDFAnnotationKey.linePoints as AnyHashable} ).first,
                   let lineEndingStyles = annotation.annotationKeyValues.filter( {$0.key == PDFAnnotationKey.lineEndingStyles as AnyHashable} ).first,
                   let color = annotation.annotationKeyValues.filter( {$0.key == PDFAnnotationKey.color as AnyHashable} ).first {
                    print(lineEndingStyles)
                    print(lineEndingStyles.value)
                    print((lineEndingStyles.value as AnyObject))
                    print((lineEndingStyles.value as AnyObject).object(at: 0))
                    print((lineEndingStyles.value as AnyObject).object(at: 1))
                    // TODO: PDF上の矢印Annotationのプロパティを変更しても、UIに反映されないため、Annotationを再度作成し、古いものを削除する
                    //                    annotation.setValue([(lineEndingStyles.value as AnyObject).object(at: 1),
                    //                                         (lineEndingStyles.value as AnyObject).object(at: 0)], forAnnotationKey: .lineEndingStyles)
                    //                    pdfView.reloadInputViews()
                    //                    pdfView.layoutDocumentView()
                    
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
                    //                    lineAnnotation.userName = annotation.userName
                    
                    // Annotationを再度作成
                    page.addAnnotation(lineAnnotation)
                    if let annotationPage = annotation.page {
                        // 古いものを削除する
                        page.removeAnnotation(annotation)
                        // iOS17対応　PDFAnnotationのpageが消えてしまう現象
                        annotation.page = annotationPage
                    }
                    
                    // Undo Redo 更新
//                    undoRedoManager.updateAnnotation(before: annotation, after: lineAnnotation)
                    undoRedoManager.showTeamMembers(completion: { didUndoAnnotations in
                        // Undo Redo が可能なAnnotation　を削除して、更新後のAnnotationを表示させる
                        self.reloadPDFAnnotations(didUndoAnnotations: didUndoAnnotations)
                    })
                    // ボタン　活性状態
                    undoButton.isEnabled = undoRedoManager.canUndo()
                    redoButton.isEnabled = undoRedoManager.canRedo()
                }
            } else if drawingMode == .select {
                print(annotation)
                // 選択したAnnotationの制御点を修正する
            } else if drawingMode == .eraser {
                // Annotationを削除する
                removeAnotation(annotation: annotation)
            } else {
                // 選択したマーカーの画像を表示させる
                selectedAnnotation = annotation
                //                // マーカーに紐付けされた画像
                //                if let fileURL = fileURL,
                //                   let contents = annotation.contents {
                //                    // 写真を iCloud Container から取得する
                //                    if let photoUrl = BackupManager.shared.getPhotoFromDocumentsDirectory(contents: contents, fileURL: fileURL) {
                //                        // マーカーに紐付けされた画像
                //                        getThumbnailImage(url: photoUrl) { image in
                //                            if let image = image {
                //                                DispatchQueue.main.async {
                //                                    self.imageView.image = image
                //                                    self.imageView.isHidden = false
                //                                }
                //                            }
                //                        }
                //                    }
                //                }
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
                
                if drawingMode == .viewingMode { // ビューモード
                    // 写真マーカー
                    print(annotation.self)
                    print(annotation.type)
                    print(annotation.contents)
                    if PDFAnnotationSubtype(rawValue: "/\(annotation.type!)") == PDFAnnotationSubtype.freeText.self && ((annotation.contents?.isEmpty) != nil)  {
                        // 写真マーカー　ズームイン
                        zoomInAtPhotoMarker(photoMarkerNumber: annotation.contents!)
                    }
                }
            }
        }
    }
    
    //    // ダイアログ　アノテーション
    //    func showDialogForSucceed(message: String, color: UIColor, frame: CGRect) {
    //        let actionSheet = UIAlertController(title: "Annotation", message: message, preferredStyle: .actionSheet)
    //        actionSheet.view.backgroundColor = color
    //        // iPad の場合のみ、ActionSheetを表示するための必要な設定
    //        if UIDevice.current.userInterfaceIdiom == .pad {
    //            actionSheet.popoverPresentationController?.sourceView = pdfView
    //            actionSheet.popoverPresentationController?.sourceRect = frame
    //            //            CGRect(
    //            //                x: frame.origin.x - frame.width,
    //            //                y: frame.origin.y - frame.height,
    //            //                width: 0,
    //            //                height: 0
    //            //            )
    //            // iPadの場合、アクションシートの背後の画面をタップできる
    //        } else {
    //            // ③表示するViewと表示位置を指定する
    //            actionSheet.popoverPresentationController?.sourceView = pdfView
    //            actionSheet.popoverPresentationController?.sourceRect = frame
    //        }
    //
    //        actionSheet.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection.any
    //
    //        self.present(actionSheet, animated: true) { () -> Void in
    //            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
    //                self.dismiss(animated: true, completion: nil)
    //            }
    //        }
    //    }
    
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
            let after = currentlySelectedAnnotation // .copy() as! PDFAnnotation コピーしなくてよい
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
                // 効かない
                // after.setValue(UIColor.orange.withAlphaComponent(0.5), forAnnotationKey: .color)
                after.color = UIColor.orange.withAlphaComponent(0.5)
                after.page = before.page
                
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
                // NOTE: 一度、document?.write(to　を実行して再びPDF編集を開始すると、PhotoAnnotationと判別できなくなる
                // annotations = annotations.filter({ $0.isKind(of: PhotoAnnotation.self) })
                for annotation in annotations {
                    
                    annotationsInAllPages.append(annotation)
                }
            }
        }
        print(annotationsInAllPages.count)
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
            // NOTE: 一度、document?.write(to　を実行して再びPDF編集を開始すると、PhotoAnnotationと判別できなくなる
            // annotations = annotations.filter({ $0.isKind(of: PhotoAnnotation.self) })
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
    
    // マーカーを追加する 写真
    func addMarkerAnotation() {
        // 現在開いているページを取得
        if let page = self.pdfView.currentPage,
           let point = point,
           let unusedNumber = unusedNumber {
            //            // 中央部に座標を指定
            //            let imageStamp = ImageAnnotation(with: image, forBounds: CGRect(x: point.x, y: point.y, width: 15, height: 15), withProperties: [:])
            //            imageStamp.contents = "\(unusedNumber)"
            //            // 対象のページへ注釈を追加
            //            page.addAnnotation(imageStamp)
            
            // freeText
            let font = UIFont.systemFont(ofSize: selectedPhotoMarkerSize)
            let size = "\(unusedNumber)".size(with: font)
            // Create dictionary of annotation properties
            let lineAttributes: [PDFAnnotationKey: Any] = [
                .color: selectedColor.withAlphaComponent(selectedAlpha.alpha),
                .contents: "\(unusedNumber)",
            ]
            
            let freeText = PhotoAnnotation(bounds: CGRect(x: point.x, y: point.y, width: size.width * 1.1 + 5, height: size.height + 5), forType: .freeText, withProperties: lineAttributes)
            // 中央寄せ
            freeText.alignment = .center
            // フォントサイズ
            freeText.font = font
            freeText.fontColor = .white
            // UUID
            freeText.userName = UUID().uuidString
            // ページ
            freeText.page = page
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
    
    // 写真マーカーを更新する
    func updatePhotoMarkerAnotation() {
        // PDF 現在のpageに存在する写真マーカーAnnotationを保持する
        getAnnotationsOnPage() { [self] in
            for annotation in self.annotationsOnPage {
                // 変更前
                before = annotation
                                
                if let before = before,
                let contents = before.contents {
                    // freeText
                    let font = UIFont.systemFont(ofSize: selectedPhotoMarkerSize)
                    let size = contents.size(with: font)
                    // Create dictionary of annotation properties
                    let lineAttributes: [PDFAnnotationKey: Any] = [
                        .color: before.color,
                        .contents: contents,
                    ]
                    // 変更後
                    let after = PhotoAnnotation(bounds: CGRect(x: before.bounds.origin.x, y: before.bounds.origin.y, width: size.width * 1.1 + 5, height: size.height + 5), forType: .freeText, withProperties: lineAttributes)
                    // 中央寄せ
                    after.alignment = .center
                    // フォントサイズ
                    after.font = font
                    after.fontColor = .white
                    // UUID
                    after.userName = UUID().uuidString
                    // ページ
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
                    // Undo Redo 更新
//                    undoRedoManager.updateAnnotation(before: before, after: after)
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
    }
    
    // MARK: - 写真マーカー　詳細
    
    // マーカーに紐付けされた画像
    @IBOutlet var imageView: UIImageView!
    // マーカー画像
    var image: UIImage?
    // 選択されたマーカー
    var selectedAnnotation: PDFAnnotation?
    
    // 写真マーカー　ズームイン
    func zoomInAtPhotoMarker(photoMarkerNumber: String) {
        // 拡大
        pdfView.scaleFactor = 5.0
        // PDF 全てのpageに存在するAnnotationを保持する
        getAllAnnotations() {
            // TODO: マーカーを拡大してセンターに表示させる
            if let annotation = self.annotationsInAllPages.filter({ String($0.contents ?? "") == photoMarkerNumber }).first {
                print("$$$$", annotation.contents)
                
                if let pdfPage = annotation.page {
                    // UIViewからPDFの座標へ変換する
                    let rect = self.pdfView.convert(UIScreen.main.bounds, to: pdfPage) // 座標系がUIViewとは異なるので気をつけましょう。
                    
                    let screenHeight = rect.height
                    let screenWidth = rect.width
                    print(screenHeight)
                    print(screenWidth)
                    print(annotation.bounds.origin.x)
                    print(annotation.bounds.origin.y)
                    
                    let cgRect = CGRect(
                        x: annotation.bounds.origin.x - screenWidth / 2,
                        y: annotation.bounds.origin.y + screenHeight / 2,
                        width: annotation.bounds.width,
                        height: annotation.bounds.height
                    )
                    
                    print(cgRect)
                    self.pdfView.go(to: cgRect, on: pdfPage)
                    // self.pdfView.center.y = annotation.bounds.center.y - 100
                }
            } else {
                self.annotationsInAllPages.map { print("$$$$$$", $0.contents) }
            }
        }
    }
    
    // MARK: - 手書きパレット
    
    private let pdfDrawer = PDFDrawer()
    let pdfDrawingGestureRecognizer = DrawingGestureRecognizer()
    // 手書き　ツール
//    var toolStackView: UIStackView?
    
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
    var selectedColor: UIColor = .black
    // 選択された透明度
    var selectedAlpha: Alpha = .alpha07
    // 選択された線の太さ
    var selectedLineWidth: CGFloat = 15.0 {
        didSet {
            fontSizeLabel.text = "\(Int(selectedLineWidth)) px"
        }
    }
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
        // 図形　写真マーカーサイズ
        createTextSizeSlider()
        // 手書き プロパティ変更パネル 閉じる
        createPropertyEditorCloseButton()
        
//        //Setup tools
//        let crayonButton = createButton(title: "Crayon", action: UIAction(handler: { _ in
//            //            self.canvas.tool = self.crayon
//        }))
//        
//        let pencilButton = createButton(title: "Pencil", action: UIAction(handler: { _ in
//            //            self.canvas.tool = self.pencil
//            self.pdfDrawer.changeTool(tool: .pencil)
//        }))
//        
//        let markerButton = createButton(title: "Marker", action: UIAction(handler: { _ in
//            //            self.canvas.tool = self.marker
//        }))
//        
//        let eraserButton = createButton(title: "Eraser", action: UIAction(handler: { _ in
//            //            self.canvas.tool = self.eraser
//        }))
//        
//        let undoButton = createButton(title: "Undo", action: UIAction(handler: { _ in
//            // TODO: 効いていない
//            self.undoManager?.undo()
//        }))
//        
//        let redoButton = createButton(title: "Redo", action: UIAction(handler: { _ in
//            // TODO: 効いていない
//            self.undoManager?.redo()
//        }))
//        
//        toolStackView = UIStackView(arrangedSubviews: [crayonButton,
//                                                       pencilButton,
//                                                       markerButton,
//                                                       eraserButton,
//                                                       undoButton,
//                                                       redoButton])
//        if let toolStackView = toolStackView {
//            toolStackView.axis = .vertical
//            toolStackView.distribution = .fillEqually
//            toolStackView.alignment = .fill
//            toolStackView.spacing = 10
//            
//            view.addSubview(toolStackView)
//            
//            toolStackView.translatesAutoresizingMaskIntoConstraints = false
//            NSLayoutConstraint.activate([toolStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 10),
//                                         toolStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
//                                         toolStackView.widthAnchor.constraint(equalToConstant: 150)])
//            toolStackView.isHidden = true
//        }
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
                colorDarkStackView.bottomAnchor.constraint(equalTo: colorPaletteView.bottomAnchor, constant: 0),
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
                colorAlphaStackView.bottomAnchor.constraint(equalTo: alphaPaletteView.bottomAnchor, constant: 0),
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

    // 図形　写真マーカーサイズ
    func createTextSizeSlider() {
        let label = UILabel()
        label.text = "写真マーカーサイズ"
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
        }
    }
    
    // カラーパレット 透明度
    private func updateAlphaPens(sender: Any?) {
        if let button = sender as? UIButton,
           let alpha = Alpha(rawValue: button.tag) {
            // 選択された透明度
            selectedAlpha = alpha
            pdfDrawer.changeColor(color: selectedColor.withAlphaComponent(selectedAlpha.alpha))
        }
    }

    // カラーパレット 破線のパターン
    private func updateDashPattern(sender: Any?) {
        if let button = sender as? UIButton,
           let pattern = DashPattern(rawValue: button.tag) {

            dashPattern = pattern
            pdfDrawer.changeDashPattern(dashPattern: dashPattern)
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
        // 写真マーカーを更新する
        updatePhotoMarkerAnotation()
    }
    
    private func smallButtonTapped(_ sender: Any) {
        if let slider = photoMarkerSlider {
            slider.value -= 1.0
            selectedPhotoMarkerSize = CGFloat(slider.value)
            // 写真マーカーを更新する
            updatePhotoMarkerAnotation()
        }
    }
    
    private func bigButtonTapped(_ sender: Any) {
        if let slider = photoMarkerSlider {
            slider.value += 1.0
            selectedPhotoMarkerSize = CGFloat(slider.value)
            // 写真マーカーを更新する
            updatePhotoMarkerAnotation()
        }
    }

    // 手書き プロパティ変更パネル 閉じる
    private func cloSepropertyEditor(sender: Any?) {
        if let button = sender as? UIButton {
            propertyEditorScrollView?.isHidden = true
        }
    }
    
    // 手書きや図形を追加する
    func addDrawingAnotation(path: UIBezierPath) {
        // 現在開いているページを取得
        if let page = self.pdfView.currentPage {
//            // UUID
//            annotation.userName = UUID().uuidString
//            // 対象のページへ注釈を追加
//            page.addAnnotation(annotation)
            
            // Undo Redo
//            undoRedoManager.addAnnotation(annotation)
            undoRedoManager.showTeamMembers(completion: { didUndoAnnotations in
                // Undo Redo が可能なAnnotation　を削除して、更新後のAnnotationを表示させる
                self.reloadPDFAnnotations(didUndoAnnotations: didUndoAnnotations)
            })
            // ボタン　活性状態
            undoButton.isEnabled = undoRedoManager.canUndo()
            redoButton.isEnabled = undoRedoManager.canRedo()
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
                after.fontColor = selectedColor.withAlphaComponent(selectedAlpha.alpha)
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
    
    // MARK: - PDF ファイル　マーカー　Annotation表示非表示スイッチ
    
    // Annotation表示非表示スイッチ 切り替え
    @objc
    func switchTriggered(sender: UISwitch) {
        // PDF 全てのpageに存在するAnnotationを表示非表示を切り替える
        changeAllAnnotationsVisibility(shouldDisplay: sender.isOn)
    }
    
    // PDF 全てのpageに存在するAnnotationを表示非表示を切り替える
    func changeAllAnnotationsVisibility(shouldDisplay: Bool) {
        guard let document = pdfView.document else { return }
        for i in 0..<document.pageCount {
            if let page = document.page(at: i) {
                //
                let annotations = page.annotations
                for annotation in annotations {
                    
                    annotation.shouldDisplay = shouldDisplay
                }
            }
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
    func reloadPDFAnnotations(didUndoAnnotations: [Any]?) {
        print(#function)
        // Undo Redo が可能なAnnotation　を削除する
        DispatchQueue.main.async {
            if let editingAnnotations = self.editingAnnotations {
                guard let document = self.pdfView.document else { return }
                for editingAnnotation in editingAnnotations {
                    // pageを探す
                    for i in 0..<document.pageCount {
                        if let page = document.page(at: i) {
                            if let editingAnnotation = editingAnnotation as? PDFAnnotation,
                                let editingAnnotationPage = editingAnnotation.page {
                                // page が同一か？
                                // print(document.index(for: page), document.index(for: editingAnnotationPage))
                                if document.index(for: page) == document.index(for: editingAnnotationPage) {
                                    print("対象のページの注釈を削除", editingAnnotation.contents, editingAnnotation.userName)
                                    // 対象のページの注釈を削除
                                    editingAnnotationPage.removeAnnotation(editingAnnotation)
                                    // iOS17対応　PDFAnnotationのpageが消えてしまう現象
                                    editingAnnotation.page = editingAnnotationPage
                                }
                            } else {
                                print("AnnotationにPageが設定されていない")
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
            if let editingAnnotations = didUndoAnnotations {
                guard let document = self.pdfView.document else { return }
                for editingAnnotation in editingAnnotations {
                    // pageを探す
                    for i in 0..<document.pageCount {
                        if let page = document.page(at: i) {
                            if let editingAnnotation = editingAnnotation as? PDFAnnotation,
                               let editingAnnotationPage = editingAnnotation.page {
                                // page が同一か？
                                // print(document.index(for: page), document.index(for: editingAnnotationPage))
                                if document.index(for: page) == document.index(for: editingAnnotationPage) {
                                    print("対象のページの注釈を追加", editingAnnotation.contents, editingAnnotation.userName)
                                    // 対象のページの注釈を追加
                                    page.addAnnotation(editingAnnotation)
                                }
                            } else {
                                print("AnnotationにPageが設定されていない")
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
    
    // MARK: - PDF ファイル　マークアップ　編集中の一時ファイル

    //    // 一時ファイルを削除する
    //    func deleteTempDirectory() {
    //        guard let tempDirectory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else { return }
    //        // 一時ファイル用のフォルダ
    //        let pDFsDirectory = tempDirectory.appendingPathComponent("PDFs", isDirectory: true)
    //        do {
    //            try FileManager.default.createDirectory(at: pDFsDirectory, withIntermediateDirectories: true, attributes: nil)
    //        } catch {
    //            print("失敗した")
    //        }
    //        do {
    //            let directoryContents = try FileManager.default.contentsOfDirectory(at: pDFsDirectory, includingPropertiesForKeys: nil) // ファイル一覧を取得
    //            // if you want to filter the directory contents you can do like this:
    //            let pdfFiles = directoryContents.filter { $0.pathExtension == "pdf" }
    //            print("pdf urls: ", pdfFiles)
    //            let pdfFileNames = pdfFiles.map { $0.deletingPathExtension().lastPathComponent }
    //            print("pdf list: ", pdfFileNames)
    //            // ファイルのデータを取得
    //            for fileName in pdfFileNames {
    //                let content = pDFsDirectory.appendingPathComponent(fileName + ".pdf")
    //                do {
    //                    try FileManager.default.removeItem(at: content)
    //                } catch let error {
    //                    print(error)
    //                }
    //            }
    //        } catch {
    //            print(error)
    //        }
    //    }
    
    //    // 一時ファイルを作成する
    //    func saveToTempDirectory(fileURL: URL) -> URL? {
    //        guard let documentDirectory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else { return nil }
    //        let pDFsDirectory = documentDirectory.appendingPathComponent("PDFs", isDirectory: true)
    //        do {
    //            try FileManager.default.createDirectory(at: pDFsDirectory, withIntermediateDirectories: true, attributes: nil)
    //        } catch {
    //            print("失敗した")
    //        }
    //
    //        let pdfFileName = fileURL.deletingPathExtension().lastPathComponent
    //
    //        let filePath = pDFsDirectory.appendingPathComponent("\(pdfFileName)-temp" + ".pdf")
    //        do {
    //            // コピーの前にはチェック&削除が必要
    //            if FileManager.default.fileExists(atPath: filePath.path) {
    //                // すでに backupFileUrl が存在する場合はファイルを削除する
    //                try FileManager.default.removeItem(at: filePath)
    //            }
    //            // PDFファイルを一時フォルダへコピー
    //            try FileManager.default.copyItem(at: fileURL, to: filePath)
    //
    //            print(filePath)
    //            return filePath
    //        } catch {
    //            print(error.localizedDescription)
    //            return nil
    //        }
    //    }
    
    // MARK: - フォトライブラリ
    //
    //    // 写真をカメラロールからiCloud Container にコピーする URLから
    //    func addPhotoToProjectFolder() {
    //
    //        if let unusedNumber = unusedNumber,
    //           let fileURL = fileURL,
    //           let imageURL = imageURL {
    //            // 写真を iCloud Container に保存する
    //            if let fileName = BackupManager.shared.savePhotoToDocumentsDirectory(
    //                unusedNumber: unusedNumber,
    //                fileURL: fileURL,
    //                modifiedContentsURL: imageURL) {
    //                print(fileName)
    //            }
    //        }
    //    }
    //
    //    // 写真をカメラロールからiCloud Container にコピーする Dataから
    //    func addPhotoToProjectFolder(photoData: Data) {
    //
    //        if let unusedNumber = unusedNumber,
    //           let fileURL = fileURL,
    //           let imageURL = imageURL {
    //            // 写真を iCloud Container に保存する
    //            if let fileName = BackupManager.shared.savePhotoToDocumentsDirectory(
    //                unusedNumber: unusedNumber,
    //                fileURL: fileURL,
    //                modifiedContentsURL: imageURL,
    //                photoData: photoData) {
    //                print(fileName)
    //            }
    //        }
    //    }
    
    //    // iCloud Container に保存した写真を削除する
    //    func removePhotoToProjectFolder(contents: String?) {
    //
    //        if let contents = contents {
    //            // 写真を iCloud Container から削除する
    //            let result = BackupManager.shared.deletePhotoFromDocumentsDirectory(
    //                contents: contents,
    //                fileURL: fileURL
    //            )
    //            print("写真を削除", result)
    //        }
    //    }
    
    // MARK: - フォトライブラリ
    //    // 選択された画像のURL
    //    var imageURL: URL?
    //    var imagePickerController: UIImagePickerController!
    
    //    // 写真選択画面を表示させる
    //    func showPickingPhotoScreen() {
    //        if #available(iOS 14, *) {
    //            // iOS14以降の設定
    //            var configuration = PHPickerConfiguration()
    //            configuration.filter = PHPickerFilter.images
    //            configuration.selectionLimit = 1
    //            let picker = PHPickerViewController(configuration: configuration)
    //            picker.delegate = self
    //            DispatchQueue.main.async {
    //                self.present(picker, animated: true, completion: nil)
    //            }
    //        } else {
    //            // インスタンス生成
    //            imagePickerController = UIImagePickerController()
    //            // デリゲート設定
    //            imagePickerController.delegate = self
    //            // 画像の取得先はフォトライブラリ
    //            imagePickerController.sourceType = UIImagePickerController.SourceType.photoLibrary
    //            // 画像取得後の編集を不可に
    //            imagePickerController.allowsEditing = false
    //
    //            DispatchQueue.main.async {
    //                self.present(self.imagePickerController, animated: true, completion: nil)
    //            }
    //        }
    //    }
    
    //    // 写真のアクセス権限
    //    private func albumAction() {
    //        // 端末にアルバムがあるかを確認
    //        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerController.SourceType.photoLibrary) {
    //            if #available(iOS 14, *) {
    //                // iOS14以降の設定
    //                let authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    //                self.albumCommonAction(authorizationStatus)
    //            } else {
    //                // iOS14より前の設定
    //                let authorizationStatus = PHPhotoLibrary.authorizationStatus()
    //                self.albumCommonAction(authorizationStatus)
    //            }
    //        }
    //    }
    
    //    private func albumCommonAction(_ authorizationStatus: PHAuthorizationStatus) {
    //
    //        switch authorizationStatus {
    //        case .notDetermined:
    //            // 初回起動時アルバムアクセス権限確認
    //            PHPhotoLibrary.requestAuthorization { status in
    //                switch status {
    //                case .authorized:
    //                    // アクセスを許可するとカメラロールが出てくるようにもできる
    //                    break
    //                case .denied:
    //                    // エラーダイアログを表示させる
    //                    self.showAlert()
    //                default:
    //                    break
    //                }
    //            }
    //        case .denied:
    //            // アクセス権限がないとき
    //            // エラーダイアログを表示させる
    //            showAlert()
    //        case .authorized, .restricted, .limited:
    //            // アクセス権限があるとき
    //            break
    //        @unknown default:
    //            break
    //        }
    //    }
    
    //    // エラーダイアログを表示させる
    //    func showAlert() {
    //        let alert = UIAlertController(title: "", message: "写真へのアクセスを許可してください", preferredStyle: .alert)
    //        let settingsAction = UIAlertAction(title: "設定", style: .default, handler: { (_) -> Void in
    //            guard let settingsURL = URL(string: UIApplication.openSettingsURLString ) else {
    //                return
    //            }
    //            UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
    //        })
    //        let closeAction: UIAlertAction = UIAlertAction(title: "キャンセル", style: .cancel, handler: nil)
    //        alert.addAction(settingsAction)
    //        alert.addAction(closeAction)
    //        self.present(alert, animated: true, completion: nil)
    //    }
}

//extension DrawingViewController: UIImagePickerControllerDelegate {
//    /**
//     画像が選択された時に呼ばれる.
//     */
//    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
//        // 選択された画像のURL
//        let imageURL: AnyObject?  = info[UIImagePickerController.InfoKey.imageURL] as AnyObject
//        //        Printing description of info:
//        //        ▿ 4 elements
//        //          ▿ 0 : 2 elements
//        //            ▿ key : UIImagePickerControllerInfoKey
//        //              - _rawValue : UIImagePickerControllerImageURL
//        //            - value : file:///private/var/mobile/Containers/Data/Application/26495648-C0BE-4E00-8413-DEAD08D7690F/tmp/7FA25608-1700-4A19-8A9C-CB13AA1CA0DD.jpeg
//        //          ▿ 1 : 2 elements
//        //            ▿ key : UIImagePickerControllerInfoKey
//        //              - _rawValue : UIImagePickerControllerMediaType
//        //            - value : public.image
//        //          ▿ 2 : 2 elements
//        //            ▿ key : UIImagePickerControllerInfoKey
//        //              - _rawValue : UIImagePickerControllerOriginalImage
//        //            - value : <UIImage:0x281927180 anonymous {3024, 4032} renderingMode=automatic(original)>
//        //          ▿ 3 : 2 elements
//        //            ▿ key : UIImagePickerControllerInfoKey
//        //              - _rawValue : UIImagePickerControllerReferenceURL
//        //            - value : assets-library://asset/asset.HEIC?id=49B92187-72A5-41BD-B1EE-1718C2F0F1A9&ext=HEIC
//
//        // モーダルビューを閉じる
//        self.dismiss(animated: true) {
//            // 選択された画像のURL
//            self.imageURL = imageURL as? URL // imageURL    AnyObject?    "file:///private/var/mobile/Containers/Data/Application/1786FFAB-B2B2-418B-963E-04C2EC8AE382/tmp/4F5EC81E-7D85-437B-857C-6B6369915BDB.jpeg"    0x0000000280a5d080
//            // マーカーを追加する
//            self.addMarkerAnotation()
//            // 写真をカメラロールからiCloud Container にコピーする
//            self.addPhotoToProjectFolder()
//        }
//    }
//
//    /**
//     画像選択がキャンセルされた時に呼ばれる.
//     */
//    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
//        // モーダルビューを閉じる
//        self.dismiss(animated: true, completion: nil)
//    }
//}

//extension DrawingViewController: PHPickerViewControllerDelegate {
//    //    iPhoneでは高効率画像フォーマット「HEIC」「HEVC」が標準仕様となり、
//    //    Apple端末以外では、写真データの取り扱い難易度も上がってます。
//    //    以下、デフォルトの「高効率」時のデータ保存形式。
//    //
//    //    高効率時のデータ形式
//    //
//    //    タイムラプス：HEVC（H.265）
//    //    スロー：HEVC（H.265）
//    //    ビデオ：HEVC（H.265）
//    //    写真：HEIF
//    //    バースト（連射）：JPEG
//    //    LivePhotos：HEIF + HEVC（H.265）
//    //    ポートレート： HEIF + HEIF + AAE
//    //    パノラマ：HEIF
//    //    スクリーンショット：PNG
//    //    写真はHEIF、動画はHEVC、
//    //    だけど、バーストで連射撮影した場合はJPEGにて保存となる。
//    //
//    //    以前は、ポートレート写真は、JPEGでしたけども、
//    //    最新のiOS14から？HEIFに変わってました。
//    //    ポートレートHEIFは、Windowsに取り込むとバグるけどな。
//
//    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
//        // キャンセル
//        guard let provider = results.first?.itemProvider else {
//            picker.dismiss(animated: true, completion: nil)
//            return
//        }
//        guard let typeIdentifer = provider.registeredTypeIdentifiers.first else { return }
//        // 判定可能な識別子であるかチェック
//        if provider.hasItemConformingToTypeIdentifier(typeIdentifer) {
//            //Live Photoとして取得可能化
//            if provider.canLoadObject(ofClass: PHLivePhoto.self) {
//                //LivePhotoはClassを指定してLoadObjectで読み込み
//                provider.loadObject(ofClass: PHLivePhoto.self) { (livePhotoObject, error) in
//                    do {
//                        if let livePhoto:PHLivePhoto = livePhotoObject as? PHLivePhoto {
//                            // Live Photoのプロパティから静止画を抜き出す(HEIC形式)
//                            if let imageUrl = livePhoto.value(forKey: "imageURL") as? URL {
//                                // URLからDataを生成（HEIC内のデータを参照してるため取得できる
//                                let imageData: Data = try Data(contentsOf: imageUrl)
//                                // パスを生成して画像を保存する
//                                // 選択された画像のURL
//                                self.imageURL = imageUrl // imageUrl    Foundation.URL    "file:///private/var/mobile/Containers/Data/Application/D7A1BFB4-0443-473F-9154-0E93D2D2766A/tmp/live-photo-bundle/53151B11-9D5F-407E-AEE3-CE515F2A7659.pvt/IMG_2099.HEIC"
//                                // 写真をカメラロールからiCloud Container にコピーする Dataから
//                                //                                self.addPhotoToProjectFolder(photoData: imageData)
//                            }
//                        }
//                    } catch let error {
//                        print(error)
//                    }
//                }
//            } else if provider.canLoadObject(ofClass: UIImage.self) {
//                //一般的な画像
//                // 画像の場合はloadObjectでUIImageまたはloadDataで取得する。
//                // loadItemでURLを取得する場合、URLからUIImageまたはDataの取得はアルバムへのアクセス権限が必要になる。
//
//                // 写真のパスを取得
//                provider.loadItem(forTypeIdentifier: typeIdentifer) { imageURL, error  in
//                    guard let imageURL = imageURL as? URL else {
//                        return
//                    }
//                    // 選択された画像のURL
//                    self.imageURL = imageURL // imageURL    Foundation.URL    "file:///private/var/mobile/Containers/Shared/AppGroup/53934DC7-1B16-461D-81AB-C6A8E9A6C473/File%20Provider%20Storage/photospicker/version=1&uuid=1D5FF822-7CF5-48CA-A1F9-E0C04A4CB1BD&mode=compatible&noloc=0.jpeg"
//                }
//                // 写真のデータを取得
//                provider.loadDataRepresentation(forTypeIdentifier: typeIdentifer) { (data, error) in
//                    if let imageData = data {
//                        // 写真をカメラロールからiCloud Container にコピーする Dataから
//                        //                        self.addPhotoToProjectFolder(photoData: imageData)
//                    }
//                }
//            }
//
//            picker.dismiss(animated: true, completion: {
//                // マーカーを追加する
//                self.addMarkerAnotation()
//            })
//        }
//    }
//}

// 手書きのアノテーションを追加する処理
extension DrawingViewController: DrawingManageAnnotationDelegate {
    func addAnnotation(_ path: UIBezierPath) {
        
        addDrawingAnotation(path: path)
    }
}

extension DrawingViewController: UINavigationControllerDelegate {
    
}

extension DrawingViewController: UIGestureRecognizerDelegate {
    
    @objc
    func tappedView(_ sender: UITapGestureRecognizer){
        // 編集 終了時
        if !isEditing {
            if let selectedAnnotation = selectedAnnotation {
                // 選択したマーカーの画像を表示させる
                self.selectedAnnotation = nil
            } else {
                // 選択したマーカーの画像を非表示させる
                self.imageView.image = nil
                self.imageView.isHidden = true
                
                if drawingMode == .photoMarker {
                    // ①PDFに対してPDFAnnotationを設定する
                    
                    // PDF 全てのpageに存在するAnnotationを保持する
                    getAllAnnotations() {
                        // 現在開いているページを取得
                        if let page = self.pdfView.currentPage,
                           // 使用していない連番を取得する
                           let unusedNumber = self.getUnusedNumber() {
                            // TODO: SF Symbols は50までしか存在しない
                            // let image = UIImage(systemName: "\(unusedNumber).square") {
                            // 使用していない連番
                            self.unusedNumber = unusedNumber
                            // マーカー画像
                            // self.image = image
                            // UIViewからPDFの座標へ変換する
                            let point = self.pdfView.convert(sender.location(in: self.pdfView), to: page) // 座標系がUIViewとは異なるので気をつけましょう。
                            // PDFのタップされた位置の座標
                            self.point = point
                            // 写真選択画面を表示させる
                            // self.showPickingPhotoScreen()
                            // マーカーを追加する 写真
                            self.addMarkerAnotation()
                        } else {
                            print("SF Symbols に画像が存在しない")
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
                }
            }
        }
    }
    
    @objc
    func didPanAnnotation(sender: UIPanGestureRecognizer) {
        // 現在開いているページを取得
        if let page = self.pdfView.currentPage {
            // UIViewからPDFの座標へ変換する
            let locationOnPage = pdfView.convert(sender.location(in: pdfView), to: page) // 座標系がUIViewとは異なるので気をつけましょう。
            
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

//enum Colors: Int, CaseIterable {
//    case babyBlue
//    case buttercup
//    case lilac
//    case meadow
//    case rose
//    
//    func getColor() -> UIColor {
//        switch self {
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
//        }
//    }
//}
//
//extension UIButton {
//    func makeRounded(_ cornerSize: CGFloat, borderWidth: CGFloat, borderColor: UIColor) {
//        layer.cornerRadius = cornerSize
//        layer.borderWidth = borderWidth
//        layer.borderColor = borderColor.cgColor
//    }
//}

