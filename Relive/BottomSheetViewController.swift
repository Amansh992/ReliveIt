import UIKit
import CoreLocation

class CircularImageView: UIImageView {
    override func layoutSubviews() {
        super.layoutSubviews()
        self.layer.cornerRadius = self.frame.size.width / 2
        self.clipsToBounds = true
    }
}

class BottomSheetViewController: UIViewController, CLLocationManagerDelegate {
    private var initialViewYPosition: CGFloat = 0
    @IBOutlet weak var profileImage: UIImageView!
    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var locationSwitch: UISwitch!
    @IBOutlet weak var editName: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    private var isEditingName: Bool = false
    private let locationManager = CLLocationManager()
    private var circularProfileImage: CircularImageView?
    private var loadingIndicator: UIActivityIndicatorView?
    private var dimmingView: UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        modalPresentationStyle = .overCurrentContext
        view.layer.cornerRadius = 20
        view.clipsToBounds = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap(_:)))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
              
        name.isHidden = true
        let userId = SessionManager.shared.getUserId()
        print("BottomSheetViewController loading for user: \(userId ?? "nil")")
        
        setupCircularProfileImage()
        showLoadingOnImageView()
        
        if let cancelButton = cancelButton {
            cancelButton.setTitle("Delete Account", for: .normal)
            cancelButton.setTitleColor(.systemRed, for: .normal)
            print("Cancel button configured successfully")
        } else {
            print("Error: cancelButton outlet is nil")
        }
        
        if let userId = userId {
            if let localUser = UserDataModel.shared.getUserById(userId: userId) {
                print("Local user data found: \(localUser.name)")
                locationSwitch.isOn = localUser.shareLocation ?? false
                nameField.text = localUser.name
                nameField.isUserInteractionEnabled = false
                
                if let profileImageData = localUser.profileImages.first,
                   let image = UIImage(data: profileImageData) {
                    circularProfileImage?.image = image
                    hideLoadingIndicator()
                    print("Loaded profile image from local data")
                } else if let profileImageUrl = localUser.profileImageUrl, !profileImageUrl.isEmpty {
                    loadImageFromUrl(profileImageUrl)
                } else {
                    circularProfileImage?.image = UIImage(systemName: "person.circle.fill")
                    hideLoadingIndicator()
                    print("Using placeholder image - no profile image found")
                }
                
                fetchUserProfile(userId: userId)
            } else {
                print("User found in session but not in local data model")
                circularProfileImage?.image = UIImage(systemName: "person.circle.fill")
                hideLoadingIndicator()
                fetchUserProfile(userId: userId)
            }
        } else {
            print("No user ID found in session")
            circularProfileImage?.image = UIImage(systemName: "person.circle.fill")
            hideLoadingIndicator()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupDimmingView()
        DispatchQueue.main.async {
            self.initialViewYPosition = self.view.frame.origin.y
            print("Initial view Y position: \(self.initialViewYPosition)")
        }
    }
    
    @objc private func handleBackgroundTap(_ recognizer: UITapGestureRecognizer) {
        let location = recognizer.location(in: view)
        
        // Check if the tap was outside the content area (assuming your content is in a container view)
        if !view.bounds.contains(location) || location.y < view.bounds.height * 0.2 {
            let currentLocationSharingState = locationSwitch.isOn
            dismiss(animated: true) {
                print("Bottom sheet dismissed")
                if currentLocationSharingState {
                    self.checkLocationPermission()
                }
            }
        }
    }
    
    // Modify your setupDimmingView method
    private func setupDimmingView() {
        // Remove any existing dimming view first
        dimmingView?.removeFromSuperview()
        dimmingView = nil
        
        // Create new dimming view
        dimmingView = UIView(frame: UIScreen.main.bounds)
        dimmingView?.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        dimmingView?.translatesAutoresizingMaskIntoConstraints = false
        
        // Make sure we have the right parent view
        if let presentingViewController = presentingViewController,
           let parentView = presentingViewController.view {
            parentView.addSubview(dimmingView!)
            parentView.bringSubviewToFront(self.view)
            
            NSLayoutConstraint.activate([
                dimmingView!.topAnchor.constraint(equalTo: parentView.topAnchor),
                dimmingView!.bottomAnchor.constraint(equalTo: parentView.bottomAnchor),
                dimmingView!.leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
                dimmingView!.trailingAnchor.constraint(equalTo: parentView.trailingAnchor)
            ])
            
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDimmingViewTap(_:)))
            dimmingView!.addGestureRecognizer(tapGesture)
            print("Dimming view and tap gesture added")
        } else {
            print("Error: Could not find presenting view controller")
        }
    }
    
    @objc private func handleDimmingViewTap(_ gesture: UITapGestureRecognizer) {
        print("Dimming view tapped")
        let currentLocationSharingState = locationSwitch.isOn
        dismiss(animated: true) { [weak self] in
            print("Bottom sheet dismissed")
            self?.locationSwitch.setOn(currentLocationSharingState, animated: false)
            if currentLocationSharingState {
                self?.checkLocationPermission()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        dimmingView?.removeFromSuperview()
        dimmingView = nil
        print("Dimming view removed")
    }
    
    @IBAction func cancelButton(_ sender: Any) {
        let alert = UIAlertController(
            title: "Delete Account",
            message: "Are you sure you want to delete your account? This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.performAccountDeletion()
        })
        
        present(alert, animated: true)
    }
    
    private func performAccountDeletion() {
        guard let userId = SessionManager.shared.getUserId() else {
            print("No user ID found for deletion")
            showAlert(message: "Unable to delete account. Please try again.")
            return
        }

        showLoadingIndicatorOnView()

        SupabaseManager.shared.deleteUser(userId: userId) { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.hideLoadingIndicator()

                switch result {
                case .success:
                    // Clear local data
                    UserDataModel.shared.removeUser(byId: userId)
                    SessionManager.shared.removeSession()
                    SupabaseManager.shared.clearLocalUserData()

                    // Show confirmation and redirect to registration
                    let alert = UIAlertController(
                        title: "Account Deleted",
                        message: "Your account has been successfully deleted. You can register again to create a new account.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                        let storyboard = UIStoryboard(name: "Main", bundle: nil)
                        let vc = storyboard.instantiateViewController(withIdentifier: "initialNavigation") as! UINavigationController
                        if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
                            let window = sceneDelegate.window
                            window?.rootViewController = vc
                            UIView.transition(with: window!, duration: 0.3, options: [.transitionCurlUp], animations: nil)
                        }
                    })
                    self.present(alert, animated: true)

                case .failure(let error):
                    print("Failed to delete user: \(error.localizedDescription)")
                    let message: String
                    if error.localizedDescription.contains("User not found") {
                        message = "Account not found. It may have already been deleted."
                    } else if error.localizedDescription.contains("Forbidden") {
                        message = "You are not authorized to delete this account."
                    } else if error.localizedDescription.contains("Network") {
                        message = "Network error. Please check your connection and try again."
                    } else {
                        message = "Failed to delete account: \(error.localizedDescription)"
                    }
                    self.showAlert(message: message)
                }
            }
        }
    }
    
    private func showLoadingIndicatorOnView() {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .gray
        indicator.startAnimating()
        indicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(indicator)
        
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        loadingIndicator = indicator
        view.isUserInteractionEnabled = false
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func loadImageFromUrl(_ urlString: String) {
        print("Attempting to load image from URL: \(urlString)")
        guard let url = URL(string: urlString) else {
            print("Invalid URL: \(urlString)")
            circularProfileImage?.image = UIImage(systemName: "person.circle.fill")
            hideLoadingIndicator()
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("Error loading image: \(error.localizedDescription)")
                    self.circularProfileImage?.image = UIImage(systemName: "person.circle.fill")
                    self.hideLoadingIndicator()
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    print("Invalid response or status code")
                    self.circularProfileImage?.image = UIImage(systemName: "person.circle.fill")
                    self.hideLoadingIndicator()
                    return
                }
                
                if let imageData = data, let image = UIImage(data: imageData) {
                    print("Successfully loaded image from URL")
                    self.circularProfileImage?.image = image
                    self.hideLoadingIndicator()
                    
                    if let userId = SessionManager.shared.getUserId() {
                        if var user = UserDataModel.shared.getUserById(userId: userId) {
                            user.profileImages = [imageData]
                            UserDataModel.shared.updateUser(user)
                            print("Updated user model with image data")
                        }
                    }
                } else {
                    print("Failed to create image from data")
                    self.circularProfileImage?.image = UIImage(systemName: "person.circle.fill")
                    self.hideLoadingIndicator()
                }
            }
        }.resume()
    }
    
    private func fetchUserProfile(userId: String) {
        print("Fetching user profile from Supabase for userId: \(userId)")
        SupabaseManager.shared.getUserProfile(userId: userId) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.hideLoadingIndicator()
                
                switch result {
                case .success(let user):
                    print("Successfully fetched user profile: \(user.name)")
                    self.nameField.text = user.name
                    self.locationSwitch.isOn = user.shareLocation
                    
                    if let profileImageUrl = user.profileImageUrl, !profileImageUrl.isEmpty {
                        if self.circularProfileImage?.image == nil || self.circularProfileImage?.image == UIImage(systemName: "person.circle.fill") {
                            print("Loading profile image from URL: \(profileImageUrl)")
                            self.loadImageFromUrl(profileImageUrl)
                        }
                    }
                    
                case .failure(let error):
                    print("Failed to fetch user profile: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func showLoadingOnImageView() {
        guard let circularView = circularProfileImage else { return }
        
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .gray
        indicator.startAnimating()
        indicator.translatesAutoresizingMaskIntoConstraints = false
        circularView.addSubview(indicator)
        
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: circularView.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: circularView.centerYAnchor)
        ])
        
        loadingIndicator = indicator
        circularView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.2)
    }
    
    private func hideLoadingIndicator() {
        loadingIndicator?.removeFromSuperview()
        loadingIndicator = nil
        circularProfileImage?.backgroundColor = .clear
        view.isUserInteractionEnabled = true
    }
    
    private func setupCircularProfileImage() {
        guard let superview = profileImage.superview else { return }
        
        let circularView = CircularImageView(frame: CGRect.zero)
        circularView.contentMode = .scaleAspectFill
        circularView.translatesAutoresizingMaskIntoConstraints = false
        circularView.image = profileImage.image
        circularView.backgroundColor = profileImage.backgroundColor
        
        circularView.layer.borderWidth = 2
        circularView.layer.borderColor = UIColor.lightGray.withAlphaComponent(0.3).cgColor
        
        superview.addSubview(circularView)
        
        let widthConstraint = circularView.widthAnchor.constraint(equalToConstant: 150)
        let heightConstraint = circularView.heightAnchor.constraint(equalToConstant: 150)
        let centerXConstraint = circularView.centerXAnchor.constraint(equalTo: superview.centerXAnchor)
        let topConstraint = circularView.topAnchor.constraint(equalTo: superview.topAnchor, constant: 30)
        
        NSLayoutConstraint.activate([
            widthConstraint,
            heightConstraint,
            centerXConstraint,
            topConstraint
        ])
        
        circularProfileImage = circularView
        profileImage.isHidden = true
        view.layoutIfNeeded()
    }
    
    @IBAction func allowLocation(_ sender: UISwitch) {
        if sender.isOn {
            checkLocationPermission()
        } else {
            disableLocationSharing()
        }
    }
    
    private func disableLocationSharing() {
        guard let userId = SessionManager.shared.getUserId() else {
            print("No user ID found for updating location sharing")
            return
        }
        
        if var user = UserDataModel.shared.getUserById(userId: userId) {
            user.shareLocation = false
            user.location = nil
            UserDataModel.shared.updateUser(user)
            print("Updated local user to disable location sharing")
            updateLocationSharingInSupabase(userId: userId, isSharing: false)
        }
    }
    
    @IBAction func editButton(_ sender: Any) {
        isEditingName.toggle()
        nameField.isUserInteractionEnabled = isEditingName
        
        if isEditingName {
            nameField.becomeFirstResponder()
            editName.setTitle("Done", for: .normal)
        } else {
            nameField.resignFirstResponder()
            guard let nameText = nameField.text, !nameText.isEmpty else { return }
            
            guard let userId = SessionManager.shared.getUserId() else {
                print("No user ID found for name update")
                return
            }
            
            if var user = UserDataModel.shared.getUserById(userId: userId) {
                user.name = nameText
                UserDataModel.shared.updateUser(user)
                print("Updated local user name to: \(nameText)")
                updateUserNameInSupabase(userId: userId, name: nameText)
            }
            
            editName.setTitle("Edit", for: .normal)
        }
    }
    
    private func updateUserNameInSupabase(userId: String, name: String) {
        let originalTitle = editName.title(for: .normal)
        editName.setTitle("Saving...", for: .normal)
        editName.isEnabled = false
        
        SupabaseManager.shared.updateUserName(userId: userId, name: name) { [weak self] success in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.editName.setTitle(originalTitle, for: .normal)
                self.editName.isEnabled = true
                
                if !success {
                    print("Failed to update name in Supabase")
                } else {
                    print("Successfully updated name in Supabase")
                }
            }
        }
    }
    
    @IBAction func logout(_ sender: Any) {
        SupabaseManager.shared.signOut { [weak self] success in
            guard let self = self else { return }
            
            print("Supabase sign out result: \(success ? "success" : "failed")")
            SessionManager.shared.removeSession()
            
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc = storyboard.instantiateViewController(withIdentifier: "initialNavigation") as! UINavigationController
            if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
                let window = sceneDelegate.window
                window?.rootViewController = vc
                UIView.transition(with: window!, duration: 0.3, options: [.transitionCurlUp], animations: nil)
            }
        }
    }
    
    private func updateLocationSharingInSupabase(userId: String, isSharing: Bool) {
        SupabaseManager.shared.updateLocationSharing(userId: userId, isSharing: isSharing) { success in
            if success {
                print("Successfully updated location sharing in Supabase")
            } else {
                print("Failed to update location sharing status in Supabase")
            }
        }
    }
    
    func checkLocationPermission() {
        switch CLLocationManager.authorizationStatus() {
        case .notDetermined:
            locationManager.delegate = self
            locationManager.requestWhenInUseAuthorization()
            print("Requesting location permission")
        case .restricted, .denied:
            showSettingsAlert()
            print("Location permission denied")
            locationSwitch.setOn(false, animated: true)
            disableLocationSharing()
        case .authorizedWhenInUse, .authorizedAlways:
            print("Location access granted")
            getLocation()
        @unknown default:
            fatalError("Unknown authorization status")
        }
    }
    
    func showSettingsAlert() {
        let alertController = UIAlertController(
            title: "Location Permission Needed",
            message: "Please enable location in Settings to use this feature.",
            preferredStyle: .alert
        )
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { [weak self] _ in
            self?.locationSwitch.setOn(false, animated: true)
        }))
        
        alertController.addAction(UIAlertAction(title: "Allow Location", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        self.present(alertController, animated: true)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("Location permission granted")
            locationSwitch.setOn(true, animated: true)
            getLocation()
        case .denied, .restricted:
            print("Location permission denied")
            locationSwitch.setOn(false, animated: true)
            disableLocationSharing()
        case .notDetermined:
            print("Location permission not determined")
        @unknown default:
            break
        }
    }
    
    func getLocation() {
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.startUpdatingLocation()
            print("Starting location updates")
        } else {
            print("Location services are not enabled.")
            locationSwitch.setOn(false, animated: true)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        
        guard let userId = SessionManager.shared.getUserId() else {
            print("No user ID found for updating location")
            return
        }
        
        print("Received location update: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        if var user = UserDataModel.shared.getUserById(userId: userId) {
            user.shareLocation = true
            let l = CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            user.location = LocationCoordinate(location: l)
            UserDataModel.shared.updateUser(user)
            print("Updated local user with location")
            updateLocationInSupabase(userId: userId, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        }
        
        locationManager.stopUpdatingLocation()
    }
    
    private func updateLocationInSupabase(userId: String, latitude: Double, longitude: Double) {
        SupabaseManager.shared.updateUserLocation(userId: userId, latitude: latitude, longitude: longitude) { success in
            if success {
                print("Successfully updated location in Supabase")
            } else {
                print("Failed to update location in Supabase")
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to get location: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.locationSwitch.setOn(false, animated: true)
        }
    }
}
