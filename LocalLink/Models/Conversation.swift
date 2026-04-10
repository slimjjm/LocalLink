import Foundation

struct Conversation: Identifiable {
    
    let id: String
    
    let businessId: String
    let customerId: String
    
    let title: String
    let lastMessage: String
    let timestamp: Date
    let unreadCount: Int
    
    // MARK: - Time Formatting
    
    var timeText: String {
        
        let seconds = Int(Date().timeIntervalSince(timestamp))
        
        if seconds < 60 {
            return "Now"
        } else if seconds < 3600 {
            return "\(seconds / 60)m"
        } else if seconds < 86400 {
            return "\(seconds / 3600)h"
        } else if seconds < 172800 {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: timestamp)
        }
    }
}
