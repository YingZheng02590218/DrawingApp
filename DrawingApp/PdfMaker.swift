//
//  PdfMaker.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/09/26.
//

import Foundation
import UIKit

class PdfMaker {
    
    var PDFpath: [URL]?
    
//    let hTMLhelper = HTMLhelperAccount()
    let paperSize = CGSize(width: 170 / 25.4 * 72, height: 257 / 25.4 * 72) // 調整した　A4 210×297mm
    // 勘定名
    var account: String = ""
    var fiscalYear = 0
    
    func initialize() {
        // 初期化
        PDFpath = []
        
        guard let tempDirectory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else { return }
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
            PDFpath = pdfFiles
            print("pdf urls: ", pdfFiles)
            let pdfFileNames = pdfFiles.map { $0.deletingPathExtension().lastPathComponent }
            print("pdf list: ", pdfFileNames)
            // ファイルのデータを取得
//            for fileName in pdfFileNames {
//                let content = pDFsDirectory.appendingPathComponent(fileName + ".pdf")
//                do {
//                    try FileManager.default.removeItem(at: content)
//                } catch let error {
//                    print(error)
//                }
//            }
        } catch {
            print(error)
        }
        
//        readDB()
    }
    
//    func readDB() {
//        // PDFデータを一時ディレクトリに保存する
//        if let fileName = saveToTempDirectory(data: pdfData) {
//            // PDFファイルを表示する
//            self.PDFpath?.append(fileName)
//        }
//    }
//
//    /*
//     この関数はHTML文字列を受け取り、PDFファイルを表す `NSData` オブジェクトを返します。
//     */
//    func getPDF(fromHTML: String) -> NSData {
//        let renderer = UIPrintPageRenderer()
//        let paperFrame = CGRect(origin: .zero, size: paperSize)
//
//        renderer.setValue(paperFrame, forKey: "paperRect")
//        renderer.setValue(paperFrame, forKey: "printableRect")
//
//        let formatter = UIMarkupTextPrintFormatter(markupText: fromHTML)
//        formatter.perPageContentInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
//        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)
//
//        let pdfData = NSMutableData()
//
//        UIGraphicsBeginPDFContextToData(pdfData, paperFrame, [:])
//        for pageI in 0..<renderer.numberOfPages {
//            UIGraphicsBeginPDFPage()
//            print(UIGraphicsGetPDFContextBounds())
//            renderer.drawPage(at: pageI, in: paperFrame)
//        }
//        UIGraphicsEndPDFContext()
//        return pdfData
//    }
    
    /*
     この関数は、特定の `data` をアプリの一時ストレージに保存します。さらに、そのファイルが存在する場所のパスを返します。
     */
    func saveToTempDirectory(data: NSData) -> URL? {
        guard let documentDirectory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else { return nil }
        let pDFsDirectory = documentDirectory.appendingPathComponent("PDFs", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: pDFsDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("失敗した")
        }
        
        // "receipt-" + UUID().uuidString
        // "\(fiscalYear)-Account-\(account)"
        
        let filePath = pDFsDirectory.appendingPathComponent("図面" + ".pdf")
        do {
            try data.write(to: filePath)
            print(filePath)
            return filePath
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
    
}
