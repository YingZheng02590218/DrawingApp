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
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView?.image = nil
    }
}
