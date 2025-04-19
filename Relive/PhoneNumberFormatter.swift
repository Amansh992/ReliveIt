import Foundation

class PhoneNumberFormatter {
    
    /// Standardizes phone numbers to a consistent format for storage and comparison
    /// Returns an array of possible formats to try when matching
    static func standardizePhoneNumber(_ phone: String) -> [String] {
        // Remove all non-digit characters except +
        let cleanPhone = phone.replacingOccurrences(of: "\\s|-|\\(|\\)", with: "", options: .regularExpression)
        
        // Create array of potential formats
        var formats = [cleanPhone]
        
        // If number starts with +, also add without +
        if cleanPhone.hasPrefix("+") {
            formats.append(String(cleanPhone.dropFirst()))
            
            // For US/Canada numbers (+1XXXXXXXXXX), also try without country code
            if cleanPhone.hasPrefix("+1") && cleanPhone.count > 2 {
                formats.append(String(cleanPhone.dropFirst(2)))
            }
            
            // For Indian numbers (+91XXXXXXXXXX), also try without country code
            if cleanPhone.hasPrefix("+91") && cleanPhone.count > 3 {
                formats.append(String(cleanPhone.dropFirst(3)))
            }
        } else {
            // If doesn't start with +, try with common country codes
            formats.append("+\(cleanPhone)")
            
            // If it looks like it might be a US number (10-11 digits)
            if cleanPhone.count >= 10 {
                // If starts with 1 and has 11 digits total, it's likely a US number with country code
                if cleanPhone.hasPrefix("1") && cleanPhone.count == 11 {
                    formats.append("+\(cleanPhone)")
                    formats.append(String(cleanPhone.dropFirst()))
                }
                // If it's 10 digits, it likely needs a country code
                else if cleanPhone.count == 10 {
                    formats.append("+1\(cleanPhone)")  // US format
                    formats.append("+91\(cleanPhone)") // India format
                    formats.append("91\(cleanPhone)")  // India format without +
                }
            }
            
            // If it has 91 prefix (India), try with and without +
            if cleanPhone.hasPrefix("91") && cleanPhone.count > 2 {
                formats.append("+\(cleanPhone)")
                formats.append(String(cleanPhone.dropFirst(2)))
                formats.append("+\(String(cleanPhone.dropFirst(2)))")
            }
        }
        
        // Remove duplicates and return
        return Array(Set(formats))
    }
    
    /// Attempts to find a match between two phone numbers by comparing all possible formats
    static func isPhoneNumberMatch(phone1: String, phone2: String) -> Bool {
        let formats1 = standardizePhoneNumber(phone1)
        let formats2 = standardizePhoneNumber(phone2)
        
        // Check for any intersection between the format arrays
        return !Set(formats1).intersection(Set(formats2)).isEmpty
    }
    
    /// Returns the "canonical" format of a phone number for storage
    /// This ensures we always store phone numbers consistently
    static func canonicalFormat(_ phone: String) -> String {
        let cleanPhone = phone.replacingOccurrences(of: "\\s|-|\\(|\\)", with: "", options: .regularExpression)
        
        // Prefer + format for international numbers
        if cleanPhone.hasPrefix("+") {
            return cleanPhone
        } else if cleanPhone.hasPrefix("91") && cleanPhone.count > 10 {
            // For Indian numbers, add + if missing
            return "+\(cleanPhone)"
        } else if cleanPhone.count == 10 {
            // For 10-digit Indian numbers, assume India format
            return "+91\(cleanPhone)"
        } else {
            // If unsure, just return the cleaned format
            return cleanPhone
        }
    }
}
