//
//  ViewController.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/09/21.
//

import UIKit
import PencilKit
import QuickLook

class ViewController: UIViewController {

    @IBOutlet var tableView: UITableView!
    // コンテナ　ファイル
    var backupFiles: [(String, NSNumber?, Bool)] = []
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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // tableViewをリロード
        reload()
    }
    // tableViewをリロード
    func reload() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            BackupManager.shared.load {
                print($0)
                self.backupFiles = $0
                self.tableView.reloadData()
            }
        }
    }
    
    @IBAction func pdfButtonTapped(_ sender: Any) {
        // iCloud Container に保存しているPDFファイルのパス
        self.fileURL = nil
        // QLPreview画面を表示させる
        showQLPreview()
    }
    
    // QLPreview画面を表示させる
    func showQLPreview() {
        if BackupManager.shared.isiCloudEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
            //
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                BackupManager.shared.load {
                    print($0)
                    self.backupFiles = $0
                    self.tableView.reloadData()
                }
            }
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
    
}

extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//        pdfMaker.PDFpath?.count ?? 0
        print(backupFiles.count)
        return backupFiles.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.backgroundColor = .brown
//        cell.largeContentTitle = pdfMaker.PDFpath?[indexPath.row].lastPathComponent
        
        // バックアップファイル一覧　時刻　バージョン　ファイルサイズMB
//        cell.textLabel?.text = "\(backupFiles[indexPath.row].0)"
        if let size = backupFiles[indexPath.row].1 {
            let byteCountFormatter = ByteCountFormatter()
            byteCountFormatter.allowedUnits = [.useKB] // 使用する単位を選択
            byteCountFormatter.isAdaptive = true // 端数桁を表示する(123 MB -> 123.4 MB)(KBは0桁, MBは1桁, GB以上は2桁)
            byteCountFormatter.zeroPadsFractionDigits = true // trueだと100 MBを100.0 MBとして表示する(isAdaptiveをtrueにする必要がある)
            
            let byte = Measurement<UnitInformationStorage>(value: Double(truncating: size), unit: .bytes)
            
            byteCountFormatter.countStyle = .decimal // 1 KB = 1000 bytes
            print(byteCountFormatter.string(from: byte)) // 1,024 KB
            
            cell.textLabel?.text = "\(backupFiles[indexPath.row].0)  \(byteCountFormatter.string(from: byte))"
//            cell.detailTextLabel?.textColor = .blue
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

        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        DispatchQueue.global(qos: .default).async {
            // iCloud Documents からデータベースを復元する
            BackupManager.shared.restore(folderName: self.backupFiles[indexPath.row].0) { path in
                print("restore")
                // iCloud Container に保存しているPDFファイルのパス
                self.fileURL = path
                // QLPreview画面を表示させる
                self.showQLPreview()
            }
        }
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
