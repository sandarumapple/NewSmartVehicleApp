import AuthenticationServices
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging
import Foundation
import GoogleSignIn
import LocalAuthentication
import UIKit
import UserNotifications
import WidgetKit

/// A feature observes data through this token without importing FirebaseFirestore.
final class ObservationToken {
    private var onCancel: (() -> Void)?

    init(_ onCancel: @escaping () -> Void) { self.onCancel = onCancel }

    func cancel() {
        onCancel?()
        onCancel = nil
    }

    deinit { cancel() }
}

struct SessionUser: Equatable {
    let id: String
    let displayName: String?
    let email: String?
    let isEmailVerified: Bool
    let requiresEmailVerification: Bool
}

enum AuthenticationServiceError: LocalizedError {
    case invalidEmail
    case wrongCredentials
    case emailAlreadyInUse
    case weakPassword
    case emailNotVerified
    case userDisabled
    case tooManyRequests
    case networkUnavailable
    case operationNotAllowed
    case secureStorageUnavailable
    case accountCreationFailed

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            "Enter a valid email address."
        case .wrongCredentials:
            "The email or password is incorrect."
        case .emailAlreadyInUse:
            "An account already exists for this email. Try signing in instead."
        case .weakPassword:
            "Use a stronger password with at least 6 characters."
        case .emailNotVerified:
            "Verify your email before signing in. We sent you a new verification link."
        case .userDisabled:
            "This account has been disabled. Contact support for help."
        case .tooManyRequests:
            "Too many attempts. Wait a moment and try again."
        case .networkUnavailable:
            "Check your internet connection and try again."
        case .operationNotAllowed:
            "This sign-in method is not enabled for the Firebase project."
        case .secureStorageUnavailable:
            "Secure sign-in storage is unavailable. Close and reopen the app, then try again."
        case .accountCreationFailed:
            "We could not finish creating the account. No incomplete account was kept."
        }
    }
}

enum PhotoLoadResult {
    case image(Data)
    case removed
    case missing
}

protocol AuthenticationServicing {
    var currentUser: SessionUser? { get }
    func observeChanges(_ onChange: @escaping (SessionUser?) -> Void) -> ObservationToken
    func register(email: String, password: String, name: String) async throws
    func signIn(email: String, password: String) async throws
    func sendPasswordReset(email: String) async throws
    func signInWithGoogle(idToken: String, accessToken: String) async throws
    func signInWithApple(
        credential: ASAuthorizationAppleIDCredential, rawNonce: String
    ) async throws
    func updateDisplayName(_ name: String) async throws -> SessionUser?
    func signOut() throws
}

struct GoogleSignInTokens {
    let idToken: String
    let accessToken: String
}

@MainActor protocol GoogleSignInPresenting {
    func signIn() async throws -> GoogleSignInTokens
}

protocol GarageRemoteRepository {
    var isConfigured: Bool { get }
    func observeGarage(
        userID: String, onChange: @escaping (Result<Data?, Error>) -> Void
    ) -> ObservationToken
    func observePhoto(
        userID: String, photoID: String,
        onChange: @escaping (Result<PhotoLoadResult, Error>) -> Void
    ) -> ObservationToken
    func saveGarage(_ data: Data, userID: String) async throws
    func loadPhoto(userID: String, photoID: String) async throws -> PhotoLoadResult
    func savePhoto(_ data: Data, userID: String, photoID: String) async throws
    func deletePhoto(userID: String, photoID: String) async throws
    func observeMarketplace(
        onChange: @escaping (Result<[MarketplaceItem], Error>) -> Void
    ) -> ObservationToken
    func publishListing(_ item: MarketplaceItem, userID: String) async throws
    func updateListing(_ item: MarketplaceItem, userID: String) async throws
    func deleteListing(id: UUID, userID: String) async throws
    func observePosts(
        userID: String?, onChange: @escaping (Result<[CommunityPost], Error>) -> Void
    ) -> ObservationToken
    func publishPost(_ post: CommunityPost, userID: String) async throws
    func updatePost(_ post: CommunityPost, userID: String) async throws
    func deletePost(id: UUID, userID: String) async throws
    func setPostLiked(_ liked: Bool, postID: UUID, userID: String, actorName: String) async throws
    func observeComments(
        postID: UUID, onChange: @escaping (Result<[CommunityComment], Error>) -> Void
    ) -> ObservationToken
    func publishComment(_ comment: CommunityComment, postID: UUID, userID: String) async throws
    func deleteComment(id: UUID, postID: UUID, userID: String) async throws
    func observeCommunityNotifications(
        userID: String,
        onChange: @escaping (Result<[CommunityNotification], Error>) -> Void
    ) -> ObservationToken
    func markCommunityNotificationRead(id: String, userID: String) async throws
    func saveMessagingRegistration(_ installationID: String, userID: String) async throws
    func removeMessagingRegistration(_ installationID: String, userID: String) async throws
}

protocol LocalDataStoring {
    func data(forKey key: String) -> Data?
    func set(_ value: Data, forKey key: String)
    func set(_ value: Bool, forKey key: String)
    func bool(forKey key: String) -> Bool
    func removeObject(forKey key: String)
}

protocol PhotoFileStoring {
    func photoData(ownerID: String?, photoID: String) -> Data?
    func savePhoto(_ data: Data, ownerID: String?, photoID: String) throws
    func deletePhoto(ownerID: String?, photoID: String) throws
    func saveScanPages(_ pages: [Data], ownerID: String?, documentID: UUID) throws
    func scanPages(ownerID: String?, documentID: UUID) -> [Data]
    func deleteScanPages(ownerID: String?, documentID: UUID) throws
}

protocol WidgetSnapshotPublishing {
    func publish(_ data: Data?)
}

protocol DeviceAuthenticating {
    var unlockTitle: String { get }
    func evaluate(
        requiresBiometrics: Bool, reason: String,
        completion: @escaping (Bool, NSError?) -> Void
    )
}

protocol ReminderScheduling {
    func replace(with reminders: [ScheduledReminder])
    func clear()
}

struct ScheduledReminder {
    let id: String
    let title: String
    let body: String
    let date: Date
}

enum NotificationPermissionState: Equatable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral

    var allowsAlerts: Bool {
        self == .authorized || self == .provisional || self == .ephemeral
    }
}

protocol NotificationPermissionServicing {
    func request(_ completion: @escaping (NotificationPermissionState) -> Void)
    func check(_ completion: @escaping (NotificationPermissionState) -> Void)
    func registerForRemoteNotifications()
    func unregisterForRemoteNotifications()
    func setBadgeCount(_ count: Int)
    func presentCommunityAlert(_ notification: CommunityNotification, userID: String)
}

protocol PushTokenServicing {
    func setAutoInitEnabled(_ enabled: Bool)
    func register() async throws
    func unregister() async throws
}

/// The composition root supplies the same service set to every feature.
struct AppDependencies {
    let authentication: any AuthenticationServicing
    let googleSignIn: any GoogleSignInPresenting
    let remote: any GarageRemoteRepository
    let local: any LocalDataStoring
    let photoFiles: any PhotoFileStoring
    let widget: any WidgetSnapshotPublishing
    let deviceAuthentication: any DeviceAuthenticating
    let reminders: any ReminderScheduling
    let notificationPermissions: any NotificationPermissionServicing
    let pushTokens: any PushTokenServicing

    @MainActor static func live() -> AppDependencies {
        FirebaseBackend.configureIfAvailable()
        if FirebaseBackend.isConfigured {
            Messaging.messaging().isAutoInitEnabled = false
        }
        return AppDependencies(
            authentication: FirebaseAuthenticationService(),
            googleSignIn: GoogleSignInPresenter(),
            remote: FirebaseGarageRepository(),
            local: UserDefaultsDataStore(),
            photoFiles: ApplicationPhotoFileStore(),
            widget: AppGroupWidgetPublisher(),
            deviceAuthentication: LocalDeviceAuthenticator(),
            reminders: LocalReminderScheduler(),
            notificationPermissions: SystemNotificationPermissionService(),
            pushTokens: FirebasePushTokenService()
        )
    }
}

private struct FirebaseAuthenticationService: AuthenticationServicing {
    var currentUser: SessionUser? { Auth.auth().currentUser.map(Self.sessionUser) }

    func observeChanges(_ onChange: @escaping (SessionUser?) -> Void) -> ObservationToken {
        let handle = Auth.auth()
            .addStateDidChangeListener { _, user in
                onChange(user.map(Self.sessionUser))
            }
        return ObservationToken { Auth.auth().removeStateDidChangeListener(handle) }
    }

    func register(email: String, password: String, name: String) async throws {
        let result: AuthDataResult
        do {
            result = try await Auth.auth().createUser(withEmail: email, password: password)
        } catch {
            throw Self.displayError(for: error)
        }

        do {
            let change = result.user.createProfileChangeRequest()
            change.displayName = name
            try await change.commitChanges()
            try await result.user.sendEmailVerification()
            try Auth.auth().signOut()
        } catch {
            // Account creation is a multi-step operation. Roll back a user that
            // cannot be fully prepared so the email is not left unusable.
            try? await result.user.delete()
            try? Auth.auth().signOut()
            let mapped = Self.displayError(for: error)
            if mapped is AuthenticationServiceError { throw mapped }
            throw AuthenticationServiceError.accountCreationFailed
        }
    }

    func signIn(email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            guard result.user.isEmailVerified else {
                try? await result.user.sendEmailVerification()
                try? Auth.auth().signOut()
                throw AuthenticationServiceError.emailNotVerified
            }
        } catch {
            if let error = error as? AuthenticationServiceError { throw error }
            throw Self.displayError(for: error)
        }
    }

    func sendPasswordReset(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            // Keep the response account-enumeration safe. The UI displays the
            // same confirmation whether or not an account exists.
            if AuthErrorCode(rawValue: (error as NSError).code) == .userNotFound { return }
            throw Self.displayError(for: error)
        }
    }

    func signInWithGoogle(idToken: String, accessToken: String) async throws {
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken, accessToken: accessToken)
        do {
            _ = try await Auth.auth().signIn(with: credential)
        } catch {
            throw Self.displayError(for: error)
        }
    }

    func signInWithApple(
        credential: ASAuthorizationAppleIDCredential, rawNonce: String
    ) async throws {
        guard let data = credential.identityToken,
            let token = String(data: data, encoding: .utf8)
        else { throw BackendError.appleTokenMissing }
        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: token, rawNonce: rawNonce, fullName: credential.fullName)
        do {
            _ = try await Auth.auth().signIn(with: firebaseCredential)
        } catch {
            throw Self.displayError(for: error)
        }
    }

    func updateDisplayName(_ name: String) async throws -> SessionUser? {
        guard let user = Auth.auth().currentUser else { return nil }
        let change = user.createProfileChangeRequest()
        change.displayName = name
        try await change.commitChanges()
        _ = try await user.getIDTokenResult(forcingRefresh: true)
        return Self.sessionUser(user)
    }

    func signOut() throws { try Auth.auth().signOut() }

    private static func sessionUser(_ user: FirebaseAuth.User) -> SessionUser {
        SessionUser(
            id: user.uid,
            displayName: user.displayName,
            email: user.email,
            isEmailVerified: user.isEmailVerified,
            requiresEmailVerification: user.providerData.contains { $0.providerID == "password" }
        )
    }

    private static func displayError(for error: Error) -> Error {
        guard let code = AuthErrorCode(rawValue: (error as NSError).code) else { return error }
        switch code {
        case .invalidEmail:
            return AuthenticationServiceError.invalidEmail
        case .wrongPassword, .userNotFound, .invalidCredential:
            return AuthenticationServiceError.wrongCredentials
        case .emailAlreadyInUse:
            return AuthenticationServiceError.emailAlreadyInUse
        case .weakPassword:
            return AuthenticationServiceError.weakPassword
        case .userDisabled:
            return AuthenticationServiceError.userDisabled
        case .tooManyRequests:
            return AuthenticationServiceError.tooManyRequests
        case .networkError:
            return AuthenticationServiceError.networkUnavailable
        case .operationNotAllowed:
            return AuthenticationServiceError.operationNotAllowed
        case .keychainError:
            return AuthenticationServiceError.secureStorageUnavailable
        default:
            return error
        }
    }
}

private enum GoogleSignInPresentationError: LocalizedError {
    case missingConfiguration
    case missingWindow
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            "Google sign-in is not configured for this Firebase app yet."
        case .missingWindow:
            "Unable to open Google sign-in. Try again."
        case .missingToken:
            "Google did not return a sign-in token. Try again."
        }
    }
}

private struct GoogleSignInPresenter: GoogleSignInPresenting {
    func signIn() async throws -> GoogleSignInTokens {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw GoogleSignInPresentationError.missingConfiguration
        }
        guard
            let controller = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)?
                .rootViewController
        else { throw GoogleSignInPresentationError.missingWindow }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: controller)
        guard let idToken = result.user.idToken?.tokenString else {
            throw GoogleSignInPresentationError.missingToken
        }
        return GoogleSignInTokens(
            idToken: idToken, accessToken: result.user.accessToken.tokenString)
    }
}

private struct FirebaseGarageRepository: GarageRemoteRepository {
    var isConfigured: Bool { FirebaseBackend.isConfigured }

    func observeGarage(
        userID: String, onChange: @escaping (Result<Data?, Error>) -> Void
    ) -> ObservationToken {
        let listener = FirebaseBackend.observeGarage(userID: userID, onChange: onChange)
        return ObservationToken { listener.remove() }
    }

    func observePhoto(
        userID: String, photoID: String,
        onChange: @escaping (Result<PhotoLoadResult, Error>) -> Void
    ) -> ObservationToken {
        let listener = FirebaseBackend.observePhoto(
            userID: userID, photoID: photoID, onChange: onChange)
        return ObservationToken { listener.remove() }
    }

    func saveGarage(_ data: Data, userID: String) async throws {
        try await FirebaseBackend.saveGarage(data, userID: userID)
    }

    func loadPhoto(userID: String, photoID: String) async throws -> PhotoLoadResult {
        try await FirebaseBackend.loadPhoto(userID: userID, photoID: photoID)
    }

    func savePhoto(_ data: Data, userID: String, photoID: String) async throws {
        try await FirebaseBackend.savePhoto(data, userID: userID, photoID: photoID)
    }

    func deletePhoto(userID: String, photoID: String) async throws {
        try await FirebaseBackend.deletePhoto(userID: userID, photoID: photoID)
    }

    func observeMarketplace(
        onChange: @escaping (Result<[MarketplaceItem], Error>) -> Void
    ) -> ObservationToken {
        let listener = FirebaseBackend.observeMarketplace(onChange: onChange)
        return ObservationToken { listener.remove() }
    }

    func publishListing(_ item: MarketplaceItem, userID: String) async throws {
        try await FirebaseBackend.publishListing(item, userID: userID)
    }

    func updateListing(_ item: MarketplaceItem, userID: String) async throws {
        try await FirebaseBackend.updateListing(item, userID: userID)
    }

    func deleteListing(id: UUID, userID: String) async throws {
        try await FirebaseBackend.deleteListing(id: id, userID: userID)
    }

    func observePosts(
        userID: String?, onChange: @escaping (Result<[CommunityPost], Error>) -> Void
    ) -> ObservationToken {
        let listener = FirebaseBackend.observePosts(userID: userID, onChange: onChange)
        return ObservationToken { listener.remove() }
    }

    func publishPost(_ post: CommunityPost, userID: String) async throws {
        try await FirebaseBackend.publishPost(post, userID: userID)
    }

    func updatePost(_ post: CommunityPost, userID: String) async throws {
        try await FirebaseBackend.updatePost(post, userID: userID)
    }

    func deletePost(id: UUID, userID: String) async throws {
        try await FirebaseBackend.deletePost(id: id, userID: userID)
    }

    func setPostLiked(
        _ liked: Bool, postID: UUID, userID: String, actorName: String
    ) async throws {
        try await FirebaseBackend.setPostLiked(
            liked, postID: postID, userID: userID, actorName: actorName)
    }

    func observeComments(
        postID: UUID, onChange: @escaping (Result<[CommunityComment], Error>) -> Void
    ) -> ObservationToken {
        let listener = FirebaseBackend.observeComments(postID: postID, onChange: onChange)
        return ObservationToken { listener.remove() }
    }

    func publishComment(_ comment: CommunityComment, postID: UUID, userID: String) async throws {
        try await FirebaseBackend.publishComment(comment, postID: postID, userID: userID)
    }

    func deleteComment(id: UUID, postID: UUID, userID: String) async throws {
        try await FirebaseBackend.deleteComment(id: id, postID: postID, userID: userID)
    }

    func observeCommunityNotifications(
        userID: String,
        onChange: @escaping (Result<[CommunityNotification], Error>) -> Void
    ) -> ObservationToken {
        let listener = FirebaseBackend.observeCommunityNotifications(
            userID: userID, onChange: onChange)
        return ObservationToken { listener.remove() }
    }

    func markCommunityNotificationRead(id: String, userID: String) async throws {
        try await FirebaseBackend.markCommunityNotificationRead(id: id, userID: userID)
    }

    func saveMessagingRegistration(_ installationID: String, userID: String) async throws {
        try await FirebaseBackend.saveMessagingRegistration(installationID, userID: userID)
    }

    func removeMessagingRegistration(_ installationID: String, userID: String) async throws {
        try await FirebaseBackend.removeMessagingRegistration(installationID, userID: userID)
    }
}

private struct UserDefaultsDataStore: LocalDataStoring {
    private let defaults = UserDefaults.standard
    func data(forKey key: String) -> Data? { defaults.data(forKey: key) }
    func set(_ value: Data, forKey key: String) { defaults.set(value, forKey: key) }
    func set(_ value: Bool, forKey key: String) { defaults.set(value, forKey: key) }
    func bool(forKey key: String) -> Bool { defaults.bool(forKey: key) }
    func removeObject(forKey key: String) { defaults.removeObject(forKey: key) }
}

private struct AppGroupWidgetPublisher: WidgetSnapshotPublishing {
    private let groupID = "group.com.sandaru.smartvehicle"
    private let key = "smart-vehicle-store"

    func publish(_ data: Data?) {
        guard let defaults = UserDefaults(suiteName: groupID),
            defaults.data(forKey: key) != data
        else { return }
        if let data { defaults.set(data, forKey: key) } else { defaults.removeObject(forKey: key) }
        WidgetCenter.shared.reloadTimelines(ofKind: "SmartVehicleWidget")
    }
}

private struct LocalDeviceAuthenticator: DeviceAuthenticating {
    var unlockTitle: String {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        switch context.biometryType {
        case .faceID: return "Unlock with Face ID"
        case .touchID: return "Unlock with Touch ID"
        default: return "Unlock with device passcode"
        }
    }

    func evaluate(
        requiresBiometrics: Bool, reason: String,
        completion: @escaping (Bool, NSError?) -> Void
    ) {
        let context = LAContext()
        let policy: LAPolicy =
            requiresBiometrics
            ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication
        var error: NSError?
        guard context.canEvaluatePolicy(policy, error: &error) else {
            completion(false, error)
            return
        }
        context.evaluatePolicy(policy, localizedReason: reason) { success, error in
            completion(success, error as NSError?)
        }
    }
}

private struct LocalReminderScheduler: ReminderScheduling {
    func replace(with reminders: [ScheduledReminder]) {
        clear()
        for reminder in reminders where reminder.date > Date() {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(5, reminder.date.timeIntervalSinceNow), repeats: false)
            let request = UNNotificationRequest(
                identifier: "smartvehicle.reminder.\(reminder.id)",
                content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    func clear() {
        // Earlier versions used random IDs. All pending local requests belong to this app.
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

private struct SystemNotificationPermissionService: NotificationPermissionServicing {
    func presentCommunityAlert(_ notification: CommunityNotification, userID: String) {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.message
        content.sound = .default
        content.threadIdentifier = "community"
        content.userInfo = [
            "type": notification.type,
            "postID": notification.postID.uuidString,
            "notificationID": notification.id,
            "recipientID": userID,
        ]
        UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: "community.\(userID).\(notification.id)", content: content, trigger: nil))
    }

    func setBadgeCount(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count) { _ in }
    }

    func request(_ completion: @escaping (NotificationPermissionState) -> Void) {
        UNUserNotificationCenter.current()
            .requestAuthorization(
                options: [.alert, .sound, .badge]
            ) { _, _ in
                check(completion)
            }
    }

    func check(_ completion: @escaping (NotificationPermissionState) -> Void) {
        UNUserNotificationCenter.current()
            .getNotificationSettings { settings in
                switch settings.authorizationStatus {
                case .authorized: completion(.authorized)
                case .provisional: completion(.provisional)
                case .ephemeral: completion(.ephemeral)
                case .notDetermined: completion(.notDetermined)
                case .denied: completion(.denied)
                @unknown default: completion(.denied)
                }
            }
    }

    func registerForRemoteNotifications() {
        DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
    }

    func unregisterForRemoteNotifications() {
        DispatchQueue.main.async { UIApplication.shared.unregisterForRemoteNotifications() }
    }
}

private struct FirebasePushTokenService: PushTokenServicing {
    func setAutoInitEnabled(_ enabled: Bool) { Messaging.messaging().isAutoInitEnabled = enabled }
    func register() async throws { try await Messaging.messaging().register() }
    func unregister() async throws { try await Messaging.messaging().unregister() }
}
