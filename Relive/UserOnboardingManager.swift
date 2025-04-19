import Foundation
import UIKit

// This class should be used after successful registration or login
class UserOnboardingManager {
    
    static let shared = UserOnboardingManager()
    
    // Call this method after a new user successfully registers
    func completeRegistration(userId: String, name: String, phoneNumber: String, completion: @escaping (Bool) -> Void) {
        print("Completing registration for user: \(name), ID: \(userId)")
        
        // 1. Register the user in Supabase
        SupabaseManager.shared.registerNewUser(userId: userId, name: name, phoneNumber: phoneNumber) { result in
            switch result {
            case .success(let user):
                print("Successfully registered user in database: \(user.name)")
                
                // 2. Start automatic friend discovery
                FriendDiscoveryManager.shared.performAutomaticFriendDiscovery(userId: userId)
                
                // 3. Complete standard login tasks
                SupabaseManager.shared.loginCompletion(userId: userId)
                
                // 4. Notify caller of completion
                completion(true)
                
            case .failure(let error):
                print("Failed to register user: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
    
    // Call this method when a user logs in
    func completeLogin(userId: String, completion: @escaping (Bool) -> Void) {
        print("Completing login for user ID: \(userId)")
        
        // 1. Fetch the user profile
        SupabaseManager.shared.getUserProfile(userId: userId) { result in
            switch result {
            case .success(let user):
                print("Successfully fetched user profile: \(user.name)")
                
                // 2. Perform standard login completion
                SupabaseManager.shared.loginCompletion(userId: userId)
                
                // 3. Start friend discovery in the background
                FriendDiscoveryManager.shared.performAutomaticFriendDiscovery(userId: userId)
                
                // 4. Notify caller of completion
                completion(true)
                
            case .failure(let error):
                print("Failed to fetch user profile: \(error.localizedDescription)")
                
                // Still complete the login, but log the error
                SupabaseManager.shared.loginCompletion(userId: userId)
                completion(true)
            }
        }
    }
}
