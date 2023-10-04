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

class DrawingViewController: UIViewController {
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet weak var pdfView: NonSelectablePDFView!
    // iCloud Container に保存しているPDFファイルのパス
    var fileURL: URL?
    // ローカル Container に保存している編集中のPDFファイルのパス
    var tempFilePath: URL?
    // PDF 全てのpageに存在するAnnotationを保持する
    var annotationsInAllPages: [PDFAnnotation] = []
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
    // 選択されたマーカー
    var selectedAnnotation: PDFAnnotation?

    var imagePickerController: UIImagePickerController!
        
    
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
    
    // MARK: PDF ファイル　マークアップ　編集中の一時ファイル
    
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
    
    // MARK: PDF ファイル　マーカー　Annotation
    
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
    
    // マーカーを追加する
    func addMarkerAnotation() {
        // 現在開いているページを取得
        if let page = self.pdfView.currentPage,
           let point = point,
           let unusedNumber = unusedNumber {
            // 中央部に座標を指定
            let imageStamp = ImageAnnotation(with: image, forBounds: CGRect(x: point.x, y: point.y, width: 15, height: 15), withProperties: [:])
            imageStamp.contents = "\(unusedNumber)"
            // 対象のページへ注釈を追加
            page.addAnnotation(imageStamp)
            
            //                        // freeText
            //                        let freeText = PDFAnnotation(bounds: CGRect(x: point.x, y: point.y, width: 25, height: 25), forType: .freeText, withProperties: [:])
            //                        freeText.contents = "\(self.annotationsInAllPages.count ?? 0)"
            //                        freeText.color = .green
            //                        // 対象のページへ注釈を追加
            //                        page.addAnnotation(freeText)
        }
    }
    
    // マーカーを削除する
    func removeMarkerAnotation(annotation: PDFAnnotation) {
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
            // マーカーを削除する
            removeMarkerAnotation(annotation: annotation)
            // iCloud Container に保存した写真を削除する
            removePhotoToProjectFolder(contents: annotation.contents)
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
    
    // マーカーを追加しPDFを上書き保存する
    func save() {
        if let fileURL = fileURL {
            // 一時ファイルをiCloud Container に保存しているPDFファイルへ上書き保存する
            pdfView.document?.write(to: fileURL)
        }
    }
    
    // MARK: フォトライブラリ
    
    // 写真をカメラロールからiCloud Container にコピーする
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
    
    // MARK: フォトライブラリ
    
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
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
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
                                // let data: Data = try Data(contentsOf: imageUrl)
                                // パスを生成して画像を保存する
                                // 選択された画像のURL
                                self.imageURL = imageUrl // imageUrl    Foundation.URL    "file:///private/var/mobile/Containers/Data/Application/D7A1BFB4-0443-473F-9154-0E93D2D2766A/tmp/live-photo-bundle/53151B11-9D5F-407E-AEE3-CE515F2A7659.pvt/IMG_2099.HEIC"
                            }
                        }
                    } catch let error {
                        print(error)
                    }
                }
            } else if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadItem(forTypeIdentifier: typeIdentifer) { imageURL, error  in
                    guard let imageURL = imageURL as? URL else {
                        return
                    }
                    // 選択された画像のURL
                    self.imageURL = imageURL // imageURL    Foundation.URL    "file:///private/var/mobile/Containers/Shared/AppGroup/53934DC7-1B16-461D-81AB-C6A8E9A6C473/File%20Provider%20Storage/photospicker/version=1&uuid=1D5FF822-7CF5-48CA-A1F9-E0C04A4CB1BD&mode=compatible&noloc=0.jpeg"
                }
            }
            
            picker.dismiss(animated: true, completion: {
                // マーカーを追加する
                self.addMarkerAnotation()
                // 写真をカメラロールからiCloud Container にコピーする
                self.addPhotoToProjectFolder()
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


class NonSelectablePDFView: PDFView {
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        super.canPerformAction(action, withSender: sender)
        self.currentSelection = nil
        self.clearSelection()
        return false
    }
    
    override func addGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) {
        if gestureRecognizer is UILongPressGestureRecognizer {
            gestureRecognizer.isEnabled = false
        }
        
        super.addGestureRecognizer(gestureRecognizer)
    }
}
