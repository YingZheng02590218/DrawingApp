//
//  JsonFileManager.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/11/29.
//

import Foundation
import UIKit

// MARK: 状態管理 JSONファイル

// 構造体の定義
// Jsonファイルから読み出したデータを保存する構造体
// 構造体内のtexts配列をCSVに変換する関数texts2CSV()
struct Entry: Codable {
    var date:Date
    var title:String
    var memo:String
    var audioFilePath:String
    var audioFileName:String
    var texts:[TextPhrase]
    
    /// カンマ区切りの文字列に変換
    func texts2CSV() -> String {
        var rtnStr = ""
        for i in 0 ..< texts.count {
            let time:String = "\"" + texts[i].time2hhmmss() + "\",\""
            let speaker:String = texts[i].speaker  + "\",\""
            rtnStr += time + speaker + texts[i].text  + "\"\r\n"
        }
        return rtnStr
    }
}
// Jsonファイルから読み出したデータを保存する構造体
// 配列の中身の構造体もCodableで定義しておく
// 構造体内のtopの時間をhh:mm:ssに変換する関数time2hhmmss()
struct TextPhrase: Codable {
    var top:TimeInterval
    var end:TimeInterval?
    var speaker:String
    var text:String
    var comment:String
    
    func time2hhmmss() -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.allowedUnits = [.minute,.hour,.second]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: top) ?? ""
    }
}

class JsonFileManager {
    
    static let shared = JsonFileManager()
    
    private init() {
    }
    
    let jsonFileName = "project.json"
    let liblaryPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    var entries: [Entry] = []

    // Jsonの書き込み
    // JSONEncoderで構造体をエンコードして書き込み
    func saveEntriesToJson() {
        let jsonPath = liblaryPath.absoluteString + "/" + jsonFileName
        
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = .prettyPrinted
        
        let data = try! jsonEncoder.encode(entries)
        let dataStr = String(data:data,encoding:.utf8)
        
        if dataStr?.isEmpty ?? true { return }
        do {
            // Stringデータをファイルに書き出し
            try dataStr!.write(toFile: jsonPath, atomically: true, encoding: .utf8)
        } catch _ {
            print("Write Error!  File : \(jsonPath)")
        }
    }
    
    // Jsonの読み出し
    func readSavedJson() {
        let jsonPath = liblaryPath.absoluteString + "/" + jsonFileName
        // jsonをファイルから読み出す
        let fm = FileManager()
        let jsonDecoder = JSONDecoder()
        let jsonStr:String
        // ファイルの有無をチェック
        if fm.fileExists(atPath: jsonPath) {
            do {
                jsonStr = try String(contentsOfFile: jsonPath, encoding: .utf8)
            } catch _ {
                return
            }
        } else {
            print("No File : \(jsonPath)")
            //entries = []
            // 初期状態では何もないのでリソースから作る
            if let assetJson = NSDataAsset(name: "originJson") {
                jsonStr = String(data: assetJson.data, encoding: .utf8) ?? ""
                // サンプルファイルをAudioフォルダにコピー
                if let assetAudio = NSDataAsset(name: "sampleAudio") {
                    let audioData = assetAudio.data as NSData
                    let audioFilePath = documentsPath.absoluteString + "/Audio/sample.mp3"
                    let audioFolderPath = documentsPath.absoluteString + "/Audio"
                    //Audioフォルダが無ければ作る
                    var isDirExists : ObjCBool = false
                    fm.fileExists(atPath: audioFolderPath, isDirectory:&isDirExists)
                    if !isDirExists.boolValue {
                        do {
                            try fm.createDirectory(atPath: audioFolderPath, withIntermediateDirectories: true, attributes: nil)
                        } catch let error1 {
                            print("Error createDirectory : \(audioFolderPath) : " + error1.localizedDescription  )
                            return
                        }
                    }
                    // ファイルを書き込む
                    audioData.write(toFile: audioFilePath, atomically: true)
                }
            } else {
                entries = [Entry(date:Date(),title:"No Date",memo:"",audioFilePath:"NoAudio.mp4",audioFileName:"NoAudio.mp4",texts:[TextPhrase(top:0,end:nil,speaker:"No One",text:"say something",comment:"no comment")])]
                return
            }
        }
        
        entries = try! jsonDecoder.decode([Entry].self, from: jsonStr.data(using: .utf8)!)
    }
    
    //    // 状態管理 JSONファイル
    //    let fileName = "project.json"
    //    let urlString = "http://....../test.json" // JSONファイルのURL
    //
    //    func setupJsonFile() {
    //        if let url = URL(string: urlString) {
    //            if let desktopURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
    //                //         if let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
    //                do {
    //                    let data = try Data(contentsOf: url)
    //                    let fileURL = desktopURL.appendingPathComponent(fileName)
    //                    try data.write(to: fileURL)
    //                } catch let error {
    //                    print("Read or Write Error: \(error.localizedDescription)")
    //                }
    //            } else {
    //                print("ローカルディスク上のパス取得失敗")
    //            }
    //        } else {
    //            print("不正なURL")
    //        }
    //
    //    }
    //
    //    @IBAction func getJSON(_ sender: Any) {
    //        if let url = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
    //            let fileURL = url.appendingPathComponent(fileName)
    //            do {
    //                if FileManager.default.fileExists(atPath: fileURL.path) {
    //                    let data = try Data(contentsOf: fileURL)
    //                    if let dataArray = try JSONSerialization.jsonObject(with: data) as? [[String : Any]] {
    //                        for element in dataArray {
    //                            print("\(element)")
    //                        }
    //                    } else {
    //                        print("JSONファイル作成失敗")
    //                    }
    //                } else {
    //                    print("ファイル保存失敗")
    //                }
    //            } catch let error {
    //                print("Error \(error.localizedDescription)")
    //            }
    //        } else {
    //            print("ローカルディスク上のパス取得失敗")
    //        }
    //    }
}
