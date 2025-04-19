import UIKit
import Photos

class ChoosePhotoCollectionViewController: UICollectionViewController {
    
    var assets: [PHAsset] = []
    var album: SharedAlbum?
    var selectedImagesData: [ImageData] = []

    func createCompositionalLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
            let section: NSCollectionLayoutSection
            switch sectionIndex {
            case 0:
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(0.333),
                    heightDimension: .fractionalHeight(1.0)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                item.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
                
                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .fractionalHeight(0.15)
                )
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                
                section = NSCollectionLayoutSection(group: group)
            default:
                return nil
            }
            return section
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        requestPhotoLibraryAccess()
    }

    private func setupCollectionView() {
        collectionView.collectionViewLayout = createCompositionalLayout()
        collectionView.allowsMultipleSelection = true
        title = "Select Photos"
        
        // Add Done and Cancel buttons to navigation bar
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(doneButtonTapped))
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelButtonTapped))
    }

    // MARK: - Request Photo Library Access
    func requestPhotoLibraryAccess() {
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self.fetchPhotos()
                case .denied, .restricted:
                    self.showPhotoLibraryAccessDeniedAlert()
                case .notDetermined:
                    break
                @unknown default:
                    break
                }
            }
        }
    }

    private func showPhotoLibraryAccessDeniedAlert() {
        let alert = UIAlertController(
            title: "Photo Library Access Denied",
            message: "Please allow photo library access in Settings to select photos.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true, completion: nil)
    }

    // MARK: - Fetch Photos
    func fetchPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let fetchedAssets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        assets = []
        fetchedAssets.enumerateObjects { (asset, _, _) in
            self.assets.append(asset)
        }
        
        DispatchQueue.main.async {
            self.collectionView.reloadData()
        }
    }

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return assets.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ChooseCell", for: indexPath) as! ChoosePhotoCollectionViewCell
        let asset = assets[indexPath.item]
        let imageManager = PHImageManager.default()
        let imageSize = CGSize(width: 200, height: 200)
        
        imageManager.requestImage(for: asset, targetSize: imageSize, contentMode: .aspectFill, options: nil) { image, _ in
            DispatchQueue.main.async {
                cell.imageView.image = image
            }
        }
        
        // Restore cell's selection state
        cell.isSelectedForCheckmark = selectedImagesData.contains { $0.imageId == asset.localIdentifier }
        
        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? ChoosePhotoCollectionViewCell else { return }
        
        cell.isSelectedForCheckmark.toggle()
        
        let asset = assets[indexPath.item]
        let imageManager = PHImageManager.default()

        imageManager.requestImageData(for: asset, options: nil) { [weak self] data, _, _, _ in
            guard let self = self, let data = data else { return }
            
            let imageId = asset.localIdentifier
            
            if cell.isSelectedForCheckmark {
                // Add image
                if !self.selectedImagesData.contains(where: { $0.imageId == imageId }) {
                    let locationCoordinate = LocationCoordinate(location: asset.location ?? CLLocation(latitude: 0, longitude: 0))
                    let capturedByUserId = SessionManager.shared.getSession() ?? "unknown_user"
                    let sharedWithUserIds: [String]? = self.album?.sharedWithUserIds

                    let imageData = ImageData(
                        imageId: imageId,
                        image: data,
                        locationCaptured: locationCoordinate,
                        capturedByUserId: capturedByUserId,
                        sharedWithUserIds: sharedWithUserIds
                    )

                    self.selectedImagesData.append(imageData)
                }
            } else {
                // Remove image
                if let index = self.selectedImagesData.firstIndex(where: { $0.imageId == imageId }) {
                    self.selectedImagesData.remove(at: index)
                }
            }
        }
    }
    
    @objc private func doneButtonTapped() {
        guard let album = album else {
            showErrorAlert(message: "Album not found. Please create an album first.")
            return
        }
        
        guard !selectedImagesData.isEmpty else {
            showErrorAlert(message: "Please select at least one photo.")
            return
        }
        
        print("Starting upload of \(selectedImagesData.count) images to album \(album.albumId)")
        
        // Show loading indicator
        let loadingAlert = UIAlertController(title: nil, message: "Uploading photos...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true, completion: nil)
        
        // Initialize imagesIds with existing or empty array
        var localIds = album.imagesIds ?? []
        
        // Add images to local model first
        for imageData in selectedImagesData {
            localIds.append(imageData.imageId)
            ImageDataModel.shared.addImage(imageData)
            print("Added image \(imageData.imageId) to local storage")
        }
        
        // Sync with Supabase - first save images, then update album
        Task {
            do {
                print("Beginning Supabase upload process...")
                
                // Save images to Supabase
                var savedImageIds: [String] = []
                
                for (index, imageData) in selectedImagesData.enumerated() {
                    do {
                        print("Uploading image \(index + 1) of \(selectedImagesData.count)...")
                        
                        let (success, imageId) = try await SupabaseManager.shared.saveImage(
                            imageData: imageData.image,
                            albumId: album.albumId
                        )
                        
                        if success, let imageId = imageId {
                            print("✅ Successfully saved image \(index + 1) with ID: \(imageId)")
                            savedImageIds.append(imageId)
                        } else {
                            print("❌ Failed to save image \(index + 1) - no ID returned")
                        }
                    } catch {
                        print("❌ Error saving image \(index + 1): \(error.localizedDescription)")
                    }
                }
                
                print("Saved \(savedImageIds.count) of \(selectedImagesData.count) images to Supabase")
                
                // Debug: Check if images were saved in the database
                SupabaseManager.shared.debugImageUpload(albumId: album.albumId) { debugInfo in
                    print("Album debug info: \(String(describing: debugInfo))")
                }
                
                if !savedImageIds.isEmpty {
                    print("Updating album with saved image IDs: \(savedImageIds)")
                    
                    // Update the album in Supabase with saved image IDs
                    SupabaseManager.shared.updateAlbumImageIds(albumId: album.albumId, imageIds: savedImageIds) { success in
                        print("Album update result: \(success ? "success" : "failure")")
                        
                        DispatchQueue.main.async {
                            self.dismiss(animated: true) {
                                if success {
                                    // Update local model
                                    if var updatedAlbum = SharedAlbumsDataModel.shared.getAlbum(byId: album.albumId) {
                                        if updatedAlbum.imagesIds == nil {
                                            updatedAlbum.imagesIds = savedImageIds
                                        } else {
                                            // Merge existing and new IDs
                                            let existingIds = Set(updatedAlbum.imagesIds ?? [])
                                            let newIds = Set(savedImageIds)
                                            let combined = Array(existingIds.union(newIds))
                                            updatedAlbum.imagesIds = combined
                                        }
                                        SharedAlbumsDataModel.shared.updateSharedAlbum(updatedAlbum)
                                        print("Updated local album with \(updatedAlbum.imagesIds?.count ?? 0) total images")
                                    }
                                    
                                    // Show success message
                                    let alert = UIAlertController(
                                        title: "Success",
                                        message: "Photos uploaded successfully",
                                        preferredStyle: .alert
                                    )
                                    alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                                        self.navigationController?.popViewController(animated: true)
                                    })
                                    self.present(alert, animated: true)
                                    
                                    // Notify that album has been updated
                                    NotificationCenter.default.post(name: NSNotification.Name("AlbumUpdatedNotification"), object: nil)
                                } else {
                                    self.showErrorAlert(message: "Failed to update album with new photos")
                                }
                            }
                        }
                    }
                } else {
                    // No images were saved successfully
                    DispatchQueue.main.async {
                        self.dismiss(animated: true) {
                            self.showErrorAlert(message: "Failed to upload photos to the server")
                        }
                    }
                }
            } catch {
                print("❌ Error in image upload process: \(error)")
                DispatchQueue.main.async {
                    self.dismiss(animated: true) {
                        self.showErrorAlert(message: "Failed to upload photos: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    @objc private func cancelButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}
