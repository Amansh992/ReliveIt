//
//  HighlightCollectionViewCell.swift
//  Relive
//
//  Created by Ayush Nimiwal on 06/12/24.
//

import UIKit

class HighlightCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var title: UILabel!
    
    @IBOutlet weak var date: UILabel!
    @IBOutlet weak var view: UIView!
    
    
    override func awakeFromNib() {
        image.layer.cornerRadius = 12
        view.layer.cornerRadius = 12
    }
}
