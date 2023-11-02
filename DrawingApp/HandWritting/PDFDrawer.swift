//
//  PDFDrawer.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/11/02.
//

import Foundation
import PDFKit

enum DrawingTool: Int {
    case eraser = 0
    case pencil = 1
    case pen = 2
    case highlighter = 3
    
    var width: CGFloat {
        switch self {
        case .pencil:
            return 1
        case .pen:
            return 5
        case .highlighter:
            return 10
        default:
            return 0
        }
    }
    
    var alpha: CGFloat {
        switch self {
        case .highlighter:
            return 0.3 //0,5
        default:
            return 1
        }
    }
}

class PDFDrawer {
    // 手書きモード
    var isActive = false
    weak var pdfView: PDFView!
    private var path: UIBezierPath?
    private var currentAnnotation : DrawingAnnotation?
    private var currentPage: PDFPage?
    var drawingTool = DrawingTool.pen
    var color = UIColor.red // default color is red
    var lineWidth: CGFloat = 5.0
    var dashPattern: [CGFloat] = [1.0, 5.0]

    func changeTool(tool: DrawingTool) {
        self.drawingTool = tool
    }
    
    func changeColor(color: UIColor) {
        self.color = color
    }
    
    func changeLineWidth(lineWidth: CGFloat) {
        self.lineWidth = lineWidth
    }
}

extension PDFDrawer: DrawingGestureRecognizerDelegate {
    func gestureRecognizerBegan(_ location: CGPoint) {
        if isActive {
            guard let page = pdfView.page(for: location, nearest: true) else { return }
            currentPage = page
            let convertedPoint = pdfView.convert(location, to: currentPage!)
            path = UIBezierPath()
            path?.lineCapStyle = .round
            path?.lineWidth = self.lineWidth
            dashPattern = [self.lineWidth, self.lineWidth]
            // 第一引数 点線の大きさ, 点線間の間隔
            // 第二引数 第一引数で指定した配列の要素数
            // 第三引数 開始位置
            path?.setLineDash(dashPattern, count: dashPattern.count, phase: 0)
            path?.move(to: convertedPoint)
        }
    }
    
    func gestureRecognizerMoved(_ location: CGPoint) {
        if isActive {
            guard let page = currentPage else { return }
            let convertedPoint = pdfView.convert(location, to: page)
            
            print(convertedPoint)
            
            if drawingTool == .eraser {
                removeAnnotationAtPoint(point: convertedPoint, page: page)
                return
            }
            
            path?.addLine(to: convertedPoint)
            path?.move(to: convertedPoint)
            
            drawAnnotation(onPage: page)
        }
    }
    
    func gestureRecognizerEnded(_ location: CGPoint) {
        if isActive {
            guard let page = currentPage else { return }
            let convertedPoint = pdfView.convert(location, to: page)
            
            // Erasing
            if drawingTool == .eraser {
                removeAnnotationAtPoint(point: convertedPoint, page: page)
                return
            }
            
            // Drawing
            guard let _ = currentAnnotation else { return }
            
            if let path = path {
                path.addLine(to: convertedPoint)
                path.move(to: convertedPoint)
                // 終わる
                path.close()
                
                // Final annotation
                page.removeAnnotation(currentAnnotation!)
                let finalAnnotation = createFinalAnnotation(path: path, page: page)
                currentAnnotation = nil
            }
        }
    }
    // TODO: pathを使用していない
    private func createAnnotation(path: UIBezierPath, page: PDFPage) -> DrawingAnnotation {
        let border = PDFBorder()
        border.lineWidth = lineWidth//drawingTool.width
        border.style = .dashed
        border.dashPattern = dashPattern

        let annotation = DrawingAnnotation(bounds: page.bounds(for: pdfView.displayBox), forType: .ink, withProperties: nil)
        annotation.color = color.withAlphaComponent(drawingTool.alpha)
        annotation.border = border
        return annotation
    }
    
    private func drawAnnotation(onPage: PDFPage) {
        guard let path = path else { return }
        
        if currentAnnotation == nil {
            currentAnnotation = createAnnotation(path: path, page: onPage)
        }
        
        currentAnnotation?.path = path
        forceRedraw(annotation: currentAnnotation!, onPage: onPage)
    }
    
    private func createFinalAnnotation(path: UIBezierPath, page: PDFPage) -> PDFAnnotation {
        let border = PDFBorder()
        border.lineWidth = lineWidth//drawingTool.width
        border.style = .dashed
        border.dashPattern = dashPattern

        let bounds = CGRect(x: path.bounds.origin.x - 5,
                            y: path.bounds.origin.y - 5,
                            width: path.bounds.size.width + 10,
                            height: path.bounds.size.height + 10)
//        var signingPathCentered = UIBezierPath()
//        signingPathCentered.cgPath = path.cgPath
        path.moveCenter(to: bounds.center)
        path.lineCapStyle = .round

        // 第一引数 点線の大きさ, 点線間の間隔
        // 第二引数 第一引数で指定した配列の要素数
        // 第三引数 開始位置
        path.setLineDash(dashPattern, count: dashPattern.count, phase: 0)
        
        let annotation = PDFAnnotation(bounds: bounds, forType: .ink, withProperties: nil)
        annotation.color = color.withAlphaComponent(drawingTool.alpha)
        annotation.border = border
        annotation.add(path)
        page.addAnnotation(annotation)
                
        return annotation
    }
    
    private func removeAnnotationAtPoint(point: CGPoint, page: PDFPage) {
        if let selectedAnnotation = page.annotationWithHitTest(at: point) {
            selectedAnnotation.page?.removeAnnotation(selectedAnnotation)
        }
    }
    
    private func forceRedraw(annotation: PDFAnnotation, onPage: PDFPage) {
        onPage.removeAnnotation(annotation)
        onPage.addAnnotation(annotation)
    }
}
