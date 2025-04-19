import UIKit
import CoreLocation
import Supabase

class SceneDelegate: UIResponder, UIWindowSceneDelegate, CLLocationManagerDelegate {

    var window: UIWindow?
    private let locationManager = CLLocationManager()
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    private let appStateNotificationName = NSNotification.Name("AppWillEnterForeground")

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
            if let windowScene = scene as? UIWindowScene {
                let window = UIWindow(windowScene: windowScene)
                NotificationDataModel.shared.updateNotifications() // This now works
                
                // Debug all users in the data model
                debugPrintAllUsers()
                
                // Check for valid session
                if SessionManager.shared.hasValidSession() {
                    if let userId = SessionManager.shared.getSession() {
                        print("Found valid session for user ID: \(userId)")
                        
                        // Verify with Supabase and get user data
                        verifySessionAndSetupUser(userId: userId, window: window)
                    } else {
                        print("Session appears valid but no user ID found - navigating to login")
                        setLoginAsRoot(window: window)
                    }
                } else {
                    // No valid session
                    print("No valid session found - navigating to login")
                    setLoginAsRoot(window: window)
                }
                
                self.window = window
                window.makeKeyAndVisible()
            }
        }
    
    private func verifySessionAndSetupUser(userId: String, window: UIWindow) {
        // First check if user exists in local data model
        if let user = UserDataModel.shared.getUser(byId: userId) {
            print("User found in local data model: \(user.name)")
            
            // Check if Supabase session is valid
            SupabaseManager.shared.isSessionValid { [weak self] isValid in
                guard let self = self else { return }
                
                if isValid {
                    print("Supabase session is valid, proceeding to main app")
                    self.navigateToMainApp(user: user, window: window)
                    
                    // Also sync data in background
                    self.backgroundSyncUserData(userId: userId)
                } else {
                    print("Supabase session is invalid, but proceeding with local data")
                    // Even if Supabase session is invalid, we can still use local data
                    // This provides offline capability and better UX
                    self.navigateToMainApp(user: user, window: window)
                }
            }
        } else {
            print("User not found in local data model, attempting to fetch from Supabase")
            
            // User exists in session but not in local model - try to fetch from Supabase
            SupabaseManager.shared.isSessionValid { [weak self] isValid in
                guard let self = self else { return }
                
                if isValid {
                    print("Supabase session is valid, syncing user data")
                    // Show loading indicator
                    let loadingVC = self.createLoadingScreen()
                    DispatchQueue.main.async {
                        window.rootViewController = loadingVC
                    }
                    
                    // Fetch user data from Supabase
                    SupabaseManager.shared.syncUserDataAfterLogin(userId: userId) { success in
                        if success, let user = UserDataModel.shared.getUser(byId: userId) {
                            print("Successfully synced user data from Supabase")
                            
                            DispatchQueue.main.async {
                                self.navigateToMainApp(user: user, window: window)
                            }
                            
                            // Continue syncing other data in background
                            SupabaseManager.shared.syncAllUserContent(userId: userId) { contentSuccess in
                                print("Complete content sync finished, success: \(contentSuccess)")
                            }
                        } else {
                            print("Failed to sync user data from Supabase")
                            
                            DispatchQueue.main.async {
                                // Clear invalid session
                                SessionManager.shared.clearSession()
                                self.setLoginAsRoot(window: window)
                            }
                        }
                    }
                } else {
                    print("Supabase session is invalid - clearing session and navigating to login")
                    
                    DispatchQueue.main.async {
                        // Clear invalid session
                        SessionManager.shared.clearSession()
                        self.setLoginAsRoot(window: window)
                    }
                }
            }
        }
    }
    
    private func navigateToMainApp(user: User, window: UIWindow) {
        DispatchQueue.main.async {
            if let tabBarController = self.storyboard.instantiateViewController(withIdentifier: "tabbar") as? UITabBarController {
                // User is logged in, set root to tabbar controller
                if user.shareLocation {
                    self.checkLocationPermissionAndFetch()
                    RevisitDataModel.shared.shareRevisitByUser(user: user)
                }
                
                // Use transition animation
                let transition = CATransition()
                transition.duration = 0.3
                transition.type = CATransitionType.fade
                window.layer.add(transition, forKey: kCATransition)
                
                window.rootViewController = tabBarController
            } else {
                print("Failed to instantiate tabbar controller - defaulting to login screen")
                self.setLoginAsRoot(window: window)
            }
        }
    }
    
    private func backgroundSyncUserData(userId: String) {
        DispatchQueue.global(qos: .background).async {
            // Refresh session
            SessionManager.shared.refreshSession()
            
            // Sync all user content in background
            SupabaseManager.shared.syncAllUserContent(userId: userId) { success in
                print("Background data sync completed with success: \(success)")
            }
        }
    }
    
    private func createLoadingScreen() -> UIViewController {
        let loadingVC = UIViewController()
        loadingVC.view.backgroundColor = .systemBackground
        
        let loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.startAnimating()
        loadingIndicator.center = loadingVC.view.center
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        let loadingLabel = UILabel()
        loadingLabel.text = "Loading your account..."
        loadingLabel.textAlignment = .center
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        
        loadingVC.view.addSubview(loadingIndicator)
        loadingVC.view.addSubview(loadingLabel)
        
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: loadingVC.view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: loadingVC.view.centerYAnchor),
            
            loadingLabel.topAnchor.constraint(equalTo: loadingIndicator.bottomAnchor, constant: 20),
            loadingLabel.leadingAnchor.constraint(equalTo: loadingVC.view.leadingAnchor, constant: 20),
            loadingLabel.trailingAnchor.constraint(equalTo: loadingVC.view.trailingAnchor, constant: -20),
            loadingLabel.centerXAnchor.constraint(equalTo: loadingVC.view.centerXAnchor)
        ])
        
        return loadingVC
    }
    
    private func setLoginAsRoot(window: UIWindow) {
        if let navigationController = storyboard.instantiateViewController(withIdentifier: "initialNavigation") as? UINavigationController {
            window.rootViewController = navigationController
        } else {
            print("Failed to instantiate navigation controller - critical error")
            // Create a simple error view controller as a fallback
            let errorVC = UIViewController()
            errorVC.view.backgroundColor = .red
            let label = UILabel()
            label.text = "Error loading app. Please reinstall."
            label.textColor = .white
            label.translatesAutoresizingMaskIntoConstraints = false
            errorVC.view.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: errorVC.view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: errorVC.view.centerYAnchor)
            ])
            window.rootViewController = errorVC
        }
    }
    
    private func checkLocationPermissionAndFetch() {
        locationManager.delegate = self

        switch CLLocationManager.authorizationStatus() {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            print("Location access is restricted or denied.")
        case .authorizedWhenInUse, .authorizedAlways:
            fetchUserLocation()
        @unknown default:
            print("Unknown authorization status")
        }
    }

    private func fetchUserLocation() {
        if CLLocationManager.locationServicesEnabled() {
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.startUpdatingLocation()
        } else {
            print("Location services are not enabled.")
        }
    }

    // CLLocationManager Delegate Methods
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        
        guard let userId = SessionManager.shared.getSession(),
              var user = UserDataModel.shared.getUser(byId: userId) else {
            print("Cannot update location: no valid user session")
            return
        }
        
        user.location = LocationCoordinate(location: location)
        UserDataModel.shared.updateUser(user)

        // Stop location updates if not needed continuously
        locationManager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to fetch location: \(error.localizedDescription)")
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            fetchUserLocation()
        } else {
            print("Location permission denied.")
            
            guard let userId = SessionManager.shared.getSession(),
                  var user = UserDataModel.shared.getUser(byId: userId) else { return }
            
            user.shareLocation = false
            user.location = nil
            UserDataModel.shared.updateUser(user)
        }
    }
    
    // Debug method to print all users in the data model
    private func debugPrintAllUsers() {
        let users = UserDataModel.shared.getAllUsers()
        print("===== ALL USERS =====")
        print("Total users: \(users.count)")
        
        for (index, user) in users.enumerated() {
            print("User \(index):")
            print("  ID: \(user.userId)")
            print("  Name: \(user.name)")
            print("  Phone: \(user.phoneNumber)")
            print("  Verification code: \(user.verificationCode)")
            print("--------------------")
        }
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        
        // Post a notification for data refresh
        NotificationCenter.default.post(name: appStateNotificationName, object: nil)
        
        // Refresh session if needed
        if SessionManager.shared.hasValidSession() {
            if let userId = SessionManager.shared.getSession() {
                // Force refresh data models
                UserDataModel.shared.reloadIfNeeded()
                NotificationDataModel.shared.reloadIfNeeded()
                ImageDataModel.shared.reloadIfNeeded()
                
                print("💡 App entering foreground - data models reloaded")
            }
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Refresh session if needed
        if SessionManager.shared.hasValidSession() {
            SessionManager.shared.refreshSession()
            
            // Post notification for active app
            NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
            
            // Background refresh of user data if needed
            if let userId = SessionManager.shared.getUserId() {
                // Force refresh data models
                UserDataModel.shared.reloadIfNeeded()
                NotificationDataModel.shared.reloadIfNeeded()
                ImageDataModel.shared.reloadIfNeeded()
                
                print("💡 App became active - data models reloaded")
                
                DispatchQueue.global(qos: .background).async {
                    SupabaseManager.shared.syncUserDataAfterLogin(userId: userId) { _ in }
                }
            }
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
    }
}
