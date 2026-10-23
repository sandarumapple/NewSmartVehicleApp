import AuthenticationServices
import Combine
import CryptoKit
import Foundation
import Security

@MainActor
protocol AuthenticationHandling: AnyObject {
    func register(email: String, password: String, name: String) async throws
    func signIn(email: String, password: String) async throws
    func sendPasswordReset(email: String) async throws
    func signInWithGoogle() async throws
    func signInWithApple(
        credential: ASAuthorizationAppleIDCredential, rawNonce: String
    ) async throws
}

extension AppStore: AuthenticationHandling {}

/// Owns authentication form state and validation. The View handles platform sign-in UI only.
@MainActor
final class AuthenticationViewModel: ObservableObject {
    @Published var isRegister = false
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var name = ""
    @Published var error: String?
    @Published var notice: String?
    @Published var resetEmail = ""
    @Published var resetError: String?
    @Published var resetConfirmation: String?
    @Published private(set) var isSubmitting = false
    @Published private(set) var isResettingPassword = false

    private var appleNonce: String?

    func toggleMode() {
        guard !isSubmitting else { return }
        isRegister.toggle()
        password = ""
        confirmPassword = ""
        error = nil
        notice = nil
    }

    func submit(using authentication: any AuthenticationHandling) {
        guard !isSubmitting else { return }

        let submittingRegistration = isRegister
        let cleanEmail = Self.normalizedEmail(email)
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard Self.isValidEmail(cleanEmail) else {
            error = "Enter a valid email address."
            return
        }
        guard password.count >= 6 else {
            error = "Password must contain at least 6 characters."
            return
        }
        if submittingRegistration {
            guard !cleanName.isEmpty else {
                error = "Enter your full name."
                return
            }
            guard password == confirmPassword else {
                error = "Passwords do not match."
                return
            }
        }

        email = cleanEmail
        name = cleanName
        isSubmitting = true
        error = nil
        notice = nil
        Task {
            do {
                if submittingRegistration {
                    try await authentication.register(
                        email: cleanEmail, password: password, name: cleanName)
                    isRegister = false
                    password = ""
                    confirmPassword = ""
                    notice = "Account created. Check your email, verify the account, then sign in."
                } else {
                    try await authentication.signIn(email: cleanEmail, password: password)
                }
            } catch {
                self.error = Self.displayMessage(for: error)
            }
            isSubmitting = false
        }
    }

    func preparePasswordReset() {
        resetEmail = Self.normalizedEmail(email)
        resetError = nil
        resetConfirmation = nil
    }

    func requestPasswordReset(using authentication: any AuthenticationHandling) {
        guard !isResettingPassword else { return }
        let cleanEmail = Self.normalizedEmail(resetEmail)
        guard Self.isValidEmail(cleanEmail) else {
            resetError = "Enter the email address used for your account."
            return
        }

        resetEmail = cleanEmail
        resetError = nil
        resetConfirmation = nil
        isResettingPassword = true
        Task {
            do {
                try await authentication.sendPasswordReset(email: cleanEmail)
                resetConfirmation =
                    "If an account exists for this email, a password-reset link has been sent."
            } catch {
                resetError = Self.displayMessage(for: error)
            }
            isResettingPassword = false
        }
    }

    func beginExternalSignIn() {
        guard !isSubmitting else { return }
        isSubmitting = true
        error = nil
        notice = nil
    }
    func failExternalSignIn(_ message: String) {
        error = message
        isSubmitting = false
    }

    func signInWithGoogle(using authentication: any AuthenticationHandling) {
        guard !isSubmitting else { return }
        beginExternalSignIn()
        Task {
            do {
                try await authentication.signInWithGoogle()
            } catch {
                self.error = Self.displayMessage(for: error)
            }
            isSubmitting = false
        }
    }

    func prepareAppleNonce() -> String {
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: 32)
        let nonce =
            SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess
            ? String(bytes.map { characters[Int($0) % characters.count] })
            : UUID().uuidString
        appleNonce = nonce
        return SHA256.hash(data: Data(nonce.utf8))
            .map { String(format: "%02x", $0) }.joined()
    }

    private static func normalizedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func isValidEmail(_ email: String) -> Bool {
        email.range(
            of: #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    func completeAppleSignIn(
        _ result: Result<ASAuthorization, Error>, using authentication: any AuthenticationHandling
    ) {
        switch result {
        case .failure(let failure):
            error = Self.displayMessage(for: failure)
            appleNonce = nil
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let nonce = appleNonce
            else {
                failExternalSignIn("Apple sign-in could not be completed. Try again.")
                return
            }
            beginExternalSignIn()
            Task {
                do {
                    try await authentication.signInWithApple(
                        credential: credential, rawNonce: nonce)
                } catch {
                    self.error = Self.displayMessage(for: error)
                }
                appleNonce = nil
                isSubmitting = false
            }
        }
    }

    private static func displayMessage(for error: Error) -> String {
        let message = error.localizedDescription
        if message.localizedCaseInsensitiveContains("keychain")
            || message.localizedCaseInsensitiveContains("secure storage")
        {
            return "Secure sign-in storage is unavailable. Close and reopen the app, then try again."
        }
        return message
    }
}
