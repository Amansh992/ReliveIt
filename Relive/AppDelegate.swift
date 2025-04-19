import UIKit
import Supabase
import UserNotifications
import CoreLocation

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, CLLocationManagerDelegate {

    private let locationManager = CLLocationManager()
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var lastRevisitNotificationTime: Date? // Track last notification time
    private let revisitCooldown: TimeInterval = 300 // 5-minute cooldown
    private let maxMonitoredRegions = 20 // Approximate iOS limit for monitored regions

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch
        print("App launched - Supabase debug mode is active")
        print("For testing, you can use '111111' as the OTP verification code")

        // Setup session checker
        setupSessionObserver()

        // Configure notification center
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission denied: \(error.localizedDescription)")
            }
        }

        // Configure location manager for background updates
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization() // Use 'always' for background location
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.startMonitoringSignificantLocationChanges()
        
        // Initialize revisit regions based on existing data
        setupRevisitRegions()

        // Show the last "Look Who's Back" notification on app launch
        Task {
            await showLastNotificationOnLaunch()
        }

        return true
    }

    // Show the most recent notification on app launch
    private func showLastNotificationOnLaunch() async {
        do {
            let response = try await SupabaseManager.shared.supabase
                .database
                .from("notifications")
                .select("*")
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
            
            // Extract the data array from the response
            guard let notifications = response.value as? [[String: Any]] else {
                print("Failed to parse notifications data")
                return
            }

            if let notification = notifications.first,
               let notificationId = notification["notification_id"] as? String,
               let userId = notification["user_id"] as? String,
               let imageIds = notification["image_ids"] as? [String],
               let toNotify = notification["to_notify"] as? [String],
               let createdAt = ISO8601DateFormatter().date(from: notification["created_at"] as? String ?? "") {
                
                let content = UNMutableNotificationContent()
                content.title = "Look Who's Back!"
                content.body = "Last revisit with \(imageIds.count) memories. Shared with: \(toNotify.joined(separator: ", "))"
                content.sound = .default
                content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)

                let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: nil)
                try await UNUserNotificationCenter.current().add(request)
                print("Displayed last notification: \(notificationId)")
            }
        } catch {
            print("Failed to fetch or display last notification: \(error.localizedDescription)")
        }
    }

    // Setup observer to monitor session changes
    private func setupSessionObserver() {
        let timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if SessionManager.shared.hasValidSession() {
                self.checkSessionValidity()
            }
        }
        timer.tolerance = 300 // 5-minute tolerance for better battery performance
        RunLoop.current.add(timer, forMode: .common)
    }

    // Check if the current session is valid with Supabase
    private func checkSessionValidity() {
        if let userId = SessionManager.shared.getUserId() {
            SupabaseManager.shared.isSessionValid { isValid in
                if isValid {
                    SessionManager.shared.refreshSession()
                    print("Session automatically refreshed for user: \(userId)")
                } else {
                    print("Warning: Supabase session is invalid but keeping local session")
                }
            }
        }
    }

    // MARK: - UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Release resources for discarded scenes
    }

    // MARK: - Background Session Handling

    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        // Handle background tasks, e.g., Supabase sync
        completionHandler()
    }

    // MARK: - Application State Transitions

    func applicationWillTerminate(_ application: UIApplication) {
        if SessionManager.shared.hasValidSession() {
            print("App terminating, session maintained")
        }
        locationManager.stopMonitoringSignificantLocationChanges()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Start background task to handle location updates
        backgroundTask = application.beginBackgroundTask(withName: "LocationUpdateTask") {
            application.endBackgroundTask(self.backgroundTask)
            self.backgroundTask = .invalid
        }

        // Ensure location updates continue in background
        locationManager.startMonitoringSignificantLocationChanges()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Clean up background task
        if backgroundTask != .invalid {
            application.endBackgroundTask(backgroundTask)
            self.backgroundTask = .invalid
        }
        locationManager.startMonitoringSignificantLocationChanges()
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle user interaction with notification
        completionHandler()
    }

    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last,
              let userId = SessionManager.shared.getSession() else {
            print("❌ No location or user ID")
            return
        }
        print("📍 Location update: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        if var user = UserDataModel.shared.getUser(byId: userId) {
            user.location = LocationCoordinate(location: location)
            UserDataModel.shared.addUser(user)
            let nearbyImages = ImageDataModel.shared.getImagesCapturedAt(location: location)
            print("🔍 Nearby images: \(nearbyImages.map { ($0.imageId, $0.locationCaptured?.latitude, $0.locationCaptured?.longitude, $0.capturedByUserId, $0.sharedWithUserIds ?? []) })")
            
            let eligibleImages = nearbyImages.filter { image in
                let isDifferentUser = image.capturedByUserId != userId
                let isSharedWithUser = (image.sharedWithUserIds ?? []).contains(userId)
                return isDifferentUser || isSharedWithUser
            }
            print("🔍 Eligible images: \(eligibleImages.map { ($0.imageId, $0.capturedByUserId, $0.sharedWithUserIds ?? []) })")
            
            if !eligibleImages.isEmpty {
                let sharedUserIds = eligibleImages.flatMap { $0.sharedWithUserIds ?? [] }.unique()
                let revisit = ReVisit(
                    visitId: UUID().uuidString,
                    location: LocationCoordinate(location: location),
                    userId: userId,
                    imageIds: eligibleImages.map { $0.imageId },
                    date: Date(),
                    sharedWithUserIds: Array(sharedUserIds)
                )
                print("✅ Revisit detected: \(revisit.visitId), images: \(revisit.imageIds), shared with: \(revisit.sharedWithUserIds)")
                lastRevisitNotificationTime = Date()
                RevisitDataModel.shared.addRevisit(revisit)
                sendRevisitNotification(revisits: [revisit])
                NotificationCenter.default.post(
                    name: NSNotification.Name("RevisitDetected"),
                    object: nil,
                    userInfo: ["revisits": [revisit]]
                )
            } else {
                print("ℹ️ No revisit detected")
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        // Handle region-based revisit detection
        guard let revisit = RevisitDataModel.shared.getAllRevisits().first(where: { $0.visitId == region.identifier }) else { return }
        print("Entered region for revisit: \(revisit.visitId)")
        
        // Check cooldown
        if let lastTime = lastRevisitNotificationTime,
           Date().timeIntervalSince(lastTime) < revisitCooldown {
            print("Cooldown active, skipping region-based notification")
            return
        }
        
        lastRevisitNotificationTime = Date()
        sendRevisitNotification(revisits: [revisit])
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed: \(error.localizedDescription)")
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("Monitoring failed for region: \(String(describing: region?.identifier)) with error: \(error.localizedDescription)")
    }

    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        print("Started monitoring region: \(region.identifier)")
    }

    // In AppDelegate.swift, update the `sendRevisitNotification` method:
    private func sendRevisitNotification(revisits: [ReVisit]) {
        guard let currentUserId = SessionManager.shared.getSession() else {
            print("🔍 No user ID for sending revisit notification")
            return
        }
        Task {
            do {
                var imageIds: [String] = []
                for revisit in revisits {
                    if let ids = revisit.imageIds {
                        imageIds.append(contentsOf: ids)
                    }
                }
                imageIds = imageIds.unique()
                let toNotify = revisits.flatMap { $0.sharedWithUserIds ?? [] }.unique()
                let notificationId = UUID().uuidString
                let notification = Notification(
                    notificationId: notificationId,
                    userId: currentUserId,
                    imageIds: imageIds,
                    toNotify: toNotify,
                    createdAt: Date()
                )
                try await SupabaseManager.shared.saveNotification(notification: notification)
                NotificationDataModel.shared.addNotification(notification: notification)
                let content = UNMutableNotificationContent()
                content.title = "Look Who's Back!"
                content.body = "You revisited a location with \(imageIds.count) memories. Shared with: \(toNotify.joined(separator: ", "))"
                content.sound = .default
                content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
                let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: nil)
                try await UNUserNotificationCenter.current().add(request)
                print("🔔 Revisit notification sent: \(notificationId)")
            } catch {
                print("❌ Failed to send revisit notification: \(error.localizedDescription)")
            }
        }
    }
    func checkLocationPermissionAndFetch() {
        DispatchQueue.global(qos: .userInitiated).async {
            let locationManager = CLLocationManager()
            locationManager.delegate = self // Ensure AppDelegate conforms to CLLocationManagerDelegate
            switch locationManager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                locationManager.requestLocation()
            case .notDetermined:
                DispatchQueue.main.async {
                    locationManager.requestWhenInUseAuthorization()
                }
            default:
                print("Location permission denied or restricted")
            }
        }
    }

    // Setup revisit regions based on existing data
    private func setupRevisitRegions() {
        let revisits = RevisitDataModel.shared.getAllRevisits()
        print("Setting up \(revisits.count) revisit regions")
        for revisit in revisits {
            let coordinate = revisit.location.toCLLocation().coordinate
            let region = CLCircularRegion(center: coordinate, radius: 100, identifier: revisit.visitId)
            region.notifyOnEntry = true
            region.notifyOnExit = false
            if locationManager.monitoredRegions.count < maxMonitoredRegions {
                locationManager.startMonitoring(for: region)
            } else {
                print("Warning: Maximum region monitoring limit (\(maxMonitoredRegions)) reached, skipping region for \(revisit.visitId)")
            }
        }
    }
    private func configureLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
        locationManager.requestAlwaysAuthorization()
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.startUpdatingLocation()
        print("🗺️ Location manager configured")
    }
    
}

// Extension for unique array elements

