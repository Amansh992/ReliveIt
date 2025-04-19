import UIKit

class ProfileImageManager {
    static let shared = ProfileImageManager()
    
    private init() {}
    
    func saveProfileImageForAutoShare(userId: String) {
        // Check if we already have their profile image data
        if let user = UserDataModel.shared.getUser(byId: userId), !user.profileImages.isEmpty {
            // We already have their profile image in our local data model
            if let imageData = user.profileImages.first {
                saveProfileImageToAutoShareDB(userId: userId, imageData: imageData)
            } else if let profileImageUrl = user.profileImageUrl, !profileImageUrl.isEmpty {
                // Try to download from URL
                downloadProfileImage(from: profileImageUrl) { [weak self] data in
                    if let imageData = data {
                        self?.saveProfileImageToAutoShareDB(userId: userId, imageData: imageData)
                    }
                }
            }
        } else {
            // Fetch from server
            SupabaseManager.shared.getUserProfile(userId: userId) { [weak self] result in
                switch result {
                case .success(let user):
                    if let profileImageUrl = user.profileImageUrl, !profileImageUrl.isEmpty {
                        self?.downloadProfileImage(from: profileImageUrl) { data in
                            if let imageData = data {
                                self?.saveProfileImageToAutoShareDB(userId: userId, imageData: imageData)
                            }
                        }
                    }
                case .failure(let error):
                    print("Failed to fetch user profile: \(error)")
                }
            }
        }
    }
    
    private func downloadProfileImage(from urlString: String, completion: @escaping (Data?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            completion(data)
        }.resume()
    }
    
    private func saveProfileImageToAutoShareDB(userId: String, imageData: Data) {
        // Create directory if needed
        let fileManager = FileManager.default
        let autoShareDir = getAutoShareDirectory()
        
        if !fileManager.fileExists(atPath: autoShareDir.path) {
            do {
                try fileManager.createDirectory(at: autoShareDir, withIntermediateDirectories: true)
            } catch {
                print("Failed to create auto-share directory: \(error)")
                return
            }
        }
        
        // Save image data
        let imagePath = autoShareDir.appendingPathComponent("friend_\(userId).dat")
        do {
            try imageData.write(to: imagePath)
            
            // Register in UserDefaults
            var autoShareFriends = UserDefaults.standard.stringArray(forKey: "AutoShareFriends") ?? []
            if !autoShareFriends.contains(userId) {
                autoShareFriends.append(userId)
                UserDefaults.standard.set(autoShareFriends, forKey: "AutoShareFriends")
            }
            
            print("Saved profile image for auto-share: \(userId)")
        } catch {
            print("Failed to save profile image: \(error)")
        }
    }
    
    private func getAutoShareDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AutoShareFaces")
    }
}
