import Foundation
import UIKit
import Supabase

extension SupabaseManager {
    
    func syncUserDataAfterLogin(userId: String, completion: @escaping (Bool) -> Void) {
        Task {
            do {
                print("Starting complete data sync for user: \(userId)")
                
                // Step 1: Get the basic user profile
                let response = try await supabase
                    .database
                    .from("users")
                    .select("*")
                    .eq("user_id", value: userId)
                    .limit(1)
                    .execute()
                    
                guard let userData = (try JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]])?.first else {
                    print("User not found in database during sync")
                    DispatchQueue.main.async {
                        completion(false)
                    }
                    return
                }
                
                print("Got user profile data from database")
                
                // Step 2: Extract user information
                let name = userData["name"] as? String ?? "Unknown"
                let phone = userData["phone"] as? String ?? ""
                let profileImageUrl = userData["profile_image_url"] as? String ?? ""
                let shareLocation = userData["share_location"] as? Bool ?? false
                
                // Get location if available
                var location: LocationCoordinate? = nil
                if let latitude = userData["latitude"] as? Double,
                   let longitude = userData["longitude"] as? Double {
                    // Create LocationCoordinate directly with lat/lng
                    location = LocationCoordinate(latitude: latitude, longitude: longitude)
                }
                
                // Step 3: Get user's friends list
                let friendsResponse = try await supabase
                    .database
                    .from("user_friends")
                    .select("friend_id")
                    .eq("user_id", value: userId)
                    .execute()
                    
                let friendListUserIds = (try JSONSerialization.jsonObject(with: friendsResponse.data, options: []) as? [[String: Any]])?.compactMap { $0["friend_id"] as? String } ?? []
                
                print("Got \(friendListUserIds.count) friends from database")
                
                // Step 4: Get shared albums
                let albumsResponse = try await supabase
                    .database
                    .from("shared_albums")
                    .select("album_id")
                    .or("created_by_user_id.eq.\(userId),shared_with_user_ids.cs.{\"\(userId)\"}")
                    .execute()
                    
                let sharedAlbums = (try JSONSerialization.jsonObject(with: albumsResponse.data, options: []) as? [[String: Any]])?.compactMap { $0["album_id"] as? String } ?? []
                
                print("Got \(sharedAlbums.count) shared albums from database")
                
                // Step 5: Get users who can see this user's location
                let sharingResponse = try await supabase
                    .database
                    .from("location_sharing")
                    .select("shared_with_id")
                    .eq("user_id", value: userId)
                    .execute()
                    
                let sharedWithUserIds = (try JSONSerialization.jsonObject(with: sharingResponse.data, options: []) as? [[String: Any]])?.compactMap { $0["shared_with_id"] as? String } ?? []
                
                print("User shares location with \(sharedWithUserIds.count) users")
                
                // Step 6: Create complete user object
                var user = User(
                    userId: userId,
                    name: name,
                    phoneNumber: phone,
                    profileImages: [],
                    verificationCode: "",
                    shareLocation: shareLocation,
                    location: location,
                    sharedWithUserIds: sharedWithUserIds,
                    friendListUserIds: friendListUserIds,
                    sharedAlbums: sharedAlbums
                )
                
                user.profileImageUrl = profileImageUrl
                user.registrationComplete = userData["registration_complete"] as? Bool ?? false
                
                // Step 7: Update the user in the local data model
                DispatchQueue.main.async {
                    print("Updating local user data model with fully synced data")
                    UserDataModel.shared.updateUser(user)
                    
                    // Step 8: If there's a profile image URL, load the image data
                    if !profileImageUrl.isEmpty {
                        self.loadProfileImageFromURL(profileImageUrl) { imageData in
                            if let imageData = imageData {
                                print("Successfully loaded profile image data")
                                
                                // Update user with profile image data
                                var updatedUser = UserDataModel.shared.getUser(byId: userId)
                                updatedUser?.profileImages = [imageData]
                                
                                if let updatedUser = updatedUser {
                                    UserDataModel.shared.updateUser(updatedUser)
                                }
                            }
                        }
                    }
                    
                    completion(true)
                }
                
            } catch {
                print("Error syncing user data: \(error)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
    
    // Helper method to load profile image from URL
    private func loadProfileImageFromURL(_ urlString: String, completion: @escaping (Data?) -> Void) {
        guard let url = URL(string: urlString) else {
            print("Invalid URL for profile image: \(urlString)")
            completion(nil)
            return
        }
        
        print("Attempting to load image from URL: \(urlString)")
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error loading image: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            if let data = data {
                print("Successfully loaded image from URL")
                completion(data)
            } else {
                print("No data received from image URL")
                completion(nil)
            }
        }.resume()
    }
    
    func clearAndSyncAllData(userId: String, completion: @escaping (Bool) -> Void) {
        // Clear all local data first
        clearLocalData()
        
        // Then sync everything from Supabase
        syncAllData(userId: userId, completion: completion)
    }

    // Helper method to clear all local data models
    private func clearLocalData() {
        DispatchQueue.main.async {
            UserDataModel.shared.clearAllData()
            ImageDataModel.shared.clearAllData()
            RevisitDataModel.shared.clearAllData()
            SharedAlbumsDataModel.shared.clearAllData()
            NotificationDataModel.shared.clearAllData()
        }
    }

    // Comprehensive method to sync all data from Supabase
    func syncAllData(userId: String, completion: @escaping (Bool) -> Void) {
        Task {
            do {
                try await syncUserProfile(userId: userId)
                try await syncFriendsList(userId: userId)
                try await syncSharedAlbums(userId: userId)
                try await syncImages(userId: userId) // Ensure this completes
                try await syncRevisits(userId: userId)
                try await syncNotifications(userId: userId)
                
                DispatchQueue.main.async {
                    completion(true)
                }
            } catch {
                completion(false)
            }
        }
    }

    // Sync individual user profile
    private func syncUserProfile(userId: String) async throws {
        print("Syncing user profile for ID: \(userId)")
        
        let response = try await supabase
            .database
            .from("users")
            .select()
            .eq("user_id", value: userId.lowercased())
            .limit(1)
            .execute()
            
        if let userData = try JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]],
           let userInfo = userData.first {
            
            let name = userInfo["name"] as? String ?? "Unknown"
            let phone = userInfo["phone"] as? String ?? ""
            let profileImageUrl = userInfo["profile_image_url"] as? String ?? ""
            let shareLocation = userInfo["share_location"] as? Bool ?? false
            let registrationComplete = userInfo["registration_complete"] as? Bool ?? false
            
            // Create location if available
            var location: LocationCoordinate? = nil
            if let latitude = userInfo["latitude"] as? Double,
               let longitude = userInfo["longitude"] as? Double {
                location = LocationCoordinate(latitude: latitude, longitude: longitude)
            }
            
            // Create the user object
            var user = User(
                userId: userId,
                name: name,
                phoneNumber: phone,
                profileImages: [],
                verificationCode: "",
                shareLocation: shareLocation,
                location: location,
                sharedWithUserIds: [],
                friendListUserIds: [],
                sharedAlbums: []
            )
            
            user.profileImageUrl = profileImageUrl
            user.registrationComplete = registrationComplete
            
            // Save to local data model
            DispatchQueue.main.async {
                UserDataModel.shared.updateUser(user)
                print("User profile synchronized: \(name), ID: \(userId)")
                
                // If there's a profile image URL, load it
                if !profileImageUrl.isEmpty {
                    self.loadProfileImageFromURL(profileImageUrl) { imageData in
                        if let imageData = imageData {
                            var updatedUser = UserDataModel.shared.getUser(byId: userId)
                            updatedUser?.profileImages = [imageData]
                            
                            if let updatedUser = updatedUser {
                                UserDataModel.shared.updateUser(updatedUser)
                                print("Profile image synchronized")
                            }
                        }
                    }
                }
            }
        } else {
            print("No user data found for ID: \(userId)")
        }
    }

    // Sync friends list
    private func syncFriendsList(userId: String) async throws {
        print("Syncing friends list for user: \(userId)")
        
        let response = try await supabase
            .database
            .from("user_friends")
            .select("friend_id")
            .eq("user_id", value: userId.lowercased())
            .execute()
            
        let friendsData = try JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]] ?? []
        let friendIds = friendsData.compactMap { $0["friend_id"] as? String }
        
        print("Found \(friendIds.count) friends")
        
        // Update local user with friends list
        DispatchQueue.main.async {
            if var user = UserDataModel.shared.getUser(byId: userId) {
                user.friendListUserIds = friendIds
                UserDataModel.shared.updateUser(user)
                print("Friends list updated")
            }
        }
    }

    // Sync shared albums
    private func syncSharedAlbums(userId: String) async throws {
        print("Syncing shared albums for user: \(userId)")
        
        // Get both created by user and shared with user albums
        let response = try await supabase
            .database
            .from("shared_albums")
            .select("*")  // Select all fields
            .or("created_by_user_id.eq.\(userId.lowercased()),shared_with_user_ids.cs.{\"\(userId.lowercased())\"}")
            .execute()
        
        // Debug print raw response
        print("Raw Album Sync Response: \(String(data: response.data, encoding: .utf8) ?? "nil")")
        
        guard let albumsData = try JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]] else {
            print("Failed to parse albums data")
            return
        }
        
        print("Found \(albumsData.count) shared albums")
        
        var albumIds: [String] = []
        
        for albumData in albumsData {
            let albumId = albumData["album_id"] as? String ?? UUID().uuidString
            let albumName = albumData["album_name"] as? String ?? "Untitled Album"
            let createdByUserId = albumData["created_by_user_id"] as? String ?? ""
            
            // Parse shared with user IDs
            let sharedWithUserIds = parseArrayField(albumData["shared_with_user_ids"])
            
            // Extract image IDs more robustly
            var imageIds: [String] = []
            
            if let directImageIds = albumData["image_ids"] as? [String] {
                // Direct image_ids field
                imageIds = directImageIds
            } else if let imageIdsJson = albumData["image_ids"] {
                // Try to parse if it's a JSON string
                if let imageIdsData = try? JSONSerialization.data(withJSONObject: imageIdsJson, options: []),
                   let imageIdsString = String(data: imageIdsData, encoding: .utf8) {
                    print("Image IDs JSON: \(imageIdsString)")
                    
                    // Try to extract array from string (handling PostgreSQL array format)
                    if let arrayString = imageIdsString.replacingOccurrences(of: "\"", with: "")
                        .replacingOccurrences(of: "[", with: "")
                        .replacingOccurrences(of: "]", with: "")
                        .components(separatedBy: ",") as? [String] {
                        imageIds = arrayString.filter { !$0.isEmpty }
                    }
                }
            }
            
            print("Album \(albumId) has \(imageIds.count) images: \(imageIds)")
            
            // Parse created at date
            var createdAt = Date()
            if let createdAtStr = albumData["created_at"] as? String {
                let dateFormatter = ISO8601DateFormatter()
                createdAt = dateFormatter.date(from: createdAtStr) ?? Date()
            }
            
            // Create album object
            let album = SharedAlbum(
                albumId: albumId,
                albumName: albumName,
                createdByUserId: createdByUserId,
                sharedWithUserIds: sharedWithUserIds,
                imagesIds: imageIds,
                createdAt: createdAt
            )
            
            // Add to local data store
            DispatchQueue.main.async {
                SharedAlbumsDataModel.shared.addSharedAlbum(album)
                print("Added album: \(albumName) with \(imageIds.count) images")
            }
            
            albumIds.append(albumId)
            
            // Sync images for this album
            if !imageIds.isEmpty {
                try await syncAlbumImages(imageIds: imageIds)
            }
        }
        
        // Update user with album IDs
        DispatchQueue.main.async {
            if var user = UserDataModel.shared.getUser(byId: userId) {
                user.sharedAlbums = albumIds
                UserDataModel.shared.updateUser(user)
                print("User updated with \(albumIds.count) album IDs")
            }
        }
    }

    private func syncAlbumImages(imageIds: [String]) async throws {
        print("Syncing \(imageIds.count) images")
        
        // If no images to sync, return early
        if imageIds.isEmpty {
            print("No images to sync")
            return
        }
        
        // Build a query that selects specific image IDs
        let response = try await supabase
            .database
            .from("images")
            .select()
            .in("image_id", values: imageIds)
            .execute()
        
        // Debug response
        print("Image sync response: \(String(data: response.data, encoding: .utf8) ?? "nil")")
        
        guard let imagesData = try JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]] else {
            print("No image data found for IDs: \(imageIds)")
            return
        }
        
        print("Found \(imagesData.count) images out of \(imageIds.count) requested")
        
        // Create a dispatch group to wait for all images to download
        let downloadGroup = DispatchGroup()
        
        for imageData in imagesData {
            guard let imageId = imageData["image_id"] as? String,
                  let imageUrlStr = imageData["image_url"] as? String,
                  let imageUrl = URL(string: imageUrlStr) else {
                print("Missing required image data for an image record")
                continue
            }
            
            // Enter the dispatch group before starting the download
            downloadGroup.enter()
            
            // Download image data asynchronously
            Task {
                do {
                    print("Downloading image from URL: \(imageUrlStr)")
                    
                    // Async download image data
                    let (data, response) = try await URLSession.shared.data(from: imageUrl)
                    
                    if let httpResponse = response as? HTTPURLResponse {
                        print("Image download status: \(httpResponse.statusCode)")
                    }
                    
                    print("Downloaded image data size: \(data.count) bytes")
                    
                    // Extract location if available
                    var locationCoordinate: LocationCoordinate? = nil
                    if let latitude = imageData["latitude"] as? Double,
                       let longitude = imageData["longitude"] as? Double {
                        locationCoordinate = LocationCoordinate(latitude: latitude, longitude: longitude)
                    }
                    
                    let image = ImageData(
                        imageId: imageId,
                        image: data,
                        locationCaptured: locationCoordinate,
                        capturedByUserId: imageData["captured_by_user_id"] as? String ?? "",
                        sharedWithUserIds: parseArrayField(imageData["shared_with_user_ids"]),
                        createdAt: parseCreatedAtDate(imageData["created_at"])
                    )
                    
                    DispatchQueue.main.async {
                        ImageDataModel.shared.addImage(image)
                        print("✅ Synced image: \(imageId)")
                        downloadGroup.leave()
                    }
                } catch {
                    print("❌ Failed to sync image \(imageId): \(error)")
                    downloadGroup.leave()
                }
            }
        }
        
        // Wait for all downloads to complete with a reasonable timeout
        _ = downloadGroup.wait(timeout: .now() + 60)
        print("Completed syncing \(imagesData.count) images")
    }

    // Helper function to parse created_at dates consistently
    // Helper function to parse created_at dates consistently
    private func parseCreatedAtDate(_ dateValue: Any?) -> Date {
        if let dateString = dateValue as? String {
            let dateFormatter = ISO8601DateFormatter()
            return dateFormatter.date(from: dateString) ?? Date()
        }
        return Date()
    }

    // Sync images
    private func syncImages(userId: String) async throws {
        print("Syncing images for user: \(userId)")
        
        let response = try await supabase
            .database
            .from("images")
            .select()
            .or("captured_by_user_id.eq.\(userId.lowercased()),shared_with_user_ids.cs.{\"\(userId.lowercased())\"}")
            .execute()

        guard let imagesData = try JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]] else {
            print("No image data found")
            return
        }

        // Clear existing images to prevent duplicates
        DispatchQueue.main.async {
            ImageDataModel.shared.clearAllData()
        }

        for imageData in imagesData {
            guard let imageId = imageData["image_id"] as? String,
                  let imageUrlStr = imageData["image_url"] as? String,
                  let imageUrl = URL(string: imageUrlStr) else {
                continue
            }
            
            do {
                // Async download
                let (data, _) = try await URLSession.shared.data(from: imageUrl)
                
                let image = ImageData(
                    imageId: imageId,
                    image: data,
                    locationCaptured: nil,
                    capturedByUserId: imageData["captured_by_user_id"] as? String ?? "",
                    sharedWithUserIds: parseArrayField(imageData["shared_with_user_ids"]),
                    createdAt: Date() // Parse actual date from DB
                )
                
                DispatchQueue.main.async {
                    ImageDataModel.shared.addImage(image)
                    print("✅ Synced image: \(imageId)")
                }
            } catch {
                print("❌ Failed to sync image \(imageId): \(error)")
            }
        }
    }

    // Sync revisits
    private func syncRevisits(userId: String) async throws {
        print("Syncing revisits for user: \(userId)")
        
        let response = try await supabase
            .database
            .from("revisits")
            .select()
            .eq("user_id", value: userId.lowercased())
            .execute()
            
        if let revisitsData = try JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]] {
            print("Found \(revisitsData.count) revisits")
            
            for revisitData in revisitsData {
                let visitId = revisitData["visit_id"] as? String ?? UUID().uuidString
                
                // Location is required
                guard let latitude = revisitData["latitude"] as? Double,
                      let longitude = revisitData["longitude"] as? Double else {
                    continue
                }
                
                let location = LocationCoordinate(latitude: latitude, longitude: longitude)
                
                // Parse image IDs
                let imageIds = parseArrayField(revisitData["image_ids"])
                
                // Parse shared with user IDs
                let sharedWithUserIds = parseArrayField(revisitData["shared_with_user_ids"])
                
                // Parse date
                var date = Date()
                if let dateStr = revisitData["date"] as? String {
                    let dateFormatter = ISO8601DateFormatter()
                    date = dateFormatter.date(from: dateStr) ?? Date()
                }
                
                let revisit = ReVisit(
                    visitId: visitId,
                    location: location,
                    userId: userId,
                    imageIds: imageIds,
                    date: date,
                    sharedWithUserIds: sharedWithUserIds
                )
                
                DispatchQueue.main.async {
                    RevisitDataModel.shared.addRevisit(revisit)
                    print("Added revisit with ID: \(visitId)")
                }
            }
        }
    }

    // Sync notifications
    private func syncNotifications(userId: String) async throws {
        print("Syncing notifications for user: \(userId)")
        
        let response = try await supabase
            .database
            .from("notifications")
            .select()
            .or("user_id.eq.\(userId.lowercased()),to_notify.cs.{\"\(userId.lowercased())\"}")
            .execute()
            
        if let notificationsData = try JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]] {
            print("Found \(notificationsData.count) notifications")
            
            for notificationData in notificationsData {
                let notificationId = notificationData["notification_id"] as? String ?? UUID().uuidString
                let notificationUserId = notificationData["user_id"] as? String ?? ""
                
                // Parse image IDs
                let imageIds = parseArrayField(notificationData["image_ids"])
                
                // Parse to notify user IDs
                let toNotify = parseArrayField(notificationData["to_notify"])
                
                // Parse created at date
                var createdAt = Date()
                if let createdAtStr = notificationData["created_at"] as? String {
                    let dateFormatter = ISO8601DateFormatter()
                    createdAt = dateFormatter.date(from: createdAtStr) ?? Date()
                }
                
                let notification = Notification(
                    notificationId: notificationId,
                    userId: notificationUserId,
                    imageIds: imageIds,
                    toNotify: toNotify,
                    createdAt: createdAt
                )
                
                DispatchQueue.main.async {
                    NotificationDataModel.shared.addNotification(notification: notification)
                    print("Added notification with ID: \(notificationId)")
                }
            }
        }
    }
    
    // Helper function to parse created_at dates consistently

    
}
