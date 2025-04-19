import UIKit
import AVFoundation
import CoreImage

class FaceRegisterViewController: UIViewController, AVCapturePhotoCaptureDelegate {
  


    
    var phoneNo: String?
    var profileImage: Data?
    var name: String?
    
    var captureSession: AVCaptureSession?
    var photoOutput: AVCapturePhotoOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    let circularFrameView: UIView = {
        let frameView = UIView()
        frameView.layer.cornerRadius = 150
        frameView.layer.borderWidth = 2
        frameView.layer.borderColor = UIColor.white.cgColor
        frameView.clipsToBounds = true
        frameView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.3)
        return frameView
    }()
    
    // Status label to provide instructions and feedback to the user
    let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Position your face within the circle"
        label.textAlignment = .center
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        return label
    }()
    
    // Capture button to allow user to take their photo
    let captureButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .white
        button.layer.cornerRadius = 35
        button.layer.borderWidth = 3
        button.layer.borderColor = UIColor.lightGray.cgColor
        return button
    }()
    
    // Continue button reference
    var continueButton: UIButton!
    
    let faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Make sure we have camera usage description in Info.plist
        // NSCameraUsageDescription - "This app needs camera access to capture your profile photo"
        
        navigationItem.title = "Face Registration"
        view.backgroundColor = .black
        
        print("FaceRegisterViewController loaded with phone: \(phoneNo ?? "nil"), name: \(name ?? "nil")")
        print("User ID: \(SessionManager.shared.getUserId() ?? "nil")")
        
        // Check camera permissions first
        checkCameraPermissions()
        
        // Add circular frame view
        self.view.addSubview(circularFrameView)
        circularFrameView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            circularFrameView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            circularFrameView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor, constant: -50),
            circularFrameView.widthAnchor.constraint(equalToConstant: 300),
            circularFrameView.heightAnchor.constraint(equalToConstant: 300)
        ])
        
        // Add status label
        self.view.addSubview(statusLabel)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: circularFrameView.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            statusLabel.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // Add capture button
        self.view.addSubview(captureButton)
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 30),
            captureButton.widthAnchor.constraint(equalToConstant: 70),
            captureButton.heightAnchor.constraint(equalToConstant: 70)
        ])
        captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        
        #if targetEnvironment(simulator)
            // For simulator, just add a placeholder image
            setupPlaceholderImage()
        #else
            // Setup the camera in viewDidAppear to ensure permissions are checked first
            // Don't set up the camera here
        #endif
        
        // Add continue button - fixing this part
        continueButton = UIButton(type: .system)
        continueButton.setTitle("Continue", for: .normal)
        continueButton.setTitleColor(.white, for: .normal)
        continueButton.backgroundColor = UIColor(red: 0.4, green: 0.6, blue: 0.9, alpha: 1.0)
        continueButton.layer.cornerRadius = 8
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(continueButton)
        
        NSLayoutConstraint.activate([
            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            continueButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // Fix: Use the correct selector name to match what's expected
        continueButton.addTarget(self, action: #selector(continueButton(_:)), for: .touchUpInside)
    }
    
    private func checkCameraPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // Directly setup camera on main thread
            DispatchQueue.main.async {
                self.setupCamera()
            }
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCamera()
                    } else {
                        self?.showCameraPermissionAlert()
                    }
                }
            }
            
        case .denied, .restricted:
            showCameraPermissionAlert()
            
        @unknown default:
            break
        }
    }
    
    
    private func showCameraPermissionAlert() {
        let alert = UIAlertController(
            title: "Camera Access",
            message: "Camera access is required to complete registration. Please enable camera access in Settings.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        #if targetEnvironment(simulator)
            // Skip camera setup in simulator
        #else
            // Setup camera if we have permission
            if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
                if captureSession == nil {
                    setupCamera()
                } else if !captureSession!.isRunning {
                    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                        self?.captureSession?.startRunning()
                    }
                }
            }
        #endif
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Stop the capture session when the view disappears
        if let captureSession = captureSession, captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    #if targetEnvironment(simulator)
    func setupPlaceholderImage() {
        // Add a placeholder image to the circular frame
        let placeholderView = UIImageView(image: UIImage(named: "person.circle.fill") ?? UIImage(systemName: "person.circle.fill"))
        placeholderView.contentMode = .scaleAspectFill
        placeholderView.clipsToBounds = true
        placeholderView.translatesAutoresizingMaskIntoConstraints = false
        
        circularFrameView.addSubview(placeholderView)
        
        NSLayoutConstraint.activate([
            placeholderView.topAnchor.constraint(equalTo: circularFrameView.topAnchor),
            placeholderView.leadingAnchor.constraint(equalTo: circularFrameView.leadingAnchor),
            placeholderView.trailingAnchor.constraint(equalTo: circularFrameView.trailingAnchor),
            placeholderView.bottomAnchor.constraint(equalTo: circularFrameView.bottomAnchor)
        ])
        
        // Generate placeholder image for simulator testing
        if let image = UIImage(systemName: "person.circle.fill"),
           let imageData = image.jpegData(compressionQuality: 0.8) {
            profileImage = imageData
        } else {
            // Create a placeholder image if SF Symbols aren't available
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 300))
            let placeholderImage = renderer.image { ctx in
                UIColor.systemGray.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 300, height: 300))
            }
            
            profileImage = placeholderImage.jpegData(compressionQuality: 0.8)
        }
        
        statusLabel.text = "Placeholder image is ready (Simulator)"
    }
    #endif
    
    func setupCamera() {
        print("🔍 Starting setupCamera method")
        
        // Ensure this is called on the main thread
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.setupCamera()
                return
            }
            return
        }

        // Create a new capture session
        captureSession = AVCaptureSession()
        
        guard let captureSession = captureSession else {
            print("❌ Failed to create capture session")
            showAlert(message: "Unable to initialize camera")
            return
        }
        
        captureSession.beginConfiguration()
        
        // Set quality level
        if captureSession.canSetSessionPreset(.photo) {
            captureSession.sessionPreset = .photo
            print("✅ Set session preset to photo")
        } else {
            print("❌ Cannot set photo preset")
        }
        
        // Detailed camera device selection
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .builtInTelephotoCamera,
            .builtInUltraWideCamera
        ]
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .front
        )
        
        guard let frontCamera = discoverySession.devices.first else {
            print("❌ No front camera found")
            showAlert(message: "No front camera available")
            captureSession.commitConfiguration()
            return
        }
        
        print("✅ Front camera found: \(frontCamera.localizedName)")
        
        do {
            let input = try AVCaptureDeviceInput(device: frontCamera)
            
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                print("✅ Added input successfully")
            } else {
                print("❌ Cannot add input to capture session")
                showAlert(message: "Cannot configure camera input")
            }
            
            photoOutput = AVCapturePhotoOutput()
            
            if let photoOutput = photoOutput, captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
                print("✅ Added photo output successfully")
            } else {
                print("❌ Cannot add photo output")
                showAlert(message: "Cannot configure photo output")
            }
            
            captureSession.commitConfiguration()
            
            // Setup preview layer
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            guard let previewLayer = previewLayer else {
                print("❌ Failed to create preview layer")
                return
            }
            
            previewLayer.frame = circularFrameView.bounds
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.connection?.videoOrientation = .portrait
            
            // Remove any existing preview layers
            circularFrameView.layer.sublayers?.forEach {
                if $0 is AVCaptureVideoPreviewLayer {
                    $0.removeFromSuperlayer()
                }
            }
            
            circularFrameView.layer.addSublayer(previewLayer)
            
            // Start capture session
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                print("🔍 Starting capture session")
                self?.captureSession?.startRunning()
                
                DispatchQueue.main.async {
                    print("✅ Capture session started")
                    self?.statusLabel.text = "Camera ready. Position your face within the circle."
                }
            }
            
        } catch {
            print("❌ Error setting up camera: \(error.localizedDescription)")
            showAlert(message: "Unable to setup camera: \(error.localizedDescription)")
        }
    }
    
    @objc func capturePhoto() {
        print("Capture photo button tapped")
        
        guard let photoOutput = photoOutput, captureSession?.isRunning == true else {
            // For simulator or when camera is not available
            if profileImage == nil {
                showAlert(message: "Unable to capture photo. Please try again.")
            } else {
                showAlert(message: "Photo captured successfully!")
            }
            return
        }
        
        // Flash the capture button to give visual feedback
        UIView.animate(withDuration: 0.1, animations: {
            self.captureButton.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            self.captureButton.backgroundColor = UIColor.systemBlue
        }) { (_) in
            UIView.animate(withDuration: 0.1) {
                self.captureButton.transform = CGAffineTransform.identity
                self.captureButton.backgroundColor = UIColor.white
            }
        }
        
        // Update status
        statusLabel.text = "Capturing photo..."
        
        print("Configuring photo settings")
        let settings = AVCapturePhotoSettings()
        
        // Check if high resolution is supported
        if photoOutput.isHighResolutionCaptureEnabled {
            settings.isHighResolutionPhotoEnabled = true
            print("High resolution capture enabled")
        }
        
        print("Capturing photo with settings")
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            statusLabel.text = "Error capturing photo"
            print("Error capturing photo: \(error.localizedDescription)")
            showAlert(message: "Failed to capture photo: \(error.localizedDescription)")
            return
        }
        
        print("Photo captured successfully")
        
        guard let imageData = photo.fileDataRepresentation() else {
            statusLabel.text = "Failed to get image data"
            print("Failed to get image data from captured photo")
            showAlert(message: "Failed to get image data from capture.")
            return
        }
        
        print("Got image data, size: \(imageData.count) bytes")
        
        guard let image = UIImage(data: imageData) else {
            statusLabel.text = "Failed to create image"
            print("Failed to create UIImage from image data")
            showAlert(message: "Failed to process the captured photo.")
            return
        }
        
        // Process the image to ensure it's a good size for storage and facial recognition
        if let processedImageData = processImageForUpload(image) {
            self.profileImage = processedImageData
            print("Image processed successfully, size: \(processedImageData.count) bytes")
            
            // Update UI to show the captured image
            displayCapturedImage(image)
            
            statusLabel.text = "Photo captured successfully!"
        } else {
            statusLabel.text = "Failed to process photo"
            print("Failed to process image for upload")
            showAlert(message: "Failed to process the captured photo.")
        }
    }
    func checkAndSetupCamera() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCamera()
                    } else {
                        self?.showCameraPermissionAlert()
                    }
                }
            }
        case .denied, .restricted:
            showCameraPermissionAlert()
        @unknown default:
            break
        }
    }
    
    private func processImageForUpload(_ image: UIImage) -> Data? {
        // Resize the image to a reasonable size for facial recognition (600x600 pixels max)
        let maxSize: CGFloat = 600
        var newSize = CGSize(width: image.size.width, height: image.size.height)
        
        if image.size.width > maxSize || image.size.height > maxSize {
            if image.size.width > image.size.height {
                newSize = CGSize(width: maxSize, height: image.size.height * (maxSize / image.size.width))
            } else {
                newSize = CGSize(width: image.size.width * (maxSize / image.size.height), height: maxSize)
            }
        }
        
        print("Resizing image from \(image.size) to \(newSize)")
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // Compress to JPEG with 80% quality for good balance of size and quality
        return resizedImage?.jpegData(compressionQuality: 0.8)
    }
    
    private func displayCapturedImage(_ image: UIImage) {
        // Stop the capture session since we have our photo
        captureSession?.stopRunning()
        
        // Remove the preview layer
        previewLayer?.removeFromSuperlayer()
        
        print("Displaying captured image")
        
        // Create an image view to display the captured photo
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Clear the circular frame view and add the image view
        circularFrameView.subviews.forEach { $0.removeFromSuperview() }
        circularFrameView.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: circularFrameView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: circularFrameView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: circularFrameView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: circularFrameView.bottomAnchor)
        ])
        
        // Update the capture button to be a "retake" button
        captureButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.8)
        captureButton.setTitle("↺", for: .normal)
        captureButton.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        captureButton.setTitleColor(.white, for: .normal)
    }
    
    // Fix: Renamed method to match the expected selector
    @objc func continueButton(_ sender: UIButton) {
        print("Continue button tapped")
        
        guard let profileImage = self.profileImage else {
            showAlert(message: "Please capture your profile image before continuing.")
            return
        }
        
        // Get properly unwrapped values for name and phone number
        guard let nameStr = name, !nameStr.isEmpty else {
            showAlert(message: "Missing name information.")
            return
        }
        
        guard let phoneStr = phoneNo, !phoneStr.isEmpty else {
            showAlert(message: "Missing phone number information.")
            return
        }
        
        // Get user ID or create a fallback
        let userId = SessionManager.shared.getUserId() ?? "user\(Int(Date().timeIntervalSince1970))"
        print("Using userId: \(userId) for profile image upload")
        
        // Update status and show loading indicator
        statusLabel.text = "Saving profile..."
        showLoadingIndicator()
        
        // Upload the face image to Supabase storage
        uploadProfileImageToSupabase(profileImage: profileImage, userId: userId) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                print("Profile image upload complete with result: \(result)")
                
                switch result {
                case .success(let profileImageUrl):
                    // Now that we have the image URL, update the user in Supabase
                    self.updateUserWithProfileImage(userId: userId, imageUrl: profileImageUrl)
                    
                case .failure(let error):
                    self.hideLoadingIndicator()
                    self.statusLabel.text = "Failed to upload image"
                    print("Failed to upload profile image: \(error.localizedDescription)")
                    self.showAlert(message: "Failed to upload profile image: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func uploadProfileImageToSupabase(profileImage: Data, userId: String, completion: @escaping (Result<String, Error>) -> Void) {
        print("Starting Supabase upload for user: \(userId), image size: \(profileImage.count) bytes")
        
        // Use the SupabaseManager to upload the image
        SupabaseManager.shared.uploadProfileImage(imageData: profileImage, userId: userId, completion: completion)
    }
    
    private func updateUserWithProfileImage(userId: String, imageUrl: String) {
        print("Updating user profile with image URL and marking registration complete: \(imageUrl)")
        
        // Use the updated method that sets registration_complete to true
        SupabaseManager.shared.updateUserWithProfileComplete(userId: userId, profileImageUrl: imageUrl) { [weak self] success in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.hideLoadingIndicator()
                
                if success {
                    print("User profile updated successfully and registration marked complete, navigating to main app")
                    self.navigateToMainApp()
                } else {
                    print("Failed to update user profile and registration status")
                    self.showAlert(message: "Failed to update user profile. Please try again.")
                }
            }
        }
    }
    
    func navigateToMainApp() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let tabBarController = storyboard.instantiateViewController(withIdentifier: "tabbar") as? UITabBarController {
            tabBarController.modalPresentationStyle = .fullScreen
            present(tabBarController, animated: true)
        } else {
            showAlert(message: "Error navigating to the main app. Please restart the app.")
        }
    }
    
    // MARK: - Helper Methods
    
    private var activityIndicator: UIActivityIndicatorView?
    
    private func showLoadingIndicator() {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.startAnimating()
        indicator.center = view.center
        indicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(indicator)
        
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        activityIndicator = indicator
        
        // Add semi-transparent overlay
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(overlay, belowSubview: indicator)
        
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        overlay.tag = 999
    }
    
    private func hideLoadingIndicator() {
        activityIndicator?.removeFromSuperview()
        activityIndicator = nil
        
        if let overlay = view.viewWithTag(999) {
            overlay.removeFromSuperview()
        }
    }
    
    func showAlert(message: String) {
        let alert = UIAlertController(
            title: "Notice",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
