//
//  AlbumsCollectionViewController.swift
//  Relive
//
//  Created by Ayush Nimiwal on 10/12/24.
//

import UIKit

private let reuseIdentifier = "Cell"


class AlbumsCollectionViewController: UICollectionViewController, AlbumsAlertViewCellDelegate, UIViewControllerTransitioningDelegate, CreateEventDelegate {
    
    func didTapRelive(in cell: AlbumsCollectionViewCell) {
        guard let indexPath = collectionView.indexPath(for: cell),let ids = albums[indexPath.row].imagesIds else {return}
        var images: [UIImage] = []
        for imageId in ids {
            if let imageData = ImageDataModel.shared.getImage(byId: imageId) {
                if let image = UIImage(data: imageData.image) {
                    images.append(image)
                }
            }
        }
        
        performSegue(withIdentifier: "nnnRelive", sender: images)
    }
    
    func didTapViewButton(in cell: AlbumsCollectionViewCell) {
        guard let indexPath = collectionView.indexPath(for: cell),
              indexPath.row < albums.count else {
            print("Error: Invalid index path")
            return
        }
        
        let album = albums[indexPath.row]
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        guard let customAlertVC = storyboard.instantiateViewController(withIdentifier: "AlertViewController") as? AlertViewController else {
            return
        }
        
        // Set up the AlertViewController
        customAlertVC.isSelectionEnabled = false
        customAlertVC.isAlbum = true
        
        // Show loading indicator while fetching data
        let loadingAlert = UIAlertController(title: "Loading...", message: "Fetching album details", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        // Sync album details with Supabase
        SupabaseManager.shared.getSharedAlbumDetails(albumId: album.albumId) { [weak self] result in
            guard let self = self else {
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true, completion: nil)
                }
                return
            }
            
            switch result {
            case .success(let fetchedAlbum):
                // Update local album data
                SharedAlbumsDataModel.shared.updateSharedAlbum(fetchedAlbum)
                
                // Fetch User objects for sharedWithUserIds
                let sharedUserIds = fetchedAlbum.sharedWithUserIds ?? []
                var users: [User] = []
                
                for userId in sharedUserIds {
                    if let user = UserDataModel.shared.getUser(byId: userId) {
                        users.append(user)
                    } else {
                        // Fetch user from Supabase if not available locally
                        SupabaseManager.shared.getUserProfile(userId: userId) { userResult in
                            if case .success(let user) = userResult {
                                UserDataModel.shared.updateUser(user)
                                users.append(user)
                            }
                        }
                    }
                }
                
                // Update the AlertViewController with users
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        customAlertVC.users = users
                        customAlertVC.modalPresentationStyle = .overFullScreen
                        customAlertVC.modalTransitionStyle = .crossDissolve
                        self.present(customAlertVC, animated: true)
                    }
                }
                
            case .failure(let error):
                print("Failed to sync album details: \(error)")
                DispatchQueue.main.async {
                    loadingAlert.dismiss(animated: true) {
                        let errorAlert = UIAlertController(
                            title: "Error",
                            message: "Failed to load album details. Please try again.",
                            preferredStyle: .alert
                        )
                        errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(errorAlert, animated: true)
                    }
                }
            }
        }
    }
    
    
    
    func createCompositionalLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
            
            let section: NSCollectionLayoutSection
            
            switch sectionIndex {
                
                
            case 0:
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(0.5),
                    heightDimension: .fractionalHeight(1.0))
                
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                
                item.contentInsets = NSDirectionalEdgeInsets(
                    top: 5,
                    leading: 5,
                    bottom: 5,
                    trailing: 5)
                
                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .fractionalHeight(0.3))
                
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: groupSize,
                    subitems: [item])
                
                section = NSCollectionLayoutSection(group: group)
                
            default:
                return nil
            }
            return section
            
        }
    }
    
    // Replace your existing viewWillAppear with this
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Normal refresh when returning to the view
        refreshAlbumData()
    }
    
    // Add this method to ensure updates are reflected
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Check if we're coming from login or need a force refresh
        if let needsForceRefresh = UserDefaults.standard.object(forKey: "NeedsAlbumForceRefresh") as? Bool, needsForceRefresh {
            // Force a refresh with server sync
            refreshAlbumData(forceFetch: true)
            // Reset the flag
            UserDefaults.standard.set(false, forKey: "NeedsAlbumForceRefresh")
        }
    }
    
    var albums: [SharedAlbum] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        refreshAlbumData()
        collectionView.collectionViewLayout = createCompositionalLayout()
        
        // Set up notifications to listen for album updates
        setupNotifications()
        
        // Add long press gesture recognizer for album actions
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        collectionView.addGestureRecognizer(longPressGesture)
    }
    func didCreateEvent() {
        refreshAlbumData()
    }
    
    // Set up notifications for album updates
    func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAlbumUpdated),
            name: NSNotification.Name("AlbumUpdatedNotification"),
            object: nil
        )
    }
    
    @objc func handleAlbumUpdated() {
        print("Received AlbumUpdatedNotification, refreshing data for album list")
        // Force a sync to ensure the latest data is fetched
        refreshAlbumData(forceFetch: true)
    }
    
    // Clean up notifications when view controller is deallocated
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // Replace the refreshAlbumData() method in AlbumsCollectionViewController with this improved version:

    func refreshAlbumData(forceFetch: Bool = false) {
        // Clear existing data to avoid duplicates
        albums.removeAll()

        guard let userId = SessionManager.shared.getSession() else {
            print("No user session available")
            DispatchQueue.main.async { [weak self] in
                self?.collectionView.reloadData()
            }
            return
        }

        // Always force fetch on sign-in, share, or when explicitly requested
        let shouldForceFetch = forceFetch || UserDefaults.standard.bool(forKey: "NeedsAlbumForceRefresh")
        if shouldForceFetch {
            SupabaseManager.shared.syncAllUserContent(userId: userId) { [weak self] success in
                if success {
                    print("Successfully synced user content")
                    self?.loadAlbumsAndUsers()
                    // Check for missing images after sync
                    for album in self?.albums ?? [] {
                        if let imageIds = album.imagesIds {
                            self?.checkImagesAvailability(albumId: album.albumId, imageIds: imageIds)
                        }
                    }
                } else {
                    print("Failed to sync user content")
                    self?.loadAlbumsAndUsers() // Load local data as fallback
                }
                // Reset the refresh flag
                UserDefaults.standard.set(false, forKey: "NeedsAlbumForceRefresh")
            }
        } else {
            loadAlbumsAndUsers()
            // Check for missing images with local data
            for album in albums {
                if let imageIds = album.imagesIds {
                    checkImagesAvailability(albumId: album.albumId, imageIds: imageIds)
                }
            }
        }
    }
 

    private func loadAlbumsAndUsers() {
        if let userId = SessionManager.shared.getSession() {
            // Get unique albums
            let createdAlbums = SharedAlbumsDataModel.shared.getAlbumsByCreator(userId: userId)
            let sharedAlbums = SharedAlbumsDataModel.shared.getAlbumsSharedWith(userId: userId)
            var allAlbums = [SharedAlbum]()
            var albumIds = Set<String>()
            for album in createdAlbums + sharedAlbums {
                if !albumIds.contains(album.albumId) {
                    allAlbums.append(album)
                    albumIds.insert(album.albumId)
                }
            }
            albums = allAlbums

            // Pre-fetch users and their profile images
            let allSharedUserIds = albums.flatMap { $0.sharedWithUserIds ?? [] }
            let uniqueUserIds = Set(allSharedUserIds)
            
            let dispatchGroup = DispatchGroup()
            for userId in uniqueUserIds {
                dispatchGroup.enter()
                if UserDataModel.shared.getUser(byId: userId) == nil {
                    SupabaseManager.shared.getUserProfile(userId: userId) { result in
                        if case .success(let user) = result {
                            UserDataModel.shared.updateUser(user)
                            if let profileImageUrl = user.profileImageUrl, user.profileImages.isEmpty {
                                self.fetchProfileImage(userId: userId, url: profileImageUrl)
                            }
                        }
                        dispatchGroup.leave()
                    }
                } else {
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                print("Loaded \(createdAlbums.count) created albums and \(sharedAlbums.count) shared albums")
                for album in self.albums {
                    let imageCount = album.imagesIds?.count ?? 0
                    print("Album '\(album.albumName)' has \(imageCount) images")
                }
                DispatchQueue.main.async { [weak self] in
                    self?.collectionView.reloadData()
                }
            }
        }
    }

    // Helper method to fetch profile image
    private func fetchProfileImage(userId: String, url: String) {
        guard let imageUrl = URL(string: url) else { return }
        URLSession.shared.dataTask(with: imageUrl) { data, response, error in
            if let data = data, let image = UIImage(data: data) {
                // Fetch existing user or create a new one with all required parameters
                var user = UserDataModel.shared.getUser(byId: userId)
                if user == nil {
                    user = User(
                        userId: userId,
                        name: "", // Placeholder name
                        phoneNumber: "", // Placeholder phone number
                        profileImages: [], // Will be updated below
                        verificationCode: "",
                        shareLocation: false,
                        location: nil,
                        sharedWithUserIds: nil,
                        friendListUserIds: nil,
                        sharedAlbums: nil
                    )
                }
                
                // Update the user with the fetched profile image
                var updatedUser = user!
                updatedUser.profileImages = [data]
                UserDataModel.shared.updateUser(updatedUser)
                
                // Refresh UI on the main thread
                DispatchQueue.main.async { [weak self] in
                    self?.collectionView.reloadData() // Refresh UI if image is fetched
                }
            }
        }.resume()
    }

    private func loadAlbumsFromLocalStorage() {
        if let userId = SessionManager.shared.getSession() {
            // Get unique albums by combining created and shared albums
            let createdAlbums = SharedAlbumsDataModel.shared.getAlbumsByCreator(userId: userId)
            let sharedAlbums = SharedAlbumsDataModel.shared.getAlbumsSharedWith(userId: userId)
            
            // Combine and remove duplicates based on albumId
            var allAlbums = [SharedAlbum]()
            var albumIds = Set<String>()
            for album in createdAlbums + sharedAlbums {
                if !albumIds.contains(album.albumId) {
                    allAlbums.append(album)
                    albumIds.insert(album.albumId)
                }
            }
            albums = allAlbums

            print("Loaded \(createdAlbums.count) created albums and \(sharedAlbums.count) shared albums")
            
            // Debug image count for each album
            for album in albums {
                let imageCount = album.imagesIds?.count ?? 0
                print("Album '\(album.albumName)' has \(imageCount) images")
            }
            
            // Reload the collection view on the main thread
            DispatchQueue.main.async { [weak self] in
                self?.collectionView.reloadData()
            }
        }
    }
    

    // Helper method to check if all images for an album are available locally
    private func checkImagesAvailability(albumId: String, imageIds: [String]) {
        var missingIds: [String] = []
        
        for imageId in imageIds {
            if ImageDataModel.shared.getImage(byId: imageId) == nil {
                missingIds.append(imageId)
            }
        }
        
        if !missingIds.isEmpty {
            print("Album \(albumId) is missing \(missingIds.count) images. Attempting to fetch them.")
            
            // Try to fetch the missing images from Supabase
            SupabaseManager.shared.syncAlbumImagesOnly(albumId: albumId) { success in
                if success {
                    print("Successfully synced missing images for album \(albumId)")
                    DispatchQueue.main.async { [weak self] in
                        self?.collectionView.reloadData()
                    }
                } else {
                    print("Failed to sync missing images for album \(albumId)")
                }
            }
        }
    }
    
    // Keep the old method for compatibility
    private func loadData() {
        refreshAlbumData()
    }
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return albums.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AlbumCell", for: indexPath) as! AlbumsCollectionViewCell
        let album = albums[indexPath.item]
        var albumImage: ImageData? = nil
        var albumSharedWith: [String] = []

        // Get album cover image
        var coverImage: UIImage? // New variable for configure
        if let ids = album.imagesIds, !ids.isEmpty {
            if let albumImageData = ImageDataModel.shared.getImage(byId: ids.first!)?.image {
                albumImage = ImageDataModel.shared.getImage(byId: ids.first!) // Keep for existing logic
                coverImage = UIImage(data: albumImageData) // Set UIImage for configure
            }
        }

        // Get users the album is shared with
        if let sharedIds = album.sharedWithUserIds {
            albumSharedWith = sharedIds
        }

        // Set album cover image
        if let albumImageData = albumImage?.image, let albumImage = UIImage(data: albumImageData) {
            cell.imageView.image = albumImage
        }

        // Set album title
        cell.title.text = album.albumName

        // Reset visibility
        cell.p1Image.isHidden = true
        cell.p2Image.isHidden = true

        // Show profile images if shared users exist
        if !albumSharedWith.isEmpty {
            if let u1 = UserDataModel.shared.getUser(byId: albumSharedWith[0]),
               let u1ProfileImageData = u1.profileImages.first,
               let u1ProfileImage = UIImage(data: u1ProfileImageData) {
                cell.p1Image.image = u1ProfileImage
                cell.p1Image.isHidden = false
            }

            if albumSharedWith.count >= 2,
               let u2 = UserDataModel.shared.getUser(byId: albumSharedWith[1]),
               let u2ProfileImageData = u2.profileImages.first,
               let u2ProfileImage = UIImage(data: u2ProfileImageData) {
                cell.p2Image.image = u2ProfileImage
                cell.p2Image.isHidden = false
            }
        }

        // Get users the album is shared with for configure
        var sharedUsers: [User] = []
        if let sharedIds = album.sharedWithUserIds {
            sharedUsers = sharedIds.compactMap { UserDataModel.shared.getUser(byId: $0) }
        }

        // Fix: Pass coverImage (UIImage?) instead of albumImage (ImageData?)
        cell.configure(with: coverImage, titleText: album.albumName, sharedUsers: sharedUsers)

        cell.delegate = self
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = albums[indexPath.item].albumId
        performSegue(withIdentifier: "nextCC", sender: item)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "nextCC", let dc = segue.destination as? EachAlbumCollectionViewController  {
            dc.albumId = sender as? String
        }
        if segue.identifier == "nnnRelive",let dc = segue.destination as? ImageCollageViewController, let images = sender as? [UIImage] {
            dc.images = images
        }
        
    }
    
    
    @IBAction func CreateEvent(_ sender: UIBarButtonItem) {
        if let bottomSheetVC = storyboard?.instantiateViewController(withIdentifier: "CreateEventNavigationController") as? UINavigationController {
            if let createEventVC = bottomSheetVC.viewControllers.first as? CreateEventViewController {
                createEventVC.delegate = self
            }
            bottomSheetVC.modalPresentationStyle = .custom
            bottomSheetVC.transitioningDelegate = self
            present(bottomSheetVC, animated: true, completion: nil)
        }
    }
    
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return CreateEventBottomSheetPresentationController(presentedViewController: presented, presenting: presenting)
    }
    
    
    // MARK: - Album Actions via Long Press
    
    @objc func handleLongPress(gesture: UILongPressGestureRecognizer) {
        if gesture.state != .began { return }
        
        let point = gesture.location(in: collectionView)
        if let indexPath = collectionView.indexPathForItem(at: point) {
            let album = albums[indexPath.item]
            
            // Show action sheet for any album (removing the owner check for now)
            showActionSheet(for: album)
        }
    }
    
    private func showActionSheet(for album: SharedAlbum) {
        let actionSheet = UIAlertController(title: "Album Options", message: nil, preferredStyle: .actionSheet)
        
//        // Edit action
//        actionSheet.addAction(UIAlertAction(title: "Edit Album", style: .default) { [weak self] _ in
//            self?.showEditAlbumAlert(for: album)
//        })
        
        // Delete action
        actionSheet.addAction(UIAlertAction(title: "Delete Album", style: .destructive) { [weak self] _ in
            self?.showDeleteConfirmation(for: album)
        })
        
        // Cancel action
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(actionSheet, animated: true)
    }
    
    private func showEditAlbumAlert(for album: SharedAlbum) {
        let alert = UIAlertController(title: "Edit Album", message: "Enter a new name for the album", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.text = album.albumName
            textField.placeholder = "Album Name"
            textField.clearButtonMode = .whileEditing
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alert.addAction(UIAlertAction(title: "Update", style: .default) { [weak self] _ in
            guard let self = self,
                  let nameField = alert.textFields?.first,
                  let newName = nameField.text,
                  !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }
            
            // Create updated album
            var updatedAlbum = album
            updatedAlbum.albumName = newName
            
            // Save updated album
            SharedAlbumsDataModel.shared.updateAlbum(updatedAlbum)
            
            // Refresh data
            self.refreshAlbumData()
            
            // Post notification about album update
            NotificationCenter.default.post(name: NSNotification.Name("AlbumUpdatedNotification"), object: nil)
        })
        
        present(alert, animated: true)
    }
    
    private func showDeleteConfirmation(for album: SharedAlbum) {
        // Create alert controller
        let alert = UIAlertController(
            title: "Delete Album",
            message: "Are you sure you want to delete \"\(album.albumName)\"? This action cannot be undone.",
            preferredStyle: .alert
        )
        
        // Add cancel button
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alert.addAction(cancelAction)
        
        // Add delete button
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.performAlbumDeletion(album)
        }
        alert.addAction(deleteAction)
        
        // Present the alert
        present(alert, animated: true, completion: nil)
    }

    // Separate method to handle the actual deletion logic
    private func performAlbumDeletion(_ album: SharedAlbum) {
        // Attempt to delete from local storage
        let localDeletionSuccess = SharedAlbumsDataModel.shared.deleteAlbum(albumId: album.albumId)
        
        if localDeletionSuccess {
            print("Successfully deleted album from local storage")
            
            // Check if user is logged in to sync with server
            if let userId = SessionManager.shared.getSession() {
                // Show loading indicator
                let loadingAlert = UIAlertController(
                    title: "Deleting...",
                    message: "Please wait",
                    preferredStyle: .alert
                )
                self.present(loadingAlert, animated: true, completion: nil)
                
                // Perform server deletion
                SupabaseManager.shared.deleteAlbum(albumId: album.albumId, userId: userId) { [weak self] success in
                    guard let self = self else { return }
                    
                    DispatchQueue.main.async {
                        // Dismiss loading indicator
                        loadingAlert.dismiss(animated: true, completion: nil)
                        
                        // Show error if server deletion failed
                        if !success {
                            let errorAlert = UIAlertController(
                                title: "Warning",
                                message: "Album was deleted locally but couldn't be deleted from the server. It may reappear when you sync again.",
                                preferredStyle: .alert
                            )
                            errorAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                            self.present(errorAlert, animated: true, completion: nil)
                        }
                    }
                }
            }
            
            // Refresh UI and notify observers
            self.refreshAlbumData()
            NotificationCenter.default.post(name: NSNotification.Name("AlbumUpdatedNotification"), object: nil)
        } else {
            // Show error if local deletion failed
            let errorAlert = UIAlertController(
                title: "Error",
                message: "Failed to delete the album. Please try again.",
                preferredStyle: .alert
            )
            errorAlert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(errorAlert, animated: true, completion: nil)
        }
    }
}
