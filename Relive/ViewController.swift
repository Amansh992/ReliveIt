import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var nameText: UITextField!
    @IBOutlet weak var countryCode: UITextField!
    @IBOutlet weak var phoneno: UITextField!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var nameLabel: UILabel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = "Register"
        countryCode.text = "+91"
        setupTextFieldChangeListeners()
        changeButtonState()
    }

    @IBAction func textFieldChange(_ sender: UITextField) {
        changeButtonState()
    }
    
    func changeButtonState() {
        let nameEmpty = nameText?.text?.isEmpty ?? true
        let countryEmpty = countryCode?.text?.isEmpty ?? true
        let phoneEmpty = phoneno?.text?.isEmpty ?? true
        let emailEmpty = emailTextField?.text?.isEmpty ?? true
        sendButton?.isEnabled = !(nameEmpty || countryEmpty || phoneEmpty || emailEmpty)
    }
    @objc private func textFieldDidChange(_ textField: UITextField) {
        changeButtonState()
    }
    private func setupTextFieldChangeListeners() {
        // Add text changed notifications for all text fields
        nameText.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        countryCode.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        phoneno.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        emailTextField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        passwordTextField?.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
    }
    @IBAction func sendButtonTapped(_ sender: UIButton) {
        guard let countryCodeText = countryCode?.text, !countryCodeText.isEmpty,
              let phonenoText = phoneno?.text, !phonenoText.isEmpty,
              let nameText = nameText?.text, !nameText.isEmpty,
              let emailText = emailTextField?.text, !emailText.isEmpty else {
            showAlert(message: "Please fill in all fields")
            return
        }
        
        if !isValidEmail(emailText) {
            showAlert(message: "Please enter a valid email address")
            return
        }
        
        sender.isEnabled = false
        let originalTitle = sender.title(for: .normal)
        sender.setTitle("", for: .normal)
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .white
        indicator.tag = 999
        indicator.center = CGPoint(x: sender.bounds.width / 2, y: sender.bounds.height / 2)
        sender.addSubview(indicator)
        indicator.startAnimating()

        let fullPhoneNo = "\(countryCodeText)\(phonenoText)"
        let formattedPhone = fullPhoneNo.replacingOccurrences(of: "\\s|-|\\(|\\)", with: "", options: .regularExpression)

        SupabaseManager.shared.checkUserExists(email: emailText) { [weak self] exists in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if exists {
                    self.hideLoadingIndicator(on: sender, title: originalTitle ?? "Send")
                    print("User already exists with email: \(emailText)")
                    self.showSignInOptions(for: emailText)
                    return
                }
                
                SupabaseManager.shared.sendOTP(email: emailText) { [weak self] result in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        
                        self.hideLoadingIndicator(on: sender, title: originalTitle ?? "Send")
                        
                        switch result {
                        case .success():
                            print("OTP sent successfully via email for registration")
                            
                            UserDefaults.standard.set(formattedPhone, forKey: "TempRegistrationPhone")
                            UserDefaults.standard.set(emailText, forKey: "TempRegistrationEmail")
                            UserDefaults.standard.set(nameText, forKey: "TempRegistrationName")
                            UserDefaults.standard.synchronize()
                            
                            let alert = UIAlertController(
                                title: "Verification Code Sent",
                                message: "A verification code has been sent to your email address. Please check your inbox and enter the 6-digit code.",
                                preferredStyle: .alert
                            )
                            
                            alert.addAction(UIAlertAction(title: "Continue", style: .default) { [weak self] _ in
                                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                                if let verificationVC = storyboard.instantiateViewController(withIdentifier: "VerificationViewController") as? VerificationViewController {
                                    verificationVC.phoneNo = formattedPhone
                                    verificationVC.email = emailText
                                    verificationVC.name = nameText
                                    verificationVC.isSignInFlow = false
                                    self?.navigationController?.pushViewController(verificationVC, animated: true)
                                }
                            })
                            
                            self.present(alert, animated: true)
                            
                        case .failure(let error):
                            print("Failed to send OTP via email: \(error.localizedDescription)")
                            self.showAlert(message: "Failed to send verification code. Please check your email address and try again.")
                        }
                    }
                }
            }
        }
    }

    private func hideLoadingIndicator(on button: UIButton, title: String) {
        button.setTitle(title, for: .normal)
        if let indicator = button.viewWithTag(999) as? UIActivityIndicatorView {
            indicator.stopAnimating()
            indicator.removeFromSuperview()
        }
        button.isEnabled = true
    }
    
    func showSignInOptions(for email: String) {
        let alert = UIAlertController(
            title: "Account Exists",
            message: "An account with this email already exists. Would you like to sign in?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Sign In", style: .default) { [weak self] _ in
            self?.navigateToLoginScreen(with: email)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    func navigateToLoginScreen(with email: String) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        if let loginVC = storyboard.instantiateViewController(withIdentifier: "OTPLoginViewController") as? OTPLoginViewController {
            loginVC.email = email
            navigationController?.pushViewController(loginVC, animated: true)
        } else {
            showAlert(message: "Unable to navigate to sign-in screen. Please try again.")
        }
    }
    
    func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
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
