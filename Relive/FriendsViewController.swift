import UIKit
import Contacts
import Foundation

class FriendsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, FriendDiscoveryDelegate {
    
    // MARK: - Outlets and Properties
    private var contacts: [CNContact] = []
    private var filteredContacts: [User] = []
    @IBOutlet weak var tableView: UITableView!
    
    private var allContacts: [CNContact] = []
    var selectedFriends: Set<String> = []
    private var processedUserIds = Set<String>()
    
    weak var delegate: AddFriendsDelegate?
    
    // For handling contact-to-user matching
    private var contactPhoneNumbers: [String: String] = [:] // [phoneNumber: contactName]
    private var isLoadingUsers = true
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add comprehensive debug logging
        print("Current User ID: \(SessionManager.shared.getSession() ?? "nil")")
        
        // Set up UI components
        tableView.delegate = self
        tableView.dataSource = self
        tableView.layer.cornerRadius = 20
        setupLoadingIndicator()
        
        // Skip loading from local model, only get friends from Supabase
        loadFriendsFromBackend()
        
        // Then fetch contacts and find new friends
        requestContactPermission()
        // Add this line at the end
            setupRefreshMechanisms()
        
        // Enable selection
        tableView.allowsSelection = true
    }
    
    // MARK: - FriendDiscoveryDelegate
    
    func didDiscoverFriends(_ friends: [User]) {
        print("Friend discovery delegate received \(friends.count) friends")
        
        // Remove duplicates before updating
        let uniqueFriends = friends.uniqueUsers()
        
        // Update the filtered contacts list with unique entries
        for friend in uniqueFriends {
            if !filteredContacts.contains(where: { $0.userId == friend.userId }) {
                filteredContacts.append(friend)
            }
        }
        
        // Sort and ensure uniqueness
        filteredContacts = filteredContacts.uniqueUsers().sorted { $0.name < $1.name }
        
        // Update UI
        stopLoadingIndicator()
        tableView.reloadData()
        
        if filteredContacts.isEmpty {
            showNoFriendsMessage()
        } else {
            hideNoFriendsMessage()
        }
    }
    private func filterAppUsers() {
        print("Filtering app users from contacts...")
        
        // Use a set to track unique user IDs
        var uniqueUserIds = Set<String>()
        var uniqueFilteredContacts: [User] = []
        
        // Process each contact
        for contact in contacts {
            for phoneNumber in contact.phoneNumbers {
                var formattedPhone = phoneNumber.value.stringValue
                
                // Try different formatting options
                let formattingOptions = [
                    formattedPhone, // Original format
                    formattedPhone.replacingOccurrences(of: " ", with: ""),
                    formattedPhone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined(), // Digits only
                    formattedPhone.replacingOccurrences(of: "^0", with: "+44", options: .regularExpression), // UK format
                    formattedPhone.replacingOccurrences(of: "^1", with: "+1", options: .regularExpression)  // US format
                ]
                
                for format in formattingOptions {
                    // Check if this phone number belongs to an app user
                    if let user = UserDataModel.shared.getUserByPhoneNo(byno: format) {
                        // Ensure unique user
                        if !uniqueUserIds.contains(user.userId) {
                            uniqueUserIds.insert(user.userId)
                            uniqueFilteredContacts.append(user)
                            print("Found user: \(user.name), Phone: \(user.phoneNumber)")
                        }
                        break // Found a match, no need to try other formats
                    }
                }
            }
        }
        
        // Replace filteredContacts with unique contacts
        filteredContacts = uniqueFilteredContacts
        
        // Debug output
        print("Found \(filteredContacts.count) unique friends.")
        
        // Update UI
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadData()
            
            // Show message if no friends found
            if self?.filteredContacts.isEmpty ?? true {
                self?.showNoFriendsMessage()
            } else {
                self?.hideNoFriendsMessage()
            }
        }
    }
    // MARK: - Helper Methods
    
    private func loadExistingFriends() {
        guard let currentUserId = SessionManager.shared.getSession() else {
            print("No current user ID available")
            return
        }
        
        // Get current user's friends from local model
        if let currentUser = UserDataModel.shared.getUser(byId: currentUserId),
           let friendIds = currentUser.friendListUserIds {
            
            print("Loading \(friendIds.count) existing friends from local model")
            
            // Load each friend's data
            for friendId in friendIds {
                if let friend = UserDataModel.shared.getUser(byId: friendId) {
                    if !filteredContacts.contains(where: { $0.userId == friendId }) {
                        filteredContacts.append(friend)
                        selectedFriends.insert(friendId)
                        processedUserIds.insert(friendId)
                    }
                }
            }
            
            // Update UI immediately with existing friends
            filteredContacts.sort { $0.name < $1.name }
            tableView.reloadData()
        }
        
        // Also try to load friends from Supabase
        SupabaseManager.shared.getUserFriends(userId: currentUserId) { [weak self] result in
            switch result {
            case .success(let friendIds):
                print("Loaded \(friendIds.count) friends from Supabase")
                
                var newFriends: [User] = []
                
                // Load each friend's data
                for friendId in friendIds {
                    // Skip already processed users
                    if self?.processedUserIds.contains(friendId) == true {
                        continue
                    }
                    
                    if let friend = UserDataModel.shared.getUser(byId: friendId) {
                        // We already have this user locally
                        if !(self?.filteredContacts.contains(where: { $0.userId == friendId }) ?? false) {
                            newFriends.append(friend)
                            self?.selectedFriends.insert(friendId)
                            self?.processedUserIds.insert(friendId)
                        }
                    } else {
                        // Need to fetch this user from Supabase
                        self?.fetchUserDetails(userId: friendId) { user in
                            if let user = user {
                                DispatchQueue.main.async {
                                    if !(self?.filteredContacts.contains(where: { $0.userId == friendId }) ?? false) {
                                        self?.filteredContacts.append(user)
                                        self?.selectedFriends.insert(friendId)
                                        self?.processedUserIds.insert(friendId)
                                        self?.tableView.reloadData()
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Add new friends to the list
                if !newFriends.isEmpty {
                    DispatchQueue.main.async {
                        self?.filteredContacts.append(contentsOf: newFriends)
                        self?.filteredContacts.sort { $0.name < $1.name }
                        self?.tableView.reloadData()
                    }
                }
                
            case .failure(let error):
                print("Failed to load friends from Supabase: \(error.localizedDescription)")
            }
        }
    }
    
    private func fetchUserDetails(userId: String, completion: @escaping (User?) -> Void) {
        SupabaseManager.shared.getUserProfile(userId: userId) { result in
            switch result {
            case .success(let user):
                completion(user)
            case .failure(let error):
                print("Failed to fetch user details: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }
    
    private func setupLoadingIndicator() {
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.center = view.center
        activityIndicator.hidesWhenStopped = true
        activityIndicator.tag = 999
        view.addSubview(activityIndicator)
        activityIndicator.startAnimating()
    }
    
    private func stopLoadingIndicator() {
        if let activityIndicator = view.viewWithTag(999) as? UIActivityIndicatorView {
            activityIndicator.stopAnimating()
            activityIndicator.removeFromSuperview()
        }
    }
    private func loadFriendsFromBackend() {
        guard let currentUserId = SessionManager.shared.getSession() else {
               print("🚨 NO CURRENT USER ID AVAILABLE")
               return
           }
           
           print("🔍 Loading friends for user ID: \(currentUserId)")
        
        // Get friends directly from Supabase
        SupabaseManager.shared.getUserFriends(userId: currentUserId) { [weak self] result in
            switch result {
            case .success(let friendIds):
                print("Loaded \(friendIds.count) friends from Supabase")
                
                // For each friend ID, fetch user details from backend
                for friendId in friendIds {
                    // Skip already processed users
                    print("🧩 Friend ID: \(friendId)")
                    if self?.processedUserIds.contains(friendId) == true {
                        continue
                    }
                    
                    self?.processedUserIds.insert(friendId)
                    
                    // Fetch user details from backend
                    DispatchQueue.global().async {
                        self?.fetchUserDetailsFromBackend(userId: friendId) { user in
                            if let user = user {
                                DispatchQueue.main.async {
                                    // Add to filtered contacts
                                    if !(self?.filteredContacts.contains(where: { $0.userId == friendId }) ?? false) {
                                        self?.filteredContacts.append(user)
                                        self?.selectedFriends.insert(friendId)
                                        
                                        // Update UI
                                        self?.filteredContacts.sort { $0.name < $1.name }
                                        self?.tableView.reloadData()
                                        
                                        if !(self?.filteredContacts.isEmpty ?? true) {
                                            self?.hideNoFriendsMessage()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
            case .failure(let error):
                print("Failed to load friends from Supabase: \(error.localizedDescription)")
            }
        }
    }

    private func fetchUserDetailsFromBackend(userId: String, completion: @escaping (User?) -> Void) {
        SupabaseManager.shared.getUserProfile(userId: userId) { result in
            switch result {
            case .success(let user):
                completion(user)
            case .failure(let error):
                print("Failed to fetch user details: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }
    // Add these properties to your FriendsViewController class
    private var refreshTimer: Timer?
    private var refreshControl: UIRefreshControl!

    // Add this to your viewDidLoad method
    private func setupRefreshMechanisms() {
        // Setup pull-to-refresh
        refreshControl = UIRefreshControl()
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl.addTarget(self, action: #selector(refreshFriendsManually), for: .valueChanged)
        tableView.refreshControl = refreshControl
        
        // Setup background refresh timer
        startBackgroundRefreshTimer()
    }

    // Call this when view appears
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Start the refresh timer when view appears
        startBackgroundRefreshTimer()
        
        // Do an immediate refresh to get the latest data
        refreshFriendsFromBackend(showLoadingIndicator: false)
        stopBackgroundRefreshTimer()
    }

    // Call this when view disappears
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Stop the timer when view disappears to save resources
        stopBackgroundRefreshTimer()
    }

    // Start background timer
    private func startBackgroundRefreshTimer() {
        // Stop existing timer if any
        stopBackgroundRefreshTimer()
        
        // Create a new timer that fires every 30 seconds
        refreshTimer = Timer.scheduledTimer(
            timeInterval: 30.0,
            target: self,
            selector: #selector(backgroundRefreshTimerFired),
            userInfo: nil,
            repeats: true
        )
    }

    // Stop background timer
    private func stopBackgroundRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // Called when refresh timer fires
    @objc private func backgroundRefreshTimerFired() {
        // Only refresh if view is visible
        if self.viewIfLoaded?.window != nil {
            refreshFriendsFromBackend(showLoadingIndicator: false)
        }
    }

    // Called when user manually pulls to refresh
    @objc private func refreshFriendsManually() {
        refreshFriendsFromBackend(showLoadingIndicator: true)
    }

    // Central refresh method
    private func refreshFriendsFromBackend(showLoadingIndicator: Bool) {
        guard let currentUserId = SessionManager.shared.getSession() else {
            if showLoadingIndicator {
                refreshControl.endRefreshing()
            }
            return
        }
        
        print("Refreshing friends from backend...")
        
        // Show loading indicator if requested
        if showLoadingIndicator && !refreshControl.isRefreshing {
            refreshControl.beginRefreshing()
        }
        
        // Keep track of already known friends to avoid duplicates
        let existingFriendIds = Set(filteredContacts.map { $0.userId })
        
        // Get friends from Supabase
        SupabaseManager.shared.getUserFriends(userId: currentUserId) { [weak self] result in
            switch result {
            case .success(let friendIds):
                print("Refresh found \(friendIds.count) friends in backend")
                
                var newFriendIds = Set<String>()
                
                // Find new friends that weren't known before
                for friendId in friendIds {
                    if !existingFriendIds.contains(friendId) && friendId != currentUserId {
                        newFriendIds.insert(friendId)
                    }
                }
                
                // If there are new friends, fetch their details
                if !newFriendIds.isEmpty {
                    print("Found \(newFriendIds.count) new friends during refresh")
                    
                    let dispatchGroup = DispatchGroup()
                    var newFriends: [User] = []
                    
                    // Fetch each new friend's details
                    for friendId in newFriendIds {
                        dispatchGroup.enter()
                        
                        self?.fetchUserDetailsFromBackend(userId: friendId) { user in
                            if let user = user {
                                newFriends.append(user)
                            }
                            dispatchGroup.leave()
                        }
                    }
                    
                    // When all user details are fetched
                    dispatchGroup.notify(queue: .main) {
                        // Add new friends to the list
                        if !newFriends.isEmpty {
                            if let strongSelf = self {
                                // Add to filtered contacts
                                strongSelf.filteredContacts.append(contentsOf: newFriends)
                                
                                // Mark them as selected if needed
                                for friend in newFriends {
                                    if strongSelf.selectedFriends.contains(friend.userId) {
                                        print("Friend \(friend.name) is already selected")
                                    }
                                }
                                
                                // Sort and reload
                                strongSelf.filteredContacts.sort { $0.name < $1.name }
                                strongSelf.tableView.reloadData()
                                
                                // Show notification about new friends
                                strongSelf.showNewFriendsNotification(count: newFriends.count)
                            }
                        }
                        
                        // End refreshing
                        if showLoadingIndicator {
                            self?.refreshControl.endRefreshing()
                        }
                    }
                } else {
                    // No new friends, just end refreshing
                    if showLoadingIndicator {
                        self?.refreshControl.endRefreshing()
                    }
                }
                
            case .failure(let error):
                print("Failed to refresh friends: \(error.localizedDescription)")
                if showLoadingIndicator {
                    self?.refreshControl.endRefreshing()
                }
            }
        }
    }

    // Show a notification about new friends
    private func showNewFriendsNotification(count: Int) {
        let message = count == 1 ? "1 new friend found!" : "\(count) new friends found!"
        
        let banner = UIView(frame: CGRect(x: 0, y: -50, width: view.bounds.width, height: 50))
        banner.backgroundColor = UIColor(red: 0.2, green: 0.7, blue: 0.2, alpha: 0.9)
        banner.layer.cornerRadius = 8
        banner.clipsToBounds = true
        banner.layer.shadowColor = UIColor.black.cgColor
        banner.layer.shadowOffset = CGSize(width: 0, height: 2)
        banner.layer.shadowOpacity = 0.3
        banner.layer.shadowRadius = 4
        
        let label = UILabel(frame: CGRect(x: 20, y: 0, width: banner.bounds.width - 40, height: banner.bounds.height))
        label.text = message
        label.textColor = .white
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        banner.addSubview(label)
        
        view.addSubview(banner)
        
        // Animate banner in
        UIView.animate(withDuration: 0.5, animations: {
            banner.frame.origin.y = 20
        }) { _ in
            // Animate banner out after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                UIView.animate(withDuration: 0.5, animations: {
                    banner.frame.origin.y = -50
                }) { _ in
                    banner.removeFromSuperview()
                }
            }
        }
    }
    
    // MARK: - Action Methods
    
    @IBAction func doneButton(_ sender: Any) {
        let selectedUsers = filteredContacts.filter { selectedFriends.contains($0.userId) }
        print("Selected \(selectedUsers.count) friends for sharing")
        
        // If using Supabase, update friend relationships with selected friends
        if let currentUserId = SessionManager.shared.getSession(), !selectedUsers.isEmpty {
            // Show loading indicator
            let loadingAlert = UIAlertController(
                title: "Saving",
                message: "Updating your friend list...",
                preferredStyle: .alert
            )
            present(loadingAlert, animated: true)
            
            // Get selected user IDs
            let selectedUserIds = selectedUsers.map { $0.userId }
            
            // Update friend list directly with selected IDs
            SupabaseManager.shared.updateFriendList(userId: currentUserId, friendIds: selectedUserIds) { [weak self] success in
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        if success {
                            print("Successfully updated friend list in Supabase")
                            
                            // Update local user model
                            if var currentUser = UserDataModel.shared.getUser(byId: currentUserId) {
                                currentUser.friendListUserIds = selectedUserIds
                                UserDataModel.shared.updateUser(currentUser)
                            }
                            
                            // Notify delegate and dismiss
                            self?.delegate?.didSelectFriends(selectedUsers)
                            self?.dismiss(animated: true)
                        } else {
                            // Show error
                            let errorAlert = UIAlertController(
                                title: "Error",
                                message: "Failed to update your friend list. Please try again.",
                                preferredStyle: .alert
                            )
                            errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                            self?.present(errorAlert, animated: true)
                        }
                    }
                }
            }
        } else {
            // No user ID or no selected friends
            delegate?.didSelectFriends(selectedUsers)
            dismiss(animated: true, completion: nil)
        }
    }
    
    @IBAction func cancel(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Phone Number Normalization
    
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
                }
            }
        }
        
        // Add format with specific regional variations
        formats.append(cleanPhone.replacingOccurrences(of: "^0", with: "+91", options: .regularExpression))  // India
        formats.append(cleanPhone.replacingOccurrences(of: "^0", with: "+44", options: .regularExpression))  // UK
        
        return formats
    }
    
    // MARK: - Contacts Access
    
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
            self.stopLoadingIndicator()
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
                        self?.stopLoadingIndicator()
                    }
                }
            }
            
        @unknown default:
            print("Unknown authorization status for contacts")
            self.stopLoadingIndicator()
        }
    }
    
    private func showContactsPermissionAlert() {
        let alert = UIAlertController(
            title: "Contacts Access Required",
            message: "This app needs access to your contacts to show which of your contacts are using Relive. Please enable contacts access in Settings.",
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
    
    private func showContactsFetchErrorAlert() {
        let alert = UIAlertController(
            title: "Couldn't Access Contacts",
            message: "There was a problem accessing your contacts. You can try again or continue without adding friends.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Contacts and User Processing
    
    private func fetchContacts() {
        print("Fetching contacts...")
        let store = CNContactStore()
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor
        ]
        
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        
        // Clear previous data
        allContacts.removeAll()
        contactPhoneNumbers.removeAll()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try store.enumerateContacts(with: request) { contact, _ in
                    let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    
                    // Process each phone number
                    for phoneNumber in contact.phoneNumbers {
                        let originalPhone = phoneNumber.value.stringValue
                        let standardized = self?.standardizePhoneNumber(originalPhone) ?? ""
                        
                        if !standardized.isEmpty {
                            // Only keep the first phone number per contact to avoid duplicates
                            if self?.contactPhoneNumbers[standardized] == nil {
                                self?.contactPhoneNumbers[standardized] = name
                            }
                        }
                    }
                }
                
                print("Fetched \(self?.contactPhoneNumbers.count ?? 0) unique phone numbers")
                
                DispatchQueue.main.async {
                    self?.findUsersMatchingContactsInSupabase()
                }
                
            } catch {
                print("Failed to fetch contacts: \(error)")
                DispatchQueue.main.async {
                    self?.showContactsFetchErrorAlert()
                    self?.stopLoadingIndicator()
                }
            }
        }
    }
    private func standardizePhoneNumber(_ phone: String) -> String {
        // Remove all non-digit characters
        let digitsOnly = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // If the number is already in international format, return as is
        if digitsOnly.hasPrefix("91") && digitsOnly.count == 12 {
            return "+\(digitsOnly)"
        }
        
        // For Indian numbers (assuming 10-digit mobile numbers)
        if digitsOnly.count == 10 {
            return "+91\(digitsOnly)"
        }
        
        // For numbers already starting with +91
        if phone.hasPrefix("+91") && digitsOnly.count == 12 {
            return phone
        }
        
        // More comprehensive handling
        if digitsOnly.count > 10 {
            // Take last 10 digits
            let lastTenDigits = String(digitsOnly.suffix(10))
            return "+91\(lastTenDigits)"
        }
        
        // If we can't format the number, return empty string
        return ""
    }
    private func searchLocalUsersImmediately() {
        print("Searching for users in local database...")
        
        // Get all users from the local database
        let allLocalUsers = UserDataModel.shared.getAllUsers()
        print("Found \(allLocalUsers.count) users in local database")
        
        // Skip the current user
        let currentUserId = SessionManager.shared.getSession()
        
        // Get current user data to check friends list
        let currentUserFriends = Set<String>()
        if let currentUser = UserDataModel.shared.getUser(byId: currentUserId ?? ""),
           let friendIds = currentUser.friendListUserIds {
            processedUserIds.formUnion(friendIds)
            print("Filtering out \(processedUserIds.count) existing friends")
        }
        
        // Also filter out current user
        if let userId = currentUserId {
            processedUserIds.insert(userId)
        }
        
        var newMatches = false
        
        for user in allLocalUsers {
            // Skip current user and already processed users
            if user.userId == currentUserId || processedUserIds.contains(user.userId) {
                continue
            }
            
            // Normalize the user's phone number
            let userPhoneFormats = normalizePhoneNumber(user.phoneNumber)
            
            // Check each contact against these phone formats
            for contact in allContacts {
                for phoneNumber in contact.phoneNumbers {
                    let originalPhone = phoneNumber.value.stringValue
                    let contactPhoneFormats = normalizePhoneNumber(originalPhone)
                    
                    // Check for intersection between user phone formats and contact phone formats
                    let matchedFormats = Set(userPhoneFormats).intersection(Set(contactPhoneFormats))
                    
                    if !matchedFormats.isEmpty {
                        // Construct contact name
                        let givenName = contact.givenName
                        let familyName = contact.familyName
                        let contactName = [givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ")
                        
                        // Create a user with contact name
                        var matchedUser = user
                        if !contactName.isEmpty {
                            matchedUser.name = contactName
                        }
                        
                        // Add to filtered contacts if not already present
                        if !filteredContacts.contains(where: { $0.userId == matchedUser.userId }) {
                            filteredContacts.append(matchedUser)
                            processedUserIds.insert(matchedUser.userId)
                            newMatches = true
                            
                            print("Matched user: \(matchedUser.name), Phone: \(matchedUser.phoneNumber)")
                        }
                        
                        break // Stop checking after first match
                    }
                }
            }
        }
        
        // Immediately update the UI with any matches found
        if newMatches {
            DispatchQueue.main.async {
                self.filteredContacts.sort { $0.name < $1.name }
                self.tableView.reloadData()
                
                if !self.filteredContacts.isEmpty {
                    self.hideNoFriendsMessage()
                }
            }
        }
    }
    
    private func findUsersMatchingContactsInSupabase() {
        guard !contactPhoneNumbers.isEmpty else {
            print("No contact phone numbers to search")
            stopLoadingIndicator()
            return
        }
        
        // Extract and standardize phone numbers
        var uniquePhones: Set<String> = []
        var phoneToContactNameMap: [String: String] = [:]
        
        for (originalPhone, contactName) in contactPhoneNumbers {
            let standardizedPhone = standardizePhoneNumber(originalPhone)
            if !standardizedPhone.isEmpty {
                uniquePhones.insert(standardizedPhone)
                phoneToContactNameMap[standardizedPhone] = contactName
            }
        }
        
        let phoneNumbersArray = Array(uniquePhones)
        print("🔍 Searching for \(phoneNumbersArray.count) unique phone numbers")
        
        SupabaseManager.shared.findUsersByPhone(phoneNumbers: phoneNumbersArray) { [weak self] result in
            switch result {
            case .success(let users):
                print("🎉 Found \(users.count) matching users")
                
                guard let self = self else { return }
                
                // Process matched users with deduplication
                var matchedUsers: [User] = []
                var processedUserIds = Set<String>()
                
                for var user in users {
                    guard !processedUserIds.contains(user.userId) else { continue }
                    
                    // Update name from contacts if available
                    if let contactName = phoneToContactNameMap[user.phoneNumber] {
                        user.name = contactName.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    
                    // Skip current user
                    if user.userId != SessionManager.shared.getSession() {
                        matchedUsers.append(user)
                        processedUserIds.insert(user.userId)
                    }
                }
                
                // Update UI with deduplicated list
                DispatchQueue.main.async {
                    // Get existing user IDs to avoid re-adding
                    let existingIds = Set(self.filteredContacts.map { $0.userId })
                    let newUsers = matchedUsers.filter { !existingIds.contains($0.userId) }
                    
                    self.filteredContacts.append(contentsOf: newUsers)
                    self.filteredContacts = self.filteredContacts.uniqueUsers().sorted { $0.name < $1.name }
                    
                    self.tableView.reloadData()
                    self.stopLoadingIndicator()
                    
                    if self.filteredContacts.isEmpty {
                        self.showNoFriendsMessage()
                    } else {
                        self.hideNoFriendsMessage()
                    }
                    
                    print("Final unique contacts count: \(self.filteredContacts.count)")
                }
                
            case .failure(let error):
                print("Phone search error: \(error)")
                DispatchQueue.main.async {
                    self?.stopLoadingIndicator()
                    self?.showNoFriendsMessage()
                }
            }
        }
    }
    
    // MARK: - Debug Helpers
    
    private func addDebugLogging() {
        // Log the current state
        print("--- FRIENDS DEBUG INFO ---")
        print("Total contacts loaded: \(allContacts.count)")
        print("Total unique phone numbers: \(contactPhoneNumbers.count)")
        print("Total filtered contacts (friends): \(filteredContacts.count)")
        print("Selected friends count: \(selectedFriends.count)")
        
        // Log all app users in the system
        let allUsers = UserDataModel.shared.getAllUsers()
        print("Total users in UserDataModel: \(allUsers.count)")
        print("Users with phone numbers:")
        for user in allUsers {
            print("User: \(user.name), Phone: \(user.phoneNumber), ID: \(user.userId)")
        }
    }
    
    // MARK: - UI Helper Methods
    
    private func showSearchingMessage() {
        let messageLabel = UILabel(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: tableView.bounds.height))
        messageLabel.text = "Searching for contacts using Relive..."
        messageLabel.textAlignment = .center
        messageLabel.textColor = .gray
        messageLabel.numberOfLines = 0
        messageLabel.font = UIFont.systemFont(ofSize: 16)
        messageLabel.tag = 100
        
        tableView.backgroundView = messageLabel
    }
    
    private func showNoFriendsMessage() {
        let messageLabel = UILabel(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: tableView.bounds.height))
        messageLabel.text = "None of your contacts are using Relive yet. Invite your friends to join!"
        messageLabel.textAlignment = .center
        messageLabel.textColor = .gray
        messageLabel.numberOfLines = 0
        messageLabel.font = UIFont.systemFont(ofSize: 16)
        messageLabel.tag = 100
        
        tableView.backgroundView = messageLabel
    }
    
    private func hideNoFriendsMessage() {
        tableView.backgroundView = nil
    }
    
    // MARK: - Profile Image Loading
    
    // Add this property to your class to track ongoing image loads
    private var activeImageLoads: [String: Bool] = [:]
    private let imageLoadQueue = DispatchQueue(label: "com.app.imageLoadQueue")
    private let activeImageLoadsLock = NSLock()

    private func loadProfileImage(url: String, for user: User, at indexPath: IndexPath) {
        // Check if image is already loaded for this user
        if !user.profileImages.isEmpty {
            return
        }
        guard indexPath.row < filteredContacts.count,
                filteredContacts[indexPath.row].userId == user.userId else {
              print("Skipping image load - user no longer at index \(indexPath)")
              return
          }
        
        imageLoadQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Thread-safe check and set of loading state
            activeImageLoadsLock.lock()
            guard self.activeImageLoads[url] != true else {
                activeImageLoadsLock.unlock()
                return
            }
            self.activeImageLoads[url] = true
            activeImageLoadsLock.unlock()
            
            guard let imageUrl = URL(string: url) else {
                self.cleanupImageLoad(url: url)
                return
            }
            
            print("🌐 Loading profile image for user: \(user.name), URL: \(url)")
            
            do {
                let imageData = try Data(contentsOf: imageUrl)
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else {
                        self?.cleanupImageLoad(url: url)
                        return
                    }
                    
                    // Verify table view and index path are still valid
                    guard indexPath.section < self.tableView.numberOfSections,
                          indexPath.row < self.tableView.numberOfRows(inSection: indexPath.section),
                          indexPath.row < self.filteredContacts.count else {
                        print("Invalid indexPath: \(indexPath)")
                        self.cleanupImageLoad(url: url)
                        return
                    }
                    
                    // Verify the user still matches at this index
                    guard self.filteredContacts[indexPath.row].userId == user.userId else {
                        print("User no longer matches at this index")
                        self.cleanupImageLoad(url: url)
                        return
                    }
                    
                    // Create a copy of the user with updated image
                    var updatedUser = user
                    updatedUser.profileImages = [imageData]
                    
                    // Update user in data model
                    UserDataModel.shared.updateUser(updatedUser)
                    
                    // Find and update in filtered contacts
                    if let index = self.filteredContacts.firstIndex(where: { $0.userId == user.userId }) {
                        self.filteredContacts[index] = updatedUser
                        
                        // Reload the specific row
                        self.tableView.reloadRows(at: [indexPath], with: .automatic)
                    }
                    
                    // Clean up the load
                    self.cleanupImageLoad(url: url)
                }
            } catch {
                print("❌ Failed to load profile image for user \(user.name): \(error.localizedDescription)")
                self.cleanupImageLoad(url: url)
            }
        }
    }

    private func cleanupImageLoad(url: String) {
        activeImageLoadsLock.lock()
        activeImageLoads[url] = nil
        activeImageLoadsLock.unlock()
    }
    
    // MARK: - Table View Data Source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredContacts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FCell", for: indexPath)
        
        guard indexPath.row < filteredContacts.count else {
            cell.textLabel?.text = "Invalid Friend"
            return cell
        }
        
        let user = filteredContacts[indexPath.row]
        
        // Configure cell text
        cell.textLabel?.text = user.name
        cell.detailTextLabel?.text = user.phoneNumber
        
        // Reset accessory view
        cell.accessoryView = nil
        
        // Handle profile image
        if let profileImageData = user.profileImages.first,
           let profileImage = UIImage(data: profileImageData) {
            // Create circular image view
            let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
            imageView.contentMode = .scaleAspectFill
            imageView.layer.cornerRadius = 20
            imageView.clipsToBounds = true
            imageView.image = profileImage
            
            // Set as accessory view if no checkmark
            if !selectedFriends.contains(user.userId) {
                cell.accessoryView = imageView
            }
        } else if let profileImageUrl = user.profileImageUrl, !profileImageUrl.isEmpty {
            // Set placeholder
            let placeholderImageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
            placeholderImageView.image = UIImage(systemName: "person.circle.fill")
            placeholderImageView.contentMode = .scaleAspectFit
            placeholderImageView.layer.cornerRadius = 20
            placeholderImageView.clipsToBounds = true
            
            // Set placeholder as accessory view
            if !selectedFriends.contains(user.userId) {
                cell.accessoryView = placeholderImageView
            }
            
            // Attempt to load the image
            loadProfileImage(url: profileImageUrl, for: user, at: indexPath)
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.row < filteredContacts.count else { return }
        
        let user = filteredContacts[indexPath.row]
        
        if selectedFriends.contains(user.userId) {
            selectedFriends.remove(user.userId)
        } else {
            selectedFriends.insert(user.userId)
        }
        
        tableView.reloadRows(at: [indexPath], with: .automatic)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
extension Array where Element == User {
    func uniqueUsers() -> [User] {
        var uniqueUsers = [User]()
        var seenIds = Set<String>()
        
        for user in self {
            if !seenIds.contains(user.userId) {
                seenIds.insert(user.userId)
                uniqueUsers.append(user)
            }
        }
        
        return uniqueUsers
    }
}
