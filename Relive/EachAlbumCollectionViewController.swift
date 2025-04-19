//
//  EachAlbumCollectionViewController.swift
//  Relive
//
//  Created by Ayush Nimiwal on 10/12/24.
//

import UIKit


class EachAlbumCollectionViewController: UICollectionViewController, UIViewControllerTransitioningDelegate {
    
    
    func createCompositionalLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
            
            let section: NSCollectionLayoutSection
            
            switch sectionIndex {
                
            
            case 0:
                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(0.333),
                    heightDimension: .fractionalHeight(1.0))
                
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                
                item.contentInsets = NSDirectionalEdgeInsets(
                    top: 5,
                    leading: 5,
                    bottom: 5,
                    trailing: 5)
                
                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .fractionalHeight(0.15))
                
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

    var albumId : String?
    var album : SharedAlbum?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        album = SharedAlbumsDataModel.shared.getAlbum(byId: albumId!)
        collectionView.collectionViewLayout = createCompositionalLayout()
    }

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return album!.imagesIds?.count ?? 0
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EachCell", for: indexPath) as! EachAlbumCollectionViewCell
        
        // Reset cell to avoid recycled content
        cell.imageView.image = nil
        cell.pImage.image = nil
        
        guard let album = album, let imageId = album.imagesIds?[indexPath.item] else {
            print("Missing album or image ID at index \(indexPath.item)")
            return cell
        }
        
        // Load image data
        if let imageData = ImageDataModel.shared.getImage(byId: imageId) {
            // Main image
            if let uiImage = UIImage(data: imageData.image) {
                cell.imageView.image = uiImage
                print("Loaded image \(imageId) (\(imageData.image.count) bytes)")
            } else {
                print("Failed to convert data to UIImage for \(imageId)")
                cell.imageView.image = UIImage(systemName: "photo")
            }
            
            // Profile image
            if let user = UserDataModel.shared.getUser(byId: imageData.capturedByUserId),
               let profileImageData = user.profileImages.first,
               let profileImage = UIImage(data: profileImageData) {
                cell.pImage.image = profileImage
            } else {
                cell.pImage.image = UIImage(systemName: "person.crop.circle")
                print("Missing profile image for user \(imageData.capturedByUserId)")
            }
        } else {
            print("Missing image data for ID: \(imageId)")
            cell.imageView.image = UIImage(systemName: "exclamationmark.triangle")
        }
        
        return cell
    }

    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let image = ImageDataModel.shared.getImage(byId: album!.imagesIds![indexPath.item])
        if let image = image?.image, let image = UIImage(data: image) {
            performSegue(withIdentifier: "pppView", sender: image)
        }
        else {return}
    }
   
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "friendCC",
           let navigationController = segue.destination as? UINavigationController,
           let destinationVC = navigationController.topViewController as? FriendListViewController {
            destinationVC.album = album
        }
        
        if segue.identifier == "pppView",
           let dc = segue.destination as? ImageViewController,
           let image = sender as? UIImage {
            dc.image = image
        }
        
        if segue.identifier == "photoCC",
            let dc = segue.destination as? ChoosePhotoCollectionViewController {
            dc.album = album
        }
    }
    
    
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return BottomSheetPresentationController(presentedViewController: presented, presenting: presenting)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        album = SharedAlbumsDataModel.shared.getAlbum(byId: albumId!)
        collectionView.reloadData()
    }
   
}
