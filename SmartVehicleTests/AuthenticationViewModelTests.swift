import AuthenticationServices
import Testing
@testable import SmartVehicle

@Suite("Authentication ViewModel")
@MainActor
struct AuthenticationViewModelTests {
    @Test("Sign-in rejects an invalid email")
    func signInRejectsInvalidEmail() {
        let sut = AuthenticationViewModel()
        let authentication = AuthenticationMock()
        sut.email = "not-an-email"
        sut.password = "123456"

        sut.submit(using: authentication)

        #expect(sut.error == "Enter a valid email address.")
        #expect(authentication.signInCallCount == 0)
    }

    @Test("Sign-in rejects a short password")
    func signInRejectsShortPassword() {
        let sut = AuthenticationViewModel()
        let authentication = AuthenticationMock()
        sut.email = "driver@example.com"
        sut.password = "12345"

        sut.submit(using: authentication)

        #expect(sut.error == "Password must contain at least 6 characters.")
        #expect(authentication.signInCallCount == 0)
    }

    @Test("Registration rejects mismatched passwords")
    func registrationRejectsMismatchedPasswords() {
        let sut = AuthenticationViewModel()
        let authentication = AuthenticationMock()
        sut.isRegister = true
        sut.name = "Test Driver"
        sut.email = "driver@example.com"
        sut.password = "123456"
        sut.confirmPassword = "654321"

        sut.submit(using: authentication)

        #expect(sut.error == "Passwords do not match.")
        #expect(authentication.registerCallCount == 0)
    }

    @Test("Sign-in normalizes email before authentication")
    func signInNormalizesEmailBeforeAuthentication() async {
        let sut = AuthenticationViewModel()
        let authentication = AuthenticationMock()
        sut.email = "  DRIVER@Example.COM  "
        sut.password = "123456"

        await withCheckedContinuation { continuation in
            authentication.onSignIn = { continuation.resume() }
            sut.submit(using: authentication)
        }

        #expect(authentication.receivedEmail == "driver@example.com")
        #expect(authentication.receivedPassword == "123456")
        #expect(sut.email == "driver@example.com")
    }

    @Test("Password reset rejects an invalid email")
    func passwordResetRejectsInvalidEmail() {
        let sut = AuthenticationViewModel()
        let authentication = AuthenticationMock()
        sut.resetEmail = "invalid"

        sut.requestPasswordReset(using: authentication)

        #expect(sut.resetError == "Enter the email address used for your account.")
        #expect(authentication.passwordResetCallCount == 0)
    }
}

@MainActor
private final class AuthenticationMock: AuthenticationHandling {
    var signInCallCount = 0
    var registerCallCount = 0
    var passwordResetCallCount = 0
    var receivedEmail: String?
    var receivedPassword: String?
    var onSignIn: (() -> Void)?

    func register(email: String, password: String, name: String) async throws {
        registerCallCount += 1
    }

    func signIn(email: String, password: String) async throws {
        signInCallCount += 1
        receivedEmail = email
        receivedPassword = password
        onSignIn?()
    }

    func sendPasswordReset(email: String) async throws {
        passwordResetCallCount += 1
    }

    func signInWithGoogle() async throws {}

    func signInWithApple(
        credential: ASAuthorizationAppleIDCredential, rawNonce: String
    ) async throws {}
}
