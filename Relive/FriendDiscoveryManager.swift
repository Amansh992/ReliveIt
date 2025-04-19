import Foundation
import Contacts
import UIKit

protocol FriendDiscoveryDelegate: AnyObject {
    func didDiscoverFriends(_ friends: [User])
}

class FriendDiscoveryManager {
    
    static let shared = FriendDiscoveryManager()
    
    weak var delegate: FriendDiscoveryDelegate?
    
    private var contacts: [CNContact] = []
    private var contactPhoneNumbers: [String] = []
    private var discoveredFriends: [User] = []
    private var isDiscoveryInProgress = false
    
    // MARK: - Contact Access and Processing
    
    /// Request access to contacts and start discovery process
    func startFriendDiscovery(currentUserId: String?) {
        guard !isDiscoveryInProgress, let userId = currentUserId else {
            print("⚠️ Discovery already in progress or no user ID")
            return
        }
        
        isDiscoveryInProgress = true
        print("Starting friend discovery for user: \(userId)")
        
        // Request contacts permission
        let store = CNContactStore()
        let authStatus = CNContactStore.authorizationStatus(for: .contacts)
        
        switch authStatus {
        case .authorized:
            fetchContactsAndProcess(userId: userId)
            
        case .notDetermined:
            store.requestAccess(for: .contacts) { [weak self] granted, error in
                if granted {
                    self?.fetchContactsAndProcess(userId: userId)
                } else {
                    print("Contact access denied: \(String(describing: error))")
                    self?.isDiscoveryInProgress = false
                }
            }
            
        case .denied, .restricted:
            print("Contact access previously denied")
            isDiscoveryInProgress = false
            
        @unknown default:
            print("Unknown authorization status")
            isDiscoveryInProgress = false
        }
    }
    
    private func fetchContactsAndProcess(userId: String) {
        // Clear previous state
        contacts.removeAll()
        contactPhoneNumbers.removeAll()
        
        let store = CNContactStore()
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor
        ]
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                // Process all contacts
                try store.enumerateContacts(with: request) { contact, _ in
                    self?.contacts.append(contact)
                    
                    // Extract phone numbers
                    for phoneNumber in contact.phoneNumbers {
                        let phone = phoneNumber.value.stringValue
                        if !phone.isEmpty {
                            self?.contactPhoneNumbers.append(phone)
                        }
                    }
                }
                
                print("Fetched \(self?.contacts.count ?? 0) contacts with \(self?.contactPhoneNumbers.count ?? 0) phone numbers")
                
                // Start matching process
                self?.findMatchingUsers(userId: userId)
                
            } catch {
                print("Failed to fetch contacts: \(error)")
                DispatchQueue.main.async {
                    self?.isDiscoveryInProgress = false
                }
            }
        }
    }
    
    // MARK: - User Matching
    
    private func findMatchingUsers(userId: String) {
        // Skip if no contacts found
        if contactPhoneNumbers.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.isDiscoveryInProgress = false
            }
            return
        }
        
        print("Searching for users matching \(contactPhoneNumbers.count) contact phone numbers")
        
        // Use the enhanced method to find users
        SupabaseManager.shared.findUsersMatchingContacts(phoneNumbers: contactPhoneNumbers) { [weak self] result in
            switch result {
            case .success(let matchedUsers):
                print("Found \(matchedUsers.count) app users matching contacts")
                
                // Filter out current user from the results
                let filteredUsers = matchedUsers.filter { $0.userId != userId }
                self?.discoveredFriends = filteredUsers
                
                // Add these users as friends
                self?.addDiscoveredUsersAsFriends(userId: userId, discoveredUsers: filteredUsers)
                
            case .failure(let error):
                print("Error finding matching users: \(error)")
                DispatchQueue.main.async {
                    self?.isDiscoveryInProgress = false
                }
            }
        }
    }
    
    private func addDiscoveredUsersAsFriends(userId: String, discoveredUsers: [User]) {
        // Get IDs of discovered users
        let discoveredUserIds = discoveredUsers.map { $0.userId }
        
        // First get the current friend list
        SupabaseManager.shared.getUserFriends(userId: userId) { [weak self] result in
            switch result {
            case .success(let currentFriendIds):
                print("Current friend count: \(currentFriendIds.count)")
                
                // Merge current friends with newly discovered users
                var allFriendIds = Set(currentFriendIds)
                allFriendIds.formUnion(discoveredUserIds)
                
                // Update the friend relationships in Supabase
                SupabaseManager.shared.updateFriendList(userId: userId, friendIds: Array(allFriendIds)) { success in
                    if success {
                        print("Successfully updated friend list with \(allFriendIds.count) total friends")
                        
                        // Update local user model
                        if var currentUser = UserDataModel.shared.getUser(byId: userId) {
                            currentUser.friendListUserIds = Array(allFriendIds)
                            UserDataModel.shared.updateUser(currentUser)
                        }
                        
                        // Notify delegate about discovered friends
                        DispatchQueue.main.async {
                            self?.delegate?.didDiscoverFriends(discoveredUsers)
                            self?.isDiscoveryInProgress = false
                        }
                    } else {
                        print("Failed to update friend list")
                        DispatchQueue.main.async {
                            self?.isDiscoveryInProgress = false
                        }
                    }
                }
                
            case .failure(let error):
                print("Failed to get current friends: \(error)")
                
                // Still try to add just the discovered users
                SupabaseManager.shared.updateFriendList(userId: userId, friendIds: discoveredUserIds) { [weak self] success in
                    if success {
                        print("Added \(discoveredUserIds.count) discovered friends")
                        
                        // Update local user model
                        if var currentUser = UserDataModel.shared.getUser(byId: userId) {
                            currentUser.friendListUserIds = discoveredUserIds
                            UserDataModel.shared.updateUser(currentUser)
                        }
                        
                        DispatchQueue.main.async {
                            self?.delegate?.didDiscoverFriends(discoveredUsers)
                        }
                    }
                    
                    DispatchQueue.main.async {
                        self?.isDiscoveryInProgress = false
                    }
                }
            }
        }
    }
    
    // MARK: - Automatic Friend Discovery
    
    /// This method should be called when the app launches or user logs in
    func performAutomaticFriendDiscovery(userId: String) {
        print("Performing automatic friend discovery for user: \(userId)")
        startFriendDiscovery(currentUserId: userId)
    }
}

// Extension to integrate with user login flow
extension SupabaseManager {
    
    func loginWithAutoFriendDiscovery(userId: String, completion: @escaping (Bool) -> Void) {
        // First perform regular login completion tasks
        loginCompletion(userId: userId)
        
        // Then start automatic friend discovery
        FriendDiscoveryManager.shared.performAutomaticFriendDiscovery(userId: userId)
        
        // Complete the login flow
        completion(true)
    }
}
