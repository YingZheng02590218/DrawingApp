//
//  String+extension.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/11/14.
//

import UIKit

extension String {
    func size(with font: UIFont) -> CGSize {
        let attributes = [NSAttributedString.Key.font : font]
        return (self as NSString).size(withAttributes: attributes)
    }
}
