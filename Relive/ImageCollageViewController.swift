//
//  ImageCollageViewController.swift
//  Relive
//
//  Created by Ayush Nimiwal on 10/12/24.
//

import UIKit

class ImageCollageViewController: UIViewController {
    
    var images : [UIImage]?
    @IBOutlet weak var imageView: UIImageView!
    private var currentIndex = 0
    private var timer: Timer?
    
    @IBOutlet weak var progressBar: UIProgressView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        progressBar.progress = 0.0
        if let images = images, !images.isEmpty {
            startImageSlideshow(images: images)
        }
    }
    
    private func startImageSlideshow(images: [UIImage]) {
        imageView.image = images[currentIndex]
        progressBar.progress = 0.0
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateImage(images: images)
        }
    }
    
    private func updateImage(images: [UIImage]) {
        currentIndex = (currentIndex + 1) % images.count
        imageView.image = images[currentIndex]
        let progress = Float(currentIndex + 1) / Float(images.count)
        progressBar.setProgress(progress, animated: true)
        if currentIndex == images.count - 1 {
            progressBar.setProgress(1.0, animated: true)
        }
    }
    
    deinit {
        timer?.invalidate()
    }

}
