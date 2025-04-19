import UIKit

protocol AlbumsAlertViewCellDelegate: AnyObject {
    func didTapViewButton(in cell: AlbumsCollectionViewCell)
    func didTapRelive(in cell: AlbumsCollectionViewCell)
}

class AlbumsCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var p1Image: UIImageView!
    @IBOutlet weak var view: UIView!
    @IBOutlet weak var p2Image: UIImageView!
    
    // New properties for blur effect
    private var blurEffectView: UIVisualEffectView?
    
    weak var delegate: AlbumsAlertViewCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Setup rounded corners for the main view
        view.layer.cornerRadius = 12 // Reduced from 20 to match the image
        view.clipsToBounds = true // Ensure content is clipped to rounded corners
        
        // Setup imageView to match the view's corner radius
        imageView.layer.cornerRadius = 12 // Same as the view
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        
        // Make the title text bold and with a shadow for better visibility
        title.font = UIFont.boldSystemFont(ofSize: 18)
        title.textColor = .white
        title.shadowColor = UIColor.black.withAlphaComponent(0.5)
        title.shadowOffset = CGSize(width: 0, height: 1)
        
        // Setup profile images
        setupProfileImage(p1Image)
        setupProfileImage(p2Image)
        
        // Add blur effect for the bottom part of the image
        addBlurEffect()
    }
    
    private func setupProfileImage(_ imageView: UIImageView) {
        imageView.layer.cornerRadius = imageView.frame.height / 2
        imageView.layer.borderWidth = 2.0
        imageView.layer.borderColor = UIColor.white.cgColor
        imageView.clipsToBounds = true
        
        // Add a subtle shadow to make profile images pop
        imageView.layer.shadowColor = UIColor.black.cgColor
        imageView.layer.shadowOffset = CGSize(width: 0, height: 1)
        imageView.layer.shadowRadius = 2
        imageView.layer.shadowOpacity = 0.5
    }
    
    private func addBlurEffect() {
        // Remove any existing blur view
        blurEffectView?.removeFromSuperview()
        
        // Create a blur effect
        let blurEffect = UIBlurEffect(style: .dark)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        
        // Calculate the height needed for the blur (where text and buttons are)
        let blurHeight = view.bounds.height * 0.3
        
        // Position the blur at the bottom of the image
        blurEffectView.frame = CGRect(
            x: 0,
            y: view.bounds.height - blurHeight,
            width: view.bounds.width,
            height: blurHeight
        )
        
        // Set corner radius to match the bottom of the view
        blurEffectView.clipsToBounds = true
        blurEffectView.layer.cornerRadius = 12 // Match view's corner radius
        blurEffectView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        
        // Add the blur view between the image and other content
        view.insertSubview(blurEffectView, aboveSubview: imageView)
        
        // Store reference to blur view
        self.blurEffectView = blurEffectView
        
        // Add a semi-transparent gradient overlay for smoother transition
        addGradientOverlay()
    }
    
    private func addGradientOverlay() {
        // Create a gradient layer
        let gradientLayer = CAGradientLayer()
        
        // Set colors from transparent to semi-black
        gradientLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.4).cgColor
        ]
        
        // Set the gradient direction (top to bottom)
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 0.5)
        
        // Set frame to match the cell
        gradientLayer.frame = view.bounds
        
        // Add gradient to the view layer
        view.layer.insertSublayer(gradientLayer, above: imageView.layer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Update blur frame if the cell size changes
        if let blurView = blurEffectView {
            let blurHeight = view.bounds.height * 0.3
            blurView.frame = CGRect(
                x: 0,
                y: view.bounds.height - blurHeight,
                width: view.bounds.width,
                height: blurHeight
            )
        }
    }
    
    @IBAction func moreButton(_ sender: UIButton) {
        delegate?.didTapViewButton(in: self)
    }
    
    @IBAction func ReliveButton(_ sender: Any) {
        delegate?.didTapRelive(in: self)
    }
}
