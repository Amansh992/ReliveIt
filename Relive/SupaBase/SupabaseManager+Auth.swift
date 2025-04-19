import Foundation
import UIKit
import Supabase
struct OTPRecord: Codable {
    let id: UUID
    let email: String
    let otp: String
    let expiresAt: String  // Store as string since that's how it's in the DB
    
    enum CodingKeys: String, CodingKey {
        case id, email, otp
        case expiresAt = "expires_at"
    }
}
struct NewOTPRecord: Codable {
    let email: String
    let otp: String
    let expires_at: String
}
extension SupabaseManager {
    
    // Check if the current session is valid
    func isSessionValid(completion: @escaping (Bool) -> Void) {
        Task {
            do {
                let session = try await supabase.auth.session
                print("Session check: \(session != nil ? "Valid session" : "No session")")
                
                DispatchQueue.main.async {
                    completion(session != nil)
                }
            } catch {
                print("Error checking session validity: \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
    
    // Sign out the current user
    func signOut(completion: @escaping (Bool) -> Void) {
        Task {
            do {
                try await supabase.auth.signOut()
                print("User signed out successfully from Supabase")
                
                SessionManager.shared.clearSession()
                clearLocalUserData()
                
                DispatchQueue.main.async {
                    completion(true)
                }
            } catch {
                print("Error signing out from Supabase: \(error.localizedDescription)")
                
                SessionManager.shared.clearSession()
                clearLocalUserData()
                
                DispatchQueue.main.async {
                    completion(true)
                }
            }
        }
    }

    // Helper method to clear all local user data
    private func clearLocalUserData() {
        UserDataModel.shared.clearAllData()
        ImageDataModel.shared.clearAllData()
        SharedAlbumsDataModel.shared.clearAllData()
        RevisitDataModel.shared.clearAllData()
        NotificationDataModel.shared.clearAllData()
    }
    
    // Check if a user exists with the given email
    func checkUserExists(email: String, completion: @escaping (Bool) -> Void) {
        Task {
            do {
                print("Checking if user exists with email: \(email)")
                
                let response = try await supabase
                    .database
                    .from("users")
                    .select("user_id")
                    .eq("email", value: email.lowercased())
                    .limit(1)
                    .execute()
                
                if let jsonString = String(data: response.data, encoding: .utf8) {
                    print("Check user exists response: \(jsonString)")
                }
                
                let userData = try JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]]
                let exists = !(userData?.isEmpty ?? true)
                
                DispatchQueue.main.async {
                    completion(exists)
                }
            } catch {
                print("Error checking user existence by email: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
    
    // Send OTP to an email address
    // Send OTP function with improved error handling and session clearing
    func sendOTP(email: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                // Clear any existing session first
                try? await supabase.auth.signOut()
                SessionManager.shared.clearSession()
                
                let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                print("Sending OTP to email (raw): \(email), normalized: \(normalizedEmail) at \(Date())")
                
                // Use the standard signInWithOTP method without options
                // The SDK should handle new user creation automatically
                let response = try await supabase.auth.signInWithOTP(email: normalizedEmail)
                print("OTP request successful - Response: \(response) at \(Date())")
                
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                print("Error sending OTP to email: \(error.localizedDescription) at \(Date())")
                
                // Rate limit error handling
                if error.localizedDescription.contains("429") {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(
                            domain: "OTPRequest",
                            code: 429,
                            userInfo: [NSLocalizedDescriptionKey: "Please wait a few seconds before requesting another code."]
                        )))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        }
    }

    // Verify OTP function with improved session handling and better error messages
    func verifyOTP(email: String, otp: String, name: String?, phone: String?, completion: @escaping (Result<User, Error>) -> Void) {
        Task {
            do {
                // Clear any existing session first to avoid token conflicts
                try? await supabase.auth.signOut()
                SessionManager.shared.clearSession()
                
                let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                print("Attempting to verify OTP: \(otp) for email: \(normalizedEmail) at \(Date())")
                
                // Try to verify with email type
                let session = try await supabase.auth.verifyOTP(
                    email: normalizedEmail,
                    token: otp,
                    type: .email
                )
                
                let user = session.user
                let userId = user.id.uuidString.lowercased()
                
                print("OTP verification successful for user ID: \(userId) at \(Date())")
                
                // Save the session immediately after successful verification
                SessionManager.shared.saveSession(userId: userId)
                
                // Continue with your existing logic
                if let name = name {
                    let metadata: [String: AnyJSON] = ["name": .string(name)]
                    try await supabase.auth.update(user: UserAttributes(data: metadata))
                    print("Updated user metadata with name: \(name) at \(Date())")
                }
                
                let metadata = user.userMetadata
                let userName = name ?? (metadata["name"]?.stringValue ?? "Unknown")
                let userPhone = phone ?? ""
                
                // Modify this part to handle database errors better
                var existingProfile: [String: Any]? = nil
                do {
                    existingProfile = try await getUserProfileFromDatabase(userId: userId)
                } catch {
                    print("Error fetching user profile: \(error.localizedDescription). Creating new profile.")
                    // Continue with nil existingProfile
                }
                
                do {
                    if existingProfile == nil ||
                       (existingProfile?["name"] as? String != userName ||
                        existingProfile?["email"] as? String != normalizedEmail ||
                        existingProfile?["phone"] as? String != userPhone) {
                        try await insertUserToDatabase(userId: userId, name: userName, phone: userPhone, email: normalizedEmail)
                    }
                } catch {
                    print("Error updating user in database: \(error.localizedDescription)")
                    // Continue anyway since auth was successful
                }
                
                let userObj = User(
                    userId: userId,
                    name: userName,
                    phoneNumber: userPhone,
                    profileImages: [],
                    verificationCode: "",
                    shareLocation: false,
                    location: nil,
                    sharedWithUserIds: [],
                    friendListUserIds: [],
                    sharedAlbums: [],
                    email: normalizedEmail
                )
                
                UserDataModel.shared.addUser(userObj)
                
                DispatchQueue.main.async {
                    completion(.success(userObj))
                }
            } catch {
                print("OTP verification failed with error: \(error.localizedDescription) at \(Date())")
                
                // Try to provide more specific error messages
                if error.localizedDescription.contains("token has expired") {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(
                            domain: "OTPVerification",
                            code: 1001,
                            userInfo: [NSLocalizedDescriptionKey: "The verification code has expired. Please request a new one."]
                        )))
                    }
                } else if error.localizedDescription.contains("invalid") {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(
                            domain: "OTPVerification",
                            code: 1002,
                            userInfo: [NSLocalizedDescriptionKey: "Invalid verification code. Please check and try again."]
                        )))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    // Find a user by email
    func findUserByEmail(email: String, completion: @escaping (Result<User?, Error>) -> Void) {
        Task {
            do {
                print("Searching for user with email: \(email) at \(Date())")
                
                let response = try await supabase
                    .from("users")
                    .select("*")
                    .eq("email", value: email.lowercased())
                    .execute()
                
                if let jsonString = String(data: response.data, encoding: .utf8) {
                    print("Database response for email \(email): \(jsonString)")
                }
                
                if let userData = try JSONSerialization.jsonObject(with: response.data, options: []) as? [[String: Any]],
                   let firstUser = userData.first {
                    
                    let userId = (firstUser["user_id"] as? String ?? "").lowercased()
                    let name = firstUser["name"] as? String ?? "Unknown"
                    let phone = firstUser["phone"] as? String ?? ""
                    let profileImageUrl = firstUser["profile_image_url"] as? String ?? ""
                    
                    print("Found user: \(name), ID: \(userId)")
                    
                    var user = User(
                        userId: userId,
                        name: name,
                        phoneNumber: phone,
                        profileImages: [],
                        verificationCode: "",
                        shareLocation: firstUser["share_location"] as? Bool ?? false,
                        location: nil,
                        sharedWithUserIds: [],
                        friendListUserIds: [],
                        sharedAlbums: [],
                        email: email.lowercased()
                    )
                    
                    user.profileImageUrl = profileImageUrl
                    
                    UserDataModel.shared.addUser(user)
                    
                    DispatchQueue.main.async {
                        completion(.success(user))
                    }
                } else {
                    print("No user found with email: \(email)")
                    DispatchQueue.main.async {
                        completion(.success(nil))
                    }
                }
            } catch {
                print("Error finding user by email: \(error) at \(Date())")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    // Placeholder for generating a random OTP (if logging is implemented)
    private func generateRandomOTP() -> String {
        return String(format: "%06d", Int.random(in: 0...999999))
    }

    private func getUserProfileFromDatabase(userId: String) async throws -> [String: Any]? {
        let response = try await supabase
            .from("users")
            .select("*")
            .eq("user_id", value: userId)
            .single()
            .execute()
        
        return response.value as? [String: Any]
    }

    private func insertUserToDatabase(userId: String, name: String, phone: String, email: String) async throws {
        let userData: [String: AnyEncodable] = [
            "user_id": AnyEncodable(userId),
            "name": AnyEncodable(name),
            "phone": AnyEncodable(phone),
            "email": AnyEncodable(email),
            "profile_image_url": AnyEncodable(""),
            "registration_complete": AnyEncodable(false),
            "share_location": AnyEncodable(false)
        ]
        try await supabase
            .from("users")
            .insert(userData)
            .execute()
    }
    func storeOTP(email: String, otp: String) async throws -> UUID {
            // Create expiration time (10 minutes from now)
            let expiresAt = Date().addingTimeInterval(10 * 60)
            
            // Format date for Postgres
            let dateFormatter = ISO8601DateFormatter()
            let expiresAtString = dateFormatter.string(from: expiresAt)
            
            // Create an encodable struct for the new OTP record
            let newRecord = NewOTPRecord(
                email: email,
                otp: otp,
                expires_at: expiresAtString
            )
            
            // Insert OTP record
            let response = try await supabase
                .from("otp_records")
                .insert(newRecord)
                .select()
                .execute()
            
            // Process the response - the key fix is here:
            let data = response.data
            
            // First try to parse the entire JSON document
            do {
                if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                   let firstRecord = jsonArray.first,
                   let idString = firstRecord["id"] as? String,
                   let id = UUID(uuidString: idString) {
                    return id
                }
            } catch {
                print("JSON parsing error: \(error)")
            }
            
            // If we get here, try decoding with JSONDecoder
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let records = try decoder.decode([OTPRecord].self, from: data)
                if let record = records.first {
                    return record.id
                }
            } catch {
                print("Decoder error: \(error)")
            }
            
            // If all else fails, try to create a UUID from the first record's ID value directly
            print("Raw data: \(String(data: data, encoding: .utf8) ?? "unreadable")")
            
            throw NSError(domain: "UserController", code: 1001,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to extract OTP record ID"])
        }
}

// Helper struct to make Any conform to Encodable
struct AnyEncodable: Encodable {
    private let value: Any

    init(_ value: Any) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let number as Int:
            try container.encode(number)
        case let string as String:
            try container.encode(string)
        case let bool as Bool:
            try container.encode(bool)
        case let date as Date:
            try container.encode(date)
        default:
            let context = EncodingError.Context(
                codingPath: [],
                debugDescription: "Unsupported value: \(value)"
            )
            throw EncodingError.invalidValue(value, context)
        }
    }
}
