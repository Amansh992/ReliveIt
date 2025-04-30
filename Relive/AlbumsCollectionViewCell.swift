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
    
    private var blurEffectView: UIVisualEffectView?
    weak var delegate: AlbumsAlertViewCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // Existing setup code
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        title.font = UIFont.boldSystemFont(ofSize: 18)
        title.textColor = .white
        title.shadowColor = UIColor.black.withAlphaComponent(0.5)
        title.shadowOffset = CGSize(width: 0, height: 1)
        setupProfileImage(p1Image)
        setupProfileImage(p2Image)
        addBlurEffect()
        
        // Ensure imageView has a background color to avoid transparency issues
        imageView.backgroundColor = UIColor.systemBackground // Adapts to light/dark mode
    }
    
    func configure(with image: UIImage?, titleText: String, sharedUsers: [User]) {
        // Set image or use SF Symbol as placeholder
        if let image = image {
            imageView.image = image
            imageView.contentMode = .scaleAspectFill // Use fill for actual images
        } else {
            // Use SF Symbol "photo" as placeholder
            let placeholderImage = UIImage(systemName: "photo")?.withRenderingMode(.alwaysTemplate)
            imageView.image = placeholderImage
            imageView.contentMode = .center // Center the symbol
            imageView.tintColor = UIColor.systemGray // Neutral color for light/dark mode
        }
        
        title.text = titleText
        
        // Reset profile images
        p1Image.isHidden = true
        p2Image.isHidden = true
        
        // Configure profile images for shared users
        if !sharedUsers.isEmpty {
            if let u1ProfileImageData = sharedUsers[0].profileImages.first,
               let u1ProfileImage = UIImage(data: u1ProfileImageData) {
                p1Image.image = u1ProfileImage
                p1Image.isHidden = false
            }
            if sharedUsers.count >= 2,
               let u2ProfileImageData = sharedUsers[1].profileImages.first,
               let u2ProfileImage = UIImage(data: u2ProfileImageData) {
                p2Image.image = u2ProfileImage
                p2Image.isHidden = false
            }
        }
    }
    
    private func setupProfileImage(_ imageView: UIImageView) {
        imageView.layer.cornerRadius = imageView.frame.height / 2
        imageView.layer.borderWidth = 2.0
        imageView.layer.borderColor = UIColor.white.cgColor
        imageView.clipsToBounds = true
        imageView.layer.shadowColor = UIColor.black.cgColor
        imageView.layer.shadowOffset = CGSize(width: 0, height: 1)
        imageView.layer.shadowRadius = 2
        imageView.layer.shadowOpacity = 0.5
    }
    
    private func addBlurEffect() {
        blurEffectView?.removeFromSuperview()
        let blurEffect = UIBlurEffect(style: .dark)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        let blurHeight = view.bounds.height * 0.3
        blurEffectView.frame = CGRect(
            x: 0,
            y: view.bounds.height - blurHeight,
            width: view.bounds.width,
            height: blurHeight
        )
        blurEffectView.clipsToBounds = true
        blurEffectView.layer.cornerRadius = 12
        blurEffectView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        view.insertSubview(blurEffectView, aboveSubview: imageView)
        self.blurEffectView = blurEffectView
        addGradientOverlay()
    }
    
    private func addGradientOverlay() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.4).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 0.5)
        gradientLayer.frame = view.bounds
        view.layer.insertSublayer(gradientLayer, above: imageView.layer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
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
