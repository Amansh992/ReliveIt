import UIKit
import Contacts
import Foundation

class FriendListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, AddFriendsDelegate {
    // Delegate method implementation
    func didSelectFriends(_ friends: [User]) {
        var sFriends: [User] = selectedFriends
        for friend in friends {
            if !sFriends.contains(where: { $0.userId == friend.userId }) {
                sFriends.append(friend)
            }
        }
        
        // Update selection state
        if selectedFriends.count > 0 {
            for friend in selectedFriends {
                if !friends.contains(where: { $0.userId == friend.userId }) &&
                   filteredContacts.contains(where: { $0.userId == friend.userId }) {
                    sFriends.removeAll(where: { $0.userId == friend.userId })
                }
            }
        }
        
        selectedFriends = sFriends
        tableView.reloadData()
    }
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var addButton: UIButton!
    
    var album: SharedAlbum?
    private var selectedFriends: [User] = []
    private var allContacts: [CNContact] = []
    private var filteredContacts: [User] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.cornerRadius = 20
        view.clipsToBounds = true
        
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.layer.cornerRadius = 20
        
        // Style the add button
        configureAddButton()
        
        // Load album data safely
        loadAlbumData()
        
        // Request contacts permission immediately
        requestContactPermission()
        
        // Enable swipe to delete
        tableView.allowsSelection = true
        
        // Set custom title without arrow
        self.navigationItem.title = "Select Friends"
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Ensure we have the latest data when returning to this view
        if filteredContacts.isEmpty {
            requestContactPermission()
        }
        
        // Refresh the table data
        tableView.reloadData()
    }
    
    private func configureAddButton() {
        let imageView = UIImageView(image: UIImage(systemName: "plus"))
        imageView.contentMode = .scaleAspectFit
        imageView.frame = CGRect(x: 10, y: 10, width: 60, height: 60)
        imageView.backgroundColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
        imageView.layer.cornerRadius = 30
        addButton.addSubview(imageView)
    }
    
    private func loadAlbumData() {
        // Safely unwrap album and get the album ID
        guard let albumId = album?.albumId else {
            print("Error: No album ID available")
            return
        }
        
        // Show loading indicator
        let loadingIndicator = UIActivityIndicatorView(style: .medium)
        loadingIndicator.center = view.center
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.startAnimating()
        view.addSubview(loadingIndicator)
        
        // First get the latest album data from Supabase
        SupabaseManager.shared.getSharedAlbumDetails(albumId: albumId) { [weak self] result in
            switch result {
            case .success(let fetchedAlbum):
                // Update local album reference
                self?.album = fetchedAlbum
                
                // Get current user's session
                guard let userId = SessionManager.shared.getSession() else {
                    loadingIndicator.stopAnimating()
                    return
                }
                
                // Fetch friends for album sharing
                SupabaseManager.shared.getFriendsForAlbumSharing(userId: userId) { result in
                    DispatchQueue.main.async {
                        loadingIndicator.stopAnimating()
                        
                        switch result {
                        case .success(let friends):
                            // Filter friends who are shared with in this album
                            let sharedFriendIds = fetchedAlbum.sharedWithUserIds ?? []
                            let selectedFriends = friends.filter { sharedFriendIds.contains($0.userId) }
                            
                            print("📋 Selected Friends: \(selectedFriends.count)")
                            
                            self?.selectedFriends = selectedFriends
                            self?.tableView.reloadData()
                            
                        case .failure(let error):
                            print("Failed to load friends: \(error)")
                            // Optionally show an error to the user
                        }
                    }
                }
                
            case .failure(let error):
                print("Failed to fetch album details: \(error)")
                
                DispatchQueue.main.async {
                    loadingIndicator.stopAnimating()
                    // Optionally show an error to the user
                }
            }
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Debug print to verify we have data
        print("Number of selected friends: \(selectedFriends.count)")
        return selectedFriends.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FriendCell", for: indexPath)
        
        // Make sure we have valid data at this index
        guard indexPath.row < selectedFriends.count else {
            cell.textLabel?.text = "Invalid Friend"
            return cell
        }
        
        let friend = selectedFriends[indexPath.row]
        cell.textLabel?.text = friend.name
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16)
        cell.textLabel?.textColor = .darkGray
        cell.detailTextLabel?.text = friend.phoneNumber
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 14)
        cell.detailTextLabel?.textColor = .lightGray
        
        // Remove the disclosure indicator
        cell.accessoryType = .none
        
        // Add a custom delete button if you still want to support deletion
        let deleteButton = UIButton(type: .system)
        deleteButton.setImage(UIImage(systemName: "trash"), for: .normal)
        deleteButton.tintColor = .systemRed
        deleteButton.tag = indexPath.row
        deleteButton.addTarget(self, action: #selector(deleteButtonTapped(_:)), for: .touchUpInside)
        cell.accessoryView = deleteButton
        
        return cell
    }
    
    @objc private func deleteButtonTapped(_ sender: UIButton) {
        let index = sender.tag
        let indexPath = IndexPath(row: index, section: 0)
        
        // Check if index is valid
        if index < selectedFriends.count {
            let friend = selectedFriends[index]
            showRemoveOptions(for: friend, at: indexPath)
        }
    }
    
    // Support for tapping on a friend
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.row < selectedFriends.count else { return }
        
        let selectedFriend = selectedFriends[indexPath.row]
        showRemoveOptions(for: selectedFriend, at: indexPath)
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // Show options to remove friend
    private func showRemoveOptions(for friend: User, at indexPath: IndexPath) {
        let actionSheet = UIAlertController(
            title: "Remove \(friend.name)",
            message: "Do you want to remove this friend from the album?",
            preferredStyle: .actionSheet
        )
        
        // Remove action
        actionSheet.addAction(UIAlertAction(title: "Remove", style: .destructive) { [weak self] _ in
            self?.removeFriend(at: indexPath)
        })
        
        // Cancel action
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(actionSheet, animated: true)
    }
    
    // Support for swipe to delete
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            removeFriend(at: indexPath)
        }
    }
    
    // Remove a friend from the album
    private func removeFriend(at indexPath: IndexPath) {
        guard indexPath.row < selectedFriends.count else { return }
        
        // Remove from the selected friends array
        selectedFriends.remove(at: indexPath.row)
        
        // Update the table
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "addFriendCC",
           let navigationController = segue.destination as? UINavigationController,
           let destinationVC = navigationController.topViewController as? FriendsViewController {
            // Pass selected friends to the destination view controller
            var selectedFriendIds = Set<String>()
            for friend in selectedFriends {
                selectedFriendIds.insert(friend.userId)
            }
            destinationVC.selectedFriends = selectedFriendIds
            destinationVC.delegate = self
            
            // Make sure we set the title without the arrow
            destinationVC.title = "Select Friends"
        }
    }
    
    @IBAction func addFriendButton(_ sender: Any) {
        // This is handled by the segue
    }
    
    @IBAction func Cancel(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func Done(_ sender: Any) {
        guard let a = album else {
            print("Error: Album is nil")
            dismiss(animated: true, completion: nil)
            return
        }
        
        // Show loading indicator
        let loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.center = view.center
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.startAnimating()
        view.addSubview(loadingIndicator)
        
        // Map selected friends to user IDs
        let userIds = selectedFriends.map { $0.userId }
        
        // Create updated album
        var updatedAlbum = a
        updatedAlbum.sharedWithUserIds = userIds
        
        // First update the Supabase database
        SupabaseManager.shared.shareAlbumWithFriends(albumId: a.albumId, friendIds: userIds) { [weak self] success in
            DispatchQueue.main.async {
                loadingIndicator.stopAnimating()
                
                if success {
                    print("Successfully updated album sharing in Supabase")
                    
                    // Fetch the latest album details to ensure consistency
                    SupabaseManager.shared.getSharedAlbumDetails(albumId: a.albumId) { result in
                        switch result {
                        case .success(let fetchedAlbum):
                            // Update local data model with the fetched album
                            SharedAlbumsDataModel.shared.updateSharedAlbum(fetchedAlbum)
                            
                            // Post notification that album was updated
                            NotificationCenter.default.post(name: NSNotification.Name("AlbumUpdatedNotification"), object: nil)
                            
                            // Dismiss the view controller
                            self?.dismiss(animated: true, completion: nil)
                            
                        case .failure(let error):
                            print("Failed to fetch updated album details: \(error.localizedDescription)")
                            // Still dismiss even if fetching details fails
                            self?.dismiss(animated: true, completion: nil)
                        }
                    }
                } else {
                    // Show error alert
                    let alert = UIAlertController(
                        title: "Update Failed",
                        message: "Failed to update album sharing. Please try again.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(alert, animated: true)
                }
            }
        }
    }
    
    private func requestContactPermission() {
        let store = CNContactStore()
        
        // Check current authorization status
        let authStatus = CNContactStore.authorizationStatus(for: .contacts)
        
        switch authStatus {
        case .authorized:
            // Already authorized, fetch contacts
            self.fetchContacts()
            return
            
        case .denied, .restricted:
            // Show alert to guide user to settings
            self.showContactsPermissionAlert()
            return
            
        case .notDetermined:
            // Request permission
            store.requestAccess(for: .contacts) { [weak self] granted, error in
                DispatchQueue.main.async {
                    if granted {
                        self?.fetchContacts()
                    } else {
                        print("Permission to access contacts denied: \(String(describing: error))")
                        self?.showContactsPermissionAlert()
                    }
                }
            }
            
        @unknown default:
            print("Unknown authorization status for contacts")
        }
    }
    
    private func showContactsPermissionAlert() {
        let alert = UIAlertController(
            title: "Contacts Access Required",
            message: "This app needs access to your contacts to show friends. Please enable contacts access in Settings.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func fetchContacts() {
        print("Fetching contacts...")
        let store = CNContactStore()
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor
        ]
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        
        // Clear previous contacts
        allContacts.removeAll()
        
        do {
            try store.enumerateContacts(with: request) { contact, _ in
                self.allContacts.append(contact)
            }
            print("Fetched \(self.allContacts.count) contacts")
            self.filterAppUsers()
        } catch {
            print("Failed to fetch contacts: \(error)")
            
            // Update UI on main thread
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    private func filterAppUsers() {
        print("Filtering app users from contacts...")
        filteredContacts.removeAll()
        
        for contact in allContacts {
            for phoneNumber in contact.phoneNumbers {
                var formattedPhone = phoneNumber.value.stringValue
                // Remove all non-digit characters
                formattedPhone = formattedPhone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                
                // Try different phone formats
                if formattedPhone.count > 0 {
                    let potentialFormats = [
                        "+\(formattedPhone)",
                        formattedPhone,
                        formattedPhone.hasPrefix("1") ? String(formattedPhone.dropFirst()) : formattedPhone,
                        formattedPhone.hasPrefix("1") ? "+\(formattedPhone)" : "+1\(formattedPhone)"
                    ]
                    
                    for format in potentialFormats {
                        if let user = UserDataModel.shared.getUserByPhoneNo(byno: format) {
                            filteredContacts.append(user)
                            break // Found a match, no need to try other formats
                        }
                    }
                }
            }
        }
        
        print("Found \(filteredContacts.count) app users from contacts")
        
        // Update UI on main thread
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
}
