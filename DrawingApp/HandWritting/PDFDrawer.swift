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

// 手書きのアノテーションを追加する処理
protocol DrawingManageAnnotationDelegate: AnyObject {
    func addAnnotation(_ currentAnnotation : DrawingAnnotation)
}

class PDFDrawer {
    // 手書きモード
    var isActive = false
    weak var pdfView: PDFView!
    private var path: UIBezierPath?
    private var currentLocation: CGPoint?
    private var currentAnnotation : DrawingAnnotation?
    private var currentPage: PDFPage?
    var drawingTool = DrawingTool.pen
    var color = UIColor.red // default color is red
    var lineWidth: CGFloat = 10.0
    var dashPattern: DashPattern = .pattern1
    
    // 手書きのアノテーションを追加する処理
    weak var drawingManageAnnotationDelegate: DrawingManageAnnotationDelegate?
    
    func changeTool(tool: DrawingTool) {
        self.drawingTool = tool
    }
    
    func changeColor(color: UIColor) {
        self.color = color
    }
    
    func changeLineWidth(lineWidth: CGFloat) {
        self.lineWidth = lineWidth
    }
    
    func changeDashPattern(dashPattern: DashPattern) {
        self.dashPattern = dashPattern
    }
}

extension PDFDrawer: DrawingGestureRecognizerDelegate {
    func gestureRecognizerBegan(_ location: CGPoint) {
        if isActive {
            // ペン先の位置
            currentLocation = location
            
            guard let page = pdfView.page(for: location, nearest: true) else { return }
            currentPage = page
            let convertedPoint = pdfView.convert(location, to: currentPage!)
            // UIBezierPath のインスタンス生成
            path = UIBezierPath()
            path?.lineCapStyle = .square
            path?.lineJoinStyle = .round
            path?.lineWidth = self.lineWidth
            // path?.flatness = 30.0
            if dashPattern == .pattern1 {
                
            } else {
                // 第一引数 点線の大きさ, 点線間の間隔
                // 第二引数 第一引数で指定した配列の要素数
                // 第三引数 開始位置
                path?.setLineDash(dashPattern.style(width: lineWidth), count: dashPattern.style(width: lineWidth).count, phase: 0)
            }
            // 起点
            path?.move(to: convertedPoint)
        }
    }
    
    func gestureRecognizerMoved(_ location: CGPoint) {
        if isActive {
            // ペン先の位置
            if let currentLocation = currentLocation,
               location.x >= currentLocation.x + lineWidth || location.y >= currentLocation.y + lineWidth ||
                location.x <= currentLocation.x - lineWidth || location.y <= currentLocation.y - lineWidth {
                print(self.currentLocation!.x, location.x)
                print(self.currentLocation!.y, location.y)
                self.currentLocation = location
                
                guard let page = currentPage else { return }
                let convertedPoint = pdfView.convert(location, to: page)
                
                print(convertedPoint)
                
                if drawingTool == .eraser {
                    removeAnnotationAtPoint(point: convertedPoint, page: page)
                    return
                }
                // 帰着点
                path?.addLine(to: convertedPoint)
                // path?.move(to: convertedPoint)
                
                drawAnnotation(onPage: page)
            } else {
                print(self.currentLocation!.x, location.x)
                print(self.currentLocation!.y, location.y)
            }
        }
    }
    
    func gestureRecognizerEnded(_ location: CGPoint) {
        if isActive {
            // ペン先の位置
            currentLocation = nil
            
            guard let page = currentPage else { return }
            let convertedPoint = pdfView.convert(location, to: page)
            
            // Erasing
            if drawingTool == .eraser {
                removeAnnotationAtPoint(point: convertedPoint, page: page)
                return
            }
            
            // Drawing
            guard let _ = currentAnnotation else { return }
            
            if let path = self.path {
                // 帰着点
                path.addLine(to: convertedPoint)
                // path.move(to: convertedPoint)
                // ラインを結ぶ
                // path.close()
                
                // Final annotation
                page.removeAnnotation(self.currentAnnotation!)
                // このアノテーションをDrawingViewControllerへ渡してから、追加する
                let finalAnnotation = createFinalAnnotation(path: path, page: page)
                drawingManageAnnotationDelegate?.addAnnotation(finalAnnotation)
                currentAnnotation = nil
            }
        }
    }
    // TODO: pathを使用していない
    private func createAnnotation(path: UIBezierPath, page: PDFPage) -> DrawingAnnotation {
        let border = PDFBorder()
        border.lineWidth = lineWidth//drawingTool.width
        border.style = dashPattern == .pattern1 ? .solid : .dashed
        border.dashPattern = dashPattern == .pattern1 ? nil : dashPattern.style(width: lineWidth)
        
        let annotation = DrawingAnnotation(bounds: page.bounds(for: pdfView.displayBox), forType: .ink, withProperties: nil)
        annotation.color = color//.withAlphaComponent(drawingTool.alpha)
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
    
    private func createFinalAnnotation(path: UIBezierPath, page: PDFPage) -> DrawingAnnotation {
        let border = PDFBorder()
        border.lineWidth = lineWidth//drawingTool.width
        border.style = dashPattern == .pattern1 ? .solid : .dashed
        border.dashPattern = dashPattern == .pattern1 ? nil : dashPattern.style(width: lineWidth)
        
        let bounds = CGRect(x: path.bounds.origin.x,
                            y: path.bounds.origin.y,
                            width: path.bounds.size.width,
                            height: path.bounds.size.height)
        //        var signingPathCentered = UIBezierPath()
        //        signingPathCentered.cgPath = path.cgPath
        //        path.moveCenter(to: bounds.center)
        path.lineCapStyle = .square
        path.lineJoinStyle = .round
        path.lineWidth = self.lineWidth
        
        if dashPattern == .pattern1 {
            
        } else {
            // 第一引数 点線の大きさ, 点線間の間隔
            // 第二引数 第一引数で指定した配列の要素数
            // 第三引数 開始位置
            path.setLineDash(dashPattern.style(width: lineWidth), count: dashPattern.style(width: lineWidth).count, phase: 0)
        }
        let annotation = DrawingAnnotation(bounds: bounds, forType: .ink, withProperties: nil)
        annotation.color = color//.withAlphaComponent(drawingTool.alpha)
        annotation.border = border
        // 効かない
        // annotation.add(path)
        annotation.path = path
        page.addAnnotation(annotation)
        
        return annotation
    }
    
    private func removeAnnotationAtPoint(point: CGPoint, page: PDFPage) {
        if let selectedAnnotation = page.annotationWithHitTest(at: point) {
            selectedAnnotation.page?.removeAnnotation(selectedAnnotation)
        }
    }
    
    private func forceRedraw(annotation: DrawingAnnotation, onPage: PDFPage) {
        onPage.removeAnnotation(annotation)
        onPage.addAnnotation(annotation)
    }
}
