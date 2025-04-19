//
//  ChoosePhotoCollectionViewCell.swift
//  Relive
//
//  Created by Ayush Nimiwal on 10/12/24.
//

import UIKit

class ChoosePhotoCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var view: UIView!
    
    private var checkmarkImageView: UIImageView!
    
    var isSelectedForCheckmark: Bool = false {
        didSet {
            checkmarkImageView.isHidden = !isSelectedForCheckmark
            view.isHidden = !isSelectedForCheckmark
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupCell()
    }
    
    private func setupCell() {
        // Configure image view
        imageView.layer.cornerRadius = 20
        imageView.clipsToBounds = true
        
        // Configure view overlay
        view.layer.cornerRadius = 20
        view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        view.isHidden = true
        
        // Setup checkmark
        setupCheckmarkAccessory()
    }
    
    private func setupCheckmarkAccessory() {
        checkmarkImageView = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        checkmarkImageView.tintColor = .systemBlue
        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(checkmarkImageView)
        
        NSLayoutConstraint.activate([
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 30),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 30),
            checkmarkImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            checkmarkImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10)
        ])
        
        checkmarkImageView.isHidden = true
    }
}
