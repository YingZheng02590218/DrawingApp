//
//  JsonFileManager.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/11/29.
//

import Foundation
import UIKit
//import PDFKit

// MARK: 状態管理 JSONファイル

// プロジェクト
struct Project: Codable {
    var version: String
    var markers: [Marker]?
}

struct PathElement: Codable {
    var type: Int
    var points: Array<CGPoint>?
}

// アノテーション　注釈
struct Marker: Codable {
    var imageId: String // 写真マーカー　紐付けた撮影写真
    var data: MarkerInfo

    struct MarkerInfo: Codable {
        var id: String
        var annotationType: AnnotationType
        var size: CGFloat
        var x: CGFloat
        var y: CGFloat
        var color: ColorRGBA
        var pageLabel: String? // PDFページ
        var text: String // テキスト：表示する文字列　写真マーカー：通し番号
        var damagePattern: DamagePattern? // 損傷マーカー：画像
        // 手書き線
        var points: [PathElement]?
        var lineWidth: CGFloat?
        var dashPattern: DashPattern?
//        "strokeWidth": 17,
//        "strokeColor": "rgba(0, 0, 0, 1)",
//        "strokeDash": null,
//        "points": [
//            {
//                "x": 143.5,
//                "y": 247.5
//            },
//            {
//                "x": 147,
//                "y": 244.5
//            },
//            {
//                "x": 247,
//                "y": 223.5
//            },
//            {
//                "x": 277,
//                "y": 217.5
//            },
//            {
//                "x": 312,
//                "y": 213
//            },
//            {
//                "x": 485.5,
//                "y": 200
//            },
//            {
//                "x": 572,
//                "y": 199
//            },
//            {
//                "x": 600.5,
//                "y": 201
//            }
//        ],
//        "close": false,
//        "type": "normal",
    }
    //"image": "86ae9abd-9220-4f03-8c64-ab7eae074361",
    //"data": {
    //    "time": 1699260457535,
    //    "text": 1,
    //    "size": 51,
    //    "color": "rgba(255,0,255,0.14285714285714285)",
    //    "x": 808.2951311279362,
    //    "y": 687.5086662094482,
    //    "id": "c40575c1-fb15-469d-bf25-16d69a2a1a43"
}

class ColorRGBA: Codable {
    var red: Float = 0.0
    var green: Float = 0.0
    var blue: Float = 0.0
    var alpha: Float = 0.0
    
    init() {
    }
    
    init(color: UIColor) {
        if let colorcomponents = color.cgColor.components, colorcomponents.count == 4 {
            self.red = Float(colorcomponents[0])
            self.green = Float(colorcomponents[1])
            self.blue = Float(colorcomponents[2])
            self.alpha = Float(colorcomponents[3])
        }
        else {
            print(#function + ":no RGB")
        }
    }
    
    func toUIColor() -> UIColor {
        UIColor(red: CGFloat(self.red),
                green: CGFloat(self.green),
                blue: CGFloat(self.blue),
                alpha: CGFloat(self.alpha))
    }
}

class JsonFileManager {
    
    static let shared = JsonFileManager()
    
    private init() {
    }
    
    let jsonFileName = "project.json"
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    // プロジェクト
    var project: Project?
    
    // Jsonの書き込み
    // JSONEncoderで構造体をエンコードして書き込み
    func saveProjectToJson(project: Project?) {
        let jsonPath = documentsPath.appendingPathComponent(jsonFileName, isDirectory: false)
        
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = .prettyPrinted
        
        let data = try! jsonEncoder.encode(project)
        let dataStr = String(data: data, encoding:.utf8)
        
        if dataStr?.isEmpty ?? true { return }
        do {
            // Stringデータをファイルに書き出し
            try dataStr!.write(toFile: jsonPath.path, atomically: true, encoding: .utf8)
        } catch _ {
            print("Write Error!  File : \(jsonPath.path)")
        }
    }
    
    // Jsonの読み出し
    func readSavedJson() -> Project? {
        let jsonPath = documentsPath.appendingPathComponent(jsonFileName, isDirectory: false)
        // jsonをファイルから読み出す
        let fm = FileManager()
        let jsonDecoder = JSONDecoder()
        var jsonStr: String = ""
        // ファイルの有無をチェック
        if fm.fileExists(atPath: jsonPath.path) {
            do {
                jsonStr = try String(contentsOfFile: jsonPath.path, encoding: .utf8)
            } catch _ {
                return nil
            }
        } else {
            print("No File : \(jsonPath)")
            //entries = []
            // 初期状態では何もないのでリソースから作る
            if let assetJson = NSDataAsset(name: "originJson") {
                jsonStr = String(data: assetJson.data, encoding: .utf8) ?? ""
                do {
                    FileManager.default.createFile(atPath: jsonPath.path, contents: assetJson.data)
                } catch _ {
                    print("Error createFile : \(jsonPath) : ")
                    return nil
                }
            } else {
                return nil
            }
        }
        do { project = try jsonDecoder.decode(Project?.self, from: jsonStr.data(using: .utf8)!) } catch { project = nil }
        return project
    }
}
