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
    
    @IBOutlet weak var profileImage: UIImageView!
    
    @IBOutlet weak var name: UILabel!
    
    @IBOutlet weak var nameField: UITextField!
    
    @IBOutlet weak var locationSwitch: UISwitch!
    
    @IBOutlet weak var editName: UIButton!
        
    
    private var isEditingName: Bool = false
    
    private let locationManager = CLLocationManager()
    
    // Create a circular image view to replace the existing one
    private var circularProfileImage: CircularImageView?
    
    // Loading indicator
    private var loadingIndicator: UIActivityIndicatorView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.cornerRadius = 20
        view.clipsToBounds = true
        
        // Hide the top name label
        name.isHidden = true
        
        // Setup user data
        let userId = SessionManager.shared.getUserId()
        print("BottomSheetViewController loading for user: \(userId ?? "nil")")
        
        // Initialize circular profile image
        setupCircularProfileImage()
        
        // Show loading indicator while fetching profile
        showLoadingOnImageView()
        
        // Try to get user from local data first
        if let userId = userId {
            // Check if we can get the user from local data
            if let localUser = UserDataModel.shared.getUserById(userId: userId) {
                // Update UI with available local data
                print("Local user data found: \(localUser.name)")
                locationSwitch.isOn = localUser.shareLocation ?? false
                nameField.text = localUser.name
                nameField.isUserInteractionEnabled = false
                
                // Display local image if available
                if let profileImageData = localUser.profileImages.first,
                   let image = UIImage(data: profileImageData) {
                    // Set the image on our circular image view
                    circularProfileImage?.image = image
                    hideLoadingIndicator()
                    print("Loaded profile image from local data")
                } else if let profileImageUrl = localUser.profileImageUrl, !profileImageUrl.isEmpty {
                    // Try to load from URL
                    loadImageFromUrl(profileImageUrl)
                } else {
                    // No image available
                    circularProfileImage?.image = UIImage(systemName: "person.circle.fill")
                    hideLoadingIndicator()
                    print("Using placeholder image - no profile image found")
                }
                
                // Fetch updated user profile from Supabase including profile image
                fetchUserProfile(userId: userId)
            } else {
                print("User found in session but not in local data model")
                // Show placeholder
                circularProfileImage?.image = UIImage(systemName: "person.circle.fill")
                hideLoadingIndicator()
                
                // Try to fetch from Supabase
                fetchUserProfile(userId: userId)
            }
        } else {
            print("No user ID found in session")
            // Show placeholder
            circularProfileImage?.image = UIImage(systemName: "person.circle.fill")
            hideLoadingIndicator()
        }
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
                    
                    // Save image data to user model
                    if let userId = SessionManager.shared.getUserId() {
                        // Check if the user exists in the data model
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
                    // Update UI with fetched data
                    self.nameField.text = user.name
                    self.locationSwitch.isOn = user.shareLocation
                    
                    // Check if we need to load profile image
                    if let profileImageUrl = user.profileImageUrl, !profileImageUrl.isEmpty {
                        if self.circularProfileImage?.image == nil || self.circularProfileImage?.image == UIImage(systemName: "person.circle.fill") {
                            print("Loading profile image from URL: \(profileImageUrl)")
                            self.loadImageFromUrl(profileImageUrl)
                        }
                    }
                    
                case .failure(let error):
                    print("Failed to fetch user profile: \(error.localizedDescription)")
                    // No need to show an error message as we're using local data as fallback
                }
            }
        }
    }
    
    private func showLoadingOnImageView() {
        guard let circularView = circularProfileImage else { return }
        
        // Create loading indicator
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
        
        // Add semi-transparent background
        circularView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.2)
    }
    
    private func hideLoadingIndicator() {
        loadingIndicator?.removeFromSuperview()
        loadingIndicator = nil
        circularProfileImage?.backgroundColor = .clear
    }
    
    private func setupCircularProfileImage() {
        // Check if we have the original image view
        guard let superview = profileImage.superview else { return }
        
        // Create our custom circular image view
        let circularView = CircularImageView(frame: CGRect.zero)
        circularView.contentMode = .scaleAspectFill
        circularView.translatesAutoresizingMaskIntoConstraints = false
        
        // Copy image and background color
        circularView.image = profileImage.image
        circularView.backgroundColor = profileImage.backgroundColor
        
        // Add border
        circularView.layer.borderWidth = 2
        circularView.layer.borderColor = UIColor.lightGray.withAlphaComponent(0.3).cgColor
        
        // Add to superview
        superview.addSubview(circularView)
        
        // Get original position constraints
        let originalY = profileImage.frame.origin.y
        
        // Force a 1:1 aspect ratio with fixed size
        let widthConstraint = circularView.widthAnchor.constraint(equalToConstant: 150)
        let heightConstraint = circularView.heightAnchor.constraint(equalToConstant: 150)
        let centerXConstraint = circularView.centerXAnchor.constraint(equalTo: superview.centerXAnchor)
        
        // Use top constraint relative to superview instead of the original image
        let topConstraint = circularView.topAnchor.constraint(equalTo: superview.topAnchor, constant: 30)
        
        // Activate constraints
        NSLayoutConstraint.activate([
            widthConstraint,
            heightConstraint,
            centerXConstraint,
            topConstraint
        ])
        
        // Store reference and hide original
        circularProfileImage = circularView
        profileImage.isHidden = true
        
        // Force layout
        view.layoutIfNeeded()
    }
    
    @IBAction func cancelButton(_ sender: Any) {
        // Capture the current location sharing state
        let currentLocationSharingState = locationSwitch.isOn
        
        dismiss(animated: true) { [weak self] in
            // Ensure the location switch remains in its current state
            self?.locationSwitch.setOn(currentLocationSharingState, animated: false)
            
            // If location sharing was on, ensure it remains active
            if currentLocationSharingState {
                self?.checkLocationPermission()
            }
        }
    }
    @IBAction func allowLocation(_ sender: UISwitch) {
        if sender.isOn {
            //Set state of toggle to true, send this value to data model
            checkLocationPermission()
        } else {
            // Handle disabling location sharing
            //Set state of toggle to false, send this value to data model
            disableLocationSharing()
        }
    }

    private func disableLocationSharing() {
        guard let userId = SessionManager.shared.getUserId() else {
            print("No user ID found for updating location sharing")
            return
        }
        
        // Check if user exists in the data model
        if var user = UserDataModel.shared.getUserById(userId: userId) {
            user.shareLocation = false
            user.location = nil
            UserDataModel.shared.updateUser(user)
            print("Updated local user to disable location sharing")
            
            // Also update location sharing setting in Supabase
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
            nameField.resignFirstResponder() // Dismiss the keyboard
            guard let nameText = nameField.text, !nameText.isEmpty else { return }
            
            guard let userId = SessionManager.shared.getUserId() else {
                print("No user ID found for name update")
                return
            }
            
            // Check if user exists in the data model
            if var user = UserDataModel.shared.getUserById(userId: userId) {
                user.name = nameText
                UserDataModel.shared.updateUser(user)
                print("Updated local user name to: \(nameText)")
                
                // Also update the name in Supabase
                updateUserNameInSupabase(userId: userId, name: nameText)
            }
            
            editName.setTitle("Edit", for: .normal)
        }
    }
    
    private func updateUserNameInSupabase(userId: String, name: String) {
        // Show small loading indicator in the edit button
        let originalTitle = editName.title(for: .normal)
        editName.setTitle("Saving...", for: .normal)
        editName.isEnabled = false
        
        // Create a custom method in SupabaseManager to update the user's name
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
        // First try to sign out from Supabase
        SupabaseManager.shared.signOut { [weak self] success in
            guard let self = self else { return }
            
            print("Supabase sign out result: \(success ? "success" : "failed")")
            
            // Whether Supabase sign out succeeds or fails, we'll still clear the local session
            SessionManager.shared.removeSession()
            
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let vc = storyboard.instantiateViewController(withIdentifier: "initialNavigation") as! UINavigationController
            if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
                let window = sceneDelegate.window
                window?.rootViewController = vc
                UIView.transition(with: window!, duration: 0.3, options: [.transitionCurlUp], animations: nil, completion: nil)
            }
        }
    }
    
    
    
    private func updateLocationSharingInSupabase(userId: String, isSharing: Bool) {
        // Create a custom method in SupabaseManager to update the user's location sharing
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
            // Ensure the switch reflects the previous state
            self?.locationSwitch.setOn(false, animated: true)
        }))
        
        alertController.addAction(UIAlertAction(title: "Allow Location", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        self.present(alertController, animated: true, completion: nil)
    }

    // Handle user's response to permission request
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

    // CLLocationManager delegate method to handle location updates
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        
        guard let userId = SessionManager.shared.getUserId() else {
            print("No user ID found for updating location")
            return
        }
        
        print("Received location update: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        // Check if user exists in the data model
        if var user = UserDataModel.shared.getUserById(userId: userId) {
            user.shareLocation = true
            let l = CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            user.location = LocationCoordinate(location: l)
            UserDataModel.shared.updateUser(user)
            print("Updated local user with location")
            
            // Also update location data in Supabase
            updateLocationInSupabase(userId: userId, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        }
        
        locationManager.stopUpdatingLocation()
    }
    
    private func updateLocationInSupabase(userId: String, latitude: Double, longitude: Double) {
        // Create a custom method in SupabaseManager to update the user's location
        SupabaseManager.shared.updateUserLocation(userId: userId, latitude: latitude, longitude: longitude) { success in
            if success {
                print("Successfully updated location in Supabase")
            } else {
                print("Failed to update location in Supabase")
            }
        }
    }

    // Handle error in case of failure to get location
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to get location: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.locationSwitch.setOn(false, animated: true)
        }
    }
    
}
