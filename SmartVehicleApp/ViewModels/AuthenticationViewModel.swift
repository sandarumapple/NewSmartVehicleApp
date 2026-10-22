import AuthenticationServices
import Combine
import CryptoKit
import Foundation
import Security

@MainActor
protocol AuthenticationHandling: AnyObject {
    func register(email: String, password: String, name: String) async throws
    func signIn(email: String, password: String) async throws
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
    @Published var name = ""
    @Published var error: String?
    @Published private(set) var isSubmitting = false

    private var appleNonce: String?

    func toggleMode() {
        isRegister.toggle()
        error = nil
    }

    func submit(using authentication: any AuthenticationHandling) {
        guard email.contains("@"), password.count >= 6,
            !isRegister || !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            error = "Enter a valid email, password (6+ characters), and required details."
            return
        }
        isSubmitting = true
        error = nil
        Task {
            do {
                if isRegister {
                    try await authentication.register(
                        email: email, password: password, name: name)
                } else {
                    try await authentication.signIn(email: email, password: password)
                }
            } catch {
                self.error = error.localizedDescription
            }
            isSubmitting = false
        }
    }

    func beginExternalSignIn() {
        isSubmitting = true
        error = nil
    }
    func failExternalSignIn(_ message: String) {
        error = message
        isSubmitting = false
    }

    func signInWithGoogle(using authentication: any AuthenticationHandling) {
        beginExternalSignIn()
        Task {
            do {
                try await authentication.signInWithGoogle()
            } catch {
                self.error = error.localizedDescription
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

    func completeAppleSignIn(
        _ result: Result<ASAuthorization, Error>, using authentication: any AuthenticationHandling
    ) {
        switch result {
        case .failure(let failure):
            error = failure.localizedDescription
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
                    self.error = error.localizedDescription
                }
                appleNonce = nil
                isSubmitting = false
            }
        }
    }
}
