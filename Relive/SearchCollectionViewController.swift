//
//  SearchCollectionViewController.swift
//  Relive
//
//  Created by Ayush Nimiwal on 09/12/24.
//

import UIKit

private let headerReuseIdentifier = "Header"
private let imageCellIdentifier = "RecentCell"

class SearchCollectionViewController: UICollectionViewController, AlertViewCellDelegate, UISearchBarDelegate {
    
    func didTapViewButton(in cell: RecentCollectionViewCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else { return }
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let customAlertVC = storyboard.instantiateViewController(withIdentifier: "AlertViewController") as? AlertViewController else {
            return
        }
        
        let image = images[indexPath.row]
        let userIds = image.sharedWithUserIds
        let users = userIds?.compactMap({ UserDataModel.shared.getUser(byId: $0) })
        
        customAlertVC.users = users
        customAlertVC.isSelectionEnabled = false
        customAlertVC.modalPresentationStyle = .overFullScreen
        customAlertVC.modalTransitionStyle = .crossDissolve
        self.present(customAlertVC, animated: true)
    }
    
    func createCompositionalLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(0.333),
                heightDimension: .fractionalHeight(1.0))
            
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5)
            
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .fractionalHeight(0.15))
            
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            
            // Increase header height to accommodate both search bar and "Recent" label
            let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(80))
            let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
            
            section.boundarySupplementaryItems = [header]
            return section
        }
    }

    var images: [ImageData] = [] // Search results
    var allImages: [ImageData] = [] // All available images
    var isSearched: Bool = false // Flag to track if search was performed
    
    var searchBar: UISearchBar?
    var recentLabel: UILabel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Load all images but don't display anything yet
        loadAllImages()
        
        collectionView.collectionViewLayout = createCompositionalLayout()
        collectionView.register(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: headerReuseIdentifier)
    }
    
    private func loadAllImages() {
        guard let userId = SessionManager.shared.getSession() else { return }
        
        // Load user's images and shared images
        let userImages = ImageDataModel.shared.getImagesCapturedBy(userId: userId)
        let sharedImages = ImageDataModel.shared.getImagesSharedWith(userId: userId)
        allImages = userImages + sharedImages
        
        // Start with an empty display
        images = []
        isSearched = false
        
        collectionView.reloadData()
    }
    
    // This function is called when search button on keyboard is pressed
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder() // Hide keyboard
        
        performSearch(with: searchBar.text ?? "")
    }
    
    // This function is called when cancel button is clicked
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.resignFirstResponder()
        
        // Reset to show no results
        images = []
        isSearched = false
        updateRecentLabel()
        collectionView.reloadData()
    }
    
    private func updateRecentLabel() {
        recentLabel?.isHidden = !isSearched
    }
    
    // Perform the actual search
    private func performSearch(with searchText: String) {
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedSearchText.isEmpty {
            // If search text is empty, show no results
            images = []
            isSearched = false
        } else {
            // Filter based on search text
            let lowercasedSearchText = trimmedSearchText.lowercased()
            
            images = allImages.filter { image in
                // Check creator name
                if let creator = UserDataModel.shared.getUser(byId: image.capturedByUserId),
                   creator.name.lowercased().contains(lowercasedSearchText) {
                    return true
                }
                
                // Check shared users
                if let sharedUserIds = image.sharedWithUserIds {
                    for userId in sharedUserIds {
                        if let user = UserDataModel.shared.getUser(byId: userId),
                           user.name.lowercased().contains(lowercasedSearchText) {
                            return true
                        }
                    }
                }
                
                return false
            }
            
            isSearched = true
        }
        
        updateRecentLabel()
        collectionView.reloadData()
    }

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let image = images[indexPath.row]
        let uiimage = UIImage(data: image.image)
        performSegue(withIdentifier: "ppView", sender: uiimage)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ppView", let dc = segue.destination as? ImageViewController, let image = sender as? UIImage {
            dc.image = image
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: imageCellIdentifier, for: indexPath) as! RecentCollectionViewCell
        
        guard indexPath.row < images.count else {
            return cell
        }
        
        let imageData = images[indexPath.row]
        
        // Configure cell with image
        if let uiImage = UIImage(data: imageData.image) {
            cell.image.image = uiImage
        } else {
            cell.image.image = UIImage(systemName: "photo")
        }
        
        // Configure profile images
        let user1 = UserDataModel.shared.getUser(byId: imageData.sharedWithUserIds?.first ?? "")
        let user2 = UserDataModel.shared.getUser(byId: imageData.sharedWithUserIds?.last ?? "")
        
        if let p1Image = user1?.profileImages.first {
            cell.p1Image.image = UIImage(data: p1Image)
        } else {
            cell.p1Image.image = UIImage(systemName: "person.circle")
        }
        
        if let p2Image = user2?.profileImages.first {
            cell.p2Image.image = UIImage(data: p2Image)
        } else {
            cell.p2Image.image = UIImage(systemName: "person.circle")
        }
        
        cell.delegate = self
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: headerReuseIdentifier, for: indexPath)
            header.subviews.forEach { $0.removeFromSuperview() }
            
            // Create and configure the search bar
            searchBar = UISearchBar(frame: CGRect(x: 0, y: 0, width: header.frame.width, height: 44))
            searchBar?.placeholder = "Search by name..."
            searchBar?.delegate = self
            searchBar?.showsCancelButton = true
            searchBar?.searchTextField.enablesReturnKeyAutomatically = true
            header.addSubview(searchBar!)
            
            // Create "Recent" label - initially hidden
            recentLabel = UILabel(frame: CGRect(x: 15, y: 44, width: header.frame.width - 30, height: 30))
            recentLabel?.text = "Recent"
            recentLabel?.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
            recentLabel?.textColor = .black
            recentLabel?.isHidden = !isSearched
            header.addSubview(recentLabel!)
            
            return header
        }
        return UICollectionReusableView()
    }
}
