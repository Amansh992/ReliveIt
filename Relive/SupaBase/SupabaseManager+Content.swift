import Foundation
import UIKit
import Supabase

extension SupabaseManager {
    
    /// Function to sync all user content
    func syncAllUserContent(userId: String, completion: @escaping (Bool) -> Void) {
        Task {
            do {
                // Step 1: Sync images shared with the user
                let imagesResponse = try await supabase
                    .database
                    .from("images")
                    .select("*")
                    .or("captured_by_user_id.eq.\(userId),shared_with_user_ids.cs.{\"\(userId)\"}")
                    .execute()
                    
                if let imagesData = try JSONSerialization.jsonObject(with: imagesResponse.data, options: []) as? [[String: Any]] {
                    print("Found \(imagesData.count) images for user")
                    
                    for imageData in imagesData {
                        let imageId = imageData["image_id"] as? String ?? UUID().uuidString
                        let capturedByUserId = imageData["captured_by_user_id"] as? String ?? ""
                        let imageUrl = imageData["image_url"] as? String ?? ""
                        
                        // Get location if available
                        var locationCaptured: LocationCoordinate? = nil
                        if let latitude = imageData["latitude"] as? Double,
                           let longitude = imageData["longitude"] as? Double {
                            // Direct initialization
                            locationCaptured = LocationCoordinate(latitude: latitude, longitude: longitude)
                        }
                        
                        // Get shared with users - ensure non-nil array
                        let sharedWithUserIds = parseArrayField(imageData["shared_with_user_ids"])
                        
                        // Load the image if there's a URL
                        if !imageUrl.isEmpty {
                            if let url = URL(string: imageUrl) {
                                URLSession.shared.dataTask(with: url) { data, response, error in
                                    if let imageData = data {
                                        // Using current date for createdAt to match expected initializer
                                        let now = Date()
                                        let image = ImageData(
                                            imageId: imageId,
                                            image: imageData,
                                            locationCaptured: locationCaptured,
                                            capturedByUserId: capturedByUserId,
                                            sharedWithUserIds: sharedWithUserIds,
                                            createdAt: now
                                        )
                                        
                                        DispatchQueue.main.async {
                                            ImageDataModel.shared.addImage(image)
                                        }
                                    }
                                }.resume()
                            }
                        }
                    }
                }
                
                // Step 2: Sync revisits
                let revisitsResponse = try await supabase
                    .database
                    .from("revisits")
                    .select("*")
                    .eq("user_id", value: userId)
                    .execute()
                    
                if let revisitsData = try JSONSerialization.jsonObject(with: revisitsResponse.data, options: []) as? [[String: Any]] {
                    print("Found \(revisitsData.count) revisits for user")
                    
                    for revisitData in revisitsData {
                        let visitId = revisitData["visit_id"] as? String ?? UUID().uuidString
                        let date = parseDate(revisitData["date"]) ?? Date()
                        
                        // Get location
                        var location: LocationCoordinate? = nil
                        if let latitude = revisitData["latitude"] as? Double,
                           let longitude = revisitData["longitude"] as? Double {
                            // Direct initialization
                            location = LocationCoordinate(latitude: latitude, longitude: longitude)
                        } else {
                            continue // Skip if no valid location
                        }
                        
                        // Get image IDs and shared with users - ensure non-nil arrays
                        let imageIds = parseArrayField(revisitData["image_ids"])
                        let sharedWithUserIds = parseArrayField(revisitData["shared_with_user_ids"])
                        
                        // We've validated that location is not nil above
                        let revisit = ReVisit(
                            visitId: visitId,
                            location: location!,
                            userId: userId,
                            imageIds: imageIds,
                            date: date,
                            sharedWithUserIds: sharedWithUserIds
                        )
                        
                        DispatchQueue.main.async {
                            RevisitDataModel.shared.addRevisit(revisit)
                        }
                    }
                }
                
                // Step 3: Sync shared albums in detail
                let detailedAlbumsResponse = try await supabase
                    .database
                    .from("shared_albums")
                    .select("*")
                    .or("created_by_user_id.eq.\(userId),shared_with_user_ids.cs.{\"\(userId)\"}")
                    .execute()
                    
                if let albumsData = try JSONSerialization.jsonObject(with: detailedAlbumsResponse.data, options: []) as? [[String: Any]] {
                    print("Syncing \(albumsData.count) detailed albums")
                    
                    for albumData in albumsData {
                        let albumId = albumData["album_id"] as? String ?? UUID().uuidString
                        let albumName = albumData["album_name"] as? String ?? "Untitled Album"
                        let createdByUserId = albumData["created_by_user_id"] as? String ?? ""
                        let createdAt = parseDate(albumData["created_at"]) ?? Date()
                        
                        // Get image IDs and shared with users - ensure non-nil arrays
                        let imageIds = parseArrayField(albumData["image_ids"])
                        let sharedWithUserIds = parseArrayField(albumData["shared_with_user_ids"])
                        
                        let album = SharedAlbum(
                            albumId: albumId,
                            albumName: albumName,
                            createdByUserId: createdByUserId,
                            sharedWithUserIds: sharedWithUserIds,
                            imagesIds: imageIds,
                            createdAt: createdAt
                        )
                        
                        DispatchQueue.main.async {
                            SharedAlbumsDataModel.shared.addSharedAlbum(album)
                        }
                    }
                }
                // Add this in SupabaseManager+Content.swift, at the end of the syncAllUserContent function
                // After the "Step 3: Sync shared albums in detail" block, add this code:

                if let albumsData = try JSONSerialization.jsonObject(with: detailedAlbumsResponse.data, options: []) as? [[String: Any]] {
                    print("Syncing \(albumsData.count) detailed albums")
                    
                    // Track if we found any albums shared with this user but not created by them
                    var foundSharedAlbums = false
                    
                    for albumData in albumsData {
                        let albumId = albumData["album_id"] as? String ?? UUID().uuidString
                        let albumName = albumData["album_name"] as? String ?? "Untitled Album"
                        let createdByUserId = albumData["created_by_user_id"] as? String ?? ""
                        let createdAt = parseDate(albumData["created_at"]) ?? Date()
                        
                        // Get image IDs and shared with users - ensure non-nil arrays
                        let imageIds = parseArrayField(albumData["image_ids"])
                        let sharedWithUserIds = parseArrayField(albumData["shared_with_user_ids"])
                        
                        // Check if this album is shared with the user but not created by them
                        if createdByUserId != userId && sharedWithUserIds.contains(userId) {
                            foundSharedAlbums = true
                        }
                        
                        let album = SharedAlbum(
                            albumId: albumId,
                            albumName: albumName,
                            createdByUserId: createdByUserId,
                            sharedWithUserIds: sharedWithUserIds,
                            imagesIds: imageIds,
                            createdAt: createdAt
                        )
                        
                        DispatchQueue.main.async {
                            SharedAlbumsDataModel.shared.addSharedAlbum(album)
                        }
                    }
                    
                    // If we found shared albums, post a notification
                    if foundSharedAlbums {
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: NSNotification.Name("AlbumUpdatedNotification"), object: nil)
                        }
                    }
                }
                
                // Step 4: Sync notifications
                let notificationsResponse = try await supabase
                    .database
                    .from("notifications")
                    .select("*")
                    .or("user_id.eq.\(userId),to_notify.cs.{\"\(userId)\"}")
                    .execute()
                    
                if let notificationsData = try JSONSerialization.jsonObject(with: notificationsResponse.data, options: []) as? [[String: Any]] {
                    print("Found \(notificationsData.count) notifications for user")
                    
                    for notificationData in notificationsData {
                        let notificationId = notificationData["notification_id"] as? String ?? UUID().uuidString
                        let notificationUserId = notificationData["user_id"] as? String ?? ""
                        let createdAt = parseDate(notificationData["created_at"]) ?? Date()
                        
                        // Get image IDs and to notify users - ensure non-nil arrays
                        let imageIds = parseArrayField(notificationData["image_ids"])
                        let toNotify = parseArrayField(notificationData["to_notify"])
                        
                        let notification = Notification(
                            notificationId: notificationId,
                            userId: notificationUserId,
                            imageIds: imageIds,
                            toNotify: toNotify,
                            createdAt: createdAt
                        )
                        
                        DispatchQueue.main.async {
                            NotificationDataModel.shared.addNotification(notification: notification)
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    print("Successfully synced all user content")
                    completion(true)
                }
                
            } catch {
                print("Error syncing user content: \(error)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
            DispatchQueue.main.async {
                   // Post notification that sync is complete
                   NotificationCenter.default.post(name: NSNotification.Name("SupabaseSyncCompleted"), object: nil)
                   completion(true) // or whatever success value
               }
        }
    }
}
