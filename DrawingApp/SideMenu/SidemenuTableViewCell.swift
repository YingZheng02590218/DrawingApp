//
//  SidemenuTableViewCell.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/11/14.
//

import UIKit

class SidemenuTableViewCell: UITableViewCell {

    // 左　画像
    @IBOutlet var leftImageView: UIImageView!
    // ラベル
    @IBOutlet var titleLabel: UILabel!
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func setup(leftImage: String, title: String) {
        leftImageView.image = UIImage(named: leftImage)
        titleLabel.text = title
    }
}
