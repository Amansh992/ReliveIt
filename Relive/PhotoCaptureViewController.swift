import UIKit
import AVFoundation
import CoreLocation
import Vision
import UserNotifications

//struct LocationCoordinate {
//    let latitude: Double
//    let longitude: Double
//    
//    init(location: CLLocation) {
//        self.latitude = location.coordinate.latitude
//        self.longitude = location.coordinate.longitude
//    }
//}

class PhotoCaptureViewController: UIViewController, AVCapturePhotoCaptureDelegate, CLLocationManagerDelegate {

    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet weak var switchButton: UIButton!
    @IBOutlet weak var imageView: UIImageView!
    
    private var captureSession: AVCaptureSession!
    private var photoOutput: AVCapturePhotoOutput!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    private var isImageSaved = false

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        imageView.image = nil
        imageView.isHidden = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if !(self.captureSession?.isRunning ?? false) {
                self.captureSession.startRunning()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setButtonsSize()
        setupCamera(position: .back)
        NotificationCenter.default.addObserver(self, selector: #selector(alertDismissed), name: NSNotification.Name("AlertViewControllerDismissed"), object: nil)
        configureLocationManager()
        if !UserDefaults.standard.bool(forKey: "EnableAutoShare") {
            UserDefaults.standard.set(true, forKey: "EnableAutoShare")
        }
        checkAutoShareFriends()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission denied: \(error.localizedDescription)")
            }
        }
    }
    
    @objc func alertDismissed() {
        imageView.image = nil
        imageView.isHidden = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if !(self.captureSession?.isRunning ?? false) {
                self.captureSession.startRunning()
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("AlertViewControllerDismissed"), object: nil)
        locationManager.stopUpdatingLocation()
    }
    
    private func configureLocationManager() {
        if !CLLocationManager.locationServicesEnabled() {
            print("❌ Location services are disabled on device")
            showLocationServicesDisabledAlert()
            return
        }
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        switch locationManager.authorizationStatus {
        case .notDetermined:
            print("ℹ️ Requesting location permission")
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ Location permission already granted")
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            print("❌ Location permission denied or restricted")
            showLocationPermissionAlert()
        default:
            print("ℹ️ Unknown authorization status")
        }
    }
    
    private func showLocationServicesDisabledAlert() {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Location Services Disabled",
                message: "Please enable Location Services in Settings > Privacy > Location Services.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            self.present(alert, animated: true)
        }
    }
    
    private func showLocationPermissionAlert() {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Location Access Required",
                message: "Please enable location services in Settings to save photo locations.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            self.present(alert, animated: true)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            currentLocation = location
            print("📍 Updated location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location manager error: \(error.localizedDescription)")
        if (error as NSError).code == CLError.locationUnknown.rawValue {
            print("ℹ️ Location temporarily unavailable, retrying...")
        } else {
            showLocationPermissionAlert()
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ Location permission granted")
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            print("❌ Location permission denied")
            showLocationPermissionAlert()
        default:
            print("ℹ️ Location permission not determined")
        }
    }
    
    private func setupCamera(position: AVCaptureDevice.Position) {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo
        photoOutput = AVCapturePhotoOutput()
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            print("Camera not available for position: \(position.rawValue)")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) && captureSession.canAddOutput(photoOutput) {
                captureSession.addInput(input)
                captureSession.addOutput(photoOutput)
                
                if previewLayer != nil {
                    previewLayer.removeFromSuperlayer()
                }
                
                previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                previewLayer.videoGravity = .resizeAspectFill
                previewLayer.frame = view.bounds
                view.layer.insertSublayer(previewLayer, at: 0)
                
                captureSession.startRunning()
            } else {
                print("Unable to add input/output to the session")
            }
        } catch {
            print("Error configuring camera input: \(error.localizedDescription)")
        }
    }
    
    func setButtonsSize() {
        let imageView = UIImageView(image: UIImage(systemName: "circle"))
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .lightGray
        imageView.frame = CGRect(x: 0, y: 0, width: 80, height: 80)
        captureButton.addSubview(imageView)
        
        let switchImageView = UIImageView(image: UIImage(systemName: "arrow.trianglehead.2.clockwise.rotate.90.camera"))
        switchImageView.contentMode = .scaleAspectFit
        switchImageView.tintColor = .lightGray
        switchImageView.frame = CGRect(x: 10, y: 10, width: 60, height: 60)
        switchButton.addSubview(switchImageView)
    }
    
    @IBAction func capturePhoto(_ sender: UIButton) {
        locationManager.requestLocation() // Trigger a fresh location update
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    @IBAction func switchCamera(_ sender: Any) {
        guard let session = captureSession, session.isRunning else { return }
        
        session.beginConfiguration()
        
        if let currentInput = session.inputs.first as? AVCaptureDeviceInput {
            session.removeInput(currentInput)
            
            currentCameraPosition = (currentCameraPosition == .back) ? .front : .back
            
            guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition) else {
                print("Failed to switch camera")
                session.commitConfiguration()
                return
            }
            
            do {
                let newInput = try AVCaptureDeviceInput(device: newCamera)
                if session.canAddInput(newInput) {
                    session.addInput(newInput)
                }
            } catch {
                print("Error switching cameras: \(error.localizedDescription)")
            }
        }
        
        session.commitConfiguration()
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let capturedImage = UIImage(data: imageData) else {
            print("Error converting photo data to UIImage")
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.imageView.image = capturedImage
            self.imageView.contentMode = .scaleAspectFit
            self.imageView.isHidden = false

            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.stopRunning()
            }

            Task {
                do {
                    let location = await self.waitForLocation(timeout: 5.0)
                    guard let location = location else {
                        print("❌ Location not available after timeout")
                        DispatchQueue.main.async {
                            self.showLocationPermissionAlert()
                        }
                        return
                    }
                    let locationCoordinate = LocationCoordinate(location: location)
                    print("📸 Saving image with location: \(locationCoordinate.latitude), \(locationCoordinate.longitude)")

                    let albumId = UserDefaults.standard.string(forKey: "AutoShareAlbumId")
                    let currentUserId = SessionManager.shared.getSession() ?? UUID().uuidString
                    let albumName = "Auto-Share Album"

                    let albumIdToUse: String
                    if let existingAlbumId = albumId {
                        let albumExists = try await SupabaseManager.shared.checkAlbumExists(albumId: existingAlbumId)
                        if !albumExists {
                            try await self.createAutoShareAlbum(albumId: existingAlbumId, userId: currentUserId, albumName: albumName)
                        }
                        albumIdToUse = existingAlbumId
                    } else {
                        let newAlbumId = UUID().uuidString
                        try await self.createAutoShareAlbum(albumId: newAlbumId, userId: currentUserId, albumName: albumName)
                        UserDefaults.standard.set(newAlbumId, forKey: "AutoShareAlbumId")
                        albumIdToUse = newAlbumId
                    }

                    if let imageData = capturedImage.jpegData(compressionQuality: 0.8), !self.isImageSaved {
                        self.isImageSaved = true
                        let (success, imageId) = try await SupabaseManager.shared.saveImage(imageData: imageData, albumId: albumIdToUse)

                        if success, let imageId = imageId {
                            try await self.updateImageLocation(imageId: imageId, latitude: locationCoordinate.latitude, longitude: locationCoordinate.longitude)
                            

                            let autoShareEnabled = UserDefaults.standard.bool(forKey: "EnableAutoShare")
                            let autoShareFriends = UserDefaults.standard.stringArray(forKey: "AutoShareFriends") ?? []

                            let imageDataObj = ImageData(
                                imageId: imageId,
                                image: imageData,
                                locationCaptured: locationCoordinate,
                                capturedByUserId: currentUserId,
                                sharedWithUserIds: autoShareEnabled ? autoShareFriends : [],
                                createdAt: Date()
                            )
                            ImageDataModel.shared.addImage(imageDataObj)

                            if autoShareEnabled && !autoShareFriends.isEmpty {
                                let faceObservations = await self.detectFaces(in: capturedImage)
                                if !faceObservations.isEmpty {
                                    try await SupabaseManager.shared.shareAlbumWithFriends(albumId: albumIdToUse, friendIds: autoShareFriends) { success in
                                        if success {
                                            print("✅ Shared album \(albumIdToUse) with friends: \(autoShareFriends)")
                                        } else {
                                            print("❌ Failed to share album with friends")
                                        }
                                    }
                                }
                            }

                            let storyboard = UIStoryboard(name: "Main", bundle: nil)
                            if let customAlertVC = storyboard.instantiateViewController(withIdentifier: "AlertViewController") as? AlertViewController {
                                customAlertVC.modalPresentationStyle = .overFullScreen
                                customAlertVC.modalTransitionStyle = .crossDissolve

                                var shouldShowAutoSharedFriends = false
                                if autoShareEnabled && !autoShareFriends.isEmpty {
                                    let faceObservations = await self.detectFaces(in: capturedImage)
                                    if !faceObservations.isEmpty {
                                        shouldShowAutoSharedFriends = true
                                    }
                                }

                                DispatchQueue.main.async {
                                    if shouldShowAutoSharedFriends {
                                        customAlertVC.showAutoSharedFriends(friendIds: autoShareFriends)
                                    }
                                    self.present(customAlertVC, animated: true)
                                }
                            }
                        }
                    }
                } catch {
                    print("Error in async operation: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        let alert = UIAlertController(title: "Error", message: "Failed to save image: \(error.localizedDescription)", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
        }
    }
    
    private func waitForLocation(timeout: TimeInterval) async -> CLLocation? {
        guard locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways else {
            print("❌ Location permission not granted")
            return nil
        }
        if let location = currentLocation {
            return location
        }
        for _ in 0..<3 {
            let location = await withCheckedContinuation { continuation in
                DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                    continuation.resume(returning: self.currentLocation)
                }
            }
            if let location = location {
                return location
            }
            print("ℹ️ Retrying location fetch...")
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        print("❌ No location after retries")
        return nil
    }
    
    private func checkAutoShareFriends() {
        if let autoShareFriends = UserDefaults.standard.stringArray(forKey: "AutoShareFriends") {
            print("Auto-share enabled for \(autoShareFriends.count) friends: \(autoShareFriends)")
        } else {
            print("No friends enabled for auto-share, initializing empty list")
            UserDefaults.standard.set([], forKey: "AutoShareFriends")
        }
    }

    private func createAutoShareAlbum(albumId: String, userId: String, albumName: String) async throws {
        let autoShareFriends = UserDefaults.standard.stringArray(forKey: "AutoShareFriends") ?? []
        let album = SharedAlbum(
            albumId: albumId,
            albumName: albumName,
            createdByUserId: userId,
            sharedWithUserIds: autoShareFriends,
            imagesIds: [],
            createdAt: Date()
        )
        
        do {
            try await SupabaseManager.shared.saveSharedAlbum(album: album, images: []) { success in
                if success {
                    print("Successfully created auto-share album")
                } else {
                    print("Failed to create auto-share album in completion")
                }
            }
        } catch {
            print("Failed to create auto-share album: \(error.localizedDescription)")
            throw NSError(domain: "PhotoCaptureViewController", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to create auto-share album"])
        }
    }

    private func updateImageLocation(imageId: String, latitude: Double, longitude: Double) async throws {
        let updateData: [String: AnyCodable] = [
            "latitude": AnyCodable(latitude),
            "longitude": AnyCodable(longitude)
        ]
        _ = try await SupabaseManager.shared.supabase
            .database
            .from("images")
            .update(updateData)
            .eq("image_id", value: imageId)
            .execute()
        print("Updated location for image \(imageId)")
    }

    private func detectFaces(in image: UIImage) async -> [VNFaceObservation] {
        guard let ciImage = CIImage(image: image) else { return [] }
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        do {
            try await handler.perform([request])
            return request.results as? [VNFaceObservation] ?? []
        } catch {
            print("Face detection failed: \(error)")
            return []
        }
    }

    private func processForAutoShare(capturedImage: UIImage) async {
        let autoShareEnabled = UserDefaults.standard.bool(forKey: "EnableAutoShare")
        guard autoShareEnabled else { return }
        
        let autoShareFriends = UserDefaults.standard.stringArray(forKey: "AutoShareFriends") ?? []
        guard !autoShareFriends.isEmpty else { return }
        
        let faceObservations = await detectFaces(in: capturedImage)
        if faceObservations.isEmpty {
            print("No faces detected in image")
            return
        }
        
        await sharePhotoWithFriends(image: capturedImage, friendIds: autoShareFriends)
    }

    private func sharePhotoWithFriends(image: UIImage, friendIds: [String]) async {
        guard let currentUserId = SessionManager.shared.getSession(),
              let imageData = image.jpegData(compressionQuality: 0.8) else { return }

        let autoShareAlbumKey = "AutoShareAlbumId"
        let albumIdToUse: String

        if let existingAlbumId = UserDefaults.standard.string(forKey: autoShareAlbumKey) {
            albumIdToUse = existingAlbumId
        } else {
            let newAlbumId = UUID().uuidString
            let albumName = "Auto-Share"
            let album = SharedAlbum(
                albumId: newAlbumId,
                albumName: albumName,
                createdByUserId: currentUserId,
                sharedWithUserIds: friendIds,
                imagesIds: [],
                createdAt: Date()
            )
            do {
                try await SupabaseManager.shared.saveSharedAlbum(album: album, images: []) { success in
                    if success {
                        UserDefaults.standard.set(newAlbumId, forKey: autoShareAlbumKey)
                        print("Created new Auto-Share album: \(newAlbumId)")
                    }
                }
                albumIdToUse = newAlbumId
            } catch {
                print("Failed to create new Auto-Share album: \(error.localizedDescription)")
                return
            }
        }

        do {
            try await SupabaseManager.shared.shareAlbumWithFriends(albumId: albumIdToUse, friendIds: friendIds) { success in
                if success {
                    print("Successfully shared album \(albumIdToUse) with \(friendIds.count) friends")
                } else {
                    print("Failed to share album with friends")
                }
            }
        } catch {
            print("Error sharing album: \(error.localizedDescription)")
        }
    }
}
