//
//  CreateEventViewController.swift
//  Relive
//
//  Created by Ayush Nimiwal on 10/12/24.
//

import UIKit

protocol CreateEventDelegate: AnyObject {
    func didCreateEvent()
}

class CreateEventViewController: UIViewController, AddFriendsDelegate {
    
    var selectedImagesData: [Data] = []

    func didSelectFriends(_ friends: [User]) {
        selectedFriends = friends
    }
    func didSelectImages(_ images: [UIImage]) {
        selectedImagesData = images.compactMap { $0.jpegData(compressionQuality: 0.8) }
    }

    
    weak var delegate: CreateEventDelegate?
    
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var addFriendButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel? // Add this if you have a title label connected in Interface Builder
    
    var selectedFriends: [User] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.cornerRadius = 20
        view.clipsToBounds = true
        
        // Set the navigation title (if in a navigation controller)
        title = "Create Album"
        
        // Find and update the title label (if it exists but is not connected via IBOutlet)
        updateCreateAlbumTitle()
        
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.frame = CGRect(x: 10, y: 10, width: 70, height: 70)
        imageView.backgroundColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
        imageView.layer.cornerRadius = 35
        let innerImageView = UIImageView(image: UIImage(systemName: "plus"))
        innerImageView.contentMode = .scaleAspectFit
        let padding: CGFloat = 5
        innerImageView.frame = CGRect(
            x: padding,
            y: padding,
            width: imageView.frame.width - 2 * padding,
            height: imageView.frame.height - 2 * padding
        )
        imageView.addSubview(innerImageView)
        addFriendButton.addSubview(imageView)
        
        // Update placeholder text
        nameField.placeholder = "Album Name"
        
        // Setup text field validation
        nameField.delegate = self
    }
    // In your album creation code - this should go where you currently create the album
    // (Likely in CreateEventViewController or similar)


    
    // Find and update title label
    private func updateCreateAlbumTitle() {
        // If we have a connected outlet, update it
        if let titleLabel = titleLabel {
            titleLabel.text = "Create Album"
            return
        }
        
        // Otherwise, search for a label with "Create Event" text
        if let eventLabel = findLabelWithText("Create Event") {
            eventLabel.text = "Create Album"
        }
        
        // Also check if there's a UILabel for "Event Name" and change it
        if let eventNameLabel = findLabelWithText("Event Name") {
            eventNameLabel.text = "Album Name"
        }
    }
    
    // Helper method to find a label with specific text
    private func findLabelWithText(_ text: String, in view: UIView? = nil) -> UILabel? {
        let searchView = view ?? self.view
        
        // Search through all subviews
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
    

    @IBAction func Cancel(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func Done(_ sender: Any) {
        // Validate required fields
        guard let name = nameField.text, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // Show error message
            showAlert(title: "Invalid Album", message: "Please enter an album name.")
            return
        }
        
        // Debug log
        print("Creating album with \(selectedImagesData.count) images")
        
        // Use a Task to handle asynchronous session retrieval
        Task {
            do {
                // Attempt to get the current user
                guard let currentUser = SupabaseManager.shared.supabase.auth.currentUser else {
                    showAlert(title: "Authentication Error", message: "Please log in again.")
                    return
                }
                
                // Debug print the user details
                print("🔍 Creating Album")
                print("Current User ID: \(currentUser.id.uuidString)")
                
                // Prepare shared users list
                var sharedWithUsers: [String] = []
                for user in selectedFriends {
                    sharedWithUsers.append(user.userId)
                }
                
                // Create a proper UUID for the album ID
                let albumId = UUID().uuidString
                
                // Create the album using the current user's ID
                let album = SharedAlbum(
                    albumId: albumId,
                    albumName: name,
                    createdByUserId: currentUser.id.uuidString,
                    sharedWithUserIds: sharedWithUsers,
                    imagesIds: [], // No images initially, they'll be added by saveSharedAlbum
                    createdAt: Date.now
                )
                
                // Save to Supabase first
                SupabaseManager.shared.saveSharedAlbum(album: album, images: selectedImagesData) { [weak self] success in
                    DispatchQueue.main.async {
                        if success {
                            print("✅ Successfully saved shared album to Supabase")
                            
                            // Post notification to update album views
                            NotificationCenter.default.post(name: NSNotification.Name("AlbumUpdatedNotification"), object: nil)
                            
                            // Inform the delegate
                            self?.delegate?.didCreateEvent()
                            
                            // Force refresh the albums view to ensure the new data is loaded
                            UserDefaults.standard.set(true, forKey: "NeedsAlbumForceRefresh")
                            
                            // Dismiss the view controller
                            self?.dismiss(animated: true, completion: nil)
                        } else {
                            print("❌ Failed to save shared album to Supabase")
                            
                            // Show error message
                            self?.showAlert(
                                title: "Upload Failed",
                                message: "Could not save album to server. Please try again."
                            )
                        }
                    }
                }
            } catch {
                // Handle any unexpected errors
                print("❌ Error creating album: \(error)")
                showAlert(title: "Error", message: "An unexpected error occurred. Please try again.")
            }
        }
    }
    // Add this debug method to help diagnose session issues
    func debugCurrentSession() {
        guard let userId = SessionManager.shared.getSession() else {
            print("❌ No active session found in SessionManager")
            return
        }
        
        print("🔍 SessionManager User ID: \(userId)")
        
        // Print details about the current authentication state
        do {
            // If your Supabase client has a different method, replace this with the correct one
            if let currentUser = SupabaseManager.shared.supabase.auth.currentUser {
                print("🔍 Supabase Current User ID: \(currentUser.id)")
                print("🔍 Supabase Current User ID (string): \(currentUser.id.uuidString)")
                print("🔍 Supabase Current User Email: \(currentUser.email ?? "No email")")
            } else {
                print("❌ No current user found in Supabase")
            }
        } catch {
            print("❌ Error checking Supabase user: \(error)")
        }
    }
    
    
   
    
    @IBAction func AddFriendButton(_ sender: UIButton) {
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "addFriendSegue",
           let navigationController = segue.destination as? UINavigationController,
            let destinationVC = navigationController.topViewController as? FriendsViewController {
            for friend in selectedFriends {
                destinationVC.selectedFriends.insert(friend.userId)
            }
            destinationVC.delegate = self
        }
    }
    
    // Helper method to display alerts
    private func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        present(alertController, animated: true)
    }
}

// MARK: - UITextFieldDelegate
extension CreateEventViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
