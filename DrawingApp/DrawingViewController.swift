//
//  DrawingViewController.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/10/02.
//

import PDFKit
import Photos
import PhotosUI
import UIKit
//import PencilKit

class DrawingViewController: UIViewController {
    
    // セグメントコントロール
    let segmentedControl = UISegmentedControl(items: ["写真マーカー", "手書き", "矢印", "直線", "四角", "円", "テキスト", "移動", "選択", "消しゴム"])
    // モード
    var drawingMode: DrawingMode = .photoMarker
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet weak var pdfThumbnailView: PDFThumbnailView!
    @IBOutlet weak var pdfView: NonSelectablePDFView!
    // iCloud Container に保存しているPDFファイルのパス
    var fileURL: URL?
    // ローカル Container に保存している編集中のPDFファイルのパス
    var tempFilePath: URL?
    // PDF 全てのpageに存在するAnnotationを保持する
    var annotationsInAllPages: [PDFAnnotation] = []
    // 選択しているAnnotation
    var currentlySelectedAnnotation: PDFAnnotation?
    // 連番 // TODO: SF Symbols は50までしか存在しない
    var numbersList = [0,1,2,3,4,5,6,7,8,9,
                       10,11,12,13,14,15,16,17,18,19,
                       20,21,22,23,24,25,26,27,28,29,
                       30,31,32,33,34,35,36,37,38,39,
                       40,41,42,43,44,45,46,47,48,49,
                       50]
    // 使用していない連番
    var unusedNumber: Int?
    // マーカー画像
    var image: UIImage?
    // 選択された画像のURL
    var imageURL: URL?
    // PDFのタップされた位置の座標
    var point: CGPoint?
    // 起点
    var beganLocation: CGPoint?
    // 途中点
    var changedLocation: CGPoint?
    // 終点
    var endLocation: CGPoint?
    // 選択されたマーカー
    var selectedAnnotation: PDFAnnotation?
    // 編集中のAnnotation
    var isEditingAnnotation: PDFAnnotation?

    var imagePickerController: UIImagePickerController!
    // 手書き　ツール
    var toolStackView: UIStackView?
    // 手書き　カラー
    var colorStackView: UIStackView?
    
//    let canvas = PKCanvasView()
//    var crayon = PKInkingTool(.pencil, color: Colors.babyBlue.getColor(), width: 70)
//    var pencil = PKInkingTool(.pencil, color: Colors.babyBlue.getColor(), width: 10)
//    var marker = PKInkingTool(.marker, color: Colors.babyBlue.getColor(), width: 40)
//    let eraser = PKEraserTool(.bitmap)
    
    private var path: UIBezierPath?
    private var currentAnnotation : DrawingAnnotation?

    private let pdfDrawer = PDFDrawer()

    let pdfDrawingGestureRecognizer = DrawingGestureRecognizer()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setEditingメソッドを使用するため、Storyboard上の編集ボタンを上書きしてボタンを生成する
        editButtonItem.tintColor = .black
        navigationItem.rightBarButtonItem = editButtonItem
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: nil, action: #selector(doSomething))
        // Annotation設定スイッチ
        let switchButton = UISwitch(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        switchButton.onTintColor = .green
        switchButton.isOn = true
        switchButton.addTarget(self, action: #selector(switchTriggered), for: .valueChanged)
        let switchBarButtonItem = UIBarButtonItem(customView: switchButton)
        navigationItem.rightBarButtonItems?.append(switchBarButtonItem)
        // セグメントコントロール
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
        navigationItem.rightBarButtonItems?.append(segmentBarButtonItem)
        
        // title設定
        navigationItem.title = "マーカーを追加する"
        
        // iCloud Container に保存しているPDFファイルのパス
        guard let fileURL = fileURL else { return }
        // 一時ファイルを削除する
        deleteTempDirectory()
        // PDFファイルを一時ディレクトリにコピーする
        if let tempFilePath = saveToTempDirectory(fileURL: fileURL) {
            // ローカル Container に保存している編集中のPDFファイルのパス
            self.tempFilePath = tempFilePath
        }
        
        guard let tempFilePath = tempFilePath else { return }
        guard let document = PDFDocument(url: tempFilePath) else { return }
        pdfView.document = document
        // 単一ページのみ
        pdfView.displayMode = .singlePage
        // 現在開いているページ currentPage にのみマーカーを追加
        pdfView.autoScales = true
        pdfView.scaleFactor += 3.0
        // PDF 全てのpageに存在するAnnotationを保持する
        getAllAnnotations() {
            // TODO: マーカーを拡大してセンターに表示させる
            if let annotation = self.annotationsInAllPages.filter({ String($0.contents ?? "") == "3" }).first {
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
//                    self.pdfView.center.y = annotation.bounds.center.y - 100
                }
            } else {
                self.annotationsInAllPages.map { print("$$$$$$", $0.contents) }
            }
        }
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
        
        // サムネイル
        pdfThumbnailView.pdfView = pdfView
        pdfThumbnailView.layoutMode = .vertical
        pdfThumbnailView.backgroundColor = UIColor.gray
        pdfThumbnailView.thumbnailSize = CGSize(width: 40, height: 60)
        
        // 手書きパレット
        createButtons()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // マーカーを追加しPDFを上書き保存する
        save()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 写真のアクセス権限
        albumAction()
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
    
    // MARK: - 手書きパレット

    // 手書きパレット
    func createButtons() {
//        canvas.frame = view.bounds
//        canvas.drawingPolicy = .anyInput
//        canvas.backgroundColor = .clear
//        canvas.isOpaque = false //背景を透明にする(だいじ)
//        view.addSubview(canvas)
//        canvas.tool = crayon
        
        //Create the color palette
        var buttons: [UIButton] = []
        
        for color in Colors.allCases {
            let button = UIButton(primaryAction: UIAction(handler: { action in
                self.updatePens(sender: action.sender)
            }))
            button.heightAnchor.constraint(equalToConstant: 100.0).isActive = true
            button.widthAnchor.constraint(equalToConstant: 100.0).isActive = true
            button.makeRounded(50, borderWidth: 10, borderColor: .black)
            button.backgroundColor = color.getColor()
            button.tag = color.rawValue
            buttons.append(button)
        }
        
        colorStackView = UIStackView(arrangedSubviews: buttons)
        if let colorStackView = colorStackView {
            colorStackView.axis = .horizontal
            colorStackView.distribution = .equalSpacing
            colorStackView.alignment = .center
            
            view.addSubview(colorStackView)
            
            colorStackView.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([colorStackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
                                         colorStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                                         colorStackView.widthAnchor.constraint(equalToConstant: view.bounds.width / 2),
                                         colorStackView.heightAnchor.constraint(equalToConstant: 100)])
            colorStackView.isHidden = true
        }
        
        //Setup tools
        let crayonButton = createButton(title: "Crayon", action: UIAction(handler: { _ in
//            self.canvas.tool = self.crayon
        }))
        
        let pencilButton = createButton(title: "Pencil", action: UIAction(handler: { _ in
//            self.canvas.tool = self.pencil
            self.pdfDrawer.changeTool(tool: .pencil)
        }))
        
        let markerButton = createButton(title: "Marker", action: UIAction(handler: { _ in
//            self.canvas.tool = self.marker
        }))
        
        let eraserButton = createButton(title: "Eraser", action: UIAction(handler: { _ in
//            self.canvas.tool = self.eraser
        }))
        
        let undoButton = createButton(title: "Undo", action: UIAction(handler: { _ in
            // TODO: 効いていない
            self.undoManager?.undo()
        }))
        
        let redoButton = createButton(title: "Redo", action: UIAction(handler: { _ in
            // TODO: 効いていない
            self.undoManager?.redo()
        }))
        
        toolStackView = UIStackView(arrangedSubviews: [crayonButton,
                                                       pencilButton,
                                                       markerButton,
                                                       eraserButton,
                                                       undoButton,
                                                       redoButton])
        if let toolStackView = toolStackView {
            toolStackView.axis = .vertical
            toolStackView.distribution = .fillEqually
            toolStackView.alignment = .fill
            toolStackView.spacing = 10
            
            view.addSubview(toolStackView)
            
            toolStackView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([toolStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 10),
                                         toolStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                                         toolStackView.widthAnchor.constraint(equalToConstant: 150)])
            toolStackView.isHidden = true
        }
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
    
    private func updatePens(sender: Any?) {
        if let button = sender as? UIButton,
           let color = Colors(rawValue: button.tag)?.getColor() { //,
//           var currentTool = canvas.tool as? PKInkingTool {
//            //update the current tool being used by the canvas
//            currentTool.color = color
//            canvas.tool = currentTool
//            //update all the tools
//            crayon.color = color
//            pencil.color = color
//            marker.color = color
            pdfDrawer.changeColor(color: color)
        }
    }
    
    // MARK: - 戻るボタン

    @objc
    func doSomething() {
        // 戻るボタンの動作処理
        self.dismiss(animated: true)
    }
    
    // MARK: - 編集モード

    @objc
    func segmentedControlChanged() {
        drawingMode = DrawingMode(index: segmentedControl.selectedSegmentIndex)
        
        if drawingMode == .rectangle || drawingMode == .circle || drawingMode == .move {
            // 拡大縮小を禁止してマーカーの起点と終点を選択しやすくする
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
            
//            canvas.isHidden = false
            pdfDrawer.isActive = true
            colorStackView?.isHidden = false
            toolStackView?.isHidden = false
        } else {
            pdfView.removeGestureRecognizer(pdfDrawingGestureRecognizer)
            
//            canvas.isHidden = true
            pdfDrawer.isActive = false
            colorStackView?.isHidden = true
            toolStackView?.isHidden = true
        }
    }
    
    enum DrawingMode {
        case photoMarker
        case drawing
        case arrow
        case line
        case rectangle
        case circle
        case text
        case move
        case select
        case eraser
        // 引数ありコンストラクタ
        init(index: Int) {
            switch index {
            case 0:
                 self = .photoMarker
            case 1:
                self = .drawing
            case 2:
                self = .arrow
            case 3:
                self = .line
            case 4:
                self = .rectangle
            case 5:
                self = .circle
            case 6:
                self = .text
            case 7:
                self = .move
            case 8:
                self = .select
            case 9:
                self = .eraser
            default:
                self = .move
            }
        }
    }
    
    // ダイアログ
    func showDialogForSucceed(message: String, color: UIColor, frame: CGRect) {
        let actionSheet = UIAlertController(title: "Annotation", message: message, preferredStyle: .actionSheet)
        actionSheet.view.backgroundColor = color
        // iPad の場合のみ、ActionSheetを表示するための必要な設定
        if UIDevice.current.userInterfaceIdiom == .pad {
            actionSheet.popoverPresentationController?.sourceView = pdfView
            actionSheet.popoverPresentationController?.sourceRect = frame
//            CGRect(
//                x: frame.origin.x - frame.width,
//                y: frame.origin.y - frame.height,
//                width: 0,
//                height: 0
//            )
            // iPadの場合、アクションシートの背後の画面をタップできる
        } else {
            // ③表示するViewと表示位置を指定する
            actionSheet.popoverPresentationController?.sourceView = pdfView
            actionSheet.popoverPresentationController?.sourceRect = frame
        }
        
        actionSheet.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection.any

        self.present(actionSheet, animated: true) { () -> Void in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
    
    // MARK: - PDF ファイル　マークアップ　編集中の一時ファイル
    
    // 一時ファイルを削除する
    func deleteTempDirectory() {
        guard let tempDirectory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else { return }
        // 一時ファイル用のフォルダ
        let pDFsDirectory = tempDirectory.appendingPathComponent("PDFs", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: pDFsDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("失敗した")
        }
        do {
            let directoryContents = try FileManager.default.contentsOfDirectory(at: pDFsDirectory, includingPropertiesForKeys: nil) // ファイル一覧を取得
            // if you want to filter the directory contents you can do like this:
            let pdfFiles = directoryContents.filter { $0.pathExtension == "pdf" }
            print("pdf urls: ", pdfFiles)
            let pdfFileNames = pdfFiles.map { $0.deletingPathExtension().lastPathComponent }
            print("pdf list: ", pdfFileNames)
            // ファイルのデータを取得
            for fileName in pdfFileNames {
                let content = pDFsDirectory.appendingPathComponent(fileName + ".pdf")
                do {
                    try FileManager.default.removeItem(at: content)
                } catch let error {
                    print(error)
                }
            }
        } catch {
            print(error)
        }
    }
    
    // 一時ファイルを作成する
    func saveToTempDirectory(fileURL: URL) -> URL? {
        guard let documentDirectory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else { return nil }
        let pDFsDirectory = documentDirectory.appendingPathComponent("PDFs", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: pDFsDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("失敗した")
        }
        
        let pdfFileName = fileURL.deletingPathExtension().lastPathComponent
        
        let filePath = pDFsDirectory.appendingPathComponent("\(pdfFileName)-temp" + ".pdf")
        do {
            // コピーの前にはチェック&削除が必要
            if FileManager.default.fileExists(atPath: filePath.path) {
                // すでに backupFileUrl が存在する場合はファイルを削除する
                try FileManager.default.removeItem(at: filePath)
            }
            // PDFファイルを一時フォルダへコピー
            try FileManager.default.copyItem(at: fileURL, to: filePath)
            
            print(filePath)
            return filePath
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
    
    
    // MARK: - PDF ファイル　マーカー　Annotation
    
    // Annotation設定スイッチ 切り替え
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
    
    // PDF 全てのpageに存在するAnnotationを保持する
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
        print(annotationsInAllPages.count)
        completion()
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
            let font = UIFont.systemFont(ofSize: 15)
            let size = "\(unusedNumber)".size(with: font)
            // Create dictionary of annotation properties
            let lineAttributes: [PDFAnnotationKey: Any] = [
                .color: UIColor.green.withAlphaComponent(0.5),
                .contents: "\(unusedNumber)",
            ]

            let freeText = PhotoAnnotation(bounds: CGRect(x: point.x, y: point.y, width: size.width + 5, height: size.height + 5), forType: .freeText, withProperties: lineAttributes)
            // 対象のページへ注釈を追加
            page.addAnnotation(freeText)
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
            border.style = .dashed
            
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
            page.addAnnotation(lineAnnotation)
        }
    }
    
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
            border.style = .dashed
            
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
            page.addAnnotation(lineAnnotation)
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
            border.lineWidth = 2.0
            border.style = .dashed
            
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
            page.addAnnotation(newAnnotation)
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
            border.style = .dashed
            
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
            page.addAnnotation(newAnnotation)
        }
    }
    
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
            // 対象のページへ注釈を追加
            page.addAnnotation(freeText)
        }
    }
    // マーカーを更新する テキスト
    func updateTextMarkerAnotation(inputText: String?, fontSize: CGFloat) {

        if let isEditingAnnotation = isEditingAnnotation,
           let inputText = inputText,
           !inputText.isEmpty {
            
            // freeText
            let font = UIFont.systemFont(ofSize: fontSize)
            let size = "\(inputText)".size(with: font)
            // 文字列の長さが変化したらboundsも更新しなければならない
            isEditingAnnotation.bounds = CGRect(
                x: isEditingAnnotation.bounds.origin.x,
                y: isEditingAnnotation.bounds.origin.y,
                width: size.width + 5,
                height: size.height + 5
            )
            isEditingAnnotation.contents = inputText
            isEditingAnnotation.setValue(UIColor.orange.withAlphaComponent(0.1), forAnnotationKey: .color)
        }
    }

    // 写真マーカーを削除する
    func removeMarkerAnotation(annotation: PDFAnnotation) {
        // 現在開いているページを取得
        if let page = pdfView.currentPage {
            print(PDFAnnotationSubtype(rawValue: annotation.type!).rawValue)
            print(PDFAnnotationSubtype.stamp.rawValue.self)
            // 写真マーカー
            if annotation.isKind(of: PhotoAnnotation.self) && PDFAnnotationSubtype(rawValue: "/\(annotation.type!)") == PDFAnnotationSubtype.freeText.self && ((annotation.contents?.isEmpty) != nil)  {
                // 対象のページの注釈を削除
                page.removeAnnotation(annotation)
            }
        }
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
                // 対象のページの注釈を削除
                page.removeAnnotation(annotation)
            }
        }
    }
    
    // 手書きや図形を追加する
    func addDrawingAnotation() {
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
                // マーカーを削除する
                removeMarkerAnotation(annotation: annotation)
                // iCloud Container に保存した写真を削除する
                removePhotoToProjectFolder(contents: annotation.contents)
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
                    present(viewController, animated: true, completion: nil)
                }
            }
        } else {
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
                    // Annotationを再度作成
                    page.addAnnotation(lineAnnotation)
                    // 古いものを削除する
                    page.removeAnnotation(annotation)
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
                // マーカーに紐付けされた画像
                if let fileURL = fileURL,
                   let contents = annotation.contents {
                    // 写真を iCloud Container から取得する
                    if let photoUrl = BackupManager.shared.getPhotoFromDocumentsDirectory(contents: contents, fileURL: fileURL) {
                        // マーカーに紐付けされた画像
                        getThumbnailImage(url: photoUrl) { image in
                            if let image = image {
                                DispatchQueue.main.async {
                                    self.imageView.image = image
                                    self.imageView.isHidden = false
                                }
                            }
                        }
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
        }
    }
    
    // マーカーを追加しPDFを上書き保存する
    func save() {
        if let fileURL = fileURL {
            // 一時ファイルをiCloud Container に保存しているPDFファイルへ上書き保存する
            pdfView.document?.write(to: fileURL)
        }
    }
    
    // MARK: - フォトライブラリ
    
    // 写真をカメラロールからiCloud Container にコピーする URLから
    func addPhotoToProjectFolder() {
        
        if let unusedNumber = unusedNumber,
           let fileURL = fileURL,
           let imageURL = imageURL {
            // 写真を iCloud Container に保存する
            if let fileName = BackupManager.shared.savePhotoToDocumentsDirectory(
                unusedNumber: unusedNumber,
                fileURL: fileURL,
                modifiedContentsURL: imageURL) {
                print(fileName)
            }
        }
    }
    
    // 写真をカメラロールからiCloud Container にコピーする Dataから
    func addPhotoToProjectFolder(photoData: Data) {
        
        if let unusedNumber = unusedNumber,
           let fileURL = fileURL,
           let imageURL = imageURL {
            // 写真を iCloud Container に保存する
            if let fileName = BackupManager.shared.savePhotoToDocumentsDirectory(
                unusedNumber: unusedNumber,
                fileURL: fileURL,
                modifiedContentsURL: imageURL,
                photoData: photoData) {
                print(fileName)
            }
        }
    }
    
    // iCloud Container に保存した写真を削除する
    func removePhotoToProjectFolder(contents: String?) {
        
        if let contents = contents {
            // 写真を iCloud Container から削除する
            let result = BackupManager.shared.deletePhotoFromDocumentsDirectory(
                contents: contents,
                fileURL: fileURL
            )
            print("写真を削除", result)
        }
    }
    
    // MARK: - フォトライブラリ
    
    // 写真選択画面を表示させる
    func showPickingPhotoScreen() {
        if #available(iOS 14, *) {
            // iOS14以降の設定
            var configuration = PHPickerConfiguration()
            configuration.filter = PHPickerFilter.images
            configuration.selectionLimit = 1
            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = self
            DispatchQueue.main.async {
                self.present(picker, animated: true, completion: nil)
            }
        } else {
            // インスタンス生成
            imagePickerController = UIImagePickerController()
            // デリゲート設定
            imagePickerController.delegate = self
            // 画像の取得先はフォトライブラリ
            imagePickerController.sourceType = UIImagePickerController.SourceType.photoLibrary
            // 画像取得後の編集を不可に
            imagePickerController.allowsEditing = false
            
            DispatchQueue.main.async {
                self.present(self.imagePickerController, animated: true, completion: nil)
            }
        }
    }
    
    // 写真のアクセス権限
    private func albumAction() {
        // 端末にアルバムがあるかを確認
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerController.SourceType.photoLibrary) {
            if #available(iOS 14, *) {
                // iOS14以降の設定
                let authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                self.albumCommonAction(authorizationStatus)
            } else {
                // iOS14より前の設定
                let authorizationStatus = PHPhotoLibrary.authorizationStatus()
                self.albumCommonAction(authorizationStatus)
            }
        }
    }
    
    private func albumCommonAction(_ authorizationStatus: PHAuthorizationStatus) {
        
        switch authorizationStatus {
        case .notDetermined:
            // 初回起動時アルバムアクセス権限確認
            PHPhotoLibrary.requestAuthorization { status in
                switch status {
                case .authorized:
                    // アクセスを許可するとカメラロールが出てくるようにもできる
                    break
                case .denied:
                    // エラーダイアログを表示させる
                    self.showAlert()
                default:
                    break
                }
            }
        case .denied:
            // アクセス権限がないとき
            // エラーダイアログを表示させる
            showAlert()
        case .authorized, .restricted, .limited:
            // アクセス権限があるとき
            break
        @unknown default:
            break
        }
    }
    
    // エラーダイアログを表示させる
    func showAlert() {
        let alert = UIAlertController(title: "", message: "写真へのアクセスを許可してください", preferredStyle: .alert)
        let settingsAction = UIAlertAction(title: "設定", style: .default, handler: { (_) -> Void in
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString ) else {
                return
            }
            UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
        })
        let closeAction: UIAlertAction = UIAlertAction(title: "キャンセル", style: .cancel, handler: nil)
        alert.addAction(settingsAction)
        alert.addAction(closeAction)
        self.present(alert, animated: true, completion: nil)
    }
}
extension String {
    func size(with font: UIFont) -> CGSize {
        let attributes = [NSAttributedString.Key.font : font]
        return (self as NSString).size(withAttributes: attributes)
    }
}
extension DrawingViewController: UIImagePickerControllerDelegate {
    /**
     画像が選択された時に呼ばれる.
     */
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        // 選択された画像のURL
        let imageURL: AnyObject?  = info[UIImagePickerController.InfoKey.imageURL] as AnyObject
        //        Printing description of info:
        //        ▿ 4 elements
        //          ▿ 0 : 2 elements
        //            ▿ key : UIImagePickerControllerInfoKey
        //              - _rawValue : UIImagePickerControllerImageURL
        //            - value : file:///private/var/mobile/Containers/Data/Application/26495648-C0BE-4E00-8413-DEAD08D7690F/tmp/7FA25608-1700-4A19-8A9C-CB13AA1CA0DD.jpeg
        //          ▿ 1 : 2 elements
        //            ▿ key : UIImagePickerControllerInfoKey
        //              - _rawValue : UIImagePickerControllerMediaType
        //            - value : public.image
        //          ▿ 2 : 2 elements
        //            ▿ key : UIImagePickerControllerInfoKey
        //              - _rawValue : UIImagePickerControllerOriginalImage
        //            - value : <UIImage:0x281927180 anonymous {3024, 4032} renderingMode=automatic(original)>
        //          ▿ 3 : 2 elements
        //            ▿ key : UIImagePickerControllerInfoKey
        //              - _rawValue : UIImagePickerControllerReferenceURL
        //            - value : assets-library://asset/asset.HEIC?id=49B92187-72A5-41BD-B1EE-1718C2F0F1A9&ext=HEIC
        
        // モーダルビューを閉じる
        self.dismiss(animated: true) {
            // 選択された画像のURL
            self.imageURL = imageURL as? URL // imageURL    AnyObject?    "file:///private/var/mobile/Containers/Data/Application/1786FFAB-B2B2-418B-963E-04C2EC8AE382/tmp/4F5EC81E-7D85-437B-857C-6B6369915BDB.jpeg"    0x0000000280a5d080
            // マーカーを追加する
            self.addMarkerAnotation()
            // 写真をカメラロールからiCloud Container にコピーする
            self.addPhotoToProjectFolder()
        }
    }
    
    /**
     画像選択がキャンセルされた時に呼ばれる.
     */
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        // モーダルビューを閉じる
        self.dismiss(animated: true, completion: nil)
    }
}

extension DrawingViewController: PHPickerViewControllerDelegate {
    //    iPhoneでは高効率画像フォーマット「HEIC」「HEVC」が標準仕様となり、
    //    Apple端末以外では、写真データの取り扱い難易度も上がってます。
    //    以下、デフォルトの「高効率」時のデータ保存形式。
    //
    //    高効率時のデータ形式
    //
    //    タイムラプス：HEVC（H.265）
    //    スロー：HEVC（H.265）
    //    ビデオ：HEVC（H.265）
    //    写真：HEIF
    //    バースト（連射）：JPEG
    //    LivePhotos：HEIF + HEVC（H.265）
    //    ポートレート： HEIF + HEIF + AAE
    //    パノラマ：HEIF
    //    スクリーンショット：PNG
    //    写真はHEIF、動画はHEVC、
    //    だけど、バーストで連射撮影した場合はJPEGにて保存となる。
    //
    //    以前は、ポートレート写真は、JPEGでしたけども、
    //    最新のiOS14から？HEIFに変わってました。
    //    ポートレートHEIFは、Windowsに取り込むとバグるけどな。
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        // キャンセル
        guard let provider = results.first?.itemProvider else {
            picker.dismiss(animated: true, completion: nil)
            return
        }
        guard let typeIdentifer = provider.registeredTypeIdentifiers.first else { return }
        // 判定可能な識別子であるかチェック
        if provider.hasItemConformingToTypeIdentifier(typeIdentifer) {
            //Live Photoとして取得可能化
            if provider.canLoadObject(ofClass: PHLivePhoto.self) {
                //LivePhotoはClassを指定してLoadObjectで読み込み
                provider.loadObject(ofClass: PHLivePhoto.self) { (livePhotoObject, error) in
                    do {
                        if let livePhoto:PHLivePhoto = livePhotoObject as? PHLivePhoto {
                            // Live Photoのプロパティから静止画を抜き出す(HEIC形式)
                            if let imageUrl = livePhoto.value(forKey: "imageURL") as? URL {
                                // URLからDataを生成（HEIC内のデータを参照してるため取得できる
                                 let imageData: Data = try Data(contentsOf: imageUrl)
                                // パスを生成して画像を保存する
                                // 選択された画像のURL
                                self.imageURL = imageUrl // imageUrl    Foundation.URL    "file:///private/var/mobile/Containers/Data/Application/D7A1BFB4-0443-473F-9154-0E93D2D2766A/tmp/live-photo-bundle/53151B11-9D5F-407E-AEE3-CE515F2A7659.pvt/IMG_2099.HEIC"
                                // 写真をカメラロールからiCloud Container にコピーする Dataから
                                self.addPhotoToProjectFolder(photoData: imageData)
                            }
                        }
                    } catch let error {
                        print(error)
                    }
                }
            } else if provider.canLoadObject(ofClass: UIImage.self) {
                //一般的な画像
                // 画像の場合はloadObjectでUIImageまたはloadDataで取得する。
                // loadItemでURLを取得する場合、URLからUIImageまたはDataの取得はアルバムへのアクセス権限が必要になる。
                
                // 写真のパスを取得
                provider.loadItem(forTypeIdentifier: typeIdentifer) { imageURL, error  in
                    guard let imageURL = imageURL as? URL else {
                        return
                    }
                    // 選択された画像のURL
                    self.imageURL = imageURL // imageURL    Foundation.URL    "file:///private/var/mobile/Containers/Shared/AppGroup/53934DC7-1B16-461D-81AB-C6A8E9A6C473/File%20Provider%20Storage/photospicker/version=1&uuid=1D5FF822-7CF5-48CA-A1F9-E0C04A4CB1BD&mode=compatible&noloc=0.jpeg"
                }
                // 写真のデータを取得
                provider.loadDataRepresentation(forTypeIdentifier: typeIdentifer) { (data, error) in
                    if let imageData = data {
                        // 写真をカメラロールからiCloud Container にコピーする Dataから
                        self.addPhotoToProjectFolder(photoData: imageData)
                    }
                }
            }
            
            picker.dismiss(animated: true, completion: {
                // マーカーを追加する
                self.addMarkerAnotation()
            })
        }
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
                           let unusedNumber = self.getUnusedNumber(),
                           // TODO: SF Symbols は50までしか存在しない
                           let image = UIImage(systemName: "\(unusedNumber).square") {
                            // 使用していない連番
                            self.unusedNumber = unusedNumber
                            // マーカー画像
                            self.image = image
                            // UIViewからPDFの座標へ変換する
                            let point = self.pdfView.convert(sender.location(in: self.pdfView), to: page) // 座標系がUIViewとは異なるので気をつけましょう。
                            // PDFのタップされた位置の座標
                            self.point = point
                            // 写真選択画面を表示させる
                            self.showPickingPhotoScreen()
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
                            present(viewController, animated: true, completion: nil)
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
                    guard let annotation = page.annotation(at: locationOnPage) else {   return }
                    if annotation.isKind(of: PDFAnnotation.self) ||
                        annotation.isKind(of: ImageAnnotation.self) {
                        currentlySelectedAnnotation = annotation
                    }
                case .changed:
                    guard let annotation = currentlySelectedAnnotation else {return }
                    let initialBounds = annotation.bounds
                    // Set the center of the annotation to the spot of our finger
                    annotation.bounds = CGRect(x: locationOnPage.x - (initialBounds.width / 2), y: locationOnPage.y - (initialBounds.height / 2), width: initialBounds.width, height: initialBounds.height)
                case .ended, .cancelled, .failed:
                    currentlySelectedAnnotation = nil
                default:
                    break
                }
            }
        }
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
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

enum Colors: Int, CaseIterable {
    case babyBlue
    case buttercup
    case lilac
    case meadow
    case rose
    
    func getColor() -> UIColor {
        switch self {
        case .babyBlue:
            return UIColor(named: "BabyBlue")!
        case .buttercup:
            return UIColor(named: "Buttercup")!
        case .lilac:
            return UIColor(named: "Lilac")!
        case .meadow:
            return UIColor(named: "Meadow")!
        case .rose:
            return UIColor(named: "Rose")!
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
