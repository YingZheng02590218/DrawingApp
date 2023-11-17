//
//  PDFThumbnailCollectionViewController.swift
//  DrawingApp
//
//  Created by Hisashi Ishihara on 2023/11/16.
//

import UIKit
import PDFKit

/// Delegate that is informed of important interaction events with the current thumbnail collection view
protocol PDFThumbnailControllerDelegate: class {
    /// User has tapped on thumbnail
    func didSelectIndexPath(_ indexPath: IndexPath)
}

/// Bottom collection of thumbnails that the user can interact with
internal final class PDFThumbnailCollectionViewController: UICollectionViewController {
    /// Current document being displayed
    var document: PDFDocumentForList!
    
    /// Current page index being displayed
    var currentPageIndex: Int = 0 {
        didSet {
            guard let collectionView = collectionView else { return }
            guard let pageImages = pageImages else { return }
            guard pageImages.count > 0 else { return }
            let curentPageIndexPath = IndexPath(row: currentPageIndex, section: 0)
//            if !collectionView.indexPathsForVisibleItems.contains(curentPageIndexPath) {
                collectionView.scrollToItem(at: curentPageIndexPath, at: .centeredVertically, animated: true)
//            }
            collectionView.reloadData()
        }
    }
    
    /// Calls actions when certain cells have been interacted with
    weak var delegate: PDFThumbnailControllerDelegate?
    
    /// Small thumbnail image representations of the pdf pages
    private var pageImages: [UIImage]? {
        didSet {
            collectionView?.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        DispatchQueue.global(qos: .background).async {
            self.document.allPageImages(callback: { (images) in
                DispatchQueue.main.async {
                    self.pageImages = images
                }
            })
        }
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return pageImages?.count ?? 0
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! PDFThumbnailCell
        
        cell.imageView?.image = pageImages?[indexPath.row]
        // cell.alpha = currentPageIndex == indexPath.row ? 1 : 0.2
        
        return cell
    }
    
    @objc func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: IndexPath) -> CGSize {
        return PDFThumbnailCell.cellSize
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.didSelectIndexPath(indexPath)
    }
    
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        DispatchQueue.main.async {
            cell.alpha = self.currentPageIndex == indexPath.row ? 0.2 : 1
        }
    }
}
