import Foundation

class AuthViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var name: String = ""
    @Published var phoneNumber: String = ""
    @Published var otpCode: String = ""
    @Published var isAuthenticated: Bool = false
    @Published var errorMessage: String?
    @Published var isRegistrationFlow: Bool = true

    func sendOTP() {
        guard !email.isEmpty else {
            errorMessage = "Please enter an email address"
            return
        }

        SupabaseManager.shared.sendOTP(email: email) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ OTP sent successfully!")
                    self.errorMessage = nil
                case .failure(let error):
                    self.errorMessage = "Failed to send OTP: \(error.localizedDescription)"
                }
            }
        }
    }

    func resendOTP() {
        guard !email.isEmpty else {
            errorMessage = "Please enter an email address"
            return
        }

        SupabaseManager.shared.sendOTP(email: email) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("✅ OTP resent successfully!")
                    self.errorMessage = nil
                    self.otpCode = ""
                case .failure(let error):
                    self.errorMessage = "Failed to resend OTP: \(error.localizedDescription)"
                }
            }
        }
    }

    func verifyOTP() {
        guard !email.isEmpty, !otpCode.isEmpty else {
            errorMessage = "Please enter both email and OTP"
            return
        }

        let nameForRegistration = isRegistrationFlow ? (name.isEmpty ? nil : name) : nil
        let phoneForRegistration = isRegistrationFlow ? (phoneNumber.isEmpty ? nil : phoneNumber) : nil

        SupabaseManager.shared.verifyOTP(email: email, otp: otpCode, name: nameForRegistration, phone: phoneForRegistration) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let user):
                    print("✅ User verified: \(user.name)")
                    self.isAuthenticated = true
                    self.errorMessage = nil
                case .failure(let error):
                    self.errorMessage = "Verification failed: \(error.localizedDescription)"
                }
            }
        }
    }
    

    func toggleFlow() {
        isRegistrationFlow.toggle()
        errorMessage = nil
        clearFields()
    }

    private func clearFields() {
        email = ""
        name = ""
        phoneNumber = ""
        otpCode = ""
        isAuthenticated = false
    }
}
