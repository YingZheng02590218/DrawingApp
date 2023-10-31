//
//  ViewController.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/09/21.
//

import UIKit
//import PencilKit
import QuickLook

class ViewController: UIViewController {
    
    @IBOutlet var tableView: UITableView!

    var cellHeightList: [IndexPath: CGFloat] = [:]
    // コンテナ　ファイル
    var backupFiles: [(String, NSNumber?, Bool, URL?)] = []
    // iCloud Container に保存しているPDFファイルのパス
    var fileURL: URL?
    // 印刷機能
    let pdfMaker = PdfMaker()
    
    // ディレクトリ監視
    var isPresenting = false
    // ディレクトリ監視
    var presentedItemURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents", isDirectory: true)
    }
    // ディレクトリ監視
    let presentedItemOperationQueue = OperationQueue()
    
    deinit {
        // ディレクトリ監視
        removeFilePresenterIfNeeded()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // ディレクトリ監視
        addFilePresenterIfNeeded()
        
        tableView.register(UINib(nibName: "IconTableViewCell", bundle: nil), forCellReuseIdentifier: "cell")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // tableViewをリロード
        reload()
    }
    // tableViewをリロード
    func reload() {
        DispatchQueue.main.async {
            BackupManager.shared.load {
                print($0)
                self.backupFiles = $0
                self.cellHeightList = [:]
                self.tableView.reloadData()
            }
        }
    }
    
    // MARK: 図面PDFファイルを取り込む　iCloud Container にプロジェクトフォルダを作成

    /// 外部アプリ　ファイル読み込みボタンをタップ
    @IBAction func tapFileReadButton(_ sender: Any) {
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
    
    // MARK: 図面PDFファイルにお絵描きする　iCloud Container にプロジェクトフォルダを作成

    // ローカルに用意したPDFファイル　お絵描き
    @IBAction func pdfButtonTapped(_ sender: Any) {
        // iCloud Container に保存しているPDFファイルのパス
        self.fileURL = nil
        // QLPreview画面を表示させる
        showQLPreview()
    }
    
    // お絵描き　QLPreview画面を表示させる
    func showQLPreview() {
        if BackupManager.shared.isiCloudEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // QuickLook のパターン
                let previewController = QLPreviewController()
                previewController.delegate = self
                previewController.dataSource = self
                
                self.present(previewController, animated: true, completion: {
                    print("#####")
                    print(self)
                    
                    print(self.presentingViewController)
                    print(self.presentedViewController) // Optional(<QLPreviewController: 0x103026200>)
                    
                    print(previewController.presentingViewController) // Optional(<DrawingApp.ViewController: 0x104007830>)
                    print(previewController.presentedViewController)
                })
            }
        }
    }

    // マーカー画面を表示させる
    func showMarkerView() {
        if BackupManager.shared.isiCloudEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // PDFKit のパターン
                if let viewController = UIStoryboard(
                    name: "DrawingViewController",
                    bundle: nil
                ).instantiateInitialViewController() as? DrawingViewController {
                    // iCloud Container に保存しているPDFファイルのパス
                    viewController.fileURL = self.fileURL

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

/*
 `QLPreviewController` にPDFデータを提供する
 */

extension ViewController: QLPreviewControllerDataSource {
    
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        
        if let fileURL = fileURL {
            // iCloud Container に保存しているPDFファイルのパス
            print(fileURL)
            return 1
        } else {
            if let pdfFilePath = Bundle.main.url(forResource: "2023-Journals", withExtension: "pdf") {
                print(pdfFilePath)
                return 1
            } else {
                return 0
            }
        }
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        if let fileURL = fileURL {
            // iCloud Container に保存しているPDFファイルのパス
            return fileURL as QLPreviewItem
        } else {
            guard let pdfFilePath = Bundle.main.url(forResource: "2023-Journals", withExtension: "pdf") else {
                return "" as! QLPreviewItem
            }
            return pdfFilePath as QLPreviewItem
        }
    }
}

extension ViewController: QLPreviewControllerDelegate {
    
    // マークアップを終了した際にコールされる
    func previewController(_ controller: QLPreviewController, didSaveEditedCopyOf previewItem: QLPreviewItem, at modifiedContentsURL: URL) {
        // ここでPDFファイルを上書き保存するかどうかをたずねる
        
        // iCloud Documents にバックアップを作成する
        BackupManager.shared.backup(fileURL: fileURL, modifiedContentsURL: modifiedContentsURL,
                                    completion: {
            // tableViewをリロード
            self.reload()
        },
                                    errorHandler: {
            //
        }
        )
    }
    
    func previewController(_ controller: QLPreviewController, editingModeFor previewItem: QLPreviewItem) -> QLPreviewItemEditingMode {
        // QuickLook　コンテンツを編集する方法を示す値を返します。
        // .updateContent　元のファイルを上書きして編集を処理します。
        // .createCopy　または編集したコピーを作成して、
        // .disabled ユーザーにそのファイルを編集させたくない場合。QuickLookは編集ボタンを表示しません。
        return .createCopy
    }
    
    func previewController(_ controller: QLPreviewController, shouldOpen url: URL, for item: QLPreviewItem) -> Bool {
        true
    }
    // QLPreview画面へ遷移前と、Done ボタンを押下時にコールされる
    func previewController(_ controller: QLPreviewController, transitionViewFor item: QLPreviewItem) -> UIView? {
        // (QLPreviewItem) item = (object = "file:///private/var/containers/Bundle/Application/7AD9B624-37B6-4CBD-957F-6590FD8C3200/DrawingApp.app/2023-Journals.pdf")
        // サムネイル画像
        UIView()
    }
    
    func previewController(_ controller: QLPreviewController, didUpdateContentsOf previewItem: QLPreviewItem) {
        //
    }
    
    func previewController(_ controller: QLPreviewController, frameFor item: QLPreviewItem, inSourceView view: AutoreleasingUnsafeMutablePointer<UIView?>) -> CGRect {
        CGRect(origin: .zero, size: .init(width: 100, height: 100))
    }
    
    func previewController(_ controller: QLPreviewController, transitionImageFor item: QLPreviewItem, contentRect: UnsafeMutablePointer<CGRect>) -> UIImage? {
        UIImage()
    }
}

extension ViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let cellHeight = self.cellHeightList[indexPath] else {
            //取得できなかった場合に自動計算
            return UITableView.automaticDimension
        }
        return cellHeight
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if self.cellHeightList.keys.contains(indexPath) != true {
            self.cellHeightList[indexPath] = cell.frame.height
        }
    }
    
}

extension ViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return backupFiles.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as? IconTableViewCell else { return UITableViewCell() }
        
        // バックアップファイル一覧　時刻　バージョン　ファイルサイズMB
        cell.centerLabel.text = "\(backupFiles[indexPath.row].0)"
        if let size = backupFiles[indexPath.row].1 {
            let byteCountFormatter = ByteCountFormatter()
            byteCountFormatter.allowedUnits = [.useKB] // 使用する単位を選択
            byteCountFormatter.isAdaptive = true // 端数桁を表示する(123 MB -> 123.4 MB)(KBは0桁, MBは1桁, GB以上は2桁)
            byteCountFormatter.zeroPadsFractionDigits = true // trueだと100 MBを100.0 MBとして表示する(isAdaptiveをtrueにする必要がある)
            
            let byte = Measurement<UnitInformationStorage>(value: Double(truncating: size), unit: .bytes)
            
            byteCountFormatter.countStyle = .decimal // 1 KB = 1000 bytes
            print(byteCountFormatter.string(from: byte)) // 1,024 KB
            
            cell.subLabel.text = "\(byteCountFormatter.string(from: byte))"
        }
        // 未ダウンロードアイコン
        let isOniCloud = backupFiles[indexPath.row].2
        if isOniCloud {
            let image = UIImage(systemName: "icloud.and.arrow.down")?.withRenderingMode(.alwaysTemplate)
            let disclosureView = UIImageView(image: image)
            disclosureView.tintColor = UIColor.gray
            cell.accessoryView = disclosureView
        } else {
            cell.accessoryView = nil
        }
        // サムネイル画像
        if let url = backupFiles[indexPath.row].3 {
            getThumbnailImage(url: url) { image in
                DispatchQueue.main.async {
                    cell.leftImageView.image = image
                }
            }
            cell.leftImageView.backgroundColor = UIColor.systemGray
            cell.leftImageView.contentMode = .scaleAspectFit
        }
        // サムネイル画像
        func getThumbnailImage(url: URL, completion: @escaping (_ image: UIImage?) -> Void) {
            guard let doc = PDFDocument(url: url) else { return }
            guard let page = doc.page(at: 0) else { fatalError() }
            let image = page.thumbnail(of: CGSize(width: 1000, height: 1000), for: PDFDisplayBox.trimBox)
            
            completion(image)
        }
        // 写真データ数
        BackupManager.shared.photosIsExists(folderName: backupFiles[indexPath.row].0) { (exists, files) in
            DispatchQueue.main.async {
                if exists {
                    cell.lowerLabel.isHidden = false
                    cell.lowerLabel.text = "Photos: \(files.count)."
                } else {
                    cell.lowerLabel.isHidden = true
                    cell.lowerLabel.text = nil
                }
            }
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        DispatchQueue.global(qos: .default).async {
            // iCloud Documents からデータベースを復元する
            BackupManager.shared.restore(folderName: self.backupFiles[indexPath.row].0) { path in
                print("restore")
                // iCloud Container に保存しているPDFファイルのパス
                self.fileURL = path
                // マーカー画面を表示させる
                self.showMarkerView()
            }
        }
    }
    
    // 削除機能
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        .delete
    }
    
    // 削除機能 セルを左へスワイプ
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let action = UIContextualAction(style: .destructive, title: "削除") { (action, view, completionHandler) in
            // プロジェクトファイルを削除
            BackupManager.shared.deleteBackupFolder(
                folderName: self.backupFiles[indexPath.row].0
            )
            completionHandler(true) // 処理成功時はtrue/失敗時はfalseを設定する
        }
        action.image = UIImage(systemName: "trash.fill") // 画像設定（タイトルは非表示になる？）
        
        // 編集ボタン
        let actionEdit = UIContextualAction(style: .normal, title: "編集") { _, _, completionHandler in
            print("cellのindexPath:\(String(describing: indexPath.row))")
            // iCloud Container に保存しているPDFファイルのパス
            self.fileURL = self.backupFiles[indexPath.row].3
            // QLPreview画面を表示させる
            self.showQLPreview()
            completionHandler(true) // 処理成功時はtrue/失敗時はfalseを設定する
        }
        actionEdit.backgroundColor = .green
        actionEdit.image = UIImage(systemName: "pencil.line") // 画像設定（タイトルは非表示になる）
        
        let configuration = UISwipeActionsConfiguration(actions: [action, actionEdit])

        return configuration
    }

}

// 流れ
// ファイル/ディレクトリを管理するオブジェクトにNSFilePresenterプロトコルを指定する。
// NSFileCoordinatorのaddFilePresenter:クラスを呼び出してオブジェクトを登録する。
// NSFilePresenterのメソッド内にそれぞれの処理を書く
// 管理が必要なくなるタイミングでNSFileCoordinatorのremoveFilePresenterを呼び出してファイルプレゼンタの登録を解除する。
extension ViewController: NSFilePresenter {
    
    // ファイルプレゼンタをシステムに登録
    func addFilePresenterIfNeeded() {
        if !isPresenting {
            isPresenting = true
            NSFileCoordinator.addFilePresenter(self)
        }
    }
    
    // ファイルプレゼンタをシステムの登録から解除
    func removeFilePresenterIfNeeded() {
        if isPresenting {
            isPresenting = false
            NSFileCoordinator.removeFilePresenter(self)
        }
    }
    
    // 提示された項目の内容または属性が変更されたことを伝える。
    func presentedItemDidChange() {
        print("Change item.")
        // tableViewをリロード
        reload()
    }
    
    // ファイルまたはファイルパッケージの新しいバージョンが追加されたことをデリゲートに通知する
    func presentedItemDidGainVersion(version: NSFileVersion) {
        print("Update file at \(version.modificationDate).")
    }
    
    // ファイルまたはファイルパッケージのバージョンが消えたことをデリゲートに通知する
    func presentedItemDidLoseVersion(version: NSFileVersion) {
        print("Lose file version at \(version.modificationDate).")
    }
    
    // ディレクトリ内のアイテムが新しいバージョンになった（更新された）時の通知
    func presentedSubitem(at url: URL, didGain version: NSFileVersion) {
        
        var isDir = ObjCBool(false)
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
            if Bool(isDir.boolValue) {
                print("Update directory (\(url.path)) at \(version.modificationDate).")
            } else {
                print("Update file (\(url.path)) at \(version.modificationDate).")
            }
        }
    }
    
    // ディレクトリ内のアイテムが削除された時の通知
    func presentedSubitem(at url: URL, didLose version: NSFileVersion) {
        print("looooooooooooose")
        var isDir = ObjCBool(false)
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
            if Bool(isDir.boolValue) {
                print("Lose directory version (\(url.path)) at \(version.modificationDate).")
            } else {
                print("Lose file version (\(url.path)) at \(version.modificationDate).")
            }
        }
    }
    
    // ファイル/ディレクトリの内容変更の通知
    func presentedSubitemDidChange(at url: URL) {
        if FileManager.default.fileExists(atPath: url.path) {
            print("Add subitem (\(url.path)).")
        } else {
            print("Remove subitem (\(url.path)).")
        }
        // tableViewをリロード
        reload()
    }
    
    // ファイル/ディレクトリが移動した時の通知
    func presentedSubitemAtURL(oldURL: NSURL, didMoveToURL newURL: NSURL) {
        var isDir = ObjCBool(false)
        if FileManager.default.fileExists(atPath: newURL.path!, isDirectory: &isDir) {
            if Bool(isDir.boolValue) {
                print("Move directory from (\(oldURL.path)) to (\(newURL.path!).")
            } else {
                print("Move file from (\(oldURL.path)) to (\(newURL.path)).")
            }
        }
    }
    
    // MARK: 何したら呼ばれるのか
    
    // 何したら呼ばれるのか
    func accommodatePresentedItemDeletionWithCompletionHandler(completionHandler: (NSError?) -> Void) {
        print("accommodatePresentedItemDeletionWithCompletionHandler")
    }
    
    // 何したら呼ばれるのか
    private func accommodatePresentedSubitemDeletionAtURL(url: URL, completionHandler: @escaping (NSError?) -> Void) {
        print("accommodatePresentedSubitemDeletionAtURL")
        print("url: \(url.path)")
    }
    
    // 何したら呼ばれるのか
    func presentedSubitemDidAppear(at url: URL) {
        print("presentedSubitemDidAppearAtURL")
        print("url: \(url.path)")
    }
}

// MARK: 図面PDFファイルを取り込む　iCloud Container にプロジェクトフォルダを作成

/// UIDocumentPickerDelegate
extension ViewController: UIDocumentPickerDelegate {
    /// ファイル選択後に呼ばれる
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        // URLを取得
        guard let url = urls.first else { return }
        
        // iCloud Container のプロジェクトフォルダ内のPDFファイルは受け取れないように弾く
        guard !url.path.contains("iCloud~com~ikingdom778~DrawingApp/Documents") else {
            return
        }
        
        // 困ったところ
        // USBメモリからのファイル読み込みができない。
        // USBメモリ内からParameter選択した場合のURL
        // 例）"file:/// ~ /Parameter" ←これだとディレクトリとして認識されない
        // iPad内からParameter選択した場合のURL
        // 例）"file:/// ~ /Parameter/" ←これはディレクトリとして認識される
        // 選択したURLがディレクトリかどうか
        if url.hasDirectoryPath {
            // ここで読み込む処理
            // 対応
            // 対応として、ディレクトリチェックのif文を削除しました。
            // 元々ドキュメントピッカーで選択できる対象をフォルダに限定していたため、よくよく考えてみると不要な処理でした。
            // 結果
            // 上記の対応を行うことで無事USBメモリからもファイルが読み込めるようになりました。
        }
        // USBメモリなど外部記憶装置内のファイルにアクセスするにはセキュリティで保護されたリソースへのアクセス許可が必要
        guard url.startAccessingSecurityScopedResource() else {
            // ここで選択したURLでファイルを処理する
            return
        }
        
        // iCloud Documents にバックアップを作成する
        BackupManager.shared.backup(
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
