import Foundation

// Delegate protocol for selecting friends
protocol AddFriendsDelegate: AnyObject {
    func didSelectFriends(_ friends: [User])
}
