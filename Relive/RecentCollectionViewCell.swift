//
//  RecentCollectionViewCell.swift
//  Relive
//
//  Created by Ayush Nimiwal on 06/12/24.
//

import UIKit

protocol AlertViewCellDelegate: AnyObject {
    func didTapViewButton(in cell: RecentCollectionViewCell)
}


class RecentCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var image: UIImageView!
    
    @IBOutlet weak var p1Image: UIImageView!
    
    @IBOutlet weak var p2Image: UIImageView!
    
    weak var delegate : AlertViewCellDelegate?
    
    
    override func awakeFromNib() {
        image.layer.cornerRadius = 20
        p1Image.layer.cornerRadius = p1Image.frame.height / 2
        p1Image.layer.borderWidth = 2.0
        p1Image.layer.borderColor = UIColor.gray.cgColor
        p1Image.clipsToBounds = true
        p2Image.layer.cornerRadius = p2Image.frame.height / 2
        p2Image.layer.borderWidth = 2.0
        p2Image.layer.borderColor = UIColor.gray.cgColor
        p2Image.clipsToBounds = true
    }
    
    @IBAction func moreButton(_ sender: UIButton) {
        delegate?.didTapViewButton(in: self)
        
    }
}
