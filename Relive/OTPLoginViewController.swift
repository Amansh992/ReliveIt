//
   //  OTPLoginViewController.swift
   //  Relive
   //

   import UIKit

   class OTPLoginViewController: UIViewController {
       
       // MARK: - Outlets
       @IBOutlet weak var titleLabel: UILabel!
       @IBOutlet weak var subtitleLabel: UILabel!
       
       @IBOutlet weak var phoneNumberContainerView: UIView!
       @IBOutlet weak var phoneCodeTextField: UITextField!
       @IBOutlet weak var phoneNumberTextField: UITextField!
       
       @IBOutlet weak var sendCodeButton: UIButton!
       
       @IBOutlet weak var otpContainerView: UIView!
       @IBOutlet weak var otpTextField: UITextField!
       @IBOutlet weak var verifyOTPButton: UIButton!
       
       // MARK: - Properties
       var email: String?
       private var isOTPSent = false
       private var currentEmail: String = ""
       
       var prefillEmail: String? {
           didSet {
               if let email = prefillEmail {
                   processEmail(email)
               }
           }
       }
       
       // MARK: - Lifecycle
       override func viewDidLoad() {
           super.viewDidLoad()
           setupUI()
           setupTextFields()
           setupButtons()
           setupObservers()
           
           // Prefill email if provided
           if let email = prefillEmail ?? self.email {
               processEmail(email)
           }
       }
       
       // MARK: - Setup Methods
       private func setupUI() {
           titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
           titleLabel.text = "Welcome Back"
           
           subtitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
           subtitleLabel.text = "Sign in with your email address"
           subtitleLabel.textColor = .secondaryLabel
           
           otpContainerView.isHidden = true
           
           // Hide phone code field since it's not needed for email
           phoneCodeTextField.isHidden = true
           phoneNumberContainerView.subviews.first?.layoutIfNeeded()
           
           // Center the phoneNumberTextField programmatically
           centerEmailTextField()
       }
       
       private func centerEmailTextField() {
           phoneNumberTextField.translatesAutoresizingMaskIntoConstraints = false
           NSLayoutConstraint.activate([
               phoneNumberTextField.centerXAnchor.constraint(equalTo: phoneNumberContainerView.centerXAnchor),
               phoneNumberTextField.topAnchor.constraint(equalTo: phoneNumberContainerView.topAnchor, constant: 10), // Adjust top offset
               phoneNumberTextField.widthAnchor.constraint(equalTo: phoneNumberContainerView.widthAnchor, multiplier: 0.8),
               phoneNumberTextField.heightAnchor.constraint(equalToConstant: 44)
           ])
           
           // Ensure container is centered and has proper height
           phoneNumberContainerView.translatesAutoresizingMaskIntoConstraints = false
           NSLayoutConstraint.activate([
               phoneNumberContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
               phoneNumberContainerView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50), // Adjust vertical position
               phoneNumberContainerView.widthAnchor.constraint(equalToConstant: 320),
               phoneNumberContainerView.heightAnchor.constraint(equalToConstant: 64) // Enough height for text field + padding
           ])
       }
       
       private func setupTextFields() {
           phoneNumberTextField.keyboardType = .emailAddress
           phoneNumberTextField.placeholder = "Email Address"
           phoneNumberTextField.autocapitalizationType = .none
           phoneNumberTextField.delegate = self
           
           otpTextField.keyboardType = .numberPad
           otpTextField.placeholder = "Enter 6-digit Code"
           otpTextField.delegate = self
       }
       
       private func setupButtons() {
           [sendCodeButton, verifyOTPButton].forEach {
               $0?.layer.cornerRadius = 8
               $0?.clipsToBounds = true
               updateButtonAppearance($0!, isEnabled: false)
           }
       }
       
       private func setupObservers() {
           phoneNumberTextField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
           otpTextField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
       }
       
       // MARK: - Email Pre-filling
       private func processEmail(_ email: String) {
           let cleanedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
           phoneNumberTextField.text = cleanedEmail
           textFieldDidChange(phoneNumberTextField)
       }
       
       // MARK: - Button Appearance
       private func updateButtonAppearance(_ button: UIButton, isEnabled: Bool) {
           button.isEnabled = isEnabled
           button.backgroundColor = isEnabled ? .systemBlue : .gray
           button.setTitleColor(.white, for: .normal)
           button.alpha = isEnabled ? 1.0 : 0.6
       }
       
       // MARK: - Alerts
       private func showAlert(title: String = "Notice", message: String) {
           let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
           alertController.addAction(UIAlertAction(title: "OK", style: .default))
           present(alertController, animated: true)
       }
       
       @IBAction func sendCodeTapped(_ sender: UIButton) {
           showLoadingIndicator(on: sendCodeButton)
           
           let email = phoneNumberTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
           currentEmail = email
           
           guard isValidEmail(email) else {
               hideLoadingIndicator(on: sendCodeButton, title: "Send Code")
               showAlert(title: "Invalid Email", message: "Please enter a valid email address.")
               return
           }
           
           print("Sending OTP to email: \(email)")
           
           // Use Supabase to send OTP
           SupabaseManager.shared.sendOTP(email: email) { [weak self] result in
               DispatchQueue.main.async {
                   guard let self = self else { return }
                   
                   self.hideLoadingIndicator(on: self.sendCodeButton, title: "Send Code")
                   
                   switch result {
                   case .success():
                       print("OTP sent successfully via Supabase")
                       // Show OTP entry field
                       self.otpContainerView.isHidden = false
                       self.otpTextField.becomeFirstResponder()
                       self.isOTPSent = true
                       
                       // Show message about OTP
                       self.showAlert(title: "Verification Code Sent", message: "A verification code has been sent to your email address. If you don't receive it within a minute, check your email address or try again.")
                       
                   case .failure(let error):
                       print("Failed to send OTP via Supabase: \(error.localizedDescription)")
                       self.showAlert(title: "OTP Error", message: "Failed to send verification code. Please check your email address and try again.")
                   }
               }
           }
       }
       
       @IBAction func verifyOTPTapped(_ sender: UIButton) {
           showLoadingIndicator(on: verifyOTPButton)
           
           let enteredOTP = otpTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
           
           guard enteredOTP.count == 6 else {
               hideLoadingIndicator(on: verifyOTPButton, title: "Verify")
               showAlert(title: "Invalid OTP", message: "Please enter a 6-digit verification code.")
               return
           }
           
           print("Verifying OTP: \(enteredOTP) for email: \(currentEmail)")
           
           // Use Supabase to verify OTP
           SupabaseManager.shared.verifyOTP(email: currentEmail, otp: enteredOTP, name: nil, phone: nil) { [weak self] result in
               guard let self = self else { return }
               
               DispatchQueue.main.async {
                   self.hideLoadingIndicator(on: self.verifyOTPButton, title: "Verify")
                   
                   switch result {
                   case .success(let authUser):
                       print("Successfully verified user: \(authUser.userId)")
                       
                       // Try to find the user in database by email
                       SupabaseManager.shared.findUserByEmail(email: self.currentEmail) { findResult in
                           DispatchQueue.main.async {
                               switch findResult {
                               case .success(let dbUser):
                                   if let dbUser = dbUser {
                                       // User found in database
                                       print("Found user in database with ID: \(dbUser.userId), email: \(dbUser.email ?? "N/A")")
                                       
                                       // Save session with DB user ID
                                       SessionManager.shared.saveSession(userId: dbUser.userId)
                                       
                                       // Update local data model
                                       UserDataModel.shared.updateUser(dbUser)
                                       
                                       // Check if profile image URL exists
                                       if let profileImageUrl = dbUser.profileImageUrl, !profileImageUrl.isEmpty {
                                           print("User has a profile image URL, going to main app")
                                           self.navigateToMainApp()
                                       } else {
                                           print("User doesn't have a profile image URL, checking for face registration")
                                           if self.storyboardHasViewController(withIdentifier: "FaceRegisterViewController") {
                                               self.navigateToFaceRegistration(userId: dbUser.userId, name: dbUser.name, phone: dbUser.phoneNumber)
                                           } else {
                                               print("FaceRegisterViewController not found, going to main app")
                                               self.navigateToMainApp()
                                           }
                                       }
                                   } else {
                                       // No user found in database, redirect to registration
                                       print("User authenticated but not found in database")
                                       self.showRegistrationPrompt(forEmail: self.currentEmail)
                                   }
                               case .failure(let error):
                                   // Error finding user, redirect to registration
                                   print("Error finding user: \(error)")
                                   self.showRegistrationPrompt(forEmail: self.currentEmail)
                               }
                           }
                       }
                       
                   case .failure(let error):
                       print("Verification failed with error: \(error.localizedDescription)")
                       
                       // Check if we need to resend the OTP
                       if error.localizedDescription.contains("expired") ||
                          error.localizedDescription.contains("invalid") {
                           self.showResendOTPAlert()
                       } else {
                           self.showAlert(title: "Verification Failed", message: "Invalid verification code. Please try again.")
                       }
                   }
               }
           }
       }
       
       // Helper method to safely check if a view controller exists in storyboard
       private func storyboardHasViewController(withIdentifier id: String) -> Bool {
           do {
               _ = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: id)
               return true
           } catch {
               return false
           }
       }
       
       // Handle registration redirect
       private func showRegistrationPrompt(forEmail email: String) {
           let alert = UIAlertController(
               title: "Account Not Found",
               message: "No account found with this email address. Would you like to register?",
               preferredStyle: .alert
           )
           
           alert.addAction(UIAlertAction(title: "Register", style: .default) { [weak self] _ in
               self?.navigateToRegistrationFlow(withEmail: email)
           })
           
           alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
           
           present(alert, animated: true)
       }
       
       // Navigate to registration flow
       private func navigateToRegistrationFlow(withEmail email: String) {
           dismiss(animated: true) {
               if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootVC = window.rootViewController,
                  let navController = rootVC as? UINavigationController {
                   
                   navController.popToRootViewController(animated: false)
                   
                   if let initialVC = navController.viewControllers.first as? ViewController {
                       initialVC.emailTextField?.text = email
                       initialVC.nameText?.becomeFirstResponder()
                   }
               }
           }
       }
       
       // Navigate to face registration
       private func navigateToFaceRegistration(userId: String, name: String, phone: String) {
           do {
               let storyboard = UIStoryboard(name: "Main", bundle: nil)
               
               if let faceVC = storyboard.instantiateViewController(withIdentifier: "FaceRegisterViewController") as? FaceRegisterViewController {
                   faceVC.name = name
                   faceVC.phoneNo = phone
                   faceVC.modalPresentationStyle = .fullScreen
                   self.present(faceVC, animated: true)
               } else {
                   print("FaceRegisterViewController not found or not properly cast")
                   navigateToMainApp()
               }
           } catch {
               print("Error getting FaceRegisterViewController: \(error)")
               navigateToMainApp()
           }
       }
       
       private func showResendOTPAlert() {
           let alert = UIAlertController(
               title: "Code Expired",
               message: "Your verification code has expired. Would you like to request a new one?",
               preferredStyle: .alert
           )
           
           alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
           alert.addAction(UIAlertAction(title: "Send New Code", style: .default) { [weak self] _ in
               self?.sendCodeTapped(self?.sendCodeButton ?? UIButton())
           })
           
           present(alert, animated: true)
       }
       
       // MARK: - Navigation
       private func navigateToMainApp() {
           let loadingAlert = UIAlertController(
               title: "Loading Your Data",
               message: "Please wait while we sync your account...",
               preferredStyle: .alert
           )
           
           let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
           loadingIndicator.hidesWhenStopped = true
           loadingIndicator.style = .medium
           loadingIndicator.startAnimating()
           
           loadingAlert.view.addSubview(loadingIndicator)
           present(loadingAlert, animated: true)
           
           guard let userId = SessionManager.shared.getUserId() else {
               loadingAlert.dismiss(animated: true) {
                   self.showAlert(title: "Error", message: "User session not found. Please try again.")
               }
               return
           }
           
           SupabaseManager.shared.syncUserDataAfterLogin(userId: userId) { [weak self] success in
               guard let self = self else { return }
               
               if success {
                   print("Basic user data synchronized successfully")
                   
                   SupabaseManager.shared.syncAllUserContent(userId: userId) { contentSuccess in
                       DispatchQueue.main.async {
                           loadingAlert.dismiss(animated: true) {
                               print("All data sync completed, success: \(contentSuccess)")
                               
                               let storyboard = UIStoryboard(name: "Main", bundle: nil)
                               if let tabBarController = storyboard.instantiateViewController(withIdentifier: "tabbar") as? UITabBarController {
                                   tabBarController.modalPresentationStyle = .fullScreen
                                   
                                   let transition = CATransition()
                                   transition.duration = 0.3
                                   transition.type = CATransitionType.fade
                                   self.view.window?.layer.add(transition, forKey: kCATransition)
                                   
                                   self.present(tabBarController, animated: false)
                               } else {
                                   self.showAlert(title: "Error", message: "Could not navigate to main app. Please restart.")
                               }
                           }
                       }
                   }
               } else {
                   loadingAlert.dismiss(animated: true) {
                       self.showAlert(title: "Sync Error", message: "Could not sync your account data. Please try again.")
                   }
               }
           }
       }
       
       // MARK: - Text Field Change Handler
       @objc private func textFieldDidChange(_ textField: UITextField) {
           let isEmailValid = isValidEmail(phoneNumberTextField.text ?? "")
           updateButtonAppearance(sendCodeButton, isEnabled: isEmailValid && !isOTPSent)
           
           let isOTPValid = otpTextField.text?.count == 6
           updateButtonAppearance(verifyOTPButton, isEnabled: isOTPValid)
       }
       
       // MARK: - Loading Indicator
       private func showLoadingIndicator(on button: UIButton) {
           button.setTitle("", for: .normal)
           let indicator = UIActivityIndicatorView(style: .medium)
           indicator.color = .white
           indicator.tag = 999
           indicator.center = CGPoint(x: button.bounds.width / 2, y: button.bounds.height / 2)
           button.addSubview(indicator)
           indicator.startAnimating()
       }
       
       private func hideLoadingIndicator(on button: UIButton, title: String) {
           button.setTitle(title, for: .normal)
           if let indicator = button.viewWithTag(999) as? UIActivityIndicatorView {
               indicator.stopAnimating()
               indicator.removeFromSuperview()
           }
       }
       
       // MARK: - Email Validation
       private func isValidEmail(_ email: String) -> Bool {
           let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
           let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
           return emailPred.evaluate(with: email)
       }
       
       private func finishLogin(userId: String) {
           SessionManager.shared.saveSession(userId: userId)
           print("Login successful! User ID: \(userId)")
           print("Session saved with 30-day expiry")
           
           let loadingAlert = UIAlertController(
               title: "Loading Your Data",
               message: "Please wait while we sync your account...",
               preferredStyle: .alert
           )
           
           let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
           loadingIndicator.hidesWhenStopped = true
           loadingIndicator.style = .medium
           loadingIndicator.startAnimating()
           
           loadingAlert.view.addSubview(loadingIndicator)
           present(loadingAlert, animated: true)
           
           SupabaseManager.shared.syncUserDataAfterLogin(userId: userId) { [weak self] success in
               guard let self = self else { return }
               
               if success {
                   print("Basic user data synchronized successfully")
                   
                   SupabaseManager.shared.syncAllUserContent(userId: userId) { contentSuccess in
                       DispatchQueue.main.async {
                           loadingAlert.dismiss(animated: true) {
                               print("All data sync completed, success: \(contentSuccess)")
                               
                               SupabaseManager.shared.loginCompletion(userId: userId)
                               
                               self.navigateToMainApp()
                           }
                       }
                   }
               } else {
                   loadingAlert.dismiss(animated: true) {
                       self.showAlert(title: "Sync Error", message: "Could not sync your account data. Please try again.")
                   }
               }
           }
       }
   }

   // MARK: - UITextFieldDelegate
   extension OTPLoginViewController: UITextFieldDelegate {
       func textFieldShouldReturn(_ textField: UITextField) -> Bool {
           textField.resignFirstResponder()
           return true
       }
   }
