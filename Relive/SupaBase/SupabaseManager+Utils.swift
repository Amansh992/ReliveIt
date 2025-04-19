import Foundation
import UIKit
import Supabase

extension SupabaseManager {
    
    // Helper to safely parse array fields from JSON
    func parseArrayField(_ field: Any?) -> [String] {
        // If it's already a string array, return it directly
        if let stringArray = field as? [String] {
            return stringArray
        }
        // If it's a string, try to parse it as JSON
        else if let string = field as? String {
            // Try to parse as JSON array
            if let data = string.data(using: .utf8),
               let array = try? JSONSerialization.jsonObject(with: data, options: []) as? [String] {
                return array
            }
            
            // Try to parse PostgreSQL array format like "{id1,id2}"
            if string.hasPrefix("{") && string.hasSuffix("}") {
                let content = string.dropFirst().dropLast()
                return content.split(separator: ",")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty } // Filter out empty strings
            }
            
            // If it's a single item without brackets, return it as a single-item array
            if !string.isEmpty {
                return [string]
            }
        }
        // Handle other array formats (like Any array)
        else if let anyArray = field as? [Any] {
            return anyArray.compactMap { item in
                if let stringItem = item as? String {
                    return stringItem
                } else if let numberItem = item as? NSNumber {
                    return numberItem.stringValue // Convert numbers to strings
                }
                return nil
            }
        }
        
        // Default case: return empty array
        return []
    }

    // Helper to parse dates from various formats
    func parseDate(_ dateField: Any?) -> Date? {
        if let timestamp = dateField as? TimeInterval {
            return Date(timeIntervalSince1970: timestamp)
        } else if let dateString = dateField as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.date(from: dateString)
        }
        return nil
    }
}
