//
//  HomeCollectionViewController.swift
//  Relive
//
//  Created by Ayush Nimiwal on 06/12/24.
//

import UIKit

private let headerReuseIdentifier = "Header"

class HomeCollectionViewController: UICollectionViewController, AlertViewCellDelegate, UIViewControllerTransitioningDelegate {
    
    // New flag to check if this is a new user
    private var isNewUser = false
    private var welcomeView: UIView?
    private let hasSeenWelcomeKeyPrefix = "hasSeenWelcomeScreen_"
    
    func didTapViewButton(in cell: RecentCollectionViewCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else {return}
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let customAlertVC = storyboard.instantiateViewController(withIdentifier: "AlertViewController") as? AlertViewController else {
            return
        }
        let userIds = images[indexPath.row].sharedWithUserIds
        let users = userIds?.compactMap({UserDataModel.shared.getUser(byId: $0)})
        
        customAlertVC.users = users
        customAlertVC.isSelectionEnabled = false
        
        customAlertVC.modalPresentationStyle = .overFullScreen
        customAlertVC.modalTransitionStyle = .crossDissolve
        self.present(customAlertVC, animated: true)
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
                
                item.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
                
                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .fractionalHeight(0.3))
                
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: groupSize,
                    subitems: [item])
                
                section = NSCollectionLayoutSection(group: group)
                
                section.orthogonalScrollingBehavior = .groupPaging
                
            
            case 1:
                //Section 2 - Grid Layout
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
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
                
                section.orthogonalScrollingBehavior = .groupPaging
                
                
            case 2:
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(0.45),  // Wider cells for better visibility
                    heightDimension: .fractionalHeight(1.0))

                let item = NSCollectionLayoutItem(layoutSize: itemSize)

                // Add more breathing room between items
                item.contentInsets = NSDirectionalEdgeInsets(
                    top: 8,
                    leading: 8,
                    bottom: 8,
                    trailing: 8)

                // Make the group taller for better visibility
                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .fractionalHeight(0.25))  // Taller cells

                // Create a horizontal group with the items
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: groupSize,
                    subitem: item,
                    count: 2)  // Two items per row

                // Configure the section with the group
                section = NSCollectionLayoutSection(group: group)

                // Add section insets for better spacing
                section.contentInsets = NSDirectionalEdgeInsets(
                    top: 10,
                    leading: 10,
                    bottom: 10,
                    trailing: 10)

                // Add paging behavior for smooth scrolling
                section.orthogonalScrollingBehavior = .groupPagingCentered
 
            default:
                return nil
            }
            
            let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(50))
            let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
            
            section.boundarySupplementaryItems = [header]
            
            return section
            
        }
    }
    
    
    
    var highlights : [SharedAlbum] = []
    var lookBack : [ReVisit] = [] // Changed from Notification to ReVisit
    var images : [ImageData] = []
    
    private let appStateNotificationName = NSNotification.Name("AppWillEnterForeground")
    private var initialDataLoaded = false
    private var isInitialSyncComplete = false
    private var syncCompletionObserver: NSObjectProtocol?
    private var isDataLoadInProgress = false
    private var retryCount = 0
    private let maxRetries = 3
    private var loadingIndicator: UIActivityIndicatorView?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up collection view layout first
        collectionView.collectionViewLayout = createCompositionalLayout()
        collectionView.register(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: headerReuseIdentifier)
        
        // Setup loading indicator before any data loading
        setupLoadingIndicator()
        
        // Register for notifications
        setupNotificationObservers()
        
        // Show loading indicator and start initial data load
        showLoadingIndicator()
        initialDataLoadWithRetry()
        
        // Set up a timer to check for data after a delay
        // This catches cases where the sync finished but we didn't get notified
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self = self, !self.isInitialSyncComplete else { return }
            print("⏱️ Delayed reload triggered")
            self.forceSyncAndRefresh()
        }
    }
    
    private func setupLoadingIndicator() {
        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator?.hidesWhenStopped = true
        loadingIndicator?.translatesAutoresizingMaskIntoConstraints = false
        
        if let loadingIndicator = loadingIndicator {
            view.addSubview(loadingIndicator)
            NSLayoutConstraint.activate([
                loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
        }
    }
    
    private func setupNotificationObservers() {
        // App state notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshDataFromNotification),
            name: appStateNotificationName,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshDataFromNotification),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        // Sync completion notification
        syncCompletionObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SupabaseSyncCompleted"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.isInitialSyncComplete = true
            self.isDataLoadInProgress = false
            self.loadDataAndRefreshUI(forceFetch: false)
            self.hideLoadingIndicator()
            print("🔄 Reloading home after Supabase sync")
        }
        
        // Add listener for album updates to refresh home screen
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshDataFromNotification),
            name: NSNotification.Name("AlbumUpdatedNotification"),
            object: nil
        )
        
        // Listen for specific home screen refresh notifications from Albums tab
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshDataFromNotification),
            name: NSNotification.Name("HomeScreenShouldRefresh"),
            object: nil
        )
        
        // Listen for revisit detection
        NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleRevisitDetected(_:)),
                name: NSNotification.Name("RevisitDetected"),
                object: nil
            )
    }

    @objc private func handleRevisitDetected(_ notification: Foundation.Notification) {
        guard let userInfo = notification.userInfo,
              let revisits = userInfo["revisits"] as? [ReVisit] else {
            return
        }
        
        // Filter revisits relevant to current user
        guard let userId = SessionManager.shared.getSession() else { return }
        
        let relevantRevisits = revisits.filter { revisit in
            revisit.userId == userId ||
            (revisit.sharedWithUserIds?.contains(userId) ?? false)
        }
        
        if !relevantRevisits.isEmpty {
            lookBack = relevantRevisits
            collectionView.reloadData()
        }
    }

    private func notifySharedUsers(revisits: [ReVisit]) {
        guard let currentUserId = SessionManager.shared.getSession() else { return }
        let sharedUserIds = revisits.flatMap { $0.sharedWithUserIds ?? [] }.unique()
        let imageIds = revisits.flatMap { $0.imageIds ?? [] }.unique()
        
        let notification = Notification(
            notificationId: UUID().uuidString,
            userId: currentUserId,
            imageIds: imageIds,
            toNotify: sharedUserIds,
            createdAt: Date()
        )
        NotificationDataModel.shared.addNotification(notification: notification)
        
        // Save revisits to Supabase
        Task {
            for revisit in revisits {
                do {
                    try await RevisitDataModel.shared.saveRevisit(revisit)
                } catch {
                    print("❌ Failed to save revisit to Supabase: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func initialDataLoadWithRetry() {
        guard !isDataLoadInProgress else { return }
        
        isDataLoadInProgress = true
        
        // First try to load from local storage
        loadDataAndRefreshUI(forceFetch: false)
        
        // Then check if we have data or need to retry with force fetch
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            // If we don't have any data yet, force a sync
            if self.highlights.isEmpty && self.lookBack.isEmpty && self.images.isEmpty {
                self.retryCount += 1
                
                if self.retryCount <= self.maxRetries {
                    print("⚠️ Data not available, forcing sync (Attempt \(self.retryCount)/\(self.maxRetries))")
                    self.forceSyncAndRefresh()
                } else {
                    print("⚠️ Max retries reached, giving up automatic sync")
                    self.isDataLoadInProgress = false
                    self.hideLoadingIndicator()
                    
                    // Show a refresh button or message if needed
                    self.showEmptyStateIfNeeded()
                }
            } else {
                self.isDataLoadInProgress = false
                self.initialDataLoaded = true
                self.hideLoadingIndicator()
            }
        }
    }
    
    private func forceSyncAndRefresh() {
        guard let userId = SessionManager.shared.getSession() else {
            isDataLoadInProgress = false
            hideLoadingIndicator()
            return
        }
        
        showLoadingIndicator()
        isDataLoadInProgress = true
        
        print("🔄 Forcing sync with Supabase for user \(userId)")
        SupabaseManager.shared.syncAllUserContent(userId: userId) { [weak self] success in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if success {
                    print("✅ Supabase sync completed successfully")
                    // Load the fresh data
                    self.loadDataAndRefreshUI(forceFetch: false)
                    self.initialDataLoaded = true
                } else {
                    print("❌ Supabase sync failed")
                }
                
                self.isDataLoadInProgress = false
                self.hideLoadingIndicator()
                
                // Show empty state if we still don't have data
                if self.highlights.isEmpty && self.lookBack.isEmpty && self.images.isEmpty {
                    self.showEmptyStateIfNeeded()
                }
            }
        }
    }

    @objc private func refreshDataFromNotification() {
        DispatchQueue.main.async { [weak self] in
            self?.loadDataAndRefreshUI(forceFetch: false)
        }
    }
    
    private func refreshDataFromLocal() {
        // Just reload from local storage without network operations
        loadDataAndRefreshUI(forceFetch: false)
    }

    func loadDataAndRefreshUI(forceFetch: Bool = false) {
        // Make sure we have a valid session
        guard let userId = SessionManager.shared.getSession() else {
            print("❌ No valid user session found")
            hideLoadingIndicator()
            return
        }
        
        print("🔄 Loading data for Home screen (forceFetch: \(forceFetch))")
        
        // If force fetch is requested, sync with the server first
        if forceFetch {
            showLoadingIndicator()
            isDataLoadInProgress = true
            
            SupabaseManager.shared.syncAllUserContent(userId: userId) { [weak self] success in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isDataLoadInProgress = false
                    self.loadFromLocalStorage()
                    self.hideLoadingIndicator()
                }
            }
        } else {
            // Just load from local storage
            loadFromLocalStorage()
        }
    }
    
    // In HomeCollectionViewController.swift, update the `loadFromLocalStorage` method:
    private func loadFromLocalStorage() {
        guard let userId = SessionManager.shared.getSession() else { return }

        // Force data models to refresh their caches
        UserDataModel.shared.reloadIfNeeded()
        NotificationDataModel.shared.reloadIfNeeded()
        ImageDataModel.shared.reloadIfNeeded()
        SharedAlbumsDataModel.shared.reloadIfNeeded()
        RevisitDataModel.shared.reloadIfNeeded()

        // Load and deduplicate albums
        let sharedAlbums = SharedAlbumsDataModel.shared.getAlbumsSharedWith(userId: userId)
        let createdAlbums = SharedAlbumsDataModel.shared.getAlbumsByCreator(userId: userId)
        var uniqueHighlights = [SharedAlbum]()
        var seenAlbumIds = Set<String>()
        for album in sharedAlbums + createdAlbums {
            if !seenAlbumIds.contains(album.albumId) {
                uniqueHighlights.append(album)
                seenAlbumIds.insert(album.albumId)
            }
        }
        highlights = uniqueHighlights

        // Load revisits for the user (owner or shared)
        lookBack = RevisitDataModel.shared.getRevisitsByUser(userId: userId).sorted { $0.date > $1.date }

        // If no revisits, fetch the most recent notification
        if lookBack.isEmpty {
            if let lastNotification = NotificationDataModel.shared.getMostRecentNotificationForUser(userId: userId) {
                let syntheticRevisit = ReVisit(
                    visitId: lastNotification.notificationId,
                    location: LocationCoordinate(latitude: 0, longitude: 0), // Placeholder
                    userId: lastNotification.userId,
                    imageIds: lastNotification.imageIds ?? [],
                    date: lastNotification.createdAt,
                    sharedWithUserIds: lastNotification.toNotify
                )
                lookBack = [syntheticRevisit]
            }
        }

        images = ImageDataModel.shared.getImagesCapturedBy(userId: userId)
        images.append(contentsOf: ImageDataModel.shared.getImagesSharedWith(userId: userId))
        images = images.unique()

        // Debug logging
        print("📊 Home data loaded - Highlights: \(highlights.count), LookBack: \(lookBack.count), Images: \(images.count)")

        // Check if we should show welcome screen
        if !initialDataLoaded {
            if let user = UserDataModel.shared.getUser(byId: userId) {
                let userWelcomeKey = hasSeenWelcomeKeyPrefix + userId
                let hasSeenWelcome = UserDefaults.standard.bool(forKey: userWelcomeKey)

                isNewUser = (highlights.isEmpty && lookBack.isEmpty && images.isEmpty) && !hasSeenWelcome

                if isNewUser {
                    showWelcomeExperience(for: user)
                }
            }
            initialDataLoaded = true
        }

        // Always reload UI after data load
        collectionView.reloadData()

        // Hide loading indicator if it's showing
        hideLoadingIndicator()
    }
    
    private func showLoadingIndicator() {
        DispatchQueue.main.async { [weak self] in
            self?.loadingIndicator?.startAnimating()
        }
    }
    
    private func hideLoadingIndicator() {
        DispatchQueue.main.async { [weak self] in
            self?.loadingIndicator?.stopAnimating()
        }
    }
    
    private func showEmptyStateIfNeeded() {
        // Only show empty state if we have no data and not showing welcome screen
        if highlights.isEmpty && lookBack.isEmpty && images.isEmpty && !isNewUser {
            // Create an empty state view with a refresh button
            let emptyStateView = UIView()
            emptyStateView.translatesAutoresizingMaskIntoConstraints = false
            
//            let messageLabel = UILabel()
//            messageLabel.text = "No memories yet."
//            messageLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
//            messageLabel.textAlignment = .center
//            messageLabel.translatesAutoresizingMaskIntoConstraints = false
//            
//            let subtitleLabel = UILabel()
//            subtitleLabel.text = "Tap the camera tab to start capturing moments"
//            subtitleLabel.font = UIFont.systemFont(ofSize: 14)
//            subtitleLabel.textColor = .secondaryLabel
//            subtitleLabel.textAlignment = .center
//            subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
            
            let refreshButton = UIButton(type: .system)
            refreshButton.setTitle("Refresh", for: .normal)
            refreshButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            refreshButton.addTarget(self, action: #selector(refreshButtonTapped), for: .touchUpInside)
            refreshButton.translatesAutoresizingMaskIntoConstraints = false
            
//            emptyStateView.addSubview(messageLabel)
//            emptyStateView.addSubview(subtitleLabel)
            emptyStateView.addSubview(refreshButton)
            
            view.addSubview(emptyStateView)
            
//            NSLayoutConstraint.activate([
//                emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//                emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
//                emptyStateView.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -40),
//                
//                messageLabel.topAnchor.constraint(equalTo: emptyStateView.topAnchor),
//                messageLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor),
//                messageLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor),
//                
//                subtitleLabel.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 8),
//                subtitleLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor),
//                subtitleLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor),
//                
//                refreshButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
//                refreshButton.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
//                refreshButton.bottomAnchor.constraint(equalTo: emptyStateView.bottomAnchor)
//            ])
            
            // Store reference to remove it later
            self.welcomeView = emptyStateView
        }
    }
    
    @objc private func refreshButtonTapped() {
        // Remove empty state view
        welcomeView?.removeFromSuperview()
        welcomeView = nil
        
        // Show loading indicator and force a sync
        showLoadingIndicator()
        forceSyncAndRefresh()
    }
    
    // Public method for Album tab to call
    func refreshOnReturn() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("🔄 Home screen being refreshed after returning from Albums tab")
            self.refreshDataFromLocal()
            
            // If we still don't have data, try a force refresh
            if self.highlights.isEmpty && self.lookBack.isEmpty && self.images.isEmpty {
                print("⚠️ Home data still empty after return, forcing sync")
                self.forceSyncAndRefresh()
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if initialDataLoaded {
            // If initial data is loaded, just refresh the UI with current data
            refreshDataFromLocal()
        } else {
            // If initial data hasn't loaded yet, show loading and retry
            showLoadingIndicator()
            initialDataLoadWithRetry()
        }
        
        // Get current user ID
        guard let userId = SessionManager.shared.getSession() else { return }
        
        // Check if we should remove welcome view when returning to this screen
        let userWelcomeKey = hasSeenWelcomeKeyPrefix + userId
        if welcomeView != nil && UserDefaults.standard.bool(forKey: userWelcomeKey) {
            removeWelcomeView()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // If we don't have any data yet, try forcing a sync
        if highlights.isEmpty && lookBack.isEmpty && images.isEmpty && !isDataLoadInProgress {
            forceSyncAndRefresh()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        
        if let observer = syncCompletionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func removeWelcomeView() {
        welcomeView?.removeFromSuperview()
        welcomeView = nil
        isNewUser = false
    }
    
    private func markWelcomeAsSeen() {
        // Get current user ID
        guard let userId = SessionManager.shared.getSession() else { return }
        
        // Create user-specific key for welcome screen
        let userWelcomeKey = hasSeenWelcomeKeyPrefix + userId
        
        // Save that this specific user has seen the welcome screen
        UserDefaults.standard.set(true, forKey: userWelcomeKey)
    }
    
    private func showWelcomeExperience(for user: User) {
        // Add a welcome view
        let welcomeView = UIView()
        welcomeView.backgroundColor = .systemBackground
        welcomeView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(welcomeView)
        
        // Position welcome view
        NSLayoutConstraint.activate([
            welcomeView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            welcomeView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            welcomeView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            welcomeView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        // Profile image
        let profileImageView = UIImageView()
        if let profileImageData = user.profileImages.first,
           let profileImage = UIImage(data: profileImageData) {
            profileImageView.image = profileImage
        } else {
            profileImageView.image = UIImage(systemName: "person.circle.fill")
        }
        profileImageView.contentMode = .scaleAspectFill
        profileImageView.clipsToBounds = true
        profileImageView.layer.cornerRadius = 50
        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        welcomeView.addSubview(profileImageView)
        
        // Welcome label
        let welcomeLabel = UILabel()
        welcomeLabel.text = "Welcome to Relive, \(user.name)!"
        welcomeLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        welcomeLabel.textAlignment = .center
        welcomeLabel.translatesAutoresizingMaskIntoConstraints = false
        welcomeView.addSubview(welcomeLabel)
        
        // Description label
        let descriptionLabel = UILabel()
        descriptionLabel.text = "Start capturing moments to build your memory collection."
        descriptionLabel.font = UIFont.systemFont(ofSize: 16)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        welcomeView.addSubview(descriptionLabel)
        
        // Create tab explanation view
        let tabsExplanationView = createTabsExplanationView()
        tabsExplanationView.translatesAutoresizingMaskIntoConstraints = false
        welcomeView.addSubview(tabsExplanationView)
        
        // Create buttons
        let captureButton = UIButton(type: .system)
        captureButton.setTitle("Capture Your First Memory", for: .normal)
        captureButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        captureButton.backgroundColor = .systemBlue
        captureButton.setTitleColor(.white, for: .normal)
        captureButton.layer.cornerRadius = 12
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.addTarget(self, action: #selector(captureButtonTapped), for: .touchUpInside)
        welcomeView.addSubview(captureButton)
        
        let albumButton = UIButton(type: .system)
        albumButton.setTitle("Create Your First Album", for: .normal)
        albumButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        albumButton.backgroundColor = .systemGreen
        albumButton.setTitleColor(.white, for: .normal)
        albumButton.layer.cornerRadius = 12
        albumButton.translatesAutoresizingMaskIntoConstraints = false
        albumButton.addTarget(self, action: #selector(albumButtonTapped), for: .touchUpInside)
        welcomeView.addSubview(albumButton)
        
        // Skip button
        let skipButton = UIButton(type: .system)
        skipButton.setTitle("Skip", for: .normal)
        skipButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        skipButton.setTitleColor(.systemBlue, for: .normal)
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        skipButton.addTarget(self, action: #selector(skipButtonTapped), for: .touchUpInside)
        welcomeView.addSubview(skipButton)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            profileImageView.topAnchor.constraint(equalTo: welcomeView.topAnchor, constant: 80),
            profileImageView.centerXAnchor.constraint(equalTo: welcomeView.centerXAnchor),
            profileImageView.widthAnchor.constraint(equalToConstant: 100),
            profileImageView.heightAnchor.constraint(equalToConstant: 100),
            
            welcomeLabel.topAnchor.constraint(equalTo: profileImageView.bottomAnchor, constant: 20),
            welcomeLabel.leadingAnchor.constraint(equalTo: welcomeView.leadingAnchor, constant: 16),
            welcomeLabel.trailingAnchor.constraint(equalTo: welcomeView.trailingAnchor, constant: -16),
            
            descriptionLabel.topAnchor.constraint(equalTo: welcomeLabel.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(equalTo: welcomeView.leadingAnchor, constant: 16),
            descriptionLabel.trailingAnchor.constraint(equalTo: welcomeView.trailingAnchor, constant: -16),
            
            tabsExplanationView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 32),
            tabsExplanationView.leadingAnchor.constraint(equalTo: welcomeView.leadingAnchor, constant: 36),
            tabsExplanationView.trailingAnchor.constraint(equalTo: welcomeView.trailingAnchor, constant: -36), // Updated: More margin on trailing side
            
            captureButton.topAnchor.constraint(equalTo: tabsExplanationView.bottomAnchor, constant: 40),
            captureButton.centerXAnchor.constraint(equalTo: welcomeView.centerXAnchor),
            captureButton.widthAnchor.constraint(equalToConstant: 240),
            captureButton.heightAnchor.constraint(equalToConstant: 50),
            
            albumButton.topAnchor.constraint(equalTo: captureButton.bottomAnchor, constant: 16),
            albumButton.centerXAnchor.constraint(equalTo: welcomeView.centerXAnchor),
            albumButton.widthAnchor.constraint(equalToConstant: 240),
            albumButton.heightAnchor.constraint(equalToConstant: 50),
            
            skipButton.topAnchor.constraint(equalTo: albumButton.bottomAnchor, constant: 12),
            skipButton.centerXAnchor.constraint(equalTo: welcomeView.centerXAnchor)
        ])
        
        self.welcomeView = welcomeView
    }
    
    private func createTabsExplanationView() -> UIView {
        let container = UIView()
        
        // Relive tab explanation
        let homeIcon = UIImageView(image: UIImage(systemName: "house.fill"))
        homeIcon.tintColor = .systemBlue
        homeIcon.contentMode = .scaleAspectFit
        homeIcon.translatesAutoresizingMaskIntoConstraints = false
        
        let homeLabel = UILabel()
        homeLabel.text = "Relive: View your memories and highlights"
        homeLabel.font = UIFont.systemFont(ofSize: 14)
        homeLabel.numberOfLines = 0 // Added: Allow multiple lines
        homeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Capture tab explanation
        let captureIcon = UIImageView(image: UIImage(systemName: "camera.fill"))
        captureIcon.tintColor = .systemBlue
        captureIcon.contentMode = .scaleAspectFit
        captureIcon.translatesAutoresizingMaskIntoConstraints = false
        
        let captureLabel = UILabel()
        captureLabel.text = "Capture: Take photos and create memories"
        captureLabel.font = UIFont.systemFont(ofSize: 14)
        captureLabel.numberOfLines = 0 // Added: Allow multiple lines
        captureLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Albums tab explanation
        let albumsIcon = UIImageView(image: UIImage(systemName: "photo.on.rectangle"))
        albumsIcon.tintColor = .systemBlue
        albumsIcon.contentMode = .scaleAspectFit
        albumsIcon.translatesAutoresizingMaskIntoConstraints = false
        
        let albumsLabel = UILabel()
        albumsLabel.text = "Albums: Organize your memories into collections"
        albumsLabel.font = UIFont.systemFont(ofSize: 14)
        albumsLabel.numberOfLines = 0 // Added: Allow multiple lines
        albumsLabel.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(homeIcon)
        container.addSubview(homeLabel)
        container.addSubview(captureIcon)
        container.addSubview(captureLabel)
        container.addSubview(albumsIcon)
        container.addSubview(albumsLabel)
        
        NSLayoutConstraint.activate([
                    // Home tab
                    homeIcon.topAnchor.constraint(equalTo: container.topAnchor),
                    homeIcon.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    homeIcon.widthAnchor.constraint(equalToConstant: 24),
                    homeIcon.heightAnchor.constraint(equalToConstant: 24),
                    
                    homeLabel.centerYAnchor.constraint(equalTo: homeIcon.centerYAnchor),
                    homeLabel.leadingAnchor.constraint(equalTo: homeIcon.trailingAnchor, constant: 12),
                    homeLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    
                    // Capture tab
                    captureIcon.topAnchor.constraint(equalTo: homeIcon.bottomAnchor, constant: 16),
                    captureIcon.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    captureIcon.widthAnchor.constraint(equalToConstant: 24),
                    captureIcon.heightAnchor.constraint(equalToConstant: 24),
                    
                    captureLabel.centerYAnchor.constraint(equalTo: captureIcon.centerYAnchor),
                    captureLabel.leadingAnchor.constraint(equalTo: captureIcon.trailingAnchor, constant: 12),
                    captureLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    
                    // Albums tab
                    albumsIcon.topAnchor.constraint(equalTo: captureIcon.bottomAnchor, constant: 16),
                    albumsIcon.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    albumsIcon.widthAnchor.constraint(equalToConstant: 24),
                    albumsIcon.heightAnchor.constraint(equalToConstant: 24),
                    albumsIcon.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                    
                    albumsLabel.centerYAnchor.constraint(equalTo: albumsIcon.centerYAnchor),
                    albumsLabel.leadingAnchor.constraint(equalTo: albumsIcon.trailingAnchor, constant: 12),
                    albumsLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor)
                ])
                
                return container
            }
            
            @objc private func captureButtonTapped() {
                // Mark welcome as seen
                markWelcomeAsSeen()
                
                // Switch to the capture tab (index 1)
                if let tabBarController = self.tabBarController {
                    tabBarController.selectedIndex = 1
                }
            }
            
            @objc private func albumButtonTapped() {
                // Mark welcome as seen
                markWelcomeAsSeen()
                
                // Switch to the albums tab (index 2)
                if let tabBarController = self.tabBarController {
                    tabBarController.selectedIndex = 2
                }
            }
            
            @objc private func skipButtonTapped() {
                // Mark welcome as seen
                markWelcomeAsSeen()
                
                // Remove welcome view
                removeWelcomeView()
                
                // Reload collection view
                collectionView.reloadData()
            }
            
            override func numberOfSections(in collectionView: UICollectionView) -> Int {
                  return isNewUser ? 0 : 3
              }
            
            override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
                switch section {
                case 0:
                    return highlights.count
                case 1:
                    return lookBack.count
                case 2:
                    return images.count
                default:
                    return 0
                }
            }
            
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // Add safety checks before accessing array elements
        switch indexPath.section {
        case 0:
            guard indexPath.row < highlights.count else {
                print("❌ Highlights index out of range: \(indexPath.row)")
                return UICollectionViewCell()
            }
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "highlightCell", for: indexPath) as! HighlightCollectionViewCell
            let highlight = highlights[indexPath.row]
            
            // Safely get the first image
            if let imageIds = highlight.imagesIds, !imageIds.isEmpty,
               let image = ImageDataModel.shared.getImage(byId: imageIds[0]) {
                if let uiImage = UIImage(data: image.image) {
                    cell.image.image = uiImage
                    cell.image.contentMode = .scaleAspectFill
                    cell.image.clipsToBounds = true
                }
            }
            
            cell.title.text = highlight.albumName
            
            // Fetch creation date from Supabase
            highlight.fetchCreationDate { [weak cell] fetchedDate in
                DispatchQueue.main.async {
                    if let date = fetchedDate {
                        // Preferred: Format with medium style
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateStyle = .medium
                        dateFormatter.timeStyle = .none
                        cell?.date.text = dateFormatter.string(from: date)
                    } else {
                        // Fallback to relative time from local createdAt
                        let calendar = Calendar.current
                        let now = Date()
                        
                        if calendar.isDateInToday(highlight.createdAt) {
                            cell?.date.text = "Today"
                        } else if calendar.isDateInYesterday(highlight.createdAt) {
                            cell?.date.text = "Yesterday"
                        } else {
                            let components = calendar.dateComponents([.day], from: highlight.createdAt, to: now)
                            if let days = components.day, days < 7 {
                                cell?.date.text = "\(days) days ago"
                            } else {
                                let dateFormatter = DateFormatter()
                                dateFormatter.dateFormat = "d MMMM yyyy"
                                cell?.date.text = dateFormatter.string(from: highlight.createdAt)
                            }
                        }
                    }
                }
            }
            
            cell.layer.cornerRadius = 20
            return cell
            
        case 1:
            guard indexPath.row < lookBack.count else {
                print("❌ LookBack index out of range: \(indexPath.row)")
                return UICollectionViewCell()
            }
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LookCell", for: indexPath) as! LookCollectionViewCell
            let revisit = lookBack[indexPath.row]
            
            // Safely get user and first image
            if let user = UserDataModel.shared.getUser(byId: revisit.userId),
               let imageIds = revisit.imageIds, !imageIds.isEmpty,
               let image = ImageDataModel.shared.getImage(byId: imageIds[0]) {
                
                cell.image.image = UIImage(data: image.image)
                cell.image.contentMode = .scaleAspectFill
                cell.image.clipsToBounds = true
                
                if let profileImageData = user.profileImages.first {
                    cell.profileImage.image = UIImage(data: profileImageData)
                    cell.profileImage.contentMode = .scaleAspectFill
                    cell.profileImage.clipsToBounds = true
                }
                
                cell.userName.text = user.name
                cell.message.text = "Look who's back at this location!"
            } else {
                print("❌ Unable to configure LookBack cell for index \(indexPath.row)")
            }
            
            return cell
            
        case 2:
            guard indexPath.row < images.count else {
                print("❌ Images index out of range: \(indexPath.row)")
                return UICollectionViewCell()
            }
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "RecentCell", for: indexPath) as! RecentCollectionViewCell
            let image = images[indexPath.row]
            
            // Reset profile image visibility
            cell.p1Image.isHidden = false
            cell.p2Image.isHidden = false
            
            // Get shared user IDs
            var sharedUserIds: [String] = image.sharedWithUserIds ?? []
            
            // Handle profile images based on number of shared users
            if sharedUserIds.isEmpty {
                // No shared users
                cell.p1Image.isHidden = true
                cell.p2Image.isHidden = true
            } else if sharedUserIds.count == 1 {
                // Only one shared user
                let user1Id = sharedUserIds[0]
                if let user1 = UserDataModel.shared.getUser(byId: user1Id),
                   let user1ProfileData = user1.profileImages.first,
                   let user1ProfileImage = UIImage(data: user1ProfileData) {
                    cell.p1Image.image = user1ProfileImage
                    cell.p1Image.isHidden = false
                } else {
                    cell.p1Image.isHidden = true
                }
                // Hide second profile image
                cell.p2Image.isHidden = true
            } else if sharedUserIds.count >= 2 {
                // At least two shared users - show both profile images
                let user1Id = sharedUserIds[0]
                if let user1 = UserDataModel.shared.getUser(byId: user1Id),
                   let user1ProfileData = user1.profileImages.first,
                   let user1ProfileImage = UIImage(data: user1ProfileData) {
                    cell.p1Image.image = user1ProfileImage
                    cell.p1Image.isHidden = false
                } else {
                    cell.p1Image.isHidden = true
                }
                
                let user2Id = sharedUserIds[1]
                if let user2 = UserDataModel.shared.getUser(byId: user2Id),
                   let user2ProfileData = user2.profileImages.first,
                   let user2ProfileImage = UIImage(data: user2ProfileData) {
                    cell.p2Image.image = user2ProfileImage
                    cell.p2Image.isHidden = false
                } else {
                    cell.p2Image.isHidden = true
                }
            }

            // Set main image
            if let mainImage = UIImage(data: image.image) {
                cell.image.image = mainImage
                cell.image.contentMode = .scaleAspectFill
                cell.image.clipsToBounds = true
            }

            cell.delegate = self
            return cell
            
        default:
            return UICollectionViewCell()
        }
    }

            
            func getImagesFromIds(_ ids: [String]) -> [UIImage] {
                var images: [UIImage] = []
                
                for id in ids {
                    if let image = ImageDataModel.shared.getImage(byId: id),
                        let uiimage = UIImage(data: image.image){
                        images.append(uiimage)
                    }
                }
                
                return images
            }
            
            override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
                switch indexPath.section {
                case 0:
                    let ids = highlights[indexPath.row].imagesIds!
                    let images = getImagesFromIds(ids)
                    performSegue(withIdentifier: "nRelive", sender: images)
                case 1:
                    let ids = lookBack[indexPath.row].imageIds!
                    let images = getImagesFromIds(ids)
                    performSegue(withIdentifier: "nRelive", sender: images)
                case 2:
                    let image = images[indexPath.row]
                    let uiimage = UIImage(data: image.image)
                    performSegue(withIdentifier: "pView", sender: uiimage)
                default:
                    break
                }
            }
            
            override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
                if segue.identifier == "nRelive",let dc = segue.destination as? ImageCollageViewController, let images = sender as? [UIImage] {
                    dc.images = images
                }
                else if segue.identifier == "pView", let dc = segue.destination as? ImageViewController, let image = sender as? UIImage {
                    dc.image = image
                }
            }
            
            override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
                let header = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: headerReuseIdentifier, for: indexPath)
                
                header.subviews.forEach{$0.removeFromSuperview()}
                        
                let label = UILabel(frame: CGRect(x: 15, y: 0, width: header.frame.width - 15, height: header.frame.height))
                switch indexPath.section {
                    case 0: label.text = "Highlights"
                    case 1: lookBack.count>0 ? label.text = "Look who's back" : nil
                    case 2: label.text = "Recent"
                    default: break
                }
                label.font = UIFont.systemFont(ofSize: 20)
                label.textAlignment = .left
                
                header.addSubview(label)
                return header
            }
            
            @IBAction func settingButton(_ sender: UIButton) {
                if let bottomSheetVC = storyboard?.instantiateViewController(withIdentifier: "BottomSheetNavigationController") as? UINavigationController {
                        bottomSheetVC.modalPresentationStyle = .custom
                        bottomSheetVC.transitioningDelegate = self
                        present(bottomSheetVC, animated: true, completion: nil)
                    }
            }
            
            func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
                return BottomSheetPresentationController(presentedViewController: presented, presenting: presenting)
            }
        }


extension Array where Element: Hashable {
    func unique() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}
