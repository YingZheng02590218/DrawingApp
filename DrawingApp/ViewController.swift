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

    var fileURL: URL?
    // 印刷機能
    let pdfMaker = PdfMaker()

    override func viewDidLoad() {
        super.viewDidLoad()
        
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            BackupManager.shared.load {
                print($0)
                self.backupFiles = $0
                self.tableView.reloadData()
            }
        }
    }
    
    @IBAction func pdfButtonTapped(_ sender: Any) {
            
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
        if let PDFpath = Bundle.main.url(forResource: "2023-Journals", withExtension: "pdf") {
            print(PDFpath)
            return 1
        } else {
            return 0
        }
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        
        guard let pdfFilePath = Bundle.main.url(forResource: "2023-Journals", withExtension: "pdf") else {
            return "" as! QLPreviewItem
        }
        return pdfFilePath as QLPreviewItem
    }
}

extension ViewController: QLPreviewControllerDelegate {

    func previewController(_ controller: QLPreviewController, didSaveEditedCopyOf previewItem: QLPreviewItem, at modifiedContentsURL: URL) {
        // iCloud Documents にバックアップを作成する
        BackupManager.shared.backup(modifiedContentsURL: modifiedContentsURL,
            completion: {
                //
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
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
        return .createCopy
    }
    
    func previewController(_ controller: QLPreviewController, shouldOpen url: URL, for item: QLPreviewItem) -> Bool {
        true
    }
    
    func previewController(_ controller: QLPreviewController, transitionViewFor item: QLPreviewItem) -> UIView? {
        // (QLPreviewItem) item = (object = "file:///private/var/containers/Bundle/Application/7AD9B624-37B6-4CBD-957F-6590FD8C3200/DrawingApp.app/2023-Journals.pdf")
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
            BackupManager.shared.restore(folderName: self.backupFiles[indexPath.row].0) {
                print("restore")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    BackupManager.shared.load {
                        print($0)
                        self.backupFiles = $0
                        self.tableView.reloadData()
                    }
                }

            }
        }
    }
}
