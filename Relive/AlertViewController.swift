
//
//  AlertViewController.swift
//  Relive
//
//  Created by Ayush Nimiwal on 09/12/24.
//

import UIKit
import Foundation

class AlertViewController: UIViewController {
    
    @IBOutlet weak var outerView: UIView!
    @IBOutlet weak var innerView: UIView!
    @IBOutlet weak var actionButton: UIButton!
    
    // Title label as a property (not an IBOutlet since we'll create it programmatically)
    private var titleLabel: UILabel?
    
    private var imageViews: [UIImageView] = []
    var users: [User]? = []
    private var selectedUsers: Set<String> = []
    var isSelectionEnabled: Bool? = false
    var isAlbum: Bool = false // Add this property
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Find and update the existing title label
        findAndUpdateTitleLabel()
        
        outerView.layer.cornerRadius = 20
        addTopAndBottomBorders(to: innerView, borderColor: UIColor.gray, borderWidth: 1.0)
        actionButton.setTitle(isSelectionEnabled! ? "Share" : "Cancel", for: .normal)
        
        // Now lay out user images if any exist
        if let users = users, !users.isEmpty {
            layoutUserImages()
        }
    }
    
    // This method will find the title label in the view hierarchy and update its text
    private func findAndUpdateTitleLabel() {
        // First, check if we can find the label by recursive search
        if let titleLabel = findLabelWithText("This Photo is Shared With") {
            // Found the label, update its text if needed
            if isAlbum {
                titleLabel.text = "This Album is Shared With"
            }
            self.titleLabel = titleLabel
        } else {
            // If we can't find the existing label, create a new one
            createTitleLabel()
        }
    }
    
    // Helper method to recursively search for a UILabel with specific text
    private func findLabelWithText(_ text: String, in view: UIView? = nil) -> UILabel? {
        let searchView = view ?? self.view
        
        // Check all subviews
        for subview in searchView?.subviews ?? [] {
            if let label = subview as? UILabel, label.text == text {
                return label
            }
            
            // Recursively search in subviews
            if let foundLabel = findLabelWithText(text, in: subview) {
                return foundLabel
            }
        }
        
        return nil
    }
    
    // If we can't find the existing label, create a new one
    private func createTitleLabel() {
        let newTitleLabel = UILabel()
        newTitleLabel.textAlignment = .center
        newTitleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        newTitleLabel.text = isAlbum ? "This Album is Shared With" : "This Photo is Shared With"
        
        // Add it to the view
        if let outerView = outerView {
            outerView.addSubview(newTitleLabel)
            
            // Position it at the top of outerView
            newTitleLabel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                newTitleLabel.topAnchor.constraint(equalTo: outerView.topAnchor, constant: 16),
                newTitleLabel.leadingAnchor.constraint(equalTo: outerView.leadingAnchor, constant: 16),
                newTitleLabel.trailingAnchor.constraint(equalTo: outerView.trailingAnchor, constant: -16),
            ])
        }
        
        self.titleLabel = newTitleLabel
    }
    
    func addTopAndBottomBorders(to view: UIView, borderColor: UIColor, borderWidth: CGFloat) {
        let topBorder = CALayer()
        topBorder.backgroundColor = borderColor.cgColor
        topBorder.frame = CGRect(x: 0, y: 0, width: view.frame.size.width, height: borderWidth)
        view.layer.addSublayer(topBorder)
        
        let bottomBorder = CALayer()
        bottomBorder.backgroundColor = borderColor.cgColor
        bottomBorder.frame = CGRect(x: 0, y: view.frame.size.height - borderWidth, width: view.frame.size.width, height: borderWidth)
        view.layer.addSublayer(bottomBorder)
    }
    
    @IBAction func cancelButton(_ sender: Any) {
        if isSelectionEnabled! {
            // Handle share action
            print("Selected Users for sharing: \(selectedUsers)")
            
            if let image = (presentingViewController as? PhotoCaptureViewController)?.imageView.image,
               let imageData = image.jpegData(compressionQuality: 0.8) {
                // Share the photo with selected users via Supabase
                SupabaseManager.shared.addImageToSharedAlbum(albumId: UserDefaults.standard.string(forKey: "AutoShareAlbumId") ?? UUID().uuidString, image: imageData) { success in
                    if success {
                        print("Photo added to album successfully")
                        
                        // Update shared_with_user_ids for the image
                        SupabaseManager.shared.updateSharedWithUsers(userId: SessionManager.shared.getSession() ?? "", sharedWithUserIds: Array(self.selectedUsers)) { success in
                            if success {
                                print("Updated shared_with_user_ids successfully")
                            } else {
                                print("Failed to update shared_with_user_ids")
                            }
                        }
                    } else {
                        print("Failed to add photo to album")
                    }
                }
            }
            
            NotificationCenter.default.post(name: Foundation.Notification.Name("AlertViewControllerDismissed"), object: nil)
            dismiss(animated: true, completion: nil)
        } else {
            // Dismiss the view
            NotificationCenter.default.post(name: Foundation.Notification.Name("AlertViewControllerDismissed"), object: nil)
            dismiss(animated: true, completion: nil)
        }
    }
    
    private func layoutUserImages() {
        guard let users = users, let innerView = innerView, innerView.bounds.width > 0 else {
            print("Cannot layout images: users are nil or innerView is not ready")
            return
        }
        
        // Clear existing image views
        imageViews.forEach { $0.removeFromSuperview() }
        imageViews.removeAll()
        
        let imageSize: CGFloat = 40
        let horizontalSpacing: CGFloat = 18
        let verticalSpacing: CGFloat = 16
        let containerWidth = innerView.frame.width
        
        var xOffset: CGFloat = horizontalSpacing
        var yOffset: CGFloat = verticalSpacing
        
        for (index, user) in users.enumerated() {
            var profileImage: UIImage?
            
            // Try to get the profile image
            if let profileImageData = user.profileImages.first {
                profileImage = UIImage(data: profileImageData)
            } else if let profileImageUrl = user.profileImageUrl, !profileImageUrl.isEmpty {
                // Attempt to fetch the image from Supabase
                if let imageData = fetchProfileImageFromSupabase(url: profileImageUrl) {
                    profileImage = UIImage(data: imageData)
                    // Update user in UserDataModel
                    var updatedUser = user
                    updatedUser.profileImages = [imageData]
                    UserDataModel.shared.updateUser(updatedUser)
                }
            }
            
            guard let image = profileImage else {
                print("No profile image for user: \(user.userId)")
                continue
            }
            
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFill
            imageView.layer.cornerRadius = imageSize / 2
            imageView.clipsToBounds = true
            imageView.isUserInteractionEnabled = true
            imageView.tag = index
            
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(imageTapped(_:)))
            imageView.addGestureRecognizer(tapGesture)
            
            if xOffset + imageSize + horizontalSpacing > containerWidth {
                xOffset = horizontalSpacing
                yOffset += imageSize + verticalSpacing
            }
            
            imageView.frame = CGRect(x: xOffset, y: yOffset, width: imageSize, height: imageSize)
            imageView.layer.borderColor = UIColor.gray.cgColor
            imageView.layer.borderWidth = 2
            innerView.addSubview(imageView)
            imageViews.append(imageView)
            
            xOffset += imageSize + horizontalSpacing
        }
    }
    private func fetchProfileImageFromSupabase(url: String) -> Data? {
        guard let imageUrl = URL(string: url) else {
            print("Invalid profile image URL: \(url)")
            return nil
        }
        
        do {
            let imageData = try Data(contentsOf: imageUrl)
            return imageData
        } catch {
            print("Failed to fetch profile image from \(url): \(error)")
            return nil
        }
    }
    
    @objc private func imageTapped(_ sender: UITapGestureRecognizer) {
        guard isSelectionEnabled! else { return }
        guard let imageView = sender.view as? UIImageView,
              let users = users else { return }
        
        let index = imageView.tag
        let user = users[index]
        
        if selectedUsers.contains(user.userId) {
            // Deselect user
            selectedUsers.remove(user.userId)
            imageView.layer.borderColor = UIColor.gray.cgColor
            imageView.layer.borderWidth = 2
        } else {
            // Select user
            selectedUsers.insert(user.userId)
            imageView.layer.borderColor = UIColor(named: "AccentColor")?.cgColor ?? UIColor.blue.cgColor
            imageView.layer.borderWidth = 3
        }
        
        print("Selected Users: \(selectedUsers)")
    }
    private func checkAutoShareFriends() {
        if let autoShareFriends = UserDefaults.standard.stringArray(forKey: "AutoShareFriends") {
            print("Auto-share enabled for \(autoShareFriends.count) friends: \(autoShareFriends)")
        } else {
            print("No friends enabled for auto-share")
            // Initialize the array if it doesn't exist
            UserDefaults.standard.set([], forKey: "AutoShareFriends")
        }
    }
    // In showAutoSharedFriends method:
    func showAutoSharedFriends(friendIds: [String]) {
        print("showAutoSharedFriends called with friendIds: \(friendIds)")
        
        // Convert friend IDs to User objects
        let autoShareFriends = friendIds.compactMap { friendId in
            let user = UserDataModel.shared.getUser(byId: friendId)
            print("Friend ID: \(friendId), Found user: \(user != nil), Has profile image: \(user?.profileImages.first != nil)")
            return user
        }
        
        print("Found \(autoShareFriends.count) valid users with data")
        
        // Set the users property to display them
        self.users = autoShareFriends
        self.isSelectionEnabled = true  // Set to true to show "Share" button
        
        // Update the title
        if let titleLabel = titleLabel {
            let friendCount = autoShareFriends.count
            titleLabel.text = "Photo Auto-Shared With \(friendCount) \(friendCount == 1 ? "Friend" : "Friends")"
        }
        
        // Update the action button text directly
        DispatchQueue.main.async { [weak self] in
            self?.actionButton.setTitle("Share", for: .normal)
        }
    }
}
