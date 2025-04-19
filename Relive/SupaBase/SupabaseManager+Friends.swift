import Foundation
import UIKit
import Supabase

extension SupabaseManager {
    
    /// Get user's friend list from Supabase
    func getUserFriends(userId: String, completion: @escaping (Result<[String], Error>) -> Void) {
        Task {
            do {
                // Comprehensive logging for debugging
                print("🔍 DETAILED Fetching friends for user ID: \(userId)")
                print("🔍 USER ID Length: \(userId.count)")
                
                // More aggressive ID cleaning
                let cleanUserId = userId
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "'", with: "")
                    .replacingOccurrences(of: "\"", with: "")
                    .lowercased()
                
                print("🔍 USER ID Cleaned: '\(cleanUserId)'")
                
                // Validate UUID
                guard UUID(uuidString: cleanUserId) != nil else {
                    print("❌ Invalid UUID format")
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "SupabaseManager",
                                                    code: 400,
                                                    userInfo: [NSLocalizedDescriptionKey: "Invalid User ID format"])))
                    }
                    return
                }
                
                // More robust query
                let response = try await supabase
                    .database
                    .from("user_friends")
                    .select("friend_id")
                    .eq("user_id", value: cleanUserId)
                    .execute()
                
                // Detailed friend ID parsing
                struct FriendRecord: Codable {
                    let friend_id: String
                }
                
                // Debug print raw response
                if let rawResponseString = String(data: response.data, encoding: .utf8) {
                    print("🔬 Raw Friends Response: \(rawResponseString)")
                }
                
                var friendIds: [String] = []
                
                do {
                    // Robust JSON decoding
                    let decoder = JSONDecoder()
                    let records = try decoder.decode([FriendRecord].self, from: response.data)
                    
                    // Sanitize and clean friend IDs
                    friendIds = records.map { friendId in
                        friendId.friend_id
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .replacingOccurrences(of: "'", with: "")
                            .replacingOccurrences(of: "\"", with: "")
                            .lowercased()
                    }
                    .filter { UUID(uuidString: $0) != nil } // Ensure valid UUIDs
                    
                    // Additional logging
                    print("🏁 Total Friends Found: \(friendIds.count)")
                    print("🏁 Validated Friend IDs: \(friendIds)")
                    
                    // Log each friend ID individually
                    friendIds.enumerated().forEach { (index, friendId) in
                        print("Friend \(index + 1): \(friendId)")
                    }
                } catch {
                    print("❌ Parsing Error: \(error)")
                    print("Raw Response Data: \(String(data: response.data, encoding: .utf8) ?? "Unable to decode")")
                }
                
                // Ensure main thread for completion
                DispatchQueue.main.async {
                    if friendIds.isEmpty {
                        print("⚠️ No valid friends found for user \(cleanUserId)")
                    }
                    completion(.success(friendIds))
                }
            } catch {
                // Comprehensive error logging
                print("❌ Error fetching user friends:")
                print("Error Type: \(type(of: error))")
                print("Error Description: \(error.localizedDescription)")
                
                // Additional context for debugging
                if let supabaseError = error as? PostgrestError {
                    print("Supabase Error Details:")
                    print("Code: \(supabaseError.code ?? "N/A")")
                    print("Message: \(supabaseError.message ?? "No message")")
                }
                
                // Ensure main thread for completion
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    // Utility timeout function to prevent indefinite waiting
    func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw URLError(.timedOut)
            }
            
            let result = try await group.next()
            group.cancelAll()
            return result!
        }
    }
    /// Create a bidirectional friendship between two users
    func addBidirectionalFriendship(userId1: String, userId2: String, completion: @escaping (Bool) -> Void) {
        // First get existing friends of user1
        getUserFriends(userId: userId1) { [weak self] result1 in
            switch result1 {
            case .success(let friends1):
                var updatedFriends1 = friends1
                if !updatedFriends1.contains(userId2) {
                    updatedFriends1.append(userId2)
                }
                
                // Then get existing friends of user2
                self?.getUserFriends(userId: userId2) { result2 in
                    switch result2 {
                    case .success(let friends2):
                        var updatedFriends2 = friends2
                        if !updatedFriends2.contains(userId1) {
                            updatedFriends2.append(userId1)
                        }
                        
                        // Update both friend lists
                        let dispatchGroup = DispatchGroup()
                        var success1 = false
                        var success2 = false
                        
                        dispatchGroup.enter()
                        self?.updateFriendList(userId: userId1, friendIds: updatedFriends1) { result in
                            success1 = result
                            dispatchGroup.leave()
                        }
                        
                        dispatchGroup.enter()
                        self?.updateFriendList(userId: userId2, friendIds: updatedFriends2) { result in
                            success2 = result
                            dispatchGroup.leave()
                        }
                        
                        dispatchGroup.notify(queue: .main) {
                            completion(success1 && success2)
                        }
                        
                    case .failure:
                        // If we can't get user2's friends, at least update user1's friends
                        self?.updateFriendList(userId: userId1, friendIds: updatedFriends1) { result in
                            completion(result)
                        }
                    }
                }
                
            case .failure:
                completion(false)
            }
        }
    }
    /// Update user's friend list in Supabase
    func updateFriendList(userId: String, friendIds: [String], completion: @escaping (Bool) -> Void) {
        Task {
            do {
                print("Updating friend list for user: \(userId) with \(friendIds.count) friends")
                
                // First, verify all friend IDs exist in the users table
                var validFriendIds: [String] = []
                
                for friendId in friendIds {
                    do {
                        // Try to check if this user exists
                        let response = try await supabase
                            .database
                            .from("users")
                            .select("user_id")
                            .eq("user_id", value: friendId)
                            .limit(1)
                            .execute()
                        
                        // Parse the response to check if user exists
                        let decoder = JSONDecoder()
                        struct UserRecord: Codable {
                            let user_id: String
                        }
                        
                        let userRecords = try decoder.decode([UserRecord].self, from: response.data)
                        if !userRecords.isEmpty {
                            validFriendIds.append(friendId)
                        } else {
                            print("Warning: User with ID \(friendId) doesn't exist in database")
                        }
                    } catch {
                        print("Error checking if user \(friendId) exists: \(error.localizedDescription)")
                    }
                }
                
                print("Found \(validFriendIds.count) valid friends out of \(friendIds.count) requested")
                
                // Delete existing friend relationships
                _ = try await supabase
                    .database
                    .from("user_friends")
                    .delete()
                    .eq("user_id", value: userId.lowercased())
                    .execute()
                
                print("Delete response successful")
                
                // If we have valid friends to insert
                if !validFriendIds.isEmpty {
                    var successCount = 0
                    
                    // Insert each friend separately to avoid batch issues
                    for friendId in validFriendIds {
                        do {
                            // Use AnyCodable for more reliable serialization
                            let insertRecord: [String: AnyCodable] = [
                                "user_id": AnyCodable(userId.lowercased()),
                                "friend_id": AnyCodable(friendId.lowercased())
                            ]
                            
                            print("Attempting to insert record: \(insertRecord)")
                            
                            _ = try await supabase
                                .database
                                .from("user_friends")
                                .insert(insertRecord)
                                .execute()
                            
                            successCount += 1
                            print("Successfully inserted friend record \(successCount)")
                        } catch {
                            print("Error inserting friend: \(error.localizedDescription)")
                        }
                    }
                    
                    print("Successfully inserted \(successCount) of \(validFriendIds.count) friend records")
                    
                    // Update local user model
                    DispatchQueue.main.async {
                        if var user = UserDataModel.shared.getUser(byId: userId) {
                            // Only include the successfully added friends in the model
                            user.friendListUserIds = validFriendIds
                            UserDataModel.shared.updateUser(user)
                        }
                        
                        completion(successCount > 0)
                    }
                } else {
                    print("No valid friend IDs to insert")
                    DispatchQueue.main.async {
                        completion(true) // Still return true as the operation succeeded (just empty)
                    }
                }
            } catch {
                print("Error updating friend list: \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
    
    func sanitizeFriendIDs(_ friendIDs: [String]) -> [String] {
        return friendIDs.map { friendID in
            // Remove any surrounding single or double quotes
            let sanitized = friendID.trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
            return sanitized
        }
    }

  
}
