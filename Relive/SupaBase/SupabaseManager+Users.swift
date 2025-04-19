import Foundation
import UIKit
import Supabase

extension SupabaseManager {
    
    func getUserProfile(userId: String, completion: @escaping (Result<User, Error>) -> Void) {
        Task {
            do {
                print("Fetching user profile for userId: \(userId)")
                
                // First try to find the user by their ID
                let response = try await supabase
                    .database
                    .from("users")
                    .select()
                    .eq("user_id", value: userId)
                    .limit(1)
                    .execute()
                
                // Convert Data to JSON and log
                if let jsonString = String(data: response.data, encoding: .utf8) {
                    print("Database response JSON: \(jsonString)")
                }
                
                // Try to parse the JSON data
                do {
                    let jsonArray = try JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]]
                    
                    if let userData = jsonArray?.first {
                        print("Found user by ID: \(userData)")
                        processUserProfile(userData: userData, userId: userId, completion: completion)
                        return
                    }
                } catch {
                    print("JSON parsing error: \(error)")
                }
                
                // If no user found by ID, get the current session to check the phone number
                if let session = try? await supabase.auth.session,
                   let phone = session.user.phone {
                    
                    print("User not found by ID, trying by phone: \(phone)")
                    
                    // Use a direct query to find user by phone number
                    let phoneQueryResponse = try await supabase
                        .database
                        .from("users")
                        .select()
                        .or("phone.eq.\(phone),phone.eq.+\(phone),phone.eq.\(phone.hasPrefix("+") ? String(phone.dropFirst()) : phone)")
                        .limit(1)
                        .execute()
                    
                    // Convert Data to JSON and log
                    if let jsonString = String(data: phoneQueryResponse.data, encoding: .utf8) {
                        print("Phone query response JSON: \(jsonString)")
                    }
                    
                    // Try to parse the JSON data
                    do {
                        let jsonArray = try JSONSerialization.jsonObject(with: phoneQueryResponse.data, options: []) as? [[String: Any]]
                        
                        if let userData = jsonArray?.first {
                            print("Found user by phone: \(userData)")
                            processUserProfile(userData: userData, userId: userId, completion: completion)
                            return
                        }
                    } catch {
                        print("Phone query JSON parsing error: \(error)")
                    }
                    
                    // If still no user found, create a minimal profile
                    let phoneWithPlus = phone.hasPrefix("+") ? phone : "+\(phone)"
                    createMinimalUserProfile(userId: userId, phone: phoneWithPlus, completion: completion)
                } else {
                    // No session or phone number available
                    print("No session or phone number available")
                    let error = NSError(domain: "SupabaseManagerError", code: 404,
                                       userInfo: [NSLocalizedDescriptionKey: "User not found and no phone information available"])
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            } catch {
                print("Error fetching user profile: \(error)")
                print("Error details: \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // Helper method to process user data
    private func processUserProfile(userData: [String: Any], userId: String, completion: @escaping (Result<User, Error>) -> Void) {
        let name = userData["name"] as? String ?? "Unknown"
        let phone = userData["phone"] as? String ?? ""
        let profileImageUrl = userData["profile_image_url"] as? String ?? ""
        let dbUserId = userData["user_id"] as? String ?? userId
        
        print("Found user: \(name), ID: \(dbUserId), phone: \(phone)")
        
        // Create a basic user object
        var user = User(
            userId: dbUserId,
            name: name,
            phoneNumber: phone,
            profileImages: [],
            verificationCode: "",
            shareLocation: false,
            location: nil,
            sharedWithUserIds: [],
            friendListUserIds: [],
            sharedAlbums: []
        )
        
        // Store the profile image URL
        user.profileImageUrl = profileImageUrl
        
        // Store user in local data model
        UserDataModel.shared.updateUser(user)
        
        DispatchQueue.main.async {
            completion(.success(user))
        }
    }

    // Helper method to create a minimal user profile when user is not found in database
    private func createMinimalUserProfile(userId: String, phone: String, completion: @escaping (Result<User, Error>) -> Void) {
        print("Creating minimal user profile for ID: \(userId), phone: \(phone)")
        
        // Create a minimal user object based on authentication data
        let user = User(
            userId: userId,
            name: "User", // Default name
            phoneNumber: phone,
            profileImages: [],
            verificationCode: "",
            shareLocation: false,
            location: nil,
            sharedWithUserIds: [],
            friendListUserIds: [],
            sharedAlbums: []
        )
        
        // Store in local model
        UserDataModel.shared.updateUser(user)
        
        // Attempt to create this user in the database for future use
        Task {
            do {
                // Always try to insert the user, using upsert to handle existing records
                let newUser: [String: Any] = [
                    "user_id": userId,
                    "name": "User",
                    "phone": phone,
                    "profile_image_url": "",
                    "registration_complete": false
                ]
                
                // Convert dictionary to JSON data
                let jsonData = try JSONSerialization.data(withJSONObject: [newUser], options: [])
                
                // Use upsert to handle both new and existing users
                let response = try await supabase
                    .database
                    .from("users")
                    .upsert(jsonData)
                    .select() // Return the inserted/updated record
                    .execute()
                
                // Try to parse the JSON response
                if let jsonString = String(data: response.data, encoding: .utf8) {
                    print("Upsert response JSON: \(jsonString)")
                }
                
                do {
                    let jsonArray = try JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]]
                    
                    if let userData = jsonArray?.first {
                        print("Upserted user data: \(userData)")
                        processUserProfile(userData: userData, userId: userId, completion: completion)
                    } else {
                        print("No user data returned from upsert")
                        
                        // Fallback to returning the local user object
                        DispatchQueue.main.async {
                            completion(.success(user))
                        }
                    }
                } catch {
                    print("Upsert JSON parsing error: \(error)")
                    
                    // Fallback to returning the local user object
                    DispatchQueue.main.async {
                        completion(.success(user))
                    }
                }
            } catch {
                print("Failed to create/update minimal profile in database: \(error)")
                print("Error details: \(error.localizedDescription)")
                
                // Fallback to returning the local user object
                DispatchQueue.main.async {
                    completion(.success(user))
                }
            }
        }
    }
    
    /// Fetch all users from Supabase
    func fetchAllUsers(completion: @escaping (Result<[User], Error>) -> Void) {
        Task {
            do {
                let response = try await supabase
                    .database
                    .from("users")
                    .select()
                    .execute()
                
                if let userData = response.data as? [[String: Any]] {
                    var users: [User] = []
                    
                    for userDict in userData {
                        let userId = userDict["user_id"] as? String ?? ""
                        let name = userDict["name"] as? String ?? "Unknown"
                        let phone = userDict["phone"] as? String ?? ""
                        let profileImageUrl = userDict["profile_image_url"] as? String ?? ""
                        let shareLocation = userDict["share_location"] as? Bool ?? false
                        
                        // Create basic user object
                        var user = User(
                            userId: userId,
                            name: name,
                            phoneNumber: phone,
                            profileImages: [],
                            verificationCode: "",
                            shareLocation: shareLocation,
                            location: nil,
                            sharedWithUserIds: [],
                            friendListUserIds: [],
                            sharedAlbums: []
                        )
                        
                        // Add to local model if not already there
                        if UserDataModel.shared.getUser(byId: userId) == nil {
                            UserDataModel.shared.addUser(user)
                        }
                        
                        // Load profile image if available
                        if !profileImageUrl.isEmpty {
                            user.profileImageUrl = profileImageUrl
                        }
                        
                        users.append(user)
                    }
                    
                    DispatchQueue.main.async {
                        completion(.success(users))
                    }
                } else {
                    let error = NSError(
                        domain: "SupabaseManagerError",
                        code: 400,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to parse user data"]
                    )
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            } catch {
                print("Error fetching users: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    func findUsersByPhone(phoneNumbers: [String], completion: @escaping (Result<[User], Error>) -> Void) {
        print("🔍 Searching Supabase with phone numbers: \(phoneNumbers)")
        
        Task {
            do {
                var users: [User] = []
                var processedUserIds = Set<String>()
                let currentUserId = SessionManager.shared.getSession() // Get current user ID
                
                // Create query with multiple phone format options
                var queryBuilder = supabase
                    .database
                    .from("users")
                    .select("*")
                
                // Build OR conditions for each phone number
                var orConditions: [String] = []
                for phone in phoneNumbers {
                    // Add multiple possible phone formats to search
                    orConditions.append("phone.eq.\(phone)")
                    
                    // If the number starts with +91, also try without +
                    if phone.hasPrefix("+91") {
                        orConditions.append("phone.eq.\(phone.dropFirst(3))")
                    }
                }
                
                // Join all OR conditions
                let orQuery = orConditions.joined(separator: ",")
                queryBuilder = queryBuilder.or(orQuery)
                
                // Execute the query
                let response = try await queryBuilder.execute()
                
                // Log raw response for debugging
                if let jsonString = String(data: response.data, encoding: .utf8) {
                    print("Raw database response: \(jsonString)")
                }
                
                // Parse the results
                if let userData = try JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]] {
                    print("Found \(userData.count) matching users")
                    
                    for userDict in userData {
                        let userId = userDict["user_id"] as? String ?? ""
                        
                        // Skip current user and already processed users
                        if userId == currentUserId || processedUserIds.contains(userId) {
                            continue
                        }
                        
                        processedUserIds.insert(userId)
                        
                        let name = userDict["name"] as? String ?? "Unknown"
                        let phone = userDict["phone"] as? String ?? ""
                        let profileImageUrl = userDict["profile_image_url"] as? String ?? ""
                        
                        var user = User(
                            userId: userId,
                            name: name,
                            phoneNumber: phone,
                            profileImages: [],
                            verificationCode: "",
                            shareLocation: false,
                            location: nil,
                            sharedWithUserIds: [],
                            friendListUserIds: [],
                            sharedAlbums: []
                        )
                        
                        user.profileImageUrl = profileImageUrl
                        users.append(user)
                    }
                }
                
                // Return the matched users
                DispatchQueue.main.async {
                    completion(.success(users))
                }
            } catch {
                print("Error finding users by phone: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    

    // Add a user as friend (one direction)
    func addUserAsFriend(userId: String, friendId: String, completion: @escaping (Bool) -> Void) {
        Task {
            do {
                // First get current friend list
                let response = try await supabase
                    .database
                    .from("user_friends")
                    .select("friend_id")
                    .eq("user_id", value: userId)
                    .execute()
                
                var existingFriendIds: [String] = []
                
                if let friendData = try JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]] {
                    existingFriendIds = friendData.compactMap { $0["friend_id"] as? String }
                }
                
                // Check if already friends
                if existingFriendIds.contains(friendId) {
                    // Already friends
                    completion(true)
                    return
                }
                
                // Add new friend
                let insertRecord: [String: AnyCodable] = [
                    "user_id": AnyCodable(userId.lowercased()),
                    "friend_id": AnyCodable(friendId.lowercased())
                ]
                
                _ = try await supabase
                    .database
                    .from("user_friends")
                    .insert(insertRecord)
                    .execute()
                
                print("Successfully added \(friendId) as friend of \(userId)")
                
                // Update local model if needed
                if var user = UserDataModel.shared.getUser(byId: userId) {
                    var friendList = user.friendListUserIds ?? []
                    if !friendList.contains(friendId) {
                        friendList.append(friendId)
                        user.friendListUserIds = friendList
                        UserDataModel.shared.updateUser(user)
                    }
                }
                
                DispatchQueue.main.async {
                    completion(true)
                }
                
            } catch {
                print("Error adding friend: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }

    // Find a specific user by phone number with improved matching
    // Replace existing findUserByPhone function with this updated version
    func findUserByPhone(phone: String, completion: @escaping (Result<User?, Error>) -> Void) {
        Task {
            do {
                print("Searching for user with phone: \(phone)")
                
                // Ensure consistent phone number formatting
                let canonicalPhone = PhoneNumberFormatter.canonicalFormat(phone)
                
                // Generate all possible phone number variants
                let phoneVariants = PhoneNumberFormatter.standardizePhoneNumber(phone)
                print("Searching with phone variants: \(phoneVariants)")
                
                // Try each variant to find the user
                for variant in phoneVariants {
                    print("Trying phone variant: \(variant)")
                    
                    let query = supabase
                        .database
                        .from("users")
                        .select("*")
                        .eq("phone", value: variant)
                    
                    let response = try await query.execute()
                    
                    // Log raw response for debugging
                    if let jsonString = String(data: response.data, encoding: .utf8) {
                        print("Database response for variant \(variant): \(jsonString)")
                    }
                    
                    // Parse the response
                    if let userData = try JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]],
                       let firstUser = userData.first {
                        
                        let userId = (firstUser["user_id"] as? String ?? "").lowercased()
                        let name = firstUser["name"] as? String ?? "Unknown"
                        
                        print("Found user: \(name), ID: \(userId)")
                        
                        var user = User(
                            userId: userId,
                            name: name,
                            phoneNumber: variant,
                            profileImages: [],
                            verificationCode: "",
                            shareLocation: firstUser["share_location"] as? Bool ?? false,
                            location: nil,
                            sharedWithUserIds: [],
                            friendListUserIds: [],
                            sharedAlbums: []
                        )
                        
                        user.profileImageUrl = firstUser["profile_image_url"] as? String ?? ""
                        
                        // Add to local model
                        UserDataModel.shared.addUser(user)
                        
                        DispatchQueue.main.async {
                            completion(.success(user))
                        }
                        return
                    }
                }
                
                // If no user found after trying all variants
                print("No user found with any phone variant")
                DispatchQueue.main.async {
                    completion(.success(nil))
                }
            } catch {
                print("Error finding user by phone: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    
}
import Foundation
import UIKit
import Supabase

extension SupabaseManager {
    
    /// Improved version of findUsersByPhone that handles phone number formatting better
    func findUsersMatchingContacts(phoneNumbers: [String], completion: @escaping (Result<[User], Error>) -> Void) {
        Task {
            do {
                print("Finding users matching \(phoneNumbers.count) contacts")
                var users: [User] = []
                
                // Create a set of standardized phone numbers for comparison
                var standardizedPhones: [String] = []
                for phone in phoneNumbers {
                    standardizedPhones.append(contentsOf: PhoneNumberFormatter.standardizePhoneNumber(phone))
                }
                
                // Make the array unique to avoid redundant queries
                let uniquePhones = Array(Set(standardizedPhones))
                print("Generated \(uniquePhones.count) unique phone formats to search")
                
                // Process phone numbers in batches to avoid URL length limitations
                let batchSize = 10
                let batches = stride(from: 0, to: uniquePhones.count, by: batchSize).map {
                    Array(uniquePhones[$0..<min($0 + batchSize, uniquePhones.count)])
                }
                
                // Process each batch
                for (batchIndex, batch) in batches.enumerated() {
                    print("Processing batch \(batchIndex+1)/\(batches.count) with \(batch.count) numbers")
                    
                    if batch.isEmpty {
                        continue
                    }
                    
                    // Construct query with OR conditions for each phone number format
                    var queryBuilder = supabase
                        .database
                        .from("users")
                        .select("*")
                    
                    // Build the OR query for each phone format
                    var orConditions: [String] = []
                    for phone in batch {
                        orConditions.append("phone.eq.\(phone)")
                    }
                    
                    // Join all OR conditions
                    let orQuery = orConditions.joined(separator: ",")
                    queryBuilder = queryBuilder.or(orQuery)
                    
                    // Execute the query
                    let response = try await queryBuilder.execute()
                    
                    // Debug - show raw response
                    if let jsonString = String(data: response.data, encoding: .utf8) {
                        print("Batch \(batchIndex+1) response: \(jsonString)")
                    }
                    
                    // Parse the results
                    if let userData = try JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]] {
                        print("Found \(userData.count) matching users in batch \(batchIndex+1)")
                        
                        for userDict in userData {
                            let userId = userDict["user_id"] as? String ?? ""
                            let name = userDict["name"] as? String ?? "Unknown"
                            let phone = userDict["phone"] as? String ?? ""
                            let profileImageUrl = userDict["profile_image_url"] as? String ?? ""
                            
                            var user = User(
                                userId: userId,
                                name: name,
                                phoneNumber: phone,
                                profileImages: [],
                                verificationCode: "",
                                shareLocation: false,
                                location: nil,
                                sharedWithUserIds: [],
                                friendListUserIds: [],
                                sharedAlbums: []
                            )
                            
                            // Set profile image URL
                            user.profileImageUrl = profileImageUrl
                            
                            // Add to results if not already added
                            if !users.contains(where: { $0.userId == userId }) {
                                users.append(user)
                                
                                // Add to local data model if not already there
                                if UserDataModel.shared.getUser(byId: userId) == nil {
                                    UserDataModel.shared.addUser(user)
                                }
                            }
                        }
                    }
                }
                
                print("Found total of \(users.count) matching users from all batches")
                
                DispatchQueue.main.async {
                    completion(.success(users))
                }
            } catch {
                print("Error finding users by phone: \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    
    /// Registers phone contacts with the backend and automatically adds matching app users as friends
    func registerContactsAsFriends(userId: String, contactPhones: [String], completion: @escaping (Result<[User], Error>) -> Void) {
        // First find all users matching the contact phone numbers
        findUsersMatchingContacts(phoneNumbers: contactPhones) { [weak self] result in
            switch result {
            case .success(let matchedUsers):
                print("Found \(matchedUsers.count) app users matching contact list")
                
                // Get user IDs of matches
                let matchedUserIds = matchedUsers.map { $0.userId }
                
                // Update friend relationship in Supabase
                self?.updateFriendList(userId: userId, friendIds: matchedUserIds) { success in
                    if success {
                        print("Successfully updated friend relationships")
                        
                        // Also update the local user model
                        if var currentUser = UserDataModel.shared.getUser(byId: userId) {
                            currentUser.friendListUserIds = matchedUserIds
                            UserDataModel.shared.updateUser(currentUser)
                        }
                        
                        completion(.success(matchedUsers))
                    } else {
                        let error = NSError(
                            domain: "SupabaseManagerError",
                            code: 500,
                            userInfo: [NSLocalizedDescriptionKey: "Failed to update friend relationships"]
                        )
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Enhanced version to register a new user, ensuring phone number is properly formatted
    func registerNewUser(userId: String, name: String, phoneNumber: String, completion: @escaping (Result<User, Error>) -> Void) {
        Task {
            do {
                // Format phone number consistently
                let canonicalPhone = PhoneNumberFormatter.canonicalFormat(phoneNumber)
                
                // Create user record
                let userData: [String: AnyCodable] = [
                    "user_id": AnyCodable(userId),
                    "name": AnyCodable(name),
                    "phone": AnyCodable(canonicalPhone),
                    "profile_image_url": AnyCodable(""),
                    "registration_complete": AnyCodable(true)
                ]
                
                print("Registering new user: \(name), Phone: \(canonicalPhone), ID: \(userId)")
                
                // Insert into Supabase
                let response = try await supabase
                    .database
                    .from("users")
                    .upsert(userData)
                    .select()
                    .execute()
                
                if let jsonString = String(data: response.data, encoding: .utf8) {
                    print("User registration response: \(jsonString)")
                }
                
                // Create local User object
                let user = User(
                    userId: userId,
                    name: name,
                    phoneNumber: canonicalPhone,
                    profileImages: [],
                    verificationCode: "",
                    shareLocation: false,
                    location: nil,
                    sharedWithUserIds: [],
                    friendListUserIds: [],
                    sharedAlbums: []
                )
                
                // Add to local data model
                UserDataModel.shared.updateUser(user)
                
                DispatchQueue.main.async {
                    completion(.success(user))
                }
            } catch {
                print("Error registering new user: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
}
