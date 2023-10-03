//
//  DrawingViewController.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/10/02.
//

import PDFKit
import UIKit

class DrawingViewController: UIViewController {
    
    @IBOutlet weak var pdfView: PDFView!
    // iCloud Container に保存しているPDFファイルのパス
    var fileURL: URL?
    // ローカル Container に保存している編集中のPDFファイルのパス
    var tempFilePath: URL?
    // PDF 全てのpageに存在するAnnotationを保持する
    var annotationsInAllPages: [PDFAnnotation] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setEditingメソッドを使用するため、Storyboard上の編集ボタンを上書きしてボタンを生成する
        editButtonItem.tintColor = .black
        navigationItem.rightBarButtonItem = editButtonItem
        
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
        // pdfView.displayMode = .singlePage
        // 現在開いているページ currentPage にのみマーカーを追加
        pdfView.autoScales = true

        // ②PDF Annotationがタップされたかを監視、タップに対する処理を行う
        //　PDFAnnotationがタップされたかを監視する
        NotificationCenter.default.addObserver(self, selector: #selector(action(_:)), name: .PDFViewAnnotationHit, object: nil)
        
        // マーカーを追加する位置を取得する
        let singleTapGesture = UITapGestureRecognizer(target: self, action: #selector(tappedView(_:)))
        singleTapGesture.numberOfTapsRequired = 1
        singleTapGesture.delegate = self
        self.pdfView.addGestureRecognizer(singleTapGesture)
    }
    
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
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // マーカーを追加しPDFを上書き保存する
        save()
    }
    // PDFAnnotationがタップされた
    @objc
    func action(_ sender: Any) {
        // タップされたPDFAnnotationを取得する
        guard let notification = sender as? Notification,
              let annotation = notification.userInfo?["PDFAnnotationHit"] as? PDFAnnotation else {
            return
        }
        // タップされたPDFAnnotationに対する処理
        // 編集中
        if isEditing {
            print(annotation)
            // 現在開いているページを取得
            if let page = pdfView.currentPage {
                print(PDFAnnotationSubtype(rawValue: annotation.type!).rawValue)
                print(PDFAnnotationSubtype.stamp.rawValue.self)
                // freeText
                if PDFAnnotationSubtype(rawValue: "/\(annotation.type!)") == PDFAnnotationSubtype.stamp.self {
                    // 対象のページの注釈を削除
                    page.removeAnnotation(annotation)
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
    
    // PDF 全てのpageに存在するAnnotationを保持する
    func getAllAnnotations(completion: @escaping () -> Void) {
        guard let document = pdfView.document else { return }
        // 初期化
        annotationsInAllPages = []
        for i in 0..<document.pageCount {
            if let page = document.page(at: i) {
                // freeText
                let annotations = page.annotations.filter({ "/\($0.type!)" == PDFAnnotationSubtype.stamp.rawValue })
                for annotation in annotations {
                    
                    annotationsInAllPages.append(annotation)
                }
            }
        }
        print(annotationsInAllPages.count)
        completion()
    }
}

extension DrawingViewController: UIGestureRecognizerDelegate {
    
    @objc
    func tappedView(_ sender: UITapGestureRecognizer){
        // 編集 終了時
        if !isEditing {
            // ①PDFに対してPDFAnnotationを設定する
            
            // PDF 全てのpageに存在するAnnotationを保持する
            getAllAnnotations() {
                // 現在開いているページを取得
                if let page = self.pdfView.currentPage {
                    if let image = UIImage(systemName: "\(self.annotationsInAllPages.count ?? 0).square") {
                        // TODO: SF Symbols は50までしか存在しない
                        // 対象のページのサイズをCGRectで取得
                        let pageBounds = page.bounds(for: .cropBox)
                        // UIViewからPDFの座標へ変換する
                        let point = self.pdfView.convert(sender.location(in: self.pdfView), to: page) // 座標系がUIViewとは異なるので気をつけましょう。
                        // 中央部に座標を指定
                        let imageStamp = ImageAnnotation(with: image, forBounds: CGRect(x: point.x, y: point.y, width: 15, height: 15), withProperties: [:])
                        // 対象のページへ注釈を追加
                        page.addAnnotation(imageStamp)
                        
//                        // freeText
//                        let freeText = PDFAnnotation(bounds: CGRect(x: point.x, y: point.y, width: 25, height: 25), forType: .freeText, withProperties: [:])
//                        freeText.contents = "\(self.annotationsInAllPages.count ?? 0)"
//                        freeText.color = .green
//                        // 対象のページへ注釈を追加
//                        page.addAnnotation(freeText)
                    } else {
                        print("SF Symbols に画像が存在しない")
                    }
                }
            }
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
