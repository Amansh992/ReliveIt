import Foundation
import UIKit
import Supabase
import Contacts

class ContactManager {
    
    static let shared = ContactManager()
    
    private init() {}
    
    func fetchAppContacts(completion: @escaping ([AppContact]) -> Void) {
        // Request contact permission
        let store = CNContactStore()
        
        // Check authorization status
        let status = CNContactStore.authorizationStatus(for: .contacts)
        
        switch status {
        case .notDetermined:
            // Request permission
            store.requestAccess(for: .contacts) { [weak self] (granted, error) in
                if granted {
                    self?.retrieveContacts(store: store, completion: completion)
                } else {
                    print("Contact access denied")
                    completion([])
                }
            }
        case .authorized:
            retrieveContacts(store: store, completion: completion)
        case .restricted, .denied:
            print("Contact access restricted or denied")
            completion([])
        @unknown default:
            completion([])
        }
    }
    
    private func retrieveContacts(store: CNContactStore, completion: @escaping ([AppContact]) -> Void) {
        // Create fetch request
        let fetchRequest = CNContactFetchRequest(keysToFetch: [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor
        ])
        
        var appContacts: [AppContact] = []
        
        do {
            try store.enumerateContacts(with: fetchRequest) { (contact, _) in
                // Create AppContact
                let appContact = AppContact(
                    name: "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespacesAndNewlines),
                    phoneNumbers: contact.phoneNumbers.map { $0.value.stringValue },
                    emails: contact.emailAddresses.map { $0.value as String }
                )
                
                // You would implement your logic to match contacts with app users here
                // For now, we'll leave appUserID as nil
                appContacts.append(appContact)
            }
            
            // Return on main thread
            DispatchQueue.main.async {
                completion(appContacts)
            }
        } catch {
            print("Error fetching contacts: \(error)")
            completion([])
        }
    }
}

// Contact model
struct AppContact {
    let name: String
    let phoneNumbers: [String]
    let emails: [String]
    var appUserID: String? = nil  // This would be populated by your app's user matching logic
}
extension LocationCoordinate {
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

class SupabaseManager {
    
    static let shared = SupabaseManager()

    let supabase: SupabaseClient
    let profileImageBucket = "profile-images"
    let albumImagesBucket = "album-images"
    var client: SupabaseClient? {
          return supabase
      }
    

    private init() {
        let supabaseUrl = URL(string: "https://nilixltrfenhakxbigve.supabase.co")!
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5pbGl4bHRyZmVuaGFreGJpZ3ZlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDMxNTgzMjgsImV4cCI6MjA1ODczNDMyOH0.ecVr2WxpezDXnbrUXji8r3NrWZjBk6oOR5FuokDHSWU"

        self.supabase = SupabaseClient(supabaseURL: supabaseUrl, supabaseKey: supabaseKey)
        
        // Ensure the storage bucket exists when the manager is initialized
        self.initializeStorageBuckets()
    }
    
    private func initializeStorageBuckets() {
        Task {
            do {
                guard let user = supabase.auth.currentUser else {
                    print("No authenticated user, skipping bucket initialization")
                    return
                }
                let buckets = try await supabase.storage.listBuckets()
                
                if !buckets.contains(where: { $0.name == profileImageBucket }) {
                    _ = try await supabase.storage.createBucket(
                        profileImageBucket,
                        options: BucketOptions(public: true)
                    )
                    print("Created profile images bucket")
                }
                
                if !buckets.contains(where: { $0.name == albumImagesBucket }) {
                    _ = try await supabase.storage.createBucket(
                        albumImagesBucket,
                        options: BucketOptions(public: true)
                    )
                    print("Created album images bucket")
                }
            } catch {
                print("Error initializing storage buckets: \(error.localizedDescription)")
            }
        }
    }
    // Add this to wherever you handle user login completion:

    func loginCompletion(userId: String) {
        // First sync all user data
        SupabaseManager.shared.syncAllUserContent(userId: userId) { success in
            if success {
                print("Successfully synced all user content after login")
                
                // Post notification to update album views
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("AlbumUpdatedNotification"), object: nil)
                }
            } else {
                print("Failed to sync user content after login")
            }
        }
        UserDefaults.standard.set(true, forKey: "NeedsAlbumForceRefresh")
    }
    func debugCurrentSession() {
        // Check if there's a current user
        if let user = supabase.auth.currentUser {
            print("🔍 Current User Details:")
            print("   User ID: \(user.id)")
            print("   User ID (string): \(user.id.uuidString)")
            print("   User Email: \(user.email ?? "No email")")
        } else {
            print("❌ No current user found")
        }
    }
    // Add this method to your SupabaseManager class
    func updateSharedWithUsers(userId: String, sharedWithUserIds: [String], completion: @escaping (Bool) -> Void) {
        Task {
            do {
                // First, delete all existing sharing permissions for this user
                _ = try await supabase
                    .from("location_sharing")
                    .delete()
                    .eq("user_id", value: userId)
                    .execute()
                
                print("Deleted existing location sharing permissions for user \(userId)")
                
                // If there are no users to share with, we're done
                if sharedWithUserIds.isEmpty {
                    DispatchQueue.main.async {
                        completion(true)
                    }
                    return
                }
                
                // Verify which friends actually exist in the database
                var validFriendIds: [String] = []
                
                for friendId in sharedWithUserIds {
                    do {
                        // Check if user exists
                        let response = try await supabase
                            .database
                            .from("users")
                            .select("user_id")
                            .eq("user_id", value: friendId)
                            .limit(1)
                            .execute()
                        
                        let decoder = JSONDecoder()
                        struct UserRecord: Codable {
                            let user_id: String
                        }
                        
                        let userRecords = try decoder.decode([UserRecord].self, from: response.data)
                        if !userRecords.isEmpty {
                            validFriendIds.append(friendId)
                        } else {
                            print("Warning: User \(friendId) doesn't exist, skipping location sharing")
                        }
                    } catch {
                        print("Error checking user existence: \(error.localizedDescription)")
                    }
                }
                
                // Create new sharing permissions only for valid users
                var successCount = 0
                
                for friendId in validFriendIds {
                    do {
                        let sharingRecord: [String: AnyCodable] = [
                            "user_id": AnyCodable(userId),
                            "shared_with_id": AnyCodable(friendId)
                        ]
                        
                        print("Attempting to insert location sharing record: \(sharingRecord)")
                        
                        _ = try await supabase
                            .database
                            .from("location_sharing")
                            .insert(sharingRecord)
                            .execute()
                        
                        successCount += 1
                        print("Successfully inserted location sharing record for friend \(friendId)")
                    } catch {
                        print("Error inserting location sharing for friend \(friendId): \(error.localizedDescription)")
                    }
                }
                
                print("Successfully inserted \(successCount) of \(validFriendIds.count) location sharing records")
                
                DispatchQueue.main.async {
                    // Consider it successful if at least some records were created
                    completion(successCount > 0 || sharedWithUserIds.isEmpty)
                }
            } catch {
                print("Error updating shared users: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
    func getSharedWithFriends(userId: String, completion: @escaping (Result<[String], Error>) -> Void) {
        Task {
            do {
                let response = try await supabase
                    .database
                    .from("location_sharing")
                    .select("shared_with_id")
                    .eq("user_id", value: userId)
                    .execute()
                
                // Parse the response
                let decoder = JSONDecoder()
                struct SharingRecord: Codable {
                    let shared_with_id: String
                }
                
                let sharingRecords = try decoder.decode([SharingRecord].self, from: response.data)
                let friendIds = sharingRecords.map { $0.shared_with_id }
                
                DispatchQueue.main.async {
                    completion(.success(friendIds))
                }
            } catch {
                print("Error getting shared with friends: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    
    /// Ensure the profile images storage bucket exists
    func ensureStorageBucketExists(completion: @escaping (Bool) -> Void) {
        Task {
            do {
                // Check if bucket already exists
                let buckets = try await supabase.storage.listBuckets()
                let bucketExists = buckets.contains { $0.name == profileImageBucket }
                
                if !bucketExists {
                    // Create the bucket if it doesn't exist
                    _ = try await supabase.storage.createBucket(
                        profileImageBucket,
                        options: BucketOptions(public: true) // Make bucket public so images are accessible
                    )
                    print("Created profile images bucket")
                } else {
                    print("Profile images bucket already exists")
                }
                
                DispatchQueue.main.async {
                    completion(true)
                }
            } catch {
                print("Error checking/creating storage bucket: \(error.localizedDescription)")
                
                // For debugging, return true anyway to try upload
                DispatchQueue.main.async {
                    completion(true)
                }
            }
        }
    }
    // Add this method to your SupabaseManager class
    // Add this method to your SupabaseManager class
    func getLocationSharingPermissions(userId: String, completion: @escaping (Result<[String], Error>) -> Void) {
        struct SharedWithResponse: Codable {
            let sharedWithUserIds: [String]?
            enum CodingKeys: String, CodingKey {
                case sharedWithUserIds = "shared_with_user_ids"
            }
        }
        
        print("Fetching location sharing permissions for user ID: \(userId)")
        
        Task {
            do {
                // Query using the available supabase client
                let response = try await supabase
                    .database
                    .from("users")
                    .select("shared_with_user_ids")
                    .eq("id", value: userId)
                    .execute()
                
                // Parse the response to get shared user IDs
                // Since response.data is non-optional, we don't need to unwrap it with if let
                do {
                    // Assume the response is an array with a single user object
                    let decoder = JSONDecoder()
                    let decodedResponse = try decoder.decode([SharedWithResponse].self, from: response.data)
                    
                    if let firstUser = decodedResponse.first {
                        let sharedWithIds = firstUser.sharedWithUserIds ?? []
                        print("User \(userId) is sharing location with \(sharedWithIds.count) users")
                        
                        // Return success on the main thread
                        DispatchQueue.main.async {
                            completion(.success(sharedWithIds))
                        }
                    } else {
                        print("No user found")
                        DispatchQueue.main.async {
                            completion(.success([]))
                        }
                    }
                } catch {
                    print("Failed to decode shared user IDs: \(error)")
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            } catch {
                print("Error fetching location sharing permissions: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    func fetchAlbumCreationDate(albumId: String, completion: @escaping (Date?) -> Void) {
        Task {
            do {
                // Query the shared_albums table to get the creation date
                let response = try await supabase
                    .from("shared_albums")
                    .select("created_at")
                    .eq("album_id", value: albumId)
                    .limit(1)
                    .execute()
                
                // Try to parse the creation date
                if let jsonObject = try JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]],
                   let firstResult = jsonObject.first,
                   let createdAtString = firstResult["created_at"] as? String {
                    
                    // Use ISO8601DateFormatter to parse the timestamp
                    let dateFormatter = ISO8601DateFormatter()
                    if let createdAt = dateFormatter.date(from: createdAtString) {
                        DispatchQueue.main.async {
                            completion(createdAt)
                            return
                        }
                    }
                }
                
                // If parsing fails
                DispatchQueue.main.async {
                    print("❌ Unable to parse creation date for album \(albumId)")
                    completion(nil)
                }
            } catch {
                // Handle any errors during fetch
                print("❌ Error fetching album creation date: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    // Add this method to your SupabaseManager class extension
    func deleteAlbum(albumId: String, userId: String, completion: @escaping (Bool) -> Void) {
        Task {
            do {
                print("Attempting to delete album \(albumId) from Supabase...")
                
                // First, delete all images associated with this album from the images table
                let imagesResponse = try await supabase
                    .database
                    .from("images")
                    .delete()
                    .eq("album_id", value: albumId)
                    .execute()
                
                print("Deleted associated images with status: \(imagesResponse.status)")
                
                // Then delete the album itself
                let albumResponse = try await supabase
                    .database
                    .from("shared_albums")
                    .delete()
                    .eq("album_id", value: albumId)
                    .execute()
                
                print("Deleted album with status: \(albumResponse.status)")
                
                // If we reach here, the deletion was successful
                DispatchQueue.main.async {
                    completion(true)
                }
            } catch {
                print("Error deleting album from Supabase: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
}
// Add this as a new extension to SupabaseManager.swift
extension SupabaseManager {
    func saveSharedAlbum(album: SharedAlbum, images: [Data], completion: @escaping (Bool) -> Void) {
        Task {
            do {
                // 1. Create the album record
                let dateFormatter = ISO8601DateFormatter()
                let albumRecord: [String: AnyCodable] = [
                    "album_id": AnyCodable(album.albumId),
                    "album_name": AnyCodable(album.albumName),
                    "created_by_user_id": AnyCodable(album.createdByUserId),
                    "shared_with_user_ids": AnyCodable(album.sharedWithUserIds ?? []),
                    "image_ids": AnyCodable(album.imagesIds ?? []),
                    "created_at": AnyCodable(dateFormatter.string(from: album.createdAt))
                ]
                
                let albumResponse = try await supabase
                    .database
                    .from("shared_albums")
                    .insert(albumRecord)
                    .execute()
                
                print("✅ Created album record")
                
                // 2. Save images and collect their IDs
                var savedImageIds: [String] = []
                for imageData in images {
                    let (success, imageId) = try await self.saveImage(imageData: imageData, albumId: album.albumId)
                    if success, let imageId = imageId {
                        savedImageIds.append(imageId)
                    }
                }
                
                // 3. Update the album with image IDs
                if !savedImageIds.isEmpty {
                    let updateData: [String: AnyCodable] = [
                        "image_ids": AnyCodable(savedImageIds)
                    ]
                    
                    _ = try await supabase
                        .database
                        .from("shared_albums")
                        .update(updateData)
                        .eq("album_id", value: album.albumId)
                        .execute()
                    
                    print("✅ Updated album with \(savedImageIds.count) image IDs")
                }
                
                // Update local data model
                var updatedAlbum = album
                updatedAlbum.imagesIds = savedImageIds
                DispatchQueue.main.async {
                    SharedAlbumsDataModel.shared.addSharedAlbum(updatedAlbum)
                    completion(true)
                }
            } catch {
                print("❌ Error saving album: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
    func saveImage(imageData: Data, albumId: String) async throws -> (Bool, String?) {
        do {
            guard let userId = supabase.auth.currentUser?.id.uuidString else {
                throw NSError(domain: "SupabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
            }

            let imageId = UUID().uuidString
            let fileName = "\(userId)/\(albumId)/\(imageId).jpg"

            // Upload with retries
            var uploadSuccess = false
            for attempt in 1...3 {
                do {
                    _ = try await supabase.storage
                        .from(albumImagesBucket)
                        .upload(path: fileName, file: imageData, options: FileOptions(cacheControl: "3600"))
                    uploadSuccess = true
                    print("Image uploaded successfully on attempt \(attempt)")
                    break
                } catch {
                    print("Upload attempt \(attempt) failed: \(error)")
                    if attempt == 3 {
                        throw error
                    }
                    try await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second before retry
                }
            }

            guard uploadSuccess else {
                throw NSError(domain: "SupabaseManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to upload image after retries"])
            }

            // Verify the file exists
            let publicUrl = try supabase.storage
                .from(albumImagesBucket)
                .getPublicURL(path: fileName)

            do {
                let (data, response) = try await URLSession.shared.data(from: publicUrl)
                guard !data.isEmpty, let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    try? await supabase.storage
                        .from(albumImagesBucket)
                        .remove(paths: [fileName])
                    throw NSError(domain: "SupabaseManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Uploaded image is empty or inaccessible"])
                }
            } catch {
                try? await supabase.storage
                    .from(albumImagesBucket)
                    .remove(paths: [fileName])
                throw error
            }

            // Check if image_url already exists
            let existingImageResponse = try await supabase.database
                .from("images")
                .select("image_id")
                .eq("image_url", value: publicUrl.absoluteString)
                .limit(1)
                .execute()

            if let existingData = try JSONSerialization.jsonObject(with: existingImageResponse.data, options: []) as? [[String: Any]],
               let existingImage = existingData.first,
               let existingImageId = existingImage["image_id"] as? String {
                // Update existing record
                let updateData: [String: AnyCodable] = [
                    "latitude": AnyCodable(0.0), // Replace with actual latitude if available
                    "longitude": AnyCodable(0.0), // Replace with actual longitude if available
                    "shared_with_user_ids": AnyCodable([]) // Update with actual shared_with_user_ids if available
                ]
                _ = try await supabase.database
                    .from("images")
                    .update(updateData)
                    .eq("image_id", value: existingImageId)
                    .execute()
                await updateAlbumWithImageId(albumId: albumId, imageId: existingImageId)
                return (true, existingImageId)
            }

            // Insert new record if no duplicate found
            let autoShareFriends = UserDefaults.standard.stringArray(forKey: "AutoShareFriends") ?? []
            let sharedWithUserIds = !autoShareFriends.isEmpty ? autoShareFriends : []

            let imageRecord: [String: AnyCodable] = [
                "image_id": AnyCodable(imageId),
                "image_url": AnyCodable(publicUrl.absoluteString),
                "album_id": AnyCodable(albumId),
                "captured_by_user_id": AnyCodable(userId),
                "shared_with_user_ids": AnyCodable(sharedWithUserIds),
                "created_at": AnyCodable(ISO8601DateFormatter().string(from: Date()))
            ]

            let insertResponse = try await supabase.database
                .from("images")
                .insert(imageRecord)
                .execute()

            await updateAlbumWithImageId(albumId: albumId, imageId: imageId)
            return (true, imageId)
        } catch {
            print("Failed to save image: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func updateAlbumWithImageId(albumId: String, imageId: String) async {
        do {
            // First, get the current image_ids array, handling case sensitivity and potential absence
            let response = try await supabase
                .database
                .from("shared_albums")
                .select("image_ids") // Use the correct column name based on schema
                .eq("album_id", value: albumId)
                .limit(1)
                .execute()
            
            // Parse the response with error handling for missing column
            var existingImageIds: [String] = []
            if !response.data.isEmpty {
                if let albumsData = try JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]],
                   let albumData = albumsData.first {
                    if let ids = albumData["image_ids"] as? [String] { // Adjust to match actual column name
                        existingImageIds = ids
                    } else {
                        print("⚠️ image_ids column data is not an array of strings, initializing empty")
                    }
                }
            } else {
                print("⚠️ No album found with album_id: \(albumId), initializing empty image_ids")
            }
            
            // Add the new ID to the array if not already present
            if !existingImageIds.contains(imageId) {
                existingImageIds.append(imageId)
                
                // Update the album
                let updateData: [String: AnyCodable] = [
                    "image_ids": AnyCodable(existingImageIds)
                ]
                
                _ = try await supabase
                    .database
                    .from("shared_albums")
                    .update(updateData)
                    .eq("album_id", value: albumId)
                    .execute()
                
                print("✅ Updated album \(albumId) with new image ID: \(imageId)")
                print("✅ Album now has \(existingImageIds.count) images: \(existingImageIds)")
            } else {
                print("✅ Image ID \(imageId) already exists in album \(albumId), skipping update")
            }
        } catch {
            if error.localizedDescription.contains("column shared_albums.image_ids does not exist") {
                print("❌ Column 'image_ids' does not exist in shared_albums table. Attempting to add it...")
                do {
                    try await createImageIdsColumn()
                    // Retry the update after adding the column
                    let updateData: [String: AnyCodable] = [
                        "image_ids": AnyCodable([imageId])
                    ]
                    _ = try await supabase
                        .database
                        .from("shared_albums")
                        .update(updateData)
                        .eq("album_id", value: albumId)
                        .execute()
                    print("✅ Retried and updated album \(albumId) with new image ID: \(imageId)")
                } catch {
                    print("❌ Failed to create image_ids column or retry update: \(error.localizedDescription)")
                }
            } else {
                print("❌ Failed to update album with new image ID: \(error.localizedDescription)")
            }
        }
    }

    private func createImageIdsColumn() async throws {
        let sql = """
            ALTER TABLE shared_albums
            ADD COLUMN IF NOT EXISTS image_ids TEXT[] DEFAULT ARRAY[]::TEXT[];
        """
        // Note: The Supabase Swift SDK doesn't directly support ALTER TABLE via rpc. Use the dashboard or a custom RPC.
        // As a workaround, you can log the SQL and instruct the user to run it manually.
        print("❗ Please run the following SQL in the Supabase dashboard to add the image_ids column:")
        print(sql)
        throw NSError(domain: "SupabaseManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Column creation requires manual SQL execution in Supabase dashboard"])
        // If you set up a custom RPC (e.g., "add_image_ids_column"), use:
        // _ = try await supabase.database.rpc(fn: "add_image_ids_column").execute()
        // print("✅ Added image_ids column to shared_albums table")
    }

    // Note: You may need to define a custom RPC or use raw SQL depending on Supabase setup
    
    /// Debug function to verify if a user can see shared albums
    func debugSharedAlbums(userId: String, completion: @escaping ([String: Any]?) -> Void) {
        Task {
            do {
                print("Debugging shared albums for user ID: \(userId)")
                
                // Query for albums shared with this user
                let response = try await supabase
                    .database
                    .from("shared_albums")
                    .select("*")
                    .or("created_by_user_id.eq.\(userId),shared_with_user_ids.cs.{\"\(userId)\"}")
                    .execute()
                
                print("Raw response: \(String(data: response.data, encoding: .utf8) ?? "nil")")
                
                if let jsonObj = try JSONSerialization.jsonObject(with: response.data, options: []) as? [Any] {
                    print("Found \(jsonObj.count) shared albums")
                    
                    // Extract detailed info
                    var detailedInfo: [String: Any] = [:]
                    detailedInfo["count"] = jsonObj.count
                    detailedInfo["albums"] = jsonObj
                    
                    DispatchQueue.main.async {
                        completion(detailedInfo)
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    completion(nil)
                }
            } catch {
                print("Error debugging shared albums: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    func debugImageUpload(albumId: String, completion: @escaping ([String: Any]?) -> Void) {
        Task {
            do {
                // Check if album exists
                let albumResponse = try await supabase
                    .database
                    .from("shared_albums")
                    .select("*")
                    .eq("album_id", value: albumId)
                    .limit(1)
                    .execute()
                
                // Check images for this album
                let imagesResponse = try await supabase
                    .database
                    .from("images")
                    .select("*")
                    .eq("album_id", value: albumId)
                    .execute()
                
                // Get storage info
                let albumBucketFiles = try await supabase.storage
                    .from(albumImagesBucket) // Use your album images bucket
                    .list(path: "")
                
                var debugInfo: [String: Any] = [:]
                
                if let albumData = try JSONSerialization.jsonObject(with: albumResponse.data, options: []) as? [Any],
                   let albumDetails = albumData.first as? [String: Any] {
                    debugInfo["album"] = albumDetails
                }
                
                if let imagesData = try JSONSerialization.jsonObject(with: imagesResponse.data, options: []) as? [Any] {
                    debugInfo["images"] = imagesData
                    debugInfo["image_count"] = imagesData.count
                }
                
                debugInfo["storage_files"] = albumBucketFiles.map { $0.name }
                
                DispatchQueue.main.async {
                    completion(debugInfo)
                }
            } catch {
                print("Error debugging image upload: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    func getFriendsForAlbumSharing(userId: String, completion: @escaping (Result<[User], Error>) -> Void) {
        // Remove any potential quotes or whitespaces from userId
        let cleanUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
                                 .replacingOccurrences(of: "'", with: "")
                                 .replacingOccurrences(of: "\"", with: "")
        
        // First, get the list of friend IDs from the user_friends table
        getUserFriends(userId: cleanUserId) { [weak self] result in
            switch result {
            case .success(let friendIds):
                if friendIds.isEmpty {
                    // No friends to share with
                    print("❌ No friends found for user")
                    completion(.success([]))
                    return
                }
                
                print("🔍 Friends for Album Sharing: \(friendIds)")
                
                // Get the details of each friend
                self?.getUserDetailsByIds(userIds: friendIds) { result in
                    switch result {
                    case .success(let users):
                        print("✅ Loaded \(users.count) friends for album sharing")
                        completion(.success(users))
                    case .failure(let error):
                        print("❌ Failed to get friend details: \(error)")
                        completion(.failure(error))
                    }
                }
                
            case .failure(let error):
                print("❌ Failed to get friends: \(error)")
                completion(.failure(error))
            }
        }
    }

    func getUserDetailsByIds(userIds: [String], completion: @escaping (Result<[User], Error>) -> Void) {
        Task {
            do {
                // Aggressive cleaning and validation of user IDs
                let cleanedUserIds = userIds.map { userId in
                    userId
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "'", with: "")
                        .replacingOccurrences(of: "\"", with: "")
                        .lowercased()
                }
                .filter { UUID(uuidString: $0) != nil }
                
                print("🔍 Cleaned and Validated User IDs: \(cleanedUserIds)")
                
                guard !cleanedUserIds.isEmpty else {
                    print("❌ No valid user IDs found")
                    DispatchQueue.main.async {
                        completion(.success([]))
                    }
                    return
                }
                
                // Use parameterized query
                let response = try await supabase
                    .database
                    .from("users")
                    .select("*")
                    .in("user_id", values: cleanedUserIds)
                    .execute()
                
                // Debug print
                if let jsonString = String(data: response.data, encoding: .utf8) {
                    print("👥 User Details Response: \(jsonString)")
                }
                
                // Parse users with more flexible decoding
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                
                var users: [User] = []
                
                do {
                    users = try decoder.decode([User].self, from: response.data)
                } catch {
                    print("❌ Decoding Error: \(error)")
                    
                    // If decoding fails, try to investigate why
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .keyNotFound(let key, let context):
                            print("Key not found: \(key), Context: \(context)")
                        case .valueNotFound(let type, let context):
                            print("Value not found: \(type), Context: \(context)")
                        case .typeMismatch(let type, let context):
                            print("Type mismatch: \(type), Context: \(context)")
                        case .dataCorrupted(let context):
                            print("Data corrupted: \(context)")
                        @unknown default:
                            print("Unknown decoding error")
                        }
                    }
                    
                    // Fallback: try to parse manually or use a more flexible approach
                    if let jsonArray = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]] {
                        users = jsonArray.compactMap { userDict -> User? in
                            guard let userId = userDict["user_id"] as? String else { return nil }
                            
                            // Get profile image URL if available
                            let profileImageUrl = userDict["profile_image_url"] as? String
                            
                            // Create user with simplified initializer
                            var user = User(
                                userId: userId,
                                name: userDict["name"] as? String ?? "Unknown",
                                phoneNumber: userDict["phone"] as? String ?? "",
                                profileImages: [],
                                verificationCode: "",
                                shareLocation: userDict["share_location"] as? Bool ?? false,
                                location: nil,
                                sharedWithUserIds: nil,
                                friendListUserIds: nil,
                                sharedAlbums: nil, email: userDict["email"] as? String ?? ""
                            )
                            
                            // Set profile image URL separately
                            if let url = profileImageUrl {
                                user.profileImageUrl = url
                            }
                            
                            return user
                        }
                    }
                }
                
                // Final validation
                users = users.filter {
                    UUID(uuidString: $0.userId) != nil
                }
                
                print("✅ Found \(users.count) valid users")
                
                DispatchQueue.main.async {
                    completion(.success(users))
                }
            } catch {
                print("❌ Error fetching user details: \(error)")
                
                // Additional debugging
                if let postgrestError = error as? PostgrestError {
                    print("🚨 Postgrest Error Details:")
                    print("Code: \(postgrestError.code ?? "nil")")
                    print("Message: \(postgrestError.message)")
                    
                    // If you want more context, you can print the entire error
                    print("Full Error: \(postgrestError)")
                }
                
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
        // Share an album with friends
    func shareAlbumWithFriends(albumId: String, friendIds: [String], completion: @escaping (Bool) -> Void) {
        Task {
            do {
                // Sanitize friend IDs
                let sanitizedFriendIds = friendIds.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                
                print("🔔 Sharing Album: \(albumId)")
                print("🤝 With Friends: \(sanitizedFriendIds)")
                
                // Update shared_albums table
                let updateParams: [String: AnyCodable] = [
                    "shared_with_user_ids": AnyCodable(sanitizedFriendIds)
                ]
                
                let response = try await supabase
                    .database
                    .from("shared_albums")
                    .update(updateParams)
                    .eq("album_id", value: albumId)
                    .execute()
                
                // Debug print the response
                if let responseString = String(data: response.data, encoding: .utf8) {
                    print("🌐 Album Share Response: \(responseString)")
                }
                
                // Update local model
                DispatchQueue.main.async {
                    if var album = SharedAlbumsDataModel.shared.getAlbum(byId: albumId) {
                        album.sharedWithUserIds = sanitizedFriendIds
                        SharedAlbumsDataModel.shared.updateSharedAlbum(album)
                        
                        NotificationCenter.default.post(name: NSNotification.Name("AlbumUpdatedNotification"), object: nil)
                    }
                    
                    completion(true)
                }
            } catch {
                print("❌ Error updating album sharing: \(error)")
                
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
    func updateAlbumImageIds(albumId: String, imageIds: [String], completion: @escaping (Bool) -> Void) {
         Task {
             do {
                 // First, get the current album to retrieve existing image IDs
                 let response = try await supabase
                     .database
                     .from("shared_albums")
                     .select("image_ids")
                     .eq("album_id", value: albumId)
                     .limit(1)
                     .execute()
                 
                 // Parse existing image IDs from response
                 var existingImageIds: [String] = []
                 if let jsonData = try JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]],
                    let albumData = jsonData.first {
                     if let ids = albumData["image_ids"] as? [String] {
                         existingImageIds = ids
                     }
                 }
                 
                 // Combine existing and new IDs, removing duplicates
                 let allImageIds = Array(Set(existingImageIds + imageIds))
                 
                 // Update the album with all image IDs
                 let albumUpdate: [String: AnyCodable] = [
                     "image_ids": AnyCodable(allImageIds)
                 ]
                 
                 print("Updating album \(albumId) with \(allImageIds.count) image IDs")
                 
                 _ = try await supabase
                     .database
                     .from("shared_albums")
                     .update(albumUpdate)
                     .eq("album_id", value: albumId)
                     .execute()
                 
                 print("✅ Successfully updated album with image IDs")
                 
                 // Update the local data model
                 DispatchQueue.main.async {
                     if var album = SharedAlbumsDataModel.shared.getAlbum(byId: albumId) {
                         album.imagesIds = allImageIds
                         SharedAlbumsDataModel.shared.updateSharedAlbum(album)
                         
                         // Notify that album has been updated
                         NotificationCenter.default.post(name: NSNotification.Name("AlbumUpdatedNotification"), object: nil)
                     }
                     
                     completion(true)
                 }
             } catch {
                 print("❌ Error updating album image IDs: \(error.localizedDescription)")
                 DispatchQueue.main.async {
                     completion(false)
                 }
             }
         }
     }
    // Helper method to just sync images for a specific album
    func syncAlbumImagesOnly(albumId: String, completion: @escaping (Bool) -> Void) {
        Task {
            do {
                // Fetch album to get image IDs
                let response = try await supabase
                    .database
                    .from("shared_albums")
                    .select("image_ids")
                    .eq("album_id", value: albumId)
                    .limit(1)
                    .execute()

                guard let albumData = try JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]],
                      let album = albumData.first else {
                    print("Album not found in database: \(albumId)")
                    DispatchQueue.main.async {
                        completion(false)
                    }
                    return
                }

                // Extract image IDs
                var imageIds: [String] = []
                if let ids = album["image_ids"] as? [String] {
                    imageIds = ids
                    print("Fetched image IDs for album \(albumId): \(imageIds)")
                }

                if imageIds.isEmpty {
                    print("No images found for album \(albumId)")
                    DispatchQueue.main.async {
                        completion(true) // Still considered success, just no images
                    }
                    return
                }

                // Download images
                try await downloadImagesById(imageIds: imageIds)

                // Update local album model
                DispatchQueue.main.async {
                    if var album = SharedAlbumsDataModel.shared.getAlbum(byId: albumId) {
                        album.imagesIds = imageIds
                        SharedAlbumsDataModel.shared.updateSharedAlbum(album)
                        print("Updated local album \(albumId) with \(imageIds.count) images")
                    }
                    completion(true)
                }
            } catch {
                print("Error syncing album images: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }

    // Private helper method to download images by their IDs
    private func downloadImagesById(imageIds: [String]) async throws {
        print("Downloading \(imageIds.count) images: \(imageIds)")

        if imageIds.isEmpty {
            print("No images to download")
            return
        }

        // Query images
        let response = try await supabase
            .database
            .from("images")
            .select()
            .in("image_id", values: imageIds)
            .execute()

        print("Image query response: \(String(data: response.data, encoding: .utf8) ?? "nil")")

        var imagesData: [[String: Any]] = []
        if let parsedData = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]], !parsedData.isEmpty {
            imagesData = parsedData
            print("Found \(imagesData.count) images in database")
        } else {
            print("No images found in database for IDs: \(imageIds)")
            // Log missing images for debugging
            for imageId in imageIds {
                print("Missing image record for ID: \(imageId)")
            }
            return
        }

        for imageData in imagesData {
            let imageId = imageData["image_id"] as? String ?? UUID().uuidString
            print("Processing image ID: \(imageId)")

            // Skip if already in local storage
            if ImageDataModel.shared.getImage(byId: imageId) != nil {
                print("Image \(imageId) already exists in local storage, skipping download")
                continue
            }

            let imageUrlStr = imageData["image_url"] as? String ?? ""
            guard !imageUrlStr.isEmpty, let imageUrl = URL(string: imageUrlStr) else {
                print("Invalid or missing image URL for ID: \(imageId): \(imageUrlStr)")
                continue
            }

            do {
                print("Downloading image from URL: \(imageUrlStr)")
                let (data, httpResponse) = try await URLSession.shared.data(from: imageUrl)

                if let response = httpResponse as? HTTPURLResponse {
                    print("Image download status for \(imageId): \(response.statusCode)")
                    if response.statusCode >= 400 {
                        print("Error downloading image \(imageId): HTTP \(response.statusCode)")
                        continue
                    }
                }

                guard !data.isEmpty else {
                    print("Downloaded image data for \(imageId) is empty")
                    continue
                }

                print("Downloaded image data size for \(imageId): \(data.count) bytes")

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
                }
            } catch {
                print("❌ Failed to sync image \(imageId): \(error.localizedDescription)")
            }
        }

        print("Completed syncing \(imagesData.count) images")
    }

    // Helper function to parse created_at dates consistently
    private func parseCreatedAtDate(_ dateValue: Any?) -> Date {
        if let dateString = dateValue as? String {
            let dateFormatter = ISO8601DateFormatter()
            return dateFormatter.date(from: dateString) ?? Date()
        }
        return Date()
    }

    // Helper method to parse array fields that might be in different formats
    func debugImageTable(completion: @escaping ([String: Any]?) -> Void) {
        Task {
            do {
                // Query all images in the database
                let response = try await supabase
                    .database
                    .from("images")
                    .select("*")
                    .execute()
                
                print("Raw images response: \(String(data: response.data, encoding: .utf8) ?? "nil")")
                
                if let jsonObj = try JSONSerialization.jsonObject(with: response.data, options: []) as? [Any] {
                    print("Found \(jsonObj.count) images in database")
                    
                    var detailedInfo: [String: Any] = [:]
                    detailedInfo["count"] = jsonObj.count
                    detailedInfo["images"] = jsonObj
                    
                    DispatchQueue.main.async {
                        completion(detailedInfo)
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    completion(nil)
                }
            } catch {
                print("Error debugging image table: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    func fetchUserDetails(userIDs: [String], completion: @escaping (Result<[User], Error>) -> Void) {
        // Sanitize and validate UUIDs
        let cleanedIDs = userIDs.map { idString -> String in
            idString
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "'", with: "")
                .replacingOccurrences(of: "\"", with: "")
        }
        
        // Filter out any invalid UUIDs
        let validUUIDs = cleanedIDs.filter { UUID(uuidString: $0) != nil }
        
        guard !validUUIDs.isEmpty else {
            print("No valid UUIDs found")
            completion(.success([]))
            return
        }
        
        // Debug print
        print("Validated Friend IDs: \(validUUIDs)")
        
        // Use Task for async operation
        Task {
            do {
                // Fetch users asynchronously
                let response = try await supabase
                    .from("users")
                    .select()
                    .in("id", values: validUUIDs)
                    .execute()
                
                // Decode users
                let users = try JSONDecoder().decode([User].self, from: response.data)
                
                // Return on main thread
                await MainActor.run {
                    completion(.success(users))
                }
            } catch {
                // Return error on main thread
                await MainActor.run {
                    print("Supabase query error: \(error)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    func fetchFriendDetails(completion: @escaping ([User]) -> Void) {
        guard let userId = SessionManager.shared.getSession() else {
            print("❌ No active user session")
            completion([])
            return
        }
        
        print("🔍 DETAILED Fetching friends for user ID: \(userId)")
        
        // Fetch contacts
        ContactManager.shared.fetchAppContacts { [weak self] contacts in
            print("📱 Total contacts: \(contacts.count)")
            
            // Extract and clean app user IDs
            let appUserIDs = contacts
                .compactMap { $0.appUserID }
                .map { rawId in
                    rawId
                        .replacingOccurrences(of: "'", with: "")
                        .replacingOccurrences(of: "\"", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .filter { !$0.isEmpty }
            
            print("🏁 Cleaned App User IDs: \(appUserIDs)")
            
            guard !appUserIDs.isEmpty else {
                print("❌ No valid app user IDs found")
                completion([])
                return
            }
            
            // Perform Supabase query
            self?.getUserDetailsByIds(userIds: appUserIDs) { result in
                switch result {
                case .success(let users):
                    print("👥 Retrieved friends: \(users.count)")
                    completion(users)
                case .failure(let error):
                    print("❌ Friend Fetch Error: \(error)")
                    completion([])
                }
            }
        }
    }
    // Add this method to your SupabaseManager class

    // Add this method to your SupabaseManager class
    // Add this method to your SupabaseManager class
    func addImageToSharedAlbum(albumId: String, image: Data, completion: @escaping (Bool) -> Void) {
        Task {
            do {
                // Save the image and automatically update the album's image_ids
                let (success, imageId) = try await saveImage(imageData: image, albumId: albumId)

                if !success || imageId == nil {
                    DispatchQueue.main.async {
                        completion(false)
                    }
                    return
                }

                // Update the local data model
                DispatchQueue.main.async {
                    if var album = SharedAlbumsDataModel.shared.getAlbum(byId: albumId) {
                        if album.imagesIds == nil {
                            album.imagesIds = [imageId!]
                        } else if !album.imagesIds!.contains(imageId!) {
                            album.imagesIds!.append(imageId!)
                        }
                        SharedAlbumsDataModel.shared.updateSharedAlbum(album)
                        NotificationCenter.default.post(name: NSNotification.Name("AlbumUpdatedNotification"), object: nil)
                    }
                    completion(true)
                }
            } catch {
                print("Error adding image to shared album: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
    func getSharedAlbumDetails(albumId: String, completion: @escaping (Result<SharedAlbum, Error>) -> Void) {
        Task {
            do {
                let response = try await supabase
                    .database
                    .from("shared_albums")
                    .select("*")
                    .eq("album_id", value: albumId)
                    .limit(1)
                    .execute()
                
                // Debug: Print raw response data
                if let rawResponseString = String(data: response.data, encoding: .utf8) {
                    print("🔍 Raw Supabase Response for Album \(albumId):")
                    print(rawResponseString)
                }
                
                // Try JSON serialization first to see the structure
                if let jsonObject = try? JSONSerialization.jsonObject(with: response.data, options: []) {
                    print("🧐 JSON Object Structure:")
                    print(jsonObject)
                }
                
                // Create a flexible JSON decoder
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                // Try decoding with more flexibility
                struct FlexibleSharedAlbum: Codable {
                    var albumId: String
                    var albumName: String
                    var createdByUserId: String
                    var sharedWithUserIds: [String]?
                    var imagesIds: [String]?
                    var createdAt: String?
                    
                    enum CodingKeys: String, CodingKey {
                        case albumId = "album_id"
                        case albumName = "album_name"
                        case createdByUserId = "created_by_user_id"
                        case sharedWithUserIds = "shared_with_user_ids"
                        case imagesIds = "image_ids"
                        case createdAt = "created_at"
                    }
                    
                    func toSharedAlbum() -> SharedAlbum {
                        return SharedAlbum(
                            albumId: albumId,
                            albumName: albumName,
                            createdByUserId: createdByUserId,
                            sharedWithUserIds: sharedWithUserIds ?? [],
                            imagesIds: imagesIds ?? [],
                            createdAt: Date() // Default to current date if parsing fails
                        )
                    }
                }
                
                do {
                    let flexibleAlbums = try decoder.decode([FlexibleSharedAlbum].self, from: response.data)
                    
                    if let firstFlexibleAlbum = flexibleAlbums.first {
                        let album = firstFlexibleAlbum.toSharedAlbum()
                        
                        DispatchQueue.main.async {
                            completion(.success(album))
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(.failure(NSError(domain: "SupabaseManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "No albums found"])))
                        }
                    }
                } catch {
                    print("❌ Decoding Error Details:")
                    print("Error: \(error)")
                    
                    // More detailed error information
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .typeMismatch(let type, let context):
                            print("Type mismatch: \(type)")
                            print("Context: \(context.debugDescription)")
                        case .valueNotFound(let type, let context):
                            print("Value not found: \(type)")
                            print("Context: \(context.debugDescription)")
                        case .keyNotFound(let key, let context):
                            print("Key not found: \(key)")
                            print("Context: \(context.debugDescription)")
                        case .dataCorrupted(let context):
                            print("Data corrupted")
                            print("Context: \(context.debugDescription)")
                        @unknown default:
                            print("Unknown decoding error")
                        }
                    }
                    
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            } catch {
                print("❌ Supabase Query Error: \(error)")
                
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
//    func checkUserExists(email: String, completion: @escaping (Bool) -> Void) {
//            Task {
//                do {
//                    print("Checking if user exists with email: \(email)")
//                    
//                    // Query the users table for a matching email
//                    let response = try await supabase
//                        .database
//                        .from("users")
//                        .select("user_id")
//                        .eq("email", value: email.lowercased()) // Use lowercase for consistency
//                        .limit(1)
//                        .execute()
//                    
//                    // Log raw response for debugging
//                    if let jsonString = String(data: response.data, encoding: .utf8) {
//                        print("Check user exists response: \(jsonString)")
//                    }
//                    
//                    // Parse the response
//                    let userData = try JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]]
//                    
//                    // If userData is not empty, a user exists
//                    let exists = !(userData?.isEmpty ?? true)
//                    
//                    DispatchQueue.main.async {
//                        completion(exists)
//                    }
//                } catch {
//                    print("Error checking user existence by email: \(error.localizedDescription)")
//                    DispatchQueue.main.async {
//                        completion(false) // Assume user doesn't exist on error
//                    }
//                }
//            }
//        }
    func checkAlbumExists(albumId: String) async throws -> Bool {
            do {
                let response = try await supabase
                    .database
                    .from("shared_albums")
                    .select("album_id")
                    .eq("album_id", value: albumId)
                    .limit(1)
                    .execute()
                
                let decoder = JSONDecoder()
                let albums = try decoder.decode([[String: String]].self, from: response.data)
                return !albums.isEmpty
            } catch {
                print("Error checking album existence: \(error.localizedDescription)")
                throw error
            }
        }
    func saveNotification(notification: Notification) async throws {
        let notificationData: [String: AnyCodable] = [
            "notification_id": AnyCodable(notification.notificationId),
            "user_id": AnyCodable(notification.userId),
            "image_ids": AnyCodable(notification.imageIds ?? []),
            "to_notify": AnyCodable(notification.toNotify ?? []),
            "created_at": AnyCodable(ISO8601DateFormatter().string(from: notification.createdAt))
        ]
        do {
            try await supabase
                .database
                .from("notifications")
                .insert(notificationData)
                .execute()
            print("✅ Notification \(notification.notificationId) saved successfully")
        } catch {
            print("❌ Error saving notification: \(error.localizedDescription)")
            throw error
        }
    }
    func debugRevisitsTable(completion: @escaping ([String: Any]?) -> Void) {
        Task {
            do {
                let response = try await supabase
                    .database
                    .from("revisits")
                    .select("*")
                    .execute()

                print("📡 Raw revisits table response: \(String(data: response.data, encoding: .utf8) ?? "nil")")
                SupabaseManager.shared.debugRevisitsTable { result in
                    print("Revisits Table Debug: \(result ?? [:])")
                }

                if let jsonObj = try JSONSerialization.jsonObject(with: response.data, options: []) as? [Any] {
                    print("ℹ️ Found \(jsonObj.count) revisits in database")

                    var detailedInfo: [String: Any] = [:]
                    detailedInfo["count"] = jsonObj.count
                    detailedInfo["revisits"] = jsonObj

                    DispatchQueue.main.async {
                        completion(detailedInfo)
                    }
                    return
                }

                DispatchQueue.main.async {
                    completion(nil)
                }
            } catch {
                print("❌ Error debugging revisits table: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    func fetchLocationSharingPermissions(for userId: String) async throws -> [String] {
        do {
            let response = try await supabase
                .database
                .from("location_sharing")
                .select("shared_with_id")
                .eq("user_id", value: userId)
                .execute()
            print("📡 Raw location sharing response: \(String(data: response.data, encoding: .utf8) ?? "nil")")
            guard let records = response.value as? [[String: Any]] else {
                print("ℹ️ No location sharing permissions found for user \(userId)")
                return []
            }
            let sharedWithIds = records.compactMap { $0["shared_with_id"] as? String }
            print("✅ Found \(sharedWithIds.count) location sharing permissions: \(sharedWithIds)")
            return sharedWithIds
        } catch {
            print("❌ Error fetching location sharing: \(error.localizedDescription)")
            throw error
        }
    }
    
    
        

    
}


extension Date {
    func iso8601String() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: self)
    }
}
