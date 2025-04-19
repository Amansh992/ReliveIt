import SwiftUI

struct AuthTestView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var showResendAlert = false

    var body: some View {
        VStack(spacing: 20) {
            // Toggle between registration and sign-in
            Button(action: {
                viewModel.toggleFlow()
            }) {
                Text(viewModel.isRegistrationFlow ? "Switch to Sign In" : "Switch to Register")
                    .foregroundColor(.blue)
            }
            .padding()

            // Email field
            TextField("Enter Email", text: $viewModel.email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .keyboardType(.emailAddress)
                .autocapitalization(.none)

            // Name and phone fields for registration
            if viewModel.isRegistrationFlow {
                TextField("Enter Name", text: $viewModel.name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                TextField("Enter Phone Number (Optional)", text: $viewModel.phoneNumber)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .keyboardType(.phonePad)
            }

            // Send OTP button
            Button("Send OTP") {
                viewModel.sendOTP()
            }
            .buttonStyle(.borderedProminent)
            .padding()

            // OTP field
            TextField("Enter OTP", text: $viewModel.otpCode)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .keyboardType(.numberPad)

            // Verify OTP button
            Button("Verify OTP") {
                viewModel.verifyOTP()
            }
            .buttonStyle(.borderedProminent)
            .padding()

            // Resend OTP button
            Button("Resend OTP") {
                viewModel.resendOTP()
            }
            .foregroundColor(.blue)
            .padding()

            // Error message
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            // Success message
            if viewModel.isAuthenticated {
                Text("✅ Authentication Successful!")
                    .foregroundColor(.green)
                    .bold()
            }
        }
        .padding()
        .alert(isPresented: $showResendAlert) {
            Alert(
                title: Text("Invalid or Expired Code"),
                message: Text("The verification code is invalid or has expired. Would you like to resend a new code?"),
                primaryButton: .default(Text("Resend OTP")) {
                    viewModel.resendOTP()
                },
                secondaryButton: .cancel()
            )
        }
        .onChange(of: viewModel.errorMessage) { errorMessage in
            if let error = errorMessage, error.contains("expired") || error.contains("invalid") {
                showResendAlert = true
            }
        }
    }
}

struct AuthTestView_Previews: PreviewProvider {
    static var previews: some View {
        AuthTestView()
    }
}
