//
//  IconTableViewCell.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/10/02.
//

import UIKit

class IconTableViewCell: UITableViewCell {
    @IBOutlet var leftImageView: UIImageView!
    @IBOutlet var centerLabel: UILabel!
    @IBOutlet var subLabel: UILabel!

    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
