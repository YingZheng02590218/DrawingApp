//
//  SidemenuTableViewHeaderFooterView.swift
//  APIClientApp
//
//  Created by Hisashi Ishihara on 2023/12/11.
//

import UIKit

class SidemenuTableViewHeaderFooterView: UITableViewHeaderFooterView {

    // 画像
    @IBOutlet var leftImageView: UIImageView!
    // ラベル
    @IBOutlet var titleLabel: UILabel!

    
    func setup(leftImage: String, title: String, isShown: Bool, hasChild: Bool) {
        leftImageView.image = UIImage(named: leftImage)
        titleLabel.text = title
    }

}
