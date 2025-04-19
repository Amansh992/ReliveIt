import Foundation
import UIKit
import Supabase

extension SupabaseManager {
    
    /// Update location sharing preference in Supabase
    func updateLocationSharing(userId: String, isSharing: Bool, completion: @escaping (Bool) -> Void) {
        Task {
            do {
                let updates: [String: AnyCodable] = [
                    "share_location": AnyCodable(isSharing)
                ]
                
                _ = try await supabase
                    .database
                    .from("users")
                    .update(updates)
                    .eq("user_id", value: userId)
                    .execute()
                
                print("Successfully updated location sharing status in Supabase")
                
                DispatchQueue.main.async {
                    completion(true)
                }
            } catch {
                print("Error updating location sharing status: \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }

    /// Update user location in Supabase
    func updateUserLocation(userId: String, latitude: Double, longitude: Double, completion: @escaping (Bool) -> Void) {
        Task {
            do {
                let updates: [String: AnyCodable] = [
                    "share_location": AnyCodable(true),
                    "latitude": AnyCodable(latitude),
                    "longitude": AnyCodable(longitude)
                ]
                
                _ = try await supabase
                    .database
                    .from("users")
                    .update(updates)
                    .eq("user_id", value: userId)
                    .execute()
                
                print("Successfully updated location in Supabase")
                
                DispatchQueue.main.async {
                    completion(true)
                }
            } catch {
                print("Error updating location in Supabase: \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
    
    // Get users who can see the current user's location
    func getLocationSharedWithUsers(userId: String, completion: @escaping (Result<[String], Error>) -> Void) {
        Task {
            do {
                // Get the user's location sharing list from the location_sharing table
                let response = try await supabase
                    .database
                    .from("location_sharing")
                    .select("shared_with_id")
                    .eq("user_id", value: userId)
                    .execute()
                
                if let sharingData = response.data as? [[String: Any]] {
                    let sharedWithIds = sharingData.compactMap { $0["shared_with_id"] as? String }
                    
                    DispatchQueue.main.async {
                        completion(.success(sharedWithIds))
                    }
                } else {
                    let error = NSError(
                        domain: "SupabaseManagerError",
                        code: 400,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to parse location sharing data"]
                    )
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            } catch {
                print("Error fetching location sharing users: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Update location sharing settings in Supabase
    func updateLocationSharing(userId: String, sharedWithIds: [String], completion: @escaping (Bool) -> Void) {
        Task {
            do {
                // First, delete all existing location sharing settings
                _ = try await supabase
                    .database
                    .from("location_sharing")
                    .delete()
                    .eq("user_id", value: userId)
                    .execute()
                
                // Then insert new location sharing settings
                var insertData: [[String: AnyCodable]] = []
                
                for sharedWithId in sharedWithIds {
                    insertData.append([
                        "user_id": AnyCodable(userId),
                        "shared_with_id": AnyCodable(sharedWithId)
                    ])
                }
                
                if !insertData.isEmpty {
                    _ = try await supabase
                        .database
                        .from("location_sharing")
                        .insert(insertData)
                        .execute()
                }
                
                print("Successfully updated location sharing settings in Supabase")
                
                DispatchQueue.main.async {
                    completion(true)
                }
            } catch {
                print("Error updating location sharing settings: \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
}
