import UIKit
import CoreLocation

class VerificationViewController: UIViewController {
    
    var phoneNo: String?
    var email: String?
    var name: String?
    var isSignInFlow: Bool = false
    
    @IBOutlet weak var code: UITextField!
    @IBOutlet weak var verifyButton: UIButton!
    
    private var otpTextFields: [UITextField] = []
    private var currentTextField: UITextField?
    private var instructionLabel: UILabel?
    private var enterCodeLabel: UILabel?
    private var resendButton: UIButton?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        retrieveData()
        code.isHidden = true
        setupUI()
        createOTPTextFields()
        updateButtonState()
        addKeyboardObservers()
    }
    
    private func retrieveData() {
        if let email = email, !email.isEmpty {
            print("Email already set: \(email)")
            return
        }
        
        if let storedEmail = UserDefaults.standard.string(forKey: "TempRegistrationEmail"),
           !storedEmail.isEmpty {
            email = storedEmail
            phoneNo = UserDefaults.standard.string(forKey: "TempRegistrationPhone")
            name = UserDefaults.standard.string(forKey: "TempRegistrationName")
            print("Loaded email from UserDefaults: \(storedEmail)")
            return
        }
        
        if let presentingVC = presentingViewController as? ViewController {
            if let emailText = presentingVC.emailTextField?.text,
               let countryCode = presentingVC.countryCode?.text,
               let phone = presentingVC.phoneno?.text,
               let nameText = presentingVC.nameText?.text {
                
                email = emailText
                let fullPhone = "\(countryCode)\(phone)".replacingOccurrences(of: "\\s|-|\\(|\\)", with: "", options: .regularExpression)
                phoneNo = fullPhone
                name = nameText
                print("Retrieved email from presenting controller: \(emailText)")
                return
            }
        }
        
        print("ERROR: Email is nil or empty in VerificationViewController")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if email == nil || email!.isEmpty {
            let alert = UIAlertController(
                title: "Error",
                message: "Email address is missing. Please go back and try again.",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                self?.navigationController?.popViewController(animated: true)
            })
            
            present(alert, animated: true)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupUI() {
        navigationItem.title = "Verification"
        navigationController?.navigationBar.prefersLargeTitles = false
        
        verifyButton.setTitle("Continue", for: .normal)
        verifyButton.backgroundColor = UIColor(red: 0.4, green: 0.6, blue: 0.9, alpha: 1.0)
        verifyButton.setTitleColor(.white, for: .normal)
        verifyButton.layer.cornerRadius = 8
        verifyButton.clipsToBounds = true
        
        addInstructionLabel()
        addEnterCodeLabel()
        addResendButton()
    }
    
    private func addInstructionLabel() {
        for subview in view.subviews {
            if let label = subview as? UILabel,
               label.text?.contains("verification code sent to") == true {
                instructionLabel = label
                return
            }
        }
        
        let label = UILabel()
        let email = self.email ?? ""
        label.text = "Enter the 6-digit verification code sent to \(email)"
        label.textColor = .gray
        label.font = UIFont.systemFont(ofSize: 16)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
        
        instructionLabel = label
    }
    
    private func addEnterCodeLabel() {
        let label = UILabel()
        label.text = ""
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textColor = .black
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40)
        ])
        
        enterCodeLabel = label
    }
    
    private func addResendButton() {
        let button = UIButton(type: .system)
        button.setTitle("Resend OTP", for: .normal)
        button.setTitleColor(.systemBlue, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(resendOTPTapped), for: .touchUpInside)
        
        view.addSubview(button)
        
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.topAnchor.constraint(equalTo: verifyButton.bottomAnchor, constant: 20)
        ])
        
        resendButton = button
    }
    
    private func adjustContinueButtonPosition() {
        let verticalSpacing: CGFloat = 50
        if let containerView = otpTextFields.first?.superview {
            NSLayoutConstraint.activate([
                verifyButton.topAnchor.constraint(greaterThanOrEqualTo: containerView.bottomAnchor, constant: verticalSpacing)
            ])
        }
    }
    
    private func createOTPTextFields() {
        let digitCount = 6
        let screenWidth = UIScreen.main.bounds.width
        let boxSize: CGFloat = 40
        let spacing: CGFloat = 12
        let totalWidth = (boxSize * CGFloat(digitCount)) + (spacing * CGFloat(digitCount - 1))
        let startX = (screenWidth - totalWidth) / 2
        let yPosition = view.center.y + 20
        
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        var enterCodeView: UIView? = enterCodeLabel
        if enterCodeLabel == nil {
            for subview in view.subviews {
                if let label = subview as? UILabel,
                   label.text?.contains("Enter Code") == true ||
                   label.text?.contains("Enter code") == true {
                    enterCodeView = label
                    break
                }
            }
        }
        
        if let enterCodeView = enterCodeView {
            NSLayoutConstraint.activate([
                containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                containerView.topAnchor.constraint(equalTo: enterCodeView.bottomAnchor, constant: 30),
                containerView.widthAnchor.constraint(equalToConstant: totalWidth),
                containerView.heightAnchor.constraint(equalToConstant: boxSize)
            ])
        } else {
            NSLayoutConstraint.activate([
                containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
                containerView.widthAnchor.constraint(equalToConstant: totalWidth),
                containerView.heightAnchor.constraint(equalToConstant: boxSize)
            ])
        }
        
        for i in 0..<digitCount {
            let textField = UITextField()
            textField.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(textField)
            
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: CGFloat(i) * (boxSize + spacing)),
                textField.topAnchor.constraint(equalTo: containerView.topAnchor),
                textField.widthAnchor.constraint(equalToConstant: boxSize),
                textField.heightAnchor.constraint(equalToConstant: boxSize)
            ])
            
            textField.backgroundColor = .white // Consider using a dynamic color for background
            textField.layer.cornerRadius = 8
            textField.layer.borderWidth = 1.0
            textField.layer.borderColor = UIColor.lightGray.cgColor
            textField.textAlignment = .center
            textField.font = UIFont.systemFont(ofSize: 18, weight: .medium)
            textField.keyboardType = .numberPad
            textField.textContentType = .oneTimeCode
            textField.delegate = self
            textField.tag = i + 1
            
            // Set text color to adapt to light/dark mode
            textField.textColor = UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark ? .white : .black
            }
            
            let placeholder = NSAttributedString(
                string: " ",
                attributes: [NSAttributedString.Key.foregroundColor: UIColor.systemGray3]
            )
            textField.attributedPlaceholder = placeholder
            
            textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
            
            otpTextFields.append(textField)
        }
        
        otpTextFields.first?.becomeFirstResponder()
        
        if verifyButton.translatesAutoresizingMaskIntoConstraints == false {
            adjustContinueButtonPosition()
        }
    }
    
    private func addKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            if self.view.frame.origin.y == 0 {
                self.view.frame.origin.y -= keyboardSize.height / 5
            }
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        if self.view.frame.origin.y != 0 {
            self.view.frame.origin.y = 0
        }
    }
    
    @objc func textFieldDidChange(_ textField: UITextField) {
        if let text = textField.text, text.count > 1 {
            textField.text = String(text.prefix(1))
        }
        
        currentTextField = textField
        let tag = textField.tag
        
        if let text = textField.text, !text.isEmpty {
            if tag < otpTextFields.count {
                otpTextFields[tag].becomeFirstResponder()
            } else {
                textField.resignFirstResponder()
            }
        }
        
        updateOriginalTextField()
        updateButtonState()
    }
    
    private func updateOriginalTextField() {
        code.text = getEnteredOTPCode()
    }
    
    @IBAction func textfield(_ sender: Any) {
        updateButtonState()
    }
    
    func updateButtonState() {
        let allFieldsFilled = otpTextFields.allSatisfy { textField in
            return !(textField.text?.isEmpty ?? true)
        }
        
        updateOriginalTextField()
        
        UIView.animate(withDuration: 0.2) {
            self.verifyButton.isEnabled = allFieldsFilled
            self.verifyButton.alpha = allFieldsFilled ? 1.0 : 0.6
        }
    }
    
    private func getEnteredOTPCode() -> String {
        return otpTextFields.compactMap { $0.text }.joined()
    }
    
    @IBAction func Button(_ sender: UIButton) {
        guard let email = email, !email.isEmpty else {
            print("Email is missing or empty when verifying")
            showAlert(title: "Error", message: "Email address is missing.")
            return
        }
        
        let enteredCode = getEnteredOTPCode()
        print("User entered code: \(enteredCode)")
        
        guard enteredCode.count == 6 else {
            showAlert(title: "Error", message: "Please enter all digits of the verification code.")
            return
        }
        
        showLoadingIndicator()
        
        if isSignInFlow {
            verifyOTPWithSupabase(email: email, enteredCode: enteredCode)
        } else {
            verifyOTPWithSupabase(email: email, enteredCode: enteredCode, name: name, phone: phoneNo, sender: sender)
        }
    }
    
    @objc func resendOTPTapped() {
        guard let email = email, !email.isEmpty else {
            showAlert(title: "Error", message: "Email address is missing.")
            return
        }
        
        resendButton?.isEnabled = false
        showLoadingIndicator(on: resendButton!)
        
        SupabaseManager.shared.sendOTP(email: email) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.hideLoadingIndicator(on: self.resendButton!, title: "Resend OTP")
                self.resendButton?.isEnabled = true
                
                switch result {
                case .success():
                    print("OTP resent successfully to \(email)")
                    self.showAlert(title: "OTP Sent", message: "A new verification code has been sent to your email.")
                    self.clearOTPFields()
                case .failure(let error):
                    print("Failed to resend OTP: \(error.localizedDescription)")
                    self.showAlert(title: "Error", message: "Failed to resend OTP. Please try again.")
                }
            }
        }
    }
    
    private func verifyOTPWithSupabase(email: String, enteredCode: String) {
        SupabaseManager.shared.verifyOTP(email: email, otp: enteredCode, name: nil, phone: nil) { [weak self] result in
            guard let self = self else { return }
            
            let workItem = DispatchWorkItem {
                self.hideLoadingIndicator()
                
                switch result {
                case .success(let user):
                    print("Supabase verification successful for user: \(user.userId)")
                    
                    SupabaseManager.shared.findUserByEmail(email: email) { findResult in
                        switch findResult {
                        case .success(let dbUser):
                            if let dbUser = dbUser {
                                print("Found user in database: \(dbUser.userId)")
                                
                                SessionManager.shared.saveSession(userId: dbUser.userId)
                                
                                if let profileImageUrl = dbUser.profileImageUrl, !profileImageUrl.isEmpty {
                                    print("User has a profile image URL, going to main app")
                                    self.navigateToMainApp()
                                } else {
                                    print("User doesn't have a profile image URL, checking if face registration exists")
                                    
                                    do {
                                        _ = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "FaceRegisterViewController")
                                        print("FaceRegisterViewController exists, navigating to it")
                                        self.navigateToFaceRegistration(userId: dbUser.userId, name: dbUser.name, phone: dbUser.phoneNumber)
                                    } catch {
                                        print("FaceRegisterViewController doesn't exist in storyboard, going to main app")
                                        self.navigateToMainApp()
                                    }
                                }
                            } else {
                                print("User not found in database - need to register")
                                self.showRegistrationNeededAlert(email: email)
                            }
                        case .failure(let error):
                            print("Error checking user in database: \(error)")
                            self.showAlert(title: "Error", message: "Could not verify account. Please try again.")
                        }
                    }
                    
                case .failure(let error):
                    print("Supabase verification failed: \(error.localizedDescription)")
                    if error.localizedDescription.contains("expired") || error.localizedDescription.contains("invalid") {
                        self.showResendOTPAlert()
                    } else {
                        self.showAlert(title: "Verification Failed", message: "Invalid verification code. Please try again or resend OTP.")
                    }
                    self.clearOTPFields()
                }
            }
            
            DispatchQueue.main.async(execute: workItem)
        }
    }
    
    private func showResendOTPAlert() {
        let alert = UIAlertController(
            title: "Invalid or Expired Code",
            message: "The verification code is invalid or has expired. Would you like to resend a new code?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Resend OTP", style: .default) { [weak self] _ in
            self?.resendOTPTapped()
        })
        
        present(alert, animated: true)
    }
    
    private func showRegistrationNeededAlert(email: String) {
        let alert = UIAlertController(
            title: "Registration Required",
            message: "This email is not registered. Would you like to create an account?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Register", style: .default) { [weak self] _ in
            self?.dismiss(animated: true) {
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
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func navigateToFaceRegistration(userId: String, name: String, phone: String) {
        do {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            
            if let faceVC = storyboard.instantiateViewController(withIdentifier: "FaceRegisterViewController") as? FaceRegisterViewController {
                faceVC.name = name
                faceVC.phoneNo = phone
                
                if let navController = self.navigationController {
                    navController.pushViewController(faceVC, animated: true)
                } else {
                    faceVC.modalPresentationStyle = .fullScreen
                    self.present(faceVC, animated: true)
                }
            } else {
                print("Could not cast to FaceRegisterViewController")
                navigateToMainApp()
            }
        } catch {
            print("Error instantiating FaceRegisterViewController: \(error)")
            showAlert(title: "Notice", message: "Your account is being set up. Some features may be limited until setup is complete.")
            navigateToMainApp()
        }
    }
    
    private func verifyOTPWithSupabase(email: String, enteredCode: String, name: String?, phone: String?, sender: UIButton?) {
        SupabaseManager.shared.verifyOTP(email: email, otp: enteredCode, name: name, phone: phone) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.hideLoadingIndicator()
                
                switch result {
                case .success(let user):
                    print("Supabase registration successful for user: \(user.userId)")
                    
                    SessionManager.shared.saveSession(userId: user.userId)
                    
                    if let sender = sender {
                        self.performSegue(withIdentifier: "faceDVC", sender: sender)
                    } else {
                        self.navigateToMainApp()
                    }
                    
                case .failure(let error):
                    print("Supabase registration failed: \(error.localizedDescription)")
                    if error.localizedDescription.contains("expired") || error.localizedDescription.contains("invalid") {
                        self.showResendOTPAlert()
                    } else {
                        self.showAlert(title: "Registration Failed", message: "Failed to register user: \(error.localizedDescription)")
                    }
                    self.clearOTPFields()
                }
            }
        }
    }
    
    private func clearOTPFields() {
        for textField in otpTextFields {
            textField.text = ""
        }
        
        otpTextFields.first?.becomeFirstResponder()
        updateOriginalTextField()
        updateButtonState()
    }
    
    private var activityIndicator: UIActivityIndicatorView?
    
    private func showLoadingIndicator(on button: UIButton? = nil) {
        if let button = button {
            button.setTitle("", for: .normal)
            let indicator = UIActivityIndicatorView(style: .medium)
            indicator.color = .white
            indicator.startAnimating()
            indicator.center = CGPoint(x: button.bounds.midX, y: button.bounds.midY)
            indicator.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(indicator)
            
            NSLayoutConstraint.activate([
                indicator.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                indicator.centerYAnchor.constraint(equalTo: button.centerYAnchor)
            ])
            
            activityIndicator = indicator
            button.isUserInteractionEnabled = false
        } else {
            verifyButton.setTitle("", for: .normal)
            let indicator = UIActivityIndicatorView(style: .medium)
            indicator.color = .white
            indicator.startAnimating()
            indicator.center = CGPoint(x: verifyButton.bounds.midX, y: verifyButton.bounds.midY)
            indicator.translatesAutoresizingMaskIntoConstraints = false
            verifyButton.addSubview(indicator)
            
            NSLayoutConstraint.activate([
                indicator.centerXAnchor.constraint(equalTo: verifyButton.centerXAnchor),
                indicator.centerYAnchor.constraint(equalTo: verifyButton.centerYAnchor)
            ])
            
            activityIndicator = indicator
            verifyButton.isUserInteractionEnabled = false
        }
    }
    
    private func hideLoadingIndicator(on button: UIButton? = nil, title: String? = nil) {
        if let button = button, let title = title {
            button.setTitle(title, for: .normal)
            if let indicator = button.viewWithTag(999) as? UIActivityIndicatorView {
                indicator.stopAnimating()
                indicator.removeFromSuperview()
            }
            button.isUserInteractionEnabled = true
        } else {
            activityIndicator?.removeFromSuperview()
            verifyButton.setTitle("Continue", for: .normal)
            verifyButton.isUserInteractionEnabled = true
        }
    }
    
    func navigateToMainApp() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let tabBarController = storyboard.instantiateViewController(withIdentifier: "tabbar") as? UITabBarController {
            tabBarController.modalPresentationStyle = .fullScreen
            
            let transition = CATransition()
            transition.duration = 0.3
            transition.type = CATransitionType.fade
            view.window?.layer.add(transition, forKey: kCATransition)
            
            present(tabBarController, animated: false, completion: nil)
        }
    }
    
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard segue.identifier == "faceDVC" else { return }
        let faceVC = segue.destination as! FaceRegisterViewController
        faceVC.name = name
        faceVC.phoneNo = phoneNo
    }
}

extension VerificationViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if string.count > 1 {
            handlePastedOTP(string)
            return false
        }
        
        let allowedCharacters = CharacterSet.decimalDigits
        let characterSet = CharacterSet(charactersIn: string)
        if !allowedCharacters.isSuperset(of: characterSet) && string != "" {
            return false
        }
        
        if string.isEmpty && range.length > 0 {
            textField.text = ""
            if textField.tag > 1 {
                moveToPreviousField(before: textField)
            }
            return false
        }
        
        if range.length == 0 && textField.text?.count ?? 0 > 0 {
            textField.text = string
            moveToNextField(after: textField)
            return false
        }
        
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.layer.borderColor = UIColor.systemBlue.cgColor
        textField.layer.borderWidth = 1.5
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.layer.borderColor = UIColor.lightGray.cgColor
        textField.layer.borderWidth = 1.0
    }
    
    private func moveToNextField(after textField: UITextField) {
        let nextTag = textField.tag + 1
        if nextTag <= otpTextFields.count {
            if let nextIndex = otpTextFields.firstIndex(where: { $0.tag == nextTag }) {
                otpTextFields[nextIndex].becomeFirstResponder()
            } else {
                textField.resignFirstResponder()
            }
        } else {
            textField.resignFirstResponder()
        }
        
        updateOriginalTextField()
        updateButtonState()
    }
    
    private func moveToPreviousField(before textField: UITextField) {
        let previousTag = textField.tag - 1
        if previousTag > 0 {
            if let prevIndex = otpTextFields.firstIndex(where: { $0.tag == previousTag }) {
                otpTextFields[prevIndex].becomeFirstResponder()
            }
        }
    }
    
    private func handlePastedOTP(_ string: String) {
        let digits = string.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        let otpString = String(digits.prefix(otpTextFields.count))
        
        for (index, char) in otpString.enumerated() {
            if index < otpTextFields.count {
                otpTextFields[index].text = String(char)
            }
        }
        
        if otpString.count == otpTextFields.count {
            otpTextFields.last?.resignFirstResponder()
        } else {
            if otpString.count < otpTextFields.count {
                otpTextFields[otpString.count].becomeFirstResponder()
            }
        }
        
        updateOriginalTextField()
        updateButtonState()
    }
}
