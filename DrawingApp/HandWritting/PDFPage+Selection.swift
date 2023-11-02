//
//  PDFPage+Selection.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/11/02.
//

import UIKit
import PDFKit

extension PDFPage {
    func annotationWithHitTest(at: CGPoint) -> PDFAnnotation? {
        for annotation in annotations {
                if annotation.contains(point: at) {
                return annotation
            }
        }
        return nil
    }
}
