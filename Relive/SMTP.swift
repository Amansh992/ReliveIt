

import Foundation
import SwiftSMTP
final class OTPSender {
    private static let smtpHost = "smtp.gmail.com"
    private static let smtpPort = 465
    private static let username = "shivamdubey177@gmail.com"
    private static let password = "cpwl fidk hnfn hfwn"
    private static let senderName = "Attire Me"
    private static let senderEmail = "shivamdubey177@gmail.com"
    
    private let smtp: SMTP
    private let sender: Mail.User
    
    static let shared = OTPSender()
    
    private init() {
        self.smtp = SMTP(hostname: OTPSender.smtpHost, email: OTPSender.username, password: OTPSender.password, port: Int32(OTPSender.smtpPort), tlsMode: .requireTLS)
        self.sender = Mail.User(name: OTPSender.senderName, email: OTPSender.senderEmail)
    }
    
    func sendOTP(to recipientEmail: String, otp: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Log that we're starting
        print("Starting to send OTP to \(recipientEmail)")
        
        DispatchQueue.global().async {
            do {
                let recipient = Mail.User(email: recipientEmail)
                let subject = "Your Attire Me OTP Code (Valid for 10 Minutes)"

                let body = """
                Hi there,

                Your OTP code for Attire Me is: \(otp)

                ✅ This code is valid for 10 minutes.

                If you didn't request this, please ignore this email.

                Regards,  
                Attire Me Team  
                [attireme.app](https://attireme.app)
                """

                let sender = Mail.User(name: "Attire Me", email: "shivamdubey177@gmail.com")

                let mail = Mail(from: sender, to: [recipient], subject: subject, text: body)
                
                print("Attempting to connect to SMTP server...")
                self.smtp.send(mail) { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("SMTP Error: \(error.localizedDescription)")
                            completion(.failure(error))
                        } else {
                            print("Email sent successfully")
                            completion(.success(()))
                        }
                    }
                }
            } catch {
                print("Unexpected error: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}
