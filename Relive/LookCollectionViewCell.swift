//
//  LookCollectionViewCell.swift
//  Relive
//
//  Created by Ayush Nimiwal on 06/12/24.
//

import UIKit


class LookCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var image: UIImageView!
    
    @IBOutlet weak var profileImage: UIImageView!
    
    @IBOutlet weak var userName: UILabel!
    
    @IBOutlet weak var message: UILabel!
    
    @IBOutlet weak var letrecap: UILabel!
    
    @IBOutlet weak var view: UIView!
    
    override func awakeFromNib() {
        image.layer.cornerRadius = 20
        view.layer.cornerRadius = 20
        profileImage.layer.cornerRadius = profileImage.frame.height/2
        letrecap.layer.cornerRadius = 20
        letrecap.clipsToBounds = true
        
    }
    
}
