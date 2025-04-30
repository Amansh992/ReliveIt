//
//  DataModels.swift
//  Relive
//
//  Created by Ayush Nimiwal on 11/12/24.
//
import UIKit
import Foundation
import CoreLocation

struct User: Codable {
    var userId: String
    var name: String
    var phoneNumber: String
    var email: String? // Changed to optional
    private var _profileImage: Data?
    var profileImages: [Data] {
        get {
            if let _profileImage = _profileImage {
                return [_profileImage]
            }
            return []
        }
        set {
            if !newValue.isEmpty {
                _profileImage = newValue[0]
            } else {
                _profileImage = nil
            }
        }
    }
    
    var verificationCode: String
    var shareLocation: Bool
    var location: LocationCoordinate?
    var sharedWithUserIds: [String]?
    var friendListUserIds: [String]?
    var sharedAlbums: [String]?
    
    var profileImageUrl: String?
    var registrationComplete: Bool = false
    
    init(userId: String, name: String, phoneNumber: String, profileImages: [Data], verificationCode: String, shareLocation: Bool, location: LocationCoordinate?, sharedWithUserIds: [String]?, friendListUserIds: [String]?, sharedAlbums: [String]?, email: String? = nil) {
        self.userId = userId
        self.name = name
        self.phoneNumber = phoneNumber
        self.email = email
        if !profileImages.isEmpty {
            self._profileImage = profileImages[0]
        } else {
            self._profileImage = nil
        }
        self.verificationCode = verificationCode
        self.shareLocation = shareLocation
        self.location = location
        self.sharedWithUserIds = sharedWithUserIds ?? []
        self.friendListUserIds = friendListUserIds ?? []
        self.sharedAlbums = sharedAlbums ?? []
        self.profileImageUrl = nil
    }
    
    private enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name
        case phoneNumber = "phone"
        case _profileImage = "profileImage"
        case profileImages
        case verificationCode
        case shareLocation = "share_location"
        case location
        case sharedWithUserIds
        case friendListUserIds
        case sharedAlbums
        case profileImageUrl = "profile_image_url"
        case registrationComplete = "registration_complete"
        case email
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        userId = try container.decode(String.self, forKey: .userId)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Unknown"
        phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber) ?? ""
        verificationCode = try container.decodeIfPresent(String.self, forKey: .verificationCode) ?? ""
        shareLocation = try container.decodeIfPresent(Bool.self, forKey: .shareLocation) ?? false
        location = try container.decodeIfPresent(LocationCoordinate.self, forKey: .location)
        sharedWithUserIds = try container.decodeIfPresent([String].self, forKey: .sharedWithUserIds) ?? []
        friendListUserIds = try container.decodeIfPresent([String].self, forKey: .friendListUserIds) ?? []
        sharedAlbums = try container.decodeIfPresent([String].self, forKey: .sharedAlbums) ?? []
        profileImageUrl = try container.decodeIfPresent(String.self, forKey: .profileImageUrl)
        registrationComplete = try container.decodeIfPresent(Bool.self, forKey: .registrationComplete) ?? false
        email = try container.decodeIfPresent(String.self, forKey: .email)
        
        if let profileImage = try container.decodeIfPresent(Data.self, forKey: ._profileImage) {
            _profileImage = profileImage
        } else {
            let images = try container.decodeIfPresent([Data].self, forKey: .profileImages) ?? []
            if !images.isEmpty {
                _profileImage = images[0]
            } else {
                _profileImage = nil
            }
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(userId, forKey: .userId)
        try container.encode(name, forKey: .name)
        try container.encode(phoneNumber, forKey: .phoneNumber)
        try container.encode(verificationCode, forKey: .verificationCode)
        try container.encode(shareLocation, forKey: .shareLocation)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encode(sharedWithUserIds ?? [], forKey: .sharedWithUserIds)
        try container.encode(friendListUserIds ?? [], forKey: .friendListUserIds)
        try container.encode(sharedAlbums ?? [], forKey: .sharedAlbums)
        try container.encodeIfPresent(profileImageUrl, forKey: .profileImageUrl)
        try container.encode(registrationComplete, forKey: .registrationComplete)
        try container.encodeIfPresent(email, forKey: .email)
        
        try container.encodeIfPresent(_profileImage, forKey: ._profileImage)
        if let image = _profileImage {
            try container.encode([image], forKey: .profileImages)
        } else {
            try container.encode([Data](), forKey: .profileImages)
        }
    }
}


struct ImageData: Codable, Hashable {
    var imageId: String
    var image: Data
    var locationCaptured: LocationCoordinate?
    var capturedByUserId: String
    var sharedWithUserIds: [String]?
    var createdAt: Date = Date()

    static func == (lhs: ImageData, rhs: ImageData) -> Bool {
        return lhs.imageId.lowercased() == rhs.imageId.lowercased()
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(imageId.lowercased())
    }
}

struct ReVisit: Codable, Hashable {
    var visitId: String
    var location: LocationCoordinate
    var userId: String
    var imageIds: [String]?
    var date: Date
    var sharedWithUserIds: [String]?

    enum CodingKeys: String, CodingKey {
        case visitId = "visit_id"
        case location
        case userId = "user_id"
        case imageIds = "image_ids"
        case date
        case sharedWithUserIds = "shared_with_user_ids"
    }

    static func == (lhs: ReVisit, rhs: ReVisit) -> Bool {
        return lhs.visitId.lowercased() == rhs.visitId.lowercased()
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(visitId.lowercased())
    }
}

struct SharedAlbum : Codable {
    var albumId: String
    var albumName: String
    var createdByUserId: String
    var sharedWithUserIds: [String]?
    var imagesIds: [String]?
    var createdAt: Date
    enum CodingKeys: String, CodingKey {
          case albumId = "album_id"
          case albumName = "album_name"
          case createdByUserId = "created_by_user_id"
          case sharedWithUserIds = "shared_with_user_ids"
          case imagesIds = "image_ids"
          case createdAt = "created_at"
      }
}

struct Notification: Codable {
    var notificationId: String
    var userId: String
    var imageIds: [String]?
    var toNotify: [String]?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case notificationId = "notification_id"
        case userId = "user_id"
        case imageIds = "image_ids"
        case toNotify = "to_notify"
        case createdAt = "created_at"
    }
}

struct LocationCoordinate: Codable {
    var latitude: Double
    var longitude: Double

    // Init from CLLocation
    init(location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
    }
    
    // Direct initializer from latitude/longitude
//    init(latitude: Double, longitude: Double) {
//        self.latitude = latitude
//        self.longitude = longitude
//    }

    // Convert to CLLocation
    func toCLLocation() -> CLLocation {
        return CLLocation(latitude: self.latitude, longitude: self.longitude)
    }
}

// Move sample data creation to a class
class SampleData {
    static func createSampleData() -> (users: [User], images: [ImageData], revisits: [ReVisit], albums: [SharedAlbum], notifications: [Notification]) {
        // Create users with proper UUIDs
        let user1 = User(
            userId: UUID().uuidString,
            name: "Aman Sharma",
            phoneNumber: "+16398879427",
            profileImages: [UIImage(named: "person2")?.pngData() ?? Data()],
            verificationCode: "123456",
            shareLocation: true,
            location: LocationCoordinate(location: CLLocation(latitude: 37.785834, longitude: -122.406417)),
            sharedWithUserIds: [],
            friendListUserIds: [],
            sharedAlbums: [], email: "Aman@gmail.com"
        )

        let user2 = User(
            userId: UUID().uuidString,
            name: "Riya Sharma",
            phoneNumber: "+19876543210",
            profileImages: [UIImage(named: "person1")?.pngData() ?? Data()],
            verificationCode: "654321",
            shareLocation: false,
            location: nil,
            sharedWithUserIds: [],
            friendListUserIds: [],
            sharedAlbums: [], email: "Aman@gmail.com"
        )

        let user3 = User(
            userId: UUID().uuidString,
            name: "Aman Gupta",
            phoneNumber: "+19123456789",
            profileImages: [UIImage(named: "person3")?.pngData() ?? Data()],
            verificationCode: "789456",
            shareLocation: true,
            location: LocationCoordinate(location: CLLocation(latitude: 28.6139, longitude: 77.2090)),
            sharedWithUserIds: [],
            friendListUserIds: [],
            sharedAlbums: [], email: "Aman@gmail.com"
        )
        
        // Create images
        let image1 = ImageData(
            imageId: UUID().uuidString,
            image: UIImage(named: "img1")?.pngData() ?? Data(),
            locationCaptured: LocationCoordinate(location: CLLocation(latitude: 26.9124, longitude: 75.7873)),
            capturedByUserId: user1.userId,
            sharedWithUserIds: [user2.userId]
        )

        let image2 = ImageData(
            imageId: UUID().uuidString,
            image: UIImage(named: "img2")?.pngData() ?? Data(),
            locationCaptured: LocationCoordinate(location: CLLocation(latitude: 32.7767, longitude: 79.0428)),
            capturedByUserId: user3.userId,
            sharedWithUserIds: [user1.userId, user2.userId]
        )

        let image3 = ImageData(
            imageId: UUID().uuidString,
            image: UIImage(named: "img3")?.pngData() ?? Data(),
            locationCaptured: LocationCoordinate(location: CLLocation(latitude: 22.7767, longitude: 59.0428)),
            capturedByUserId: user2.userId,
            sharedWithUserIds: [user1.userId]
        )

        let image4 = ImageData(
            imageId: UUID().uuidString,
            image: UIImage(named: "img4")?.pngData() ?? Data(),
            locationCaptured: LocationCoordinate(location: CLLocation(latitude: 40.7128, longitude: 74.0060)),
            capturedByUserId: user3.userId,
            sharedWithUserIds: [user1.userId, user2.userId]
        )

        let image5 = ImageData(
            imageId: UUID().uuidString,
            image: UIImage(named: "img5")?.pngData() ?? Data(),
            locationCaptured: LocationCoordinate(location: CLLocation(latitude: 51.5074, longitude: 0.1278)),
            capturedByUserId: user1.userId,
            sharedWithUserIds: [user3.userId, user1.userId]
        )

        let image6 = ImageData(
            imageId: UUID().uuidString,
            image: UIImage(named: "img6")?.pngData() ?? Data(),
            locationCaptured: LocationCoordinate(location: CLLocation(latitude: 48.8566, longitude: 2.3522)),
            capturedByUserId: user3.userId,
            sharedWithUserIds: [user2.userId]
        )

        let image7 = ImageData(
            imageId: UUID().uuidString,
            image: UIImage(named: "img7")?.pngData() ?? Data(),
            locationCaptured: LocationCoordinate(location: CLLocation(latitude: 34.0522, longitude: 118.2437)),
            capturedByUserId: user1.userId,
            sharedWithUserIds: [user3.userId, user2.userId]
        )

        let image8 = ImageData(
            imageId: UUID().uuidString,
            image: UIImage(named: "img8")?.pngData() ?? Data(),
            locationCaptured: LocationCoordinate(location: CLLocation(latitude: 39.9042, longitude: 116.4074)),
            capturedByUserId: user3.userId,
            sharedWithUserIds: [user1.userId, user2.userId]
        )
        
        // Create shared albums
        let album1 = SharedAlbum(
            albumId: UUID().uuidString,
            albumName: "Vacation Memories",
            createdByUserId: user1.userId,
            sharedWithUserIds: [user2.userId, user3.userId],
            imagesIds: [image1.imageId, image3.imageId, image4.imageId],
            createdAt: Date()
        )

        let album2 = SharedAlbum(
            albumId: UUID().uuidString,
            albumName: "Wedding Album",
            createdByUserId: user3.userId,
            sharedWithUserIds: [user1.userId],
            imagesIds: [image2.imageId, image5.imageId],
            createdAt: Calendar.current.date(byAdding: .day, value: -20, to: Date())!
        )

        let album3 = SharedAlbum(
            albumId: UUID().uuidString,
            albumName: "Nature Photography",
            createdByUserId: user2.userId,
            sharedWithUserIds: [user1.userId, user3.userId],
            imagesIds: [image6.imageId, image7.imageId],
            createdAt: Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        )
        
        // Create revisits
        let revisit1 = ReVisit(
            visitId: UUID().uuidString,
            location: LocationCoordinate(location: CLLocation(latitude: 37.785834, longitude: -122.406417)),
            userId: user1.userId,
            imageIds: [image1.imageId, image2.imageId],
            date: Date(),
            sharedWithUserIds: [user2.userId]
        )

        let revisit2 = ReVisit(
            visitId: UUID().uuidString,
            location: LocationCoordinate(location: CLLocation(latitude: 19.0760, longitude: 72.8777)),
            userId: user2.userId,
            imageIds: [image3.imageId],
            date: Calendar.current.date(byAdding: .day, value: -5, to: Date())!,
            sharedWithUserIds: [user1.userId]
        )

        let revisit3 = ReVisit(
            visitId: UUID().uuidString,
            location: LocationCoordinate(location: CLLocation(latitude: 13.0827, longitude: 80.2707)),
            userId: user3.userId,
            imageIds: [image1.imageId, image3.imageId],
            date: Calendar.current.date(byAdding: .day, value: -10, to: Date())!,
            sharedWithUserIds: []
        )
        
        // Create notifications
        let notification1 = Notification(
            notificationId: UUID().uuidString,
            userId: user1.userId,
            imageIds: [image1.imageId, image5.imageId],
            toNotify: [user1.userId, user2.userId],
            createdAt: Date()
        )

        let notification2 = Notification(
            notificationId: UUID().uuidString,
            userId: user3.userId,
            imageIds: [image3.imageId, image2.imageId],
            toNotify: [user1.userId, user3.userId],
            createdAt: Date().addingTimeInterval(-86400) // 1 day ago
        )

        let notification3 = Notification(
            notificationId: UUID().uuidString,
            userId: user2.userId,
            imageIds: [image3.imageId, image5.imageId],
            toNotify: [user1.userId, user2.userId],
            createdAt: Date().addingTimeInterval(-172800) // 2 days ago
        )
        
        // Update user relationships with actual IDs
        var updatedUser1 = user1
        updatedUser1.sharedWithUserIds = [user3.userId]
        updatedUser1.friendListUserIds = [user2.userId, user3.userId]
        updatedUser1.sharedAlbums = [album1.albumId, album2.albumId, album3.albumId]

        var updatedUser2 = user2
        updatedUser2.sharedWithUserIds = [user1.userId]
        updatedUser2.friendListUserIds = [user1.userId, user3.userId]
        updatedUser2.sharedAlbums = [album3.albumId]

        var updatedUser3 = user3
        updatedUser3.sharedWithUserIds = [user1.userId, user2.userId]
        updatedUser3.friendListUserIds = [user1.userId, user2.userId]
        updatedUser3.sharedAlbums = [album1.albumId]
        
        let users = [updatedUser1, updatedUser2, updatedUser3]
        let images = [image1, image2, image3, image4, image5, image6, image7, image8]
        let revisits = [revisit1, revisit2, revisit3]
        let albums = [album1, album2, album3]
        let notifications = [notification1, notification2, notification3]
        
        return (users, images, revisits, albums, notifications)
    }
}

//SessionManager
import Foundation

class SessionManager {
    static let shared = SessionManager()
    
    // Keys for UserDefaults
    private let userIdKey = "userIdKey"
    private let sessionExpiryKey = "com.relive.sessionExpiry"
    
    private init() {}
    
    // Check if we have a valid session
    func hasValidSession() -> Bool {
        // First check if we have a userId
        guard let userId = UserDefaults.standard.string(forKey: userIdKey),
              !userId.isEmpty else {
            return false
        }
        
        // Next check if the session has expired
        if let expiryDate = UserDefaults.standard.object(forKey: sessionExpiryKey) as? Date {
            // If expiry date is in the future, session is valid
            return expiryDate > Date()
        }
        
        // If we have a userId but no expiry date, assume session is valid
        // (Backward compatibility for existing users)
        return true
    }
    
    // Save session with userId and set expiry for 30 days
    func saveSession(userId: String) {
        UserDefaults.standard.set(userId, forKey: userIdKey)
        
        // Set session expiry to 30 days from now
        let expiryDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())
        UserDefaults.standard.set(expiryDate, forKey: sessionExpiryKey)
        UserDefaults.standard.synchronize()
        
        print("Session saved for user: \(userId), expires: \(expiryDate?.description ?? "unknown")")
    }
    
    // Get the current session user ID
    func getUserId() -> String? {
        guard hasValidSession() else {
            return nil
        }
        return UserDefaults.standard.string(forKey: userIdKey)
    }
    
    // For backward compatibility with existing code
    func getSession() -> String? {
        return getUserId()
    }
    
    // Clear session when user signs out
    func clearSession() {
        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.removeObject(forKey: sessionExpiryKey)
        UserDefaults.standard.synchronize()
        
        print("User session cleared")
    }
    
    // Remove session - legacy method for backward compatibility
    func removeSession() {
        clearSession()
    }
    
    // Refresh the session, extending the expiry date
    func refreshSession() {
        guard let userId = getUserId() else {
            return
        }
        
        // Extend session by another 30 days
        let expiryDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())
        UserDefaults.standard.set(expiryDate, forKey: sessionExpiryKey)
        UserDefaults.standard.synchronize()
        
        print("Session refreshed for user: \(userId), new expiry: \(expiryDate?.description ?? "unknown")")
    }
}

class UserDataModel {
    
    static let shared = UserDataModel()
    
    private var users: [User] = []
    private var isDataLoaded = false
    
    private init() {
        loadInitialData()
    }
    
    private func loadInitialData() {
        // Initialize with sample data in development, but this will be replaced by Supabase data in production
        let sampleData = SampleData.createSampleData()
        users = sampleData.users
        isDataLoaded = true
        print("🔄 UserDataModel: Initial data loaded with \(users.count) users")
    }
    
    // Add this method to force reload data when needed
    func reloadIfNeeded() {
        // If data is already loaded and we have users, no need to reload
        if isDataLoaded && !users.isEmpty {
            print("🔄 UserDataModel: Data already loaded with \(users.count) users")
            return
        }
        
        // If data isn't loaded or users array is empty, reload
        loadInitialData()
        
        // If you're syncing with Supabase, you might also want to trigger a sync here
        if let userId = SessionManager.shared.getSession() {
            print("🔄 UserDataModel: Data reloaded for user \(userId)")
            
            // Optional: If you want to trigger a background sync with Supabase
            // DispatchQueue.global(qos: .background).async {
            //     SupabaseManager.shared.syncUserDataAfterLogin(userId: userId) { _ in }
            // }
        }
    }
    
    func getAllUsers() -> [User] {
        return users
    }

    func getUser(byId userId: String) -> User? {
        // Check for case-insensitive match to handle Supabase's lowercase UUIDs
        return users.first { $0.userId.lowercased() == userId.lowercased() }
    }
    
    func getUserById(userId: String) -> User? {
        return getUser(byId: userId)
    }
    
    func getUserByPhoneNo(byno phone: String) -> User? {
          // Remove all non-digit characters
          let digitsOnly = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
          
          // Possible phone formats to check
          let phoneFormats = [
              digitsOnly,
              "+91\(digitsOnly)",
              "91\(digitsOnly)",
              "+1\(digitsOnly)",
              phone
          ]
          
          // Iterate through all users
          for user in users {
              // Remove non-digit characters from stored phone number
              let userPhoneDigits = user.phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
              
              // Check if any format matches
              for format in phoneFormats {
                  if userPhoneDigits.hasSuffix(format) || format.hasSuffix(userPhoneDigits) {
                      return user
                  }
              }
          }
          
          return nil
      }

    func addUser(_ user: User) {
        // Check if user exists by ID (case-insensitive)
        if getUser(byId: user.userId) == nil {
            users.append(user)
        } else {
            // Update existing user instead of adding a duplicate
            updateUser(user)
        }
    }
    
    func updateUser(_ user: User) {
        // Find the user by ID (case-insensitive)
        if let index = users.firstIndex(where: { $0.userId.lowercased() == user.userId.lowercased() }) {
            users[index] = user
        } else {
            // If not found, add as new user
            users.append(user)
        }
    }


    func addFriend(toUser userId: String, friendId: String) {
        guard var user = getUser(byId: userId),
              users.contains(where: { $0.userId.lowercased() == friendId.lowercased() }) else { return }
        
        // Initialize arrays if nil
        if user.friendListUserIds == nil {
            user.friendListUserIds = []
        }
        
        // Only add if not already in the list
        if !user.friendListUserIds!.contains(where: { $0.lowercased() == friendId.lowercased() }) {
            user.friendListUserIds!.append(friendId)
            updateUser(user)
        }
    }

    func getSharedAlbums(forUser userId: String) -> [SharedAlbum] {
        guard let user = getUser(byId: userId) else {
            return []
        }
        return user.sharedAlbums?.compactMap { SharedAlbumsDataModel.shared.getAlbum(byId: $0) } ?? []
    }
    
    func generateVerificationCode(for phoneNo: String) -> Bool {
        guard let user = getUserByPhoneNo(byno: phoneNo) else {
            print("User not found with phone: \(phoneNo)")
            return false // User not found
        }
        
        // Instead of changing the verification code, just log it for debugging
        print("Using existing verification code: \(user.verificationCode)")
        
        return true
    }
    func removeUser(byId userId: String) -> Bool {
        // Find the index of the user with a case-insensitive match
        if let index = users.firstIndex(where: { $0.userId.lowercased() == userId.lowercased() }) {
            // Remove the user from the array
            users.remove(at: index)
            print("🗑️ UserDataModel: Removed user with ID \(userId)")
            
            // Optional: Sync with Supabase in the background
            // DispatchQueue.global(qos: .background).async {
            //     SupabaseManager.shared.deleteUser(userId: userId) { result in
            //         if case .failure(let error) = result {
            //             print("❌ UserDataModel: Failed to sync user deletion with Supabase: \(error)")
            //         }
            //     }
            // }
            
            return true
        } else {
            print("⚠️ UserDataModel: User with ID \(userId) not found")
            return false
        }
    }
    
    // Clear all data (for testing)
    func clearAllData() {
        users.removeAll()
        isDataLoaded = false
    }
}




class ImageDataModel {
    static let shared = ImageDataModel()
    
    private var images: [ImageData] = []
    private var isDataLoaded = false
    
    private init() {
        loadInitialData()
    }
    
    private func loadInitialData() {
        // Initialize with sample data
        let sampleData = SampleData.createSampleData()
        images = sampleData.images
        isDataLoaded = true
        print("🔄 ImageDataModel: Initial data loaded with \(images.count) images")
    }
    
    // Add this method to force reload data when needed
    func reloadIfNeeded() {
        // If data is already loaded and we have images, no need to reload
        if isDataLoaded && !images.isEmpty {
            print("🔄 ImageDataModel: Data already loaded with \(images.count) images")
            return
        }
        
        // If data isn't loaded or images array is empty, reload
        loadInitialData()
        
        if let userId = SessionManager.shared.getSession() {
            print("🔄 ImageDataModel: Data reloaded for user \(userId)")
            // Count images related to this user for debugging
            let userCapturedImages = getImagesCapturedBy(userId: userId).count
            let userSharedImages = getImagesSharedWith(userId: userId).count
            print("🔄 ImageDataModel: User has \(userCapturedImages) captured images and \(userSharedImages) shared images")
        }
    }
    
    func getAllImages() -> [ImageData] {
        return images
    }

    func getImage(byId imageId: String) -> ImageData? {
        return images.first { $0.imageId.lowercased() == imageId.lowercased() }
    }

    func addImage(_ image: ImageData) {
        if getImage(byId: image.imageId) == nil {
            images.append(image)
        } else {
            updateImage(image)
        }
    }

    func updateImage(_ image: ImageData) {
        if let index = images.firstIndex(where: { $0.imageId.lowercased() == image.imageId.lowercased() }) {
            images[index] = image
        } else {
            // If not found, add as new image
            images.append(image)
        }
    }

    func getImagesCapturedBy(userId: String) -> [ImageData] {
        return images.filter { $0.capturedByUserId.lowercased() == userId.lowercased() }
    }

    func getImagesSharedWith(userId: String) -> [ImageData] {
        return images.filter { $0.sharedWithUserIds?.contains(where: { $0.lowercased() == userId.lowercased() }) ?? false }
    }

    func getImagesCapturedAt(location: CLLocation) -> [ImageData] {
        let maxDistance: Double = 50 // meters
        return images.filter { image in
            guard let imgLocation = image.locationCaptured else {
                print("❌ Image \(image.imageId) has no location")
                return false
            }
            let imageCLLocation = CLLocation(latitude: imgLocation.latitude, longitude: imgLocation.longitude)
            let distance = location.distance(from: imageCLLocation)
            print("📏 Distance to image \(image.imageId): \(distance) meters")
            return distance <= maxDistance
        }
    }
    
    // Clear all data (for testing)
    func clearAllData() {
        images.removeAll()
        isDataLoaded = false
    }
}


class RevisitDataModel {
    static let shared = RevisitDataModel()
    
    private var revisits: [ReVisit] = []
    private var isDataLoaded = false
    
    private init() {
        loadInitialData()
    }
    
    private func loadInitialData() {
        // Load sample data initially
        let sampleData = SampleData.createSampleData()
        revisits = sampleData.revisits
        isDataLoaded = true
        print("🔄 RevisitDataModel: Initial data loaded with \(revisits.count) revisits")
        
        // Fetch from Supabase
        Task {
            await fetchRevisitsFromSupabase()
        }
    }
    
    private func fetchRevisitsFromSupabase() async {
        do {
            guard let userId = SessionManager.shared.getSession() else {
                print("❌ No user session for fetching revisits")
                return
            }

            let response = try await SupabaseManager.shared.supabase
                .database
                .from("revisits")
                .select("*")
                .or("user_id.eq.\(userId),shared_with_user_ids.cs.{\"\(userId)\"}")
                .order("date", ascending: false)
                .execute()

            // Log raw response for debugging
            if let rawResponse = String(data: response.data, encoding: .utf8) {
                print("📡 Raw revisits response: \(rawResponse)")
            } else {
                print("📡 Unable to decode raw revisits response")
            }

            guard let fetchedRevisits = response.value as? [[String: Any]], !fetchedRevisits.isEmpty else {
                print("ℹ️ No revisits found in Supabase for user \(userId)")
                return
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let newRevisits = try fetchedRevisits.map { dict in
                let jsonData = try JSONSerialization.data(withJSONObject: dict)
                return try decoder.decode(ReVisit.self, from: jsonData)
            }

            // Merge with local revisits, avoiding duplicates
            for revisit in newRevisits {
                if !revisits.contains(where: { $0.visitId == revisit.visitId }) {
                    revisits.append(revisit)
                } else {
                    if let index = revisits.firstIndex(where: { $0.visitId == revisit.visitId }) {
                        revisits[index] = revisit
                    }
                }
            }
            print("🔄 RevisitDataModel: Fetched \(newRevisits.count) revisits from Supabase")
        } catch {
            print("❌ Error fetching revisits from Supabase: \(error.localizedDescription)")
        }
    }

    func saveRevisit(_ revisit: ReVisit) async throws {
        let revisitDict: [String: AnyCodable] = [
            "visit_id": AnyCodable(revisit.visitId),
            "user_id": AnyCodable(revisit.userId),
            "date": AnyCodable(ISO8601DateFormatter().string(from: revisit.date)),
            "image_ids": AnyCodable(revisit.imageIds ?? []),
            "shared_with_user_ids": AnyCodable(revisit.sharedWithUserIds ?? []),
            "latitude": AnyCodable(revisit.location.latitude),
            "longitude": AnyCodable(revisit.location.longitude)
        ]
        do {
            let response = try await SupabaseManager.shared.supabase
                .database
                .from("revisits")
                .upsert(revisitDict, onConflict: "visit_id")
                .execute()
            print("✅ Revisit \(revisit.visitId) saved: \(String(data: response.data, encoding: .utf8) ?? "no response")")
        } catch {
            print("❌ Save revisit error: \(error.localizedDescription), revisit: \(revisitDict)")
            throw error
        }
    }
    
    func reloadIfNeeded() {
        if !isDataLoaded || revisits.isEmpty {
            loadInitialData()
        }
        
        if let userId = SessionManager.shared.getSession() {
            print("🔄 RevisitDataModel: Data reloaded for user \(userId)")
            Task {
                await fetchRevisitsFromSupabase()
            }
        }
    }
    
    func getAllRevisits() -> [ReVisit] {
        return revisits
    }

    func addRevisit(_ revisit: ReVisit) {
        if !revisits.contains(where: { $0.visitId.lowercased() == revisit.visitId.lowercased() }) {
            revisits.append(revisit)
        } else {
            if let index = revisits.firstIndex(where: { $0.visitId.lowercased() == revisit.visitId.lowercased() }) {
                revisits[index] = revisit
            }
        }
        
        // Save to Supabase
        Task {
            do {
                try await saveRevisit(revisit)
            } catch {
                print("❌ Failed to save revisit to Supabase: \(error.localizedDescription)")
            }
        }
    }

    func getRevisitsByUser(userId: String) -> [ReVisit] {
        return revisits.filter { revisit in
            revisit.userId.lowercased() == userId.lowercased() ||
            (revisit.sharedWithUserIds?.contains { $0.lowercased() == userId.lowercased() } ?? false)
        }.sorted { $0.date > $1.date }
    }

    func getRevisitsAt(location: CLLocation) -> [ReVisit] {
        return revisits.filter { revisit in
            let revisitLocation = revisit.location.toCLLocation()
            let distance = location.distance(from: revisitLocation)
            return distance <= 100 // Within 100 meters
        }
    }

    func shareRevisitByUser(user: User) {
        guard user.shareLocation == true, let userLocation = user.location else { return }
        guard user.shareLocation == true, let userLocation = user.location else { return }
        let revisits = getRevisitsByUser(userId: user.userId)
        let currentLocation = userLocation.toCLLocation()
        let finalRevisits = revisits.filter {
            let revisitCLLocation = $0.location.toCLLocation()
            let distance = currentLocation.distance(from: revisitCLLocation)
            return distance < 100 // Within 100 meters
        }
        if !finalRevisits.isEmpty {
            let userIds = finalRevisits.flatMap { $0.sharedWithUserIds ?? [] }
            let allowedUsers = user.friendListUserIds?.filter { userId in
                return userIds.contains { $0.lowercased() == userId.lowercased() }
            } ?? []
            let imageIds = finalRevisits.flatMap { $0.imageIds ?? [] }
            let notification = Notification(
                notificationId: UUID().uuidString,
                userId: user.userId,
                imageIds: imageIds,
                toNotify: allowedUsers,
                createdAt: Date()
            )
            NotificationDataModel.shared.addNotification(notification: notification)
        }
    }
    
    func clearAllData() {
        revisits.removeAll()
        isDataLoaded = false
    }
}



class SharedAlbumsDataModel {
    static let shared = SharedAlbumsDataModel()
    
    private var sharedAlbums: [SharedAlbum] = []
    
    private init() {
        // Initialize with sample data
        let sampleData = SampleData.createSampleData()
        sharedAlbums = sampleData.albums
    }
    
    func getAllSharedAlbums() -> [SharedAlbum] {
        return sharedAlbums
    }

    func getAlbum(byId albumId: String) -> SharedAlbum? {
        return sharedAlbums.first { $0.albumId.lowercased() == albumId.lowercased() }
    }

    func addSharedAlbum(_ album: SharedAlbum) {
        if !sharedAlbums.contains(where: { $0.albumId.lowercased() == album.albumId.lowercased() }) {
            sharedAlbums.append(album)
        } else {
            updateSharedAlbum(album)
        }
    }

    func updateSharedAlbum(_ album: SharedAlbum) {
        if let index = sharedAlbums.firstIndex(where: { $0.albumId.lowercased() == album.albumId.lowercased() }) {
            sharedAlbums[index] = album
        } else {
            // If not found, add as new album
            sharedAlbums.append(album)
        }
    }

    func getAlbumsByCreator(userId: String) -> [SharedAlbum] {
        return sharedAlbums.filter { $0.createdByUserId.lowercased() == userId.lowercased() }
    }

    func getAlbumsSharedWith(userId: String) -> [SharedAlbum] {
        return sharedAlbums.filter { album in
            album.sharedWithUserIds?.contains { $0.lowercased() == userId.lowercased() } ?? false
        }
    }
    
    func deleteAlbum(albumId: String) -> Bool {
        if let index = sharedAlbums.firstIndex(where: { $0.albumId.lowercased() == albumId.lowercased() }) {
            sharedAlbums.remove(at: index)
            return true
        }
        return false
    }
    
    func updateAlbum(_ updatedAlbum: SharedAlbum) {
        updateSharedAlbum(updatedAlbum) // Use existing method
    }
    
    func addImage(toAlbumWithId albumId: String, imageId: String) {
        if let index = sharedAlbums.firstIndex(where: { $0.albumId.lowercased() == albumId.lowercased() }) {
            var album = sharedAlbums[index]
            if album.imagesIds == nil {
                album.imagesIds = [imageId]
            } else if !album.imagesIds!.contains(where: { $0.lowercased() == imageId.lowercased() }) {
                album.imagesIds!.append(imageId)
            }
            sharedAlbums[index] = album
        }
    }
    
    func removeImage(fromAlbumWithId albumId: String, imageId: String) {
        if let index = sharedAlbums.firstIndex(where: { $0.albumId.lowercased() == albumId.lowercased() }),
           let imageIds = sharedAlbums[index].imagesIds,
           let imageIndex = imageIds.firstIndex(where: { $0.lowercased() == imageId.lowercased() }) {
            var album = sharedAlbums[index]
            album.imagesIds?.remove(at: imageIndex)
            sharedAlbums[index] = album
        }
    }
    
    func reloadIfNeeded() {
        // Optional: Add any reload logic here if needed
        print("🔄 SharedAlbumsDataModel: Checking if reload needed")
    }
    
    // Clear all data (for testing)
    func clearAllData() {
        sharedAlbums.removeAll()
    }
}



class NotificationDataModel {
    static let shared = NotificationDataModel()
    
    private(set) var notifications: [Notification]
    private var isDataLoaded = false
    
    private init() {
        notifications = []
        loadInitialData()
    }
    
    private func loadInitialData() {
        // Attempt to load from Supabase first
        Task {
            await fetchNotificationsFromSupabase()
            if notifications.isEmpty {
                // Fallback to sample data if Supabase fetch fails or returns empty
                let sampleData = SampleData.createSampleData()
                self.notifications = sampleData.notifications
                print("🔄 NotificationDataModel: Fallback to sample data with \(notifications.count) notifications")
            }
            isDataLoaded = true
            print("🔄 NotificationDataModel: Initial data loaded with \(notifications.count) notifications")
        }
    }
    
    private func fetchNotificationsFromSupabase() async {
        do {
            guard let userId = SessionManager.shared.getSession() else {
                print("❌ No user session for fetching notifications")
                return
            }

            let response = try await SupabaseManager.shared.supabase
                .database
                .from("notifications")
                .select("*")
                .or("user_id.eq.\(userId),to_notify.cs.{\"\(userId)\"}")
                .order("created_at", ascending: false)
                .execute()

            print("📡 Raw notifications response: \(String(data: response.data, encoding: .utf8) ?? "nil")")

            guard let fetchedNotifications = response.value as? [[String: Any]], !fetchedNotifications.isEmpty else {
                print("ℹ️ No notifications found in Supabase for user \(userId)")
                return
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            var newNotifications: [Notification] = []
            
            for dict in fetchedNotifications {
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: dict)
                    let notification = try decoder.decode(Notification.self, from: jsonData)
                    newNotifications.append(notification)
                } catch {
                    print("❌ Failed to parse notification: \(dict), error: \(error.localizedDescription)")
                }
            }

            notifications = newNotifications
            print("🔄 NotificationDataModel: Fetched \(newNotifications.count) notifications from Supabase")
        } catch {
            print("❌ Error fetching notifications from Supabase: \(error.localizedDescription)")
        }
    }
    
    func reloadIfNeeded() {
        updateNotifications()
        
        // Early return if data is already loaded and notifications are not empty
        guard !isDataLoaded || notifications.isEmpty else {
            if let userId = SessionManager.shared.getSession() {
                let userNotifications = getNotificationsByUserId(userId: userId).count
                print("🔄 NotificationDataModel: Data reloaded for user \(userId) with \(userNotifications) notifications")
            }
            return
        }
        
        Task { @MainActor in
            // Fetch notifications from Supabase
            await fetchNotificationsFromSupabase()
            
            // Ensure notifications is updated safely
            if notifications.isEmpty {
                let sampleData = SampleData.createSampleData()
                notifications = sampleData.notifications
            }
            
            // Update state on the main thread
            isDataLoaded = true
            print("🔄 NotificationDataModel: Data reloaded with \(notifications.count) notifications")
            
            // Perform user-specific notification count after data is loaded
            if let userId = SessionManager.shared.getSession() {
                let userNotifications = getNotificationsByUserId(userId: userId).count
                print("🔄 NotificationDataModel: Data reloaded for user \(userId) with \(userNotifications) notifications")
            }
        }
    }
    
    // Change access level from private to internal
    internal func updateNotifications() {
        // Clear existing notifications to refresh
        notifications.removeAll()
        // Fetch fresh data
        Task {
            await fetchNotificationsFromSupabase()
        }
    }
    
    func addNotification(notification: Notification) {
        notifications.append(notification)
        // Sync with Supabase
        Task {
            do {
                try await SupabaseManager.shared.saveNotification(notification: notification)
                print("✅ Notification \(notification.notificationId) synced to Supabase")
            } catch {
                print("❌ Failed to sync notification to Supabase: \(error.localizedDescription)")
            }
        }
    }
    
    func getNotificationsByUserId(userId: String) -> [Notification] {
        return notifications.filter { $0.userId == userId }
    }
    func getNotificationsForUser(userId: String) -> [Notification] {
        return notifications.filter { notification in
            // User created the notification
            if notification.userId.lowercased() == userId.lowercased() {
                return true
            }
            
            // Notification is shared with the user
            return notification.toNotify!.contains { $0.lowercased() == userId.lowercased() }
        }
    }
    func getMostRecentNotificationForUser(userId: String) -> Notification? {
        let userNotifications = notifications.filter {
            $0.userId.lowercased() == userId.lowercased() ||
            ($0.toNotify?.contains { $0.lowercased() == userId.lowercased() } ?? false)
        }.sorted { $0.createdAt > $1.createdAt }
        
        print("🔍 Found \(userNotifications.count) notifications for user \(userId)")
        return userNotifications.first
    }
    
    // Clear all data (for testing)
    func clearAllData() {
        notifications.removeAll()
        isDataLoaded = false
    }
}


extension SharedAlbum {
    // Method to fetch creation date from Supabase
    func fetchCreationDate(completion: @escaping (Date?) -> Void) {
        // Ensure Supabase client is available
        guard let client = SupabaseManager.shared.client else {
            print("❌ Supabase client not initialized")
            completion(nil)
            return
        }
        
        // Perform asynchronous fetch
        Task {
            do {
                // Query the shared_albums table
                let response = try await client
                    .from("shared_albums")
                    .select("created_at")
                    .eq("album_id", value: self.albumId)
                    .limit(1)
                    .execute()
                
                // Debug: Print raw response
                if let rawResponseString = String(data: response.data, encoding: .utf8) {
                    print("🔍 Raw Supabase Response for Album Creation Date:")
                    print(rawResponseString)
                }
                
                // Parse the response
                if let jsonObject = try JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]],
                   let firstResult = jsonObject.first,
                   let createdAtString = firstResult["created_at"] as? String {
                    
                    // Use ISO8601DateFormatter to parse the timestamp
                    let dateFormatter = ISO8601DateFormatter()
                    if let createdAt = dateFormatter.date(from: createdAtString) {
                        DispatchQueue.main.async {
                            completion(createdAt)
                        }
                        return
                    }
                }
                
                // If parsing fails
                DispatchQueue.main.async {
                    print("❌ Unable to parse creation date for album \(self.albumId)")
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
    
    // Formatted creation date with fallback
    func formattedCreationDate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        return dateFormatter.string(from: createdAt)
    }
    
    // Relative time description
    func relativeCreationTime() -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(createdAt) {
            return "Today"
        } else if calendar.isDateInYesterday(createdAt) {
            return "Yesterday"
        } else {
            let components = calendar.dateComponents([.day], from: createdAt, to: now)
            if let days = components.day, days < 7 {
                return "\(days) days ago"
            } else {
                return formattedCreationDate()
            }
        }
    }
}
