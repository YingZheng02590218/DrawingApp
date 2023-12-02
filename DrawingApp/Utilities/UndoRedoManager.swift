//
//  UndoRedoManager.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/11/10.
//

import Foundation
import PDFKit

// [iOS・Swift] UndoManagerで「元に戻す」を手軽に実装しよう
// https://sussan-po.com/2020/03/21/how-to-use-undomanager/

enum Operation {
    case add(_ new: Marker)
    case update(_ before: Marker, _ after: Marker)
    case delete(_ person: Marker)
}

class UndoRedoManager {
    private let undoManager: UndoManager
    private var teamMembers: [Marker]
    
    init() {
        undoManager = .init()
        teamMembers = []
        undoManager.groupsByEvent = false
        // MARK: グループ化される時の通知を受け取る
        registerForNotifications()
    }
    
    func setup(makers: [Marker]?) {
        teamMembers = makers ?? []
    }
    
    func addAnnotation(_ newAnnotation: Marker) {
        print(#function)
        
        teamMembers.append(newAnnotation)
        
        undoManager.beginUndoGrouping()
        registerOperation(.add(newAnnotation))
        undoManager.endUndoGrouping()
    }
    
    func updateAnnotation(before: Marker, after: Marker) {
        print(#function)
        
        teamMembers.removeAll(where: { $0.data.id == before.data.id })
        
        teamMembers.append(after)
        
        undoManager.beginUndoGrouping()
        registerOperation(.update(before, after))
        undoManager.endUndoGrouping()
    }
    
    func deleteAnnotation(_ annotation: Marker) {
        print(#function)
        
        teamMembers.removeAll(where: { $0.data.id == annotation.data.id })
        
        undoManager.beginUndoGrouping()
        registerOperation(.delete(annotation))
        undoManager.endUndoGrouping()
    }
    
    func undo(completion: ([Marker]) -> Void) {
        if undoManager.canUndo {
            print(#function)
            
            undoManager.undo()
            completion(teamMembers)
        } else {
            print("Cannot undo")
        }
    }
    
    func redo(completion: ([Marker]) -> Void) {
        if undoManager.canRedo {
            print(#function)
            
            undoManager.redo()
            completion(teamMembers)
        } else {
            print("Cannot undo")
        }
    }
    
    func showTeamMembers(completion: ([Marker]) -> Void) {
        completion(teamMembers)
    }
    
    func showTeamMembers() -> Int {
        return teamMembers.count
    }
    
    func canUndo() -> Bool {
        undoManager.canUndo &&
        !undoManager.isUndoing &&
        !undoManager.isRedoing
    }
    
    func canRedo() -> Bool {
        undoManager.canRedo &&
        !undoManager.isUndoing &&
        !undoManager.isRedoing
    }
    
    // MARK: 以下の議論を参照
    // https://stackoverflow.com/questions/47988403/how-will-undomanager-run-loop-grouping-be-affected-in-different-threading-contex
    private func registerForNotifications() {
        NotificationCenter.default.addObserver(forName: Notification.Name.NSUndoManagerDidOpenUndoGroup, object: undoManager, queue: nil) { _ in
            print("opening group at level \(self.undoManager.levelsOfUndo)")
        }
        
        NotificationCenter.default.addObserver(forName: Notification.Name.NSUndoManagerDidCloseUndoGroup, object: undoManager, queue: nil) { _ in
            print("closing group at level \(self.undoManager.levelsOfUndo)")
        }
    }
}

private extension UndoRedoManager {
    
    func registerOperation(_ op: Operation) {
        
        self.undoManager.registerUndo(withTarget: self) { unownedSelf in
            switch op {
            case .add(let addedAnnotation):
                // Undo
                unownedSelf.deleteAnnotation(addedAnnotation)
                // Redo
                self.undoManager.registerUndo(withTarget: self) { unownedSelf in
                    unownedSelf.addAnnotation(addedAnnotation)
                }
            case .update(let old, let new):
                // Undo
                unownedSelf.updateAnnotation(before: new, after: old)
                // Redo
                self.undoManager.registerUndo(withTarget: self) { unownedSelf in
                    unownedSelf.updateAnnotation(before: old, after: new)
                }
            case .delete(let deletedAnnotation):
                // Undo
                unownedSelf.addAnnotation(deletedAnnotation)
                // Redo
                self.undoManager.registerUndo(withTarget: self) { unownedSelf in
                    unownedSelf.deleteAnnotation(deletedAnnotation)
                }
            }
        }
    }
}

// structをundoするには#
// 今回の実装では、undoManager.registerUndoで、Targetにselfを渡しました。こうすることで、クロージャの中でクラス内のメソッドやプロパティを呼ぶことができるようになります。すなわち、メソッド経由でstructのArrayを操作できるようになります。わざわざNSMutableArrayに切り替えることなく、Undo機能を導入することができます。


//
//// やり直す」の実装方法
//// UndoManagerはredo()にも対応しています。 registerUndoをちょっと工夫して書くことになります。
//
//func addMember(name: String) {
//    members.add(name)
//    undoManager.registerUndo(withTarget: members) {
//        $0.remove(name)
//
//        // 以下を追加する（元に戻すを、更に元に戻す）
//        undoManager.registerUndo(withTarget: members) {
//            $0.add(name)
//        }
//    }
//}
//
//addMember(name: "Jiro")
//// member == ["Taro", "Hanako", "Jiro"]
//
//if undoManager.canUndo {
//    undoManager.undo()
//    // member == ["Taro", "Hanako"]
//}
//
//if undoManager.canRedo {
//    undoManager.redo()
//    // member == ["Taro", "Hanako", "Jiro"]
//}
//
//
//// ベージックな実装#
//// UndoManagerを使用したシンプルな実装は、以下の通りです。
//
//let undoManager: UndoManager
//var members: NSMutableArray = ["Taro", "Hanako"]
//
//init() {
//    // 便宜上ここに記述するが、どこに書いても問題はない
//    undoManager = UndoManager()
//}
//
//func addMember(name: String) {
//    // 通常のオペレーション
//    members.add(name)
//
//    // Undo操作をhandlerに登録
//    undoManager.registerUndo(withTarget: members) {
//        // クロージャの第一引数 $0 は、Targetで指定したmembersのこと
//        $0.remove(name)
//    }
//}
//
//addMember(name: "Jiro")
//// member == ["Taro", "Hanako", "Jiro"]
//
//// canUndoプロパティで、元に戻せることをチェックできる
//if undoManager.canUndo {
//    undoManager.undo()
//    // member == ["Taro", "Hanako"]
//}
