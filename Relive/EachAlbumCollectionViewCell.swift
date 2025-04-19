//
//  EachAlbumCollectionViewCell.swift
//  Relive
//
//  Created by Ayush Nimiwal on 10/12/24.
//

import UIKit

class EachAlbumCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var pImage: UIImageView!
    
    override func awakeFromNib() {
        imageView.layer.cornerRadius = 20
        pImage.layer.cornerRadius = pImage.frame.height / 2
        pImage.layer.borderWidth = 2.0
        pImage.layer.borderColor = UIColor.gray.cgColor
        pImage.clipsToBounds = true
    }
    
}
