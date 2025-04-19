//
//  InitialViewController.swift
//  Relive
//
//  Created by Shivam Dubey on 27/03/25.
//  Modified to integrate with Supabase
//

import UIKit

class InitialViewController: UIViewController {
    
    // Activity indicator for loading state
    private var activityIndicator: UIActivityIndicatorView?

    override func viewDidLoad() {
        super.viewDidLoad()
        if let appleButton = view.viewWithTag(100) as? UIButton {
               appleButton.isHidden = true
           }
        
        // Check if user is already logged in
        checkAuthStatus()
    }
 
    
    private func checkAuthStatus() {
        // Show loading indicator
        showLoadingIndicator()
        
        // First check if we have a stored user ID
        if let userId = UserDefaults.standard.string(forKey: "loggedInUserId") {
            print("Found stored user ID: \(userId)")
            
            // Verify with Supabase that the session is still valid
            SupabaseManager.shared.isSessionValid { isValid in
                self.hideLoadingIndicator()
                
                if isValid {
                    print("Session is valid, proceeding to main app")
                    // Save session using your SessionManager
                    SessionManager.shared.saveSession(userId: userId)
                    self.navigateToMainApp()
                } else {
                    print("Stored session is no longer valid")
                    // Clear stored user ID
                    UserDefaults.standard.removeObject(forKey: "loggedInUserId")
                }
            }
        } else {
            // No stored user ID
            self.hideLoadingIndicator()
            print("No stored user ID found")
        }
    }
    
    @IBAction func registerButtonTapped(_ sender: UIButton) {
        // Prevent multiple instances
        if navigationController?.viewControllers.contains(where: { $0 is ViewController }) == true {
            print("ViewController already in navigation stack")
            return
        }
        
        // Navigate to registration screen
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let registerVC = storyboard.instantiateViewController(withIdentifier: "ViewController") as? ViewController {
            navigationController?.pushViewController(registerVC, animated: true)
        }
    }
    
    @IBAction func continueWithAppleTapped(_ sender: UIButton) {
        // This would be implemented with Supabase's OAuth provider
//        sender.isHidden = true
        
//        showAlert(message: "Apple Sign In will be implemented in a future update.")
    }
    
    @IBAction func signInTapped(_ sender: UIButton) {
        // Check if we already have an OTPLoginViewController in the navigation stack
        if navigationController?.viewControllers.contains(where: { $0 is OTPLoginViewController }) == true {
            print("OTPLoginViewController already in navigation stack")
            return
        }
        
        // Navigate to sign in screen
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let loginVC = storyboard.instantiateViewController(withIdentifier: "OTPLoginViewController") as? OTPLoginViewController {
            navigationController?.pushViewController(loginVC, animated: true)
        }
    }
    
    private func navigateToMainApp() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let tabBarController = storyboard.instantiateViewController(withIdentifier: "tabbar") as? UITabBarController {
                tabBarController.modalPresentationStyle = .fullScreen
                
                // Add transition animation
                let transition = CATransition()
                transition.duration = 0.3
                transition.type = CATransitionType.fade
                view.window?.layer.add(transition, forKey: kCATransition)
                
                present(tabBarController, animated: false, completion: nil)
            }
        }
    }
    
    private func showAlert(title: String = "Notice", message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Loading Indicator
    
    private func showLoadingIndicator() {
        if activityIndicator == nil {
            let indicator = UIActivityIndicatorView(style: .medium)
            indicator.center = view.center
            indicator.hidesWhenStopped = true
            view.addSubview(indicator)
            activityIndicator = indicator
        }
        
        activityIndicator?.startAnimating()
        view.isUserInteractionEnabled = false
    }
    
    private func hideLoadingIndicator() {
        DispatchQueue.main.async { [weak self] in
            self?.activityIndicator?.stopAnimating()
            self?.view.isUserInteractionEnabled = true
        }
    }
}
