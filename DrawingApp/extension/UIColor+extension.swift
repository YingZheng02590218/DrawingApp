//
//  UIColor+extension.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/11/22.
//

import UIKit

extension UIColor {
    // 輝度を暗くする
    func dark(brightnessRatio: CGFloat = 0.8) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        if getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            return UIColor(hue: hue, saturation: saturation, brightness: brightness * brightnessRatio, alpha: alpha)
        } else {
            return self
        }
    }
}
