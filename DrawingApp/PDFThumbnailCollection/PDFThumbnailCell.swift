//
//  PDFThumbnailCell.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/11/16.
//

import UIKit

/// An individual thumbnail in the collection view
internal final class PDFThumbnailCell: UICollectionViewCell {
    /// Preferred size of each cell
    static let cellSize = CGSize(width: 80, height: 120)
    
    @IBOutlet var imageView: UIImageView?
    @IBOutlet var pageNumberLabel: UILabel!
    
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView?.image = nil
        pageNumberLabel?.text = ""
        isSelected = false
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // セルの枠線の太さを変える
        self.contentView.layer.borderWidth = self.isSelected ? 2 : 0
        self.contentView.layer.borderColor = UIColor.red.cgColor
    }
    
    override var isSelected: Bool {
        didSet {
            // セルの選択状態変化に応じて表示を切り替える
            self.onUpdateSelection()
        }
    }
    
    private func onUpdateSelection() {
        self.contentView.layer.borderWidth = self.isSelected ? 2 : 0
    }
}
