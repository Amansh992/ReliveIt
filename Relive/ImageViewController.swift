//
//  ImageViewController.swift
//  Relive
//
//  Created by Ayush Nimiwal on 10/12/24.
//

import UIKit

class ImageViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    var image : UIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        imageView.image = image
    }
    

}
