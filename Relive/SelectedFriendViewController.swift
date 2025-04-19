//
//  SelectedFriendViewController.swift
//  Relive
//
//  Created by Ayush Nimiwal on 10/12/24.
//

import UIKit
import Contacts

class SelectedFriendViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var tableView: UITableView!
    
    private var contacts: [CNContact] = []
    private var friends: [String] = [] // User IDs of app users from contacts
    private var selectedFriends: Set<Int> = [] // Selected indexes
    private var allowedFriends: Set<String> = [] // Friends allowed to see user's location
    private var friendList: Set<String> = [] // User's current friends
    private var allUsers: [User] = [] // All app users for easier access
    
    // UI Components
    private var loadingIndicator: UIActivityIndicatorView?
    private var processedUserIds = Set<String>()
    // Phone number tracking
    private var contactPhoneNumbers: [String: String] = [:] // [phoneNumber: contactName]
    
    // Refresh control
    private var refreshControl: UIRefreshControl!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.layer.cornerRadius = 20
        
        // Set up loading indicator
        setupLoadingIndicator()
        
        // Set up pull-to-refresh
        setupRefreshControl()
        
        // Load all app users for better filtering
        allUsers = UserDataModel.shared.getAllUsers()
        
        // Load current user's friends and permission settings
        loadUserFriends()
        
        // Then request contacts access and fetch contacts
        requestContactPermission()
    }
    override func viewWillAppear(_ animated: Bool) {
          super.viewWillAppear(animated)
          
          // Clear arrays before loading to prevent accumulation
          friends.removeAll()
          selectedFriends.removeAll()
          allowedFriends.removeAll()
          friendList.removeAll()
          processedUserIds.removeAll()
          
          // Then load data
          loadUserFriends()
      }
    private func setupRefreshControl() {
        refreshControl = UIRefreshControl()
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl.addTarget(self, action: #selector(refreshFriendsData), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }
    
    @objc private func refreshFriendsData() {
        // First reload friends from server
        loadFriendsFromBackend(showLoadingIndicator: false)
        
        // Then refresh contacts
        requestContactPermission()
    }
    
    private func setupLoadingIndicator() {
        loadingIndicator = UIActivityIndicatorView(style: .large)
        if let loadingIndicator = loadingIndicator {
            loadingIndicator.center = view.center
            loadingIndicator.hidesWhenStopped = true
            view.addSubview(loadingIndicator)
            loadingIndicator.startAnimating()
        }
    }
    
    private func loadFriendsFromBackend(showLoadingIndicator: Bool = true) {
           guard let currentUserId = SessionManager.shared.getSession() else {
               print("No current user ID available")
               if showLoadingIndicator {
                   refreshControl.endRefreshing()
               }
               return
           }
           
           print("Loading friends for user ID: \(currentUserId)")
           
           // Reset processed users when reloading
           processedUserIds.removeAll()
           
           // Show loading indicator if requested
           if showLoadingIndicator && !refreshControl.isRefreshing {
               self.loadingIndicator?.startAnimating()
           }
           
           // Get friends directly from Supabase
           SupabaseManager.shared.getUserFriends(userId: currentUserId) { [weak self] result in
               guard let self = self else { return }
               
               switch result {
               case .success(let friendIds):
                   print("Loaded \(friendIds.count) friends from Supabase")
                   
                   // Update our friend list
                   self.friendList = Set(friendIds)
                   
                   // Pre-populate friends array with existing friends - FIXED DUPLICATION
                   for friendId in friendIds {
                       if !self.processedUserIds.contains(friendId) {
                           self.friends.append(friendId)
                           self.processedUserIds.insert(friendId)
                       }
                   }
                   
                   // Update selection state
                   for (index, userId) in self.friends.enumerated() {
                       if self.friendList.contains(userId) {
                           self.selectedFriends.insert(index)
                       }
                   }
                   
                   // Load location sharing permissions
                   self.loadLocationSharingPermissions(userId: currentUserId)
                   
                   // Update UI
                   DispatchQueue.main.async {
                       if showLoadingIndicator {
                           self.loadingIndicator?.stopAnimating()
                           self.refreshControl.endRefreshing()
                       }
                       
                       self.tableView.reloadData()
                       
                       if self.friends.isEmpty {
                           self.showNoFriendsMessage()
                       } else {
                           self.hideNoFriendsMessage()
                       }
                   }
                   
               case .failure(let error):
                   // Handle error case (keeping existing logic)
                   print("Failed to load friends from Supabase: \(error.localizedDescription)")
                   
                   // Use local data as fallback but prevent duplications
                   if let user = UserDataModel.shared.getUser(byId: currentUserId),
                      let friendIds = user.friendListUserIds {
                       print("Using local friend data instead: \(friendIds.count) friends")
                       
                       self.friendList = Set(friendIds)
                       
                       // Pre-populate friends array with existing friends - FIXED DUPLICATION
                       for friendId in friendIds {
                           if !self.processedUserIds.contains(friendId) {
                               self.friends.append(friendId)
                               self.processedUserIds.insert(friendId)
                           }
                       }
                       
                       // Update selection state
                       for (index, userId) in self.friends.enumerated() {
                           if self.friendList.contains(userId) {
                               self.selectedFriends.insert(index)
                           }
                       }
                   }
                   
                   // Load location sharing permissions
                   self.loadLocationSharingPermissions(userId: currentUserId)
                   
                   DispatchQueue.main.async {
                       if showLoadingIndicator {
                           self.loadingIndicator?.stopAnimating()
                           self.refreshControl.endRefreshing()
                       }
                       
                       self.tableView.reloadData()
                       
                       if self.friends.isEmpty {
                           self.showNoFriendsMessage()
                       } else {
                           self.hideNoFriendsMessage()
                       }
                   }
               }
           }
       }
    
    private func loadLocationSharingPermissions(userId: String) {
        SupabaseManager.shared.getLocationSharingPermissions(userId: userId) { [weak self] result in
            switch result {
            case .success(let allowedUserIds):
                DispatchQueue.main.async {
                    self?.allowedFriends = Set(allowedUserIds)
                    self?.tableView.reloadData()
                }
            case .failure(let error):
                print("Failed to get location sharing permissions: \(error.localizedDescription)")
                
                // Fall back to local data
                if let user = UserDataModel.shared.getUser(byId: userId),
                   let sharedWithIds = user.sharedWithUserIds {
                    DispatchQueue.main.async {
                        self?.allowedFriends = Set(sharedWithIds)
                        self?.tableView.reloadData()
                    }
                }
            }
        }
    }
    
    func loadUserFriends() {
        guard let userId = SessionManager.shared.getSession() else { return }
        
        // Clear current data
        friends.removeAll()
        selectedFriends.removeAll()
        allowedFriends.removeAll()
        friendList.removeAll()
        
        // Load data from backend instead of just using local data
        loadFriendsFromBackend()
    }
    
    @IBAction func doneButton(_ sender: Any) {
        guard let userId = SessionManager.shared.getSession() else { return }
        
        // Show activity indicator
        let loadingIndicator = UIActivityIndicatorView(style: .medium)
        loadingIndicator.center = view.center
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.startAnimating()
        view.addSubview(loadingIndicator)
        
        // Collect the selected friend IDs
        var selectedFriendIds: [String] = []
        var allowedFriendIds: [String] = []
        
        for index in selectedFriends {
            if index >= 0 && index < friends.count {
                let friendId = friends[index]
                selectedFriendIds.append(friendId)
                
                // Check if this friend is also allowed to see location
                if allowedFriends.contains(friendId) {
                    allowedFriendIds.append(friendId)
                }
            }
        }
        
        // First, update the user_friends table
        SupabaseManager.shared.updateFriendList(userId: userId, friendIds: selectedFriendIds) { [weak self] success in
            if success {
                print("Successfully updated friend list in database")
                
                // Now update the location sharing permissions
                SupabaseManager.shared.updateSharedWithUsers(userId: userId, sharedWithUserIds: allowedFriendIds) { locationSuccess in
                    loadingIndicator.stopAnimating()
                    
                    if locationSuccess {
                        print("Successfully updated location sharing permissions")
                    } else {
                        print("Failed to update location sharing permissions")
                    }
                    
                    // Update local user model regardless of server success
                    if var user = UserDataModel.shared.getUser(byId: userId) {
                        user.friendListUserIds = selectedFriendIds
                        user.sharedWithUserIds = allowedFriendIds
                        UserDataModel.shared.updateUser(user)
                    }
                    
                    // Notify that the friend list has been updated (for album sharing UI to update)
                    NotificationCenter.default.post(name: NSNotification.Name("FriendListUpdatedNotification"), object: nil)
                    
                    // Dismiss the view controller
                    self?.dismiss(animated: true, completion: nil)
                }
            } else {
                // If updating friend list failed
                loadingIndicator.stopAnimating()
                print("Failed to update friend list in database")
                
                // Show error alert
                let alert = UIAlertController(
                    title: "Update Failed",
                    message: "Failed to update your friends list. Please try again.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(alert, animated: true)
            }
        }
    }
    
    @IBAction func cancelButton(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    func requestContactPermission() {
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
            self.loadingIndicator?.stopAnimating()
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
                        self?.loadingIndicator?.stopAnimating()
                    }
                }
            }
            
        @unknown default:
            print("Unknown authorization status for contacts")
            self.loadingIndicator?.stopAnimating()
        }
    }
    
    func showContactsPermissionAlert() {
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
        
        present(alert, animated: true, completion: nil)
    }
    
    func fetchContacts() {
        print("Fetching contacts...")
        let store = CNContactStore()
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor
        ]
        
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        
        // Start processing on a background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                // Clear previous contacts but keep existing friends
                self?.contacts.removeAll()
                self?.contactPhoneNumbers.removeAll()
                
                try store.enumerateContacts(with: request) { contact, _ in
                    self?.contacts.append(contact)
                    
                    // Format contact name
                    let givenName = contact.givenName
                    let familyName = contact.familyName
                    let contactName = [givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ")
                    
                    // Skip contacts without names
                    if contactName.isEmpty {
                        return
                    }
                    
                    // Extract and normalize phone numbers
                    for phoneNumber in contact.phoneNumbers {
                        let originalPhone = phoneNumber.value.stringValue
                        let potentialFormats = self?.normalizePhoneNumber(originalPhone) ?? []
                        
                        for format in potentialFormats {
                            self?.contactPhoneNumbers[format] = contactName
                        }
                    }
                }
                
                print("Fetched \(self?.contacts.count ?? 0) contacts with \(self?.contactPhoneNumbers.count ?? 0) phone numbers")
                
                // Use the better matching algorithm for finding users
                self?.findUsersMatchingContactsInSupabase()
            } catch {
                print("Failed to fetch contacts: \(error)")
                DispatchQueue.main.async {
                    self?.loadingIndicator?.stopAnimating()
                    // Still show any preloaded friends
                    self?.tableView.reloadData()
                }
            }
        }
    }
    
    private func normalizePhoneNumber(_ phone: String) -> [String] {
        // Remove all non-digit characters except +
        let cleanPhone = phone.components(separatedBy: CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "+")).inverted).joined()
        
        // Create array of potential formats
        var formats = [cleanPhone]
        
        // If number starts with +, also add without +
        if cleanPhone.hasPrefix("+") {
            formats.append(String(cleanPhone.dropFirst()))
            
            // For US/Canada numbers (+1XXXXXXXXXX), also try without country code
            if cleanPhone.hasPrefix("+1") && cleanPhone.count > 2 {
                formats.append(String(cleanPhone.dropFirst(2)))
            }
        } else {
            // If doesn't start with +, try with common country codes
            formats.append("+\(cleanPhone)")
            
            // If it looks like it might be a US number (10-11 digits)
            if cleanPhone.count >= 10 {
                // If starts with 1 and has 11 digits total, it's likely a US number with country code
                if cleanPhone.hasPrefix("1") && cleanPhone.count == 11 {
                    formats.append("+\(cleanPhone)")
                    formats.append(String(cleanPhone.dropFirst()))
                }
                // If it's 10 digits, it likely needs the +1 country code
                else if cleanPhone.count == 10 {
                    formats.append("+1\(cleanPhone)")
                    formats.append("+91\(cleanPhone)") // Try Indian format too
                }
            }
        }
        
        // Add format with specific regional variations
        formats.append(cleanPhone.replacingOccurrences(of: "^0", with: "+91", options: .regularExpression))  // India
        formats.append(cleanPhone.replacingOccurrences(of: "^0", with: "+44", options: .regularExpression))  // UK
        
        return formats
    }
    
    private func standardizePhoneNumber(_ phone: String) -> String {
        // Remove all non-digit characters
        let digitsOnly = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // Debug print to see what's happening
        print("Original Phone: \(phone)")
        print("Digits Only: \(digitsOnly)")
        
        // If the number is already in international format, return as is
        if digitsOnly.hasPrefix("91") && digitsOnly.count == 12 {
            let formattedNumber = "+\(digitsOnly)"
            print("Format 1: \(formattedNumber)")
            return formattedNumber
        }
        
        // For Indian numbers (assuming 10-digit mobile numbers)
        if digitsOnly.count == 10 {
            let formattedNumber = "+91\(digitsOnly)"
            print("Format 2: \(formattedNumber)")
            return formattedNumber
        }
        
        // For numbers already starting with +91
        if digitsOnly.hasPrefix("91") && digitsOnly.count == 12 {
            let formattedNumber = "+\(digitsOnly)"
            print("Format 3: \(formattedNumber)")
            return formattedNumber
        }
        
        // More comprehensive handling
        if digitsOnly.count > 10 {
            // Take last 10 digits
            let lastTenDigits = String(digitsOnly.suffix(10))
            let formattedNumber = "+91\(lastTenDigits)"
            print("Format 4: \(formattedNumber)")
            return formattedNumber
        }
        
        // For US/Canada numbers
        if digitsOnly.count == 10 {
            let formattedNumber = "+1\(digitsOnly)"
            print("US/CA Format: \(formattedNumber)")
            return formattedNumber
        }
        
        // If we can't format the number, return empty string
        print("Could not format phone number: \(phone)")
        return ""
    }
    
    private func findUsersMatchingContactsInSupabase() {
         guard !contactPhoneNumbers.isEmpty else {
             print("No contact phone numbers to search")
             DispatchQueue.main.async {
                 self.loadingIndicator?.stopAnimating()
             }
             return
         }
         
         // Extract and standardize phone numbers
         var uniquePhones: Set<String> = []
         var phoneToContactNameMap: [String: String] = [:]
         
         for (originalPhone, contactName) in contactPhoneNumbers {
             // Standardize phone number to international format with country code
             let standardizedPhone = standardizePhoneNumber(originalPhone)
             
             if !standardizedPhone.isEmpty {
                 uniquePhones.insert(standardizedPhone)
                 phoneToContactNameMap[standardizedPhone] = contactName
                 print("📱 Original: \(originalPhone) → Standardized: \(standardizedPhone), Contact: \(contactName)")
             }
         }
         
         let phoneNumbersArray = Array(uniquePhones)
         print("🔍 Searching for \(phoneNumbersArray.count) unique phone numbers")
         
         SupabaseManager.shared.findUsersByPhone(phoneNumbers: phoneNumbersArray) { [weak self] result in
             guard let self = self else { return }
             
             switch result {
             case .success(let users):
                 print("🎉 Found \(users.count) matching users")
                 
                 // Get the current user ID
                 let currentUserId = SessionManager.shared.getSession()
                 
                 // Process each matched user - FIXED DUPLICATION
                 for var user in users {
                     // Skip current user
                     if user.userId == currentUserId {
                         continue
                     }
                     
                     // Skip already processed users (THIS PREVENTS DUPLICATION)
                     if self.processedUserIds.contains(user.userId) {
                         continue
                     }
                     
                     // Match contact name if possible
                     if let contactName = phoneToContactNameMap[user.phoneNumber] {
                         user.name = contactName
                     }
                     
                     // Add user to friends and mark as processed
                     self.friends.append(user.userId)
                     self.processedUserIds.insert(user.userId)
                 }
                 
                 // Update UI
                 DispatchQueue.main.async {
                     self.loadingIndicator?.stopAnimating()
                     self.tableView.reloadData()
                     
                     if self.friends.isEmpty {
                         self.showNoFriendsMessage()
                     } else {
                         self.hideNoFriendsMessage()
                     }
                 }
                 
             case .failure(let error):
                 print("❌ Phone search error: \(error.localizedDescription)")
                 
                 // Fall back to local filtering
                 self.filterAppUsers()
             }
         }
     }
     
     // Fixed filterAppUsers method to prevent duplications
     func filterAppUsers() {
         print("Filtering app users from contacts (fallback method)...")
         
         // Create a set to track phone numbers we've already processed
         var processedPhoneNumbers = Set<String>()
         
         // Get current user ID to avoid adding self
         let currentUserId = SessionManager.shared.getSession()
         
         // Process each contact
         for contact in contacts {
             for phoneNumber in contact.phoneNumbers {
                 var formattedPhone = phoneNumber.value.stringValue
                 
                 // Remove all non-digit characters
                 let digitsOnly = formattedPhone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                 
                 // Generate multiple phone number formats to try
                 let phoneFormats = [
                     digitsOnly,                    // Just digits
                     "+91\(digitsOnly)",            // With Indian country code
                     "91\(digitsOnly)",             // Without +
                     "+1\(digitsOnly)",             // US country code
                     formattedPhone,                // Original format
                     formattedPhone.replacingOccurrences(of: " ", with: ""),  // Remove spaces
                     formattedPhone.replacingOccurrences(of: "-", with: ""),  // Remove hyphens
                     formattedPhone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)  // Remove non-digit/+ chars
                 ]
                 
                 // Try each phone format
                 for format in phoneFormats {
                     // Skip if we've already processed this phone number
                     if processedPhoneNumbers.contains(format) {
                         continue
                     }
                     
                     processedPhoneNumbers.insert(format)
                     
                     // Check if this phone number belongs to an app user
                     if let user = UserDataModel.shared.getUserByPhoneNo(byno: format) {
                         print("Found matching user: \(user.name), Phone: \(user.phoneNumber)")
                         
                         // Skip current user
                         if user.userId == currentUserId {
                             continue
                         }
                         
                         // Skip already processed users (THIS PREVENTS DUPLICATION)
                         if self.processedUserIds.contains(user.userId) {
                             continue
                         }
                         
                         // Add user to friends and mark as processed
                         self.friends.append(user.userId)
                         self.processedUserIds.insert(user.userId)
                         break // Found a match, no need to try other formats
                     }
                 }
             }
         }
         
         // Debug output
         print("Found \(friends.count) friends after filtering.")
         
         // Update UI
         DispatchQueue.main.async { [weak self] in
             self?.loadingIndicator?.stopAnimating()
             self?.tableView.reloadData()
             
             // Show message if no friends found
             if self?.friends.isEmpty ?? true {
                 self?.showNoFriendsMessage()
             } else {
                 self?.hideNoFriendsMessage()
             }
         }
     }
    
    func showNoFriendsMessage() {
        let messageLabel = UILabel(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: tableView.bounds.height))
        messageLabel.text = "No contacts found who are using this app. Invite your friends to join!"
        messageLabel.textAlignment = .center
        messageLabel.textColor = .gray
        messageLabel.numberOfLines = 0
        messageLabel.font = UIFont.systemFont(ofSize: 16)
        messageLabel.tag = 100
        
        tableView.backgroundView = messageLabel
    }
    
    func hideNoFriendsMessage() {
        tableView.backgroundView = nil
    }
    
    // MARK: - Table View Data Source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return friends.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SFCell", for: indexPath)
        
        // Ensure we have a valid index
        guard indexPath.row < friends.count else {
            cell.textLabel?.text = "Invalid Friend"
            return cell
        }
        
        let userId = friends[indexPath.row]
        
        if let user = UserDataModel.shared.getUser(byId: userId) {
            // Set up cell with user data
            cell.textLabel?.text = user.name
            cell.detailTextLabel?.text = user.phoneNumber
            cell.textLabel?.font = UIFont.systemFont(ofSize: 16)
            cell.textLabel?.textColor = .darkGray
            cell.detailTextLabel?.textColor = .lightGray
            
            // Check selection state
            cell.accessoryType = selectedFriends.contains(indexPath.row) ? .checkmark : .none
            
            // If this is a friend but not in selected set yet (first load),
            // add it to selected set
            if friendList.contains(userId) && !selectedFriends.contains(indexPath.row) {
                selectedFriends.insert(indexPath.row)
                cell.accessoryType = .checkmark
            }
            
            // Add "Allowed" or "Not Allowed" indicator
            let allowedLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 100, height: 30))
            allowedLabel.textAlignment = .right
            
            if allowedFriends.contains(userId) {
                allowedLabel.text = "Allowed"
                allowedLabel.textColor = .systemGreen
            } else {
                allowedLabel.text = "Not Allowed"
                allowedLabel.textColor = .systemRed
            }
            
            cell.accessoryView = allowedLabel
        } else {
            cell.textLabel?.text = "Unknown User"
            cell.accessoryType = .none
        }
        
        return cell
    }
    
    private func saveProfileImageForAutoShare(userId: String) {
        // Check if we already have their profile image data
        if let user = UserDataModel.shared.getUser(byId: userId),
           let profileImage = user.profileImages.first {
            
            print("Saving profile image for auto-share: \(userId)")
            
            // Create directory if needed
            let fileManager = FileManager.default
            let autoShareDir = getAutoShareDirectory()
            
            if !fileManager.fileExists(atPath: autoShareDir.path) {
                do {
                    try fileManager.createDirectory(at: autoShareDir, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print("Failed to create auto-share directory: \(error)")
                    return
                }
            }
            
            // Save image data
            let imagePath = autoShareDir.appendingPathComponent("friend_\(userId).dat")
            do {
                try profileImage.write(to: imagePath)
                
                // Register in UserDefaults
                var autoShareFriends = UserDefaults.standard.stringArray(forKey: "AutoShareFriends") ?? []
                if !autoShareFriends.contains(userId) {
                    autoShareFriends.append(userId)
                    UserDefaults.standard.set(autoShareFriends, forKey: "AutoShareFriends")
                }
                
                print("Successfully saved profile image for auto-share: \(userId)")
            } catch {
                print("Failed to save profile image: \(error)")
            }
        } else {
            print("No profile image available for user: \(userId)")
        }
    }

//    private func getAutoShareDirectory() -> URL {
//        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//            .appendingPathComponent("AutoShareFaces")
//    }

    // Fetch user profile including profile image
    private func fetchUserProfileWithImage(userId: String) {
        print("Fetching profile image for user: \(userId)")
        
        // Show loading indicator for this user in the table view if needed
        
        SupabaseManager.shared.getUserProfile(userId: userId) { [weak self] result in
            switch result {
            case .success(let user):
                // Check if user has profile image URL
                if let profileImageUrl = user.profileImageUrl, !profileImageUrl.isEmpty {
                    self?.downloadProfileImageIfNeeded(userId: userId, profileImageUrl: profileImageUrl)
                } else {
                    print("User has no profile image URL")
                }
                
            case .failure(let error):
                print("Failed to fetch user profile: \(error.localizedDescription)")
            }
        }
    }

    // Download profile image if needed
    private func downloadProfileImageIfNeeded(userId: String, profileImageUrl: String?) {
        guard let imageUrlString = profileImageUrl, !imageUrlString.isEmpty,
              let imageUrl = URL(string: imageUrlString) else {
            print("Invalid image URL for user: \(userId)")
            return
        }
        
        URLSession.shared.dataTask(with: imageUrl) { [weak self] data, response, error in
            if let error = error {
                print("Error downloading profile image: \(error.localizedDescription)")
                return
            }
            
            guard let data = data, !data.isEmpty else {
                print("No image data received")
                return
            }
            
            // Update local user model with image data
            if var user = UserDataModel.shared.getUser(byId: userId) {
                user.profileImages = [data]
                UserDataModel.shared.updateUser(user)
                print("Updated user model with downloaded profile image")
            }
            
            // Save to auto-share database
            self?.saveProfileImageToAutoShareDB(userId: userId, imageData: data)
            
            // Update UI if needed
            DispatchQueue.main.async {
                self?.tableView.reloadData()
            }
        }.resume()
    }

    // Save profile image to auto-share database
    private func saveProfileImageToAutoShareDB(userId: String, imageData: Data) {
        // Create a unique filename for this user's face data
        let filename = "friend_face_\(userId).dat"
        let fileURL = getAutoShareDirectory().appendingPathComponent(filename)
        
        // Save the image data to the file
        do {
            try imageData.write(to: fileURL)
            print("Successfully saved profile image for auto-share: \(userId)")
            
            // Also register this userId in our list of friends with auto-share enabled
            registerFriendForAutoShare(userId: userId)
        } catch {
            print("Failed to save profile image to file: \(error.localizedDescription)")
        }
    }

    // Get directory for storing auto-share profile images
    private func getAutoShareDirectory() -> URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AutoShareFaces")
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                print("Failed to create auto-share directory: \(error.localizedDescription)")
            }
        }
        
        return directory
    }

    // Register friend for auto-share in UserDefaults
    private func registerFriendForAutoShare(userId: String) {
        let defaults = UserDefaults.standard
        var autoShareFriends = defaults.array(forKey: "AutoShareFriends") as? [String] ?? []
        
        if !autoShareFriends.contains(userId) {
            autoShareFriends.append(userId)
            defaults.set(autoShareFriends, forKey: "AutoShareFriends")
            print("Registered friend for auto-share: \(userId)")
        }
    }

    // MARK: - Update the tableView(_:didSelectRowAt:) method

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.row < friends.count else { return }
        
        let userId = friends[indexPath.row]
        
        // Show action sheet with options
        let actionSheet = UIAlertController(title: "Friend Settings", message: nil, preferredStyle: .actionSheet)
        
        // Action: Allow friend to see my location
        let allowAction = UIAlertAction(title: allowedFriends.contains(userId) ? "Remove Access" : "Allow Access", style: .default) { [weak self] _ in
            guard let self = self else { return }
            
            if self.allowedFriends.contains(userId) {
                self.allowedFriends.remove(userId)
            } else {
                self.allowedFriends.insert(userId)
                
                // Save profile image for auto-share
                self.saveProfileImageForAutoShare(userId: userId)
                
                // Also ensure this friend is selected as a friend
                self.selectedFriends.insert(indexPath.row)
            }
            
            // Refresh the cell
            tableView.reloadRows(at: [indexPath], with: .automatic)
        }
        
        // Action: Toggle friend selection
        let toggleAction = UIAlertAction(title: selectedFriends.contains(indexPath.row) ? "Remove Friend" : "Add Friend", style: .default) { [weak self] _ in
            guard let self = self else { return }
            
            if self.selectedFriends.contains(indexPath.row) {
                self.selectedFriends.remove(indexPath.row)
                
                // If removing as friend, also remove from allowed list
                self.allowedFriends.remove(userId)
            } else {
                self.selectedFriends.insert(indexPath.row)
            }
            
            // Refresh the cell
            tableView.reloadRows(at: [indexPath], with: .automatic)
        }
        
        // Action: Cancel
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        actionSheet.addAction(allowAction)
        actionSheet.addAction(toggleAction)
        actionSheet.addAction(cancelAction)
        
        present(actionSheet, animated: true)
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
}
