//
//  DrawingAppTests.swift
//  DrawingAppTests
//
//  Created by Hisashi Ishihara on 2023/11/14.
//

import XCTest
@testable import DrawingApp
import PDFKit


final class DrawingAppTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testCounter() {
        let counter = UndoRedoManager()
        
        var inputText: String = "a"
    var fontSize: CGFloat = 8
        // PDFのタップされた位置の座標
        var point: CGPoint = CGPoint(x: 10, y: 10)
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
        // UUID
        freeText.userName = UUID().uuidString
        
        let freeText2 = PDFAnnotation(
            bounds: CGRect(x: point.x, y: point.y, width: size.width + 5, height: size.height + 5),
            forType: .freeText,
            withProperties: attributes
        )
        // UUID
        freeText2.userName = UUID().uuidString
        freeText2.contents = "あ"
        
        
        let freeText3 = PDFAnnotation(
            bounds: CGRect(x: point.x, y: point.y, width: size.width + 5, height: size.height + 5),
            forType: .freeText,
            withProperties: attributes
        )
        // UUID
        freeText3.userName = UUID().uuidString
        freeText3.contents = "ア"

        print("\n### スタート")
        counter.addAnnotation(freeText)
        XCTAssertEqual(counter.showTeamMembers(), 1)
        
        counter.addAnnotation(freeText2)
        XCTAssertEqual(counter.showTeamMembers(), 2)
        
        counter.deleteAnnotation(freeText)
        XCTAssertEqual(counter.showTeamMembers(), 1)

        counter.undo() { _ in
            XCTAssertEqual(counter.showTeamMembers(), 2)
        }
        counter.undo() { _ in
            XCTAssertEqual(counter.showTeamMembers(), 1)
        }
        counter.undo() { _ in
            XCTAssertEqual(counter.showTeamMembers(), 0)
        }
        counter.redo() { _ in
            XCTAssertEqual(counter.showTeamMembers(), 1)
            counter.showTeamMembers { annos in
                annos.map { print($0.userName, $0.contents) }
            }
        }
        counter.redo() { _ in
            XCTAssertEqual(counter.showTeamMembers(), 2)
        }
        counter.addAnnotation(freeText3)
        XCTAssertEqual(counter.showTeamMembers(), 3)
        
        counter.redo() { _ in
            XCTAssertEqual(counter.showTeamMembers(), 3)
        }
        counter.undo() { _ in
            XCTAssertEqual(counter.showTeamMembers(), 2)
        }
        print("### エンド\n")
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

}
