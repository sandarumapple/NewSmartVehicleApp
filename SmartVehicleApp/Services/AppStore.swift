import AuthenticationServices
import ImageIO
import LocalAuthentication
import SwiftUI
import UIKit

enum DeviceAuthenticationFailure: Error {
    case unavailable(String)
    case cancelled
    case failed(String)
    case interrupted

    var message: String {
        switch self {
        case .unavailable(let message), .failed(let message): return message
        case .cancelled: return "Authentication was cancelled. Try again when you're ready."
        case .interrupted: return "Authentication was interrupted. Try again."
        }
    }
}

@MainActor
final class AppStore: ObservableObject {
    private let dependencies: AppDependencies
    @Published var vehicles: [Vehicle] = []
    @Published var selectedVehicleID: UUID?
    @Published var maintenance: [MaintenanceRecord] = []
    @Published var fuelRecords: [FuelRecord] = []
    @Published var expenses: [ExpenseRecord] = []
    @Published var documents: [VehicleDocument] = []
    @Published var posts: [CommunityPost] = []
    @Published private(set) var communityNotifications: [CommunityNotification] = [] {
        didSet { updateNotificationBadge() }
    }
    @Published private(set) var communityNotificationError: String?
    @Published private(set) var publishConfirmations: [PublishConfirmation] = [] {
        didSet { updateNotificationBadge() }
    }
    @Published var isAuthenticated = false
    @Published var biometricEnabled = false
    @Published private(set) var biometricUnlocked = false
    @Published var notificationsEnabled = true
    @Published var maintenanceNotifications = true
    @Published var documentNotifications = true
    @Published var vehicleNotifications = true
    @Published var appearance = "Dark"
    @Published var userName = "Alex Morgan"
    @Published var userEmail = "alex.morgan@email.com"
    @Published var userPhone = ""
    @Published var userCity = ""
    @Published var userAddress = ""
    @Published var userPostalCode = ""
    @Published private(set) var profilePhoto: UIImage?
    @Published private(set) var vehiclePhotos: [UUID: UIImage] = [:]
    @Published private(set) var expenseReceiptPhotos: [UUID: UIImage] = [:]
    @Published var currency = "LKR"
    @Published var showSuccess: String?
    @Published var onboardingCompleted = true
    @Published var isRestoringSession = false
    @Published var marketplaceItems: [MarketplaceItem] = []
    @Published private(set) var savedMarketplaceItemIDs: Set<UUID> = []
    @Published private(set) var localCommentsByPostID: [UUID: [CommunityComment]] = [:]
    @Published private(set) var pendingLikePostIDs: Set<UUID> = []
    @Published var backendError: String?
    @Published private(set) var notificationPermissionState: NotificationPermissionState = .notDetermined
    @Published private(set) var pushRegistrationError: String?
    @Published private(set) var isPushRegistered = false
    @Published private(set) var pushInstallationID: String?
    @Published private(set) var undoMessage: String?

    var isFirebaseConfigured: Bool { dependencies.remote.isConfigured }
    var currentUserID: String? {
        activeUserID ?? (isFirebaseConfigured ? nil : "local-demo")
    }
    private var activeUserID: String?
    private var authListener: ObservationToken?
    private var garageListener: ObservationToken?
    private var profilePhotoListener: ObservationToken?
    private var marketplaceListener: ObservationToken?
    private var postsListener: ObservationToken?
    private var communityNotificationsListener: ObservationToken?
    private var pushObservers: [NSObjectProtocol] = []
    private var pushLifecycleTask: Task<Void, Never>?
    private var pushRegistrationSaveTask: Task<Void, Never>?
    private var apnsRegistered = false
    private var pushWasActive = false
    @Published private(set) var isSigningOut = false
    private var pendingRegistrationName: String?
    private var pendingSave: Task<Void, Never>?
    private var hasUnsavedChanges = false
    private var saveRevision = 0
    private var didStartFirebase = false
    private var biometricLockGeneration = 0
    private var requestedPhotoIDs: Set<String> = []
    private var photoRevisions: [String: Int] = [:]
    private var undoTask: Task<Void, Never>?
    private var undoAction: (() -> Void)?
    private var undoCommit: (() -> Void)?

    var selectedVehicle: Vehicle? {
        get {
            vehicles.first(where: { $0.id == selectedVehicleID }) ?? vehicles.first
        }
        set {
            if let newValue {
                selectedVehicleID = newValue.id
            }
        }
    }
    var selectedVehicleRecords: [MaintenanceRecord] {
        maintenance.filter { $0.vehicleID == selectedVehicle?.id }
    }
    var selectedFuelRecords: [FuelRecord] {
        fuelRecords.filter { $0.vehicleID == selectedVehicle?.id }
    }
    var selectedExpenses: [ExpenseRecord] {
        expenses.filter { $0.vehicleID == selectedVehicle?.id }
    }
    var selectedDocuments: [VehicleDocument] {
        documents.filter { $0.vehicleID == selectedVehicle?.id }
    }
    var totalFuel: Double { selectedFuelRecords.reduce(0) { $0 + $1.total } }
    var totalExpenses: Double {
        let otherExpenses = selectedExpenses.reduce(0) { $0 + $1.amount }
        let maintenanceCosts = selectedVehicleRecords.reduce(0) { $0 + $1.cost }
        return totalFuel + otherExpenses + maintenanceCosts
    }
    var unreadCommunityNotificationCount: Int {
        communityNotifications.lazy.filter { !$0.isRead }.count
    }
    var unreadNotificationCount: Int {
        unreadCommunityNotificationCount + publishConfirmations.filter { !$0.isRead }.count
    }

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        if isFirebaseConfigured {
            isRestoringSession = true
        } else {
            load()
            loadPublishConfirmations()
        }
        // Apply the black redesign to existing installations once. Later user
        // choices in Appearance remain intact across launches.
        let blackThemeMigrationKey = "smart-vehicle-black-theme-v1"
        if !isRestoringSession && !dependencies.local.bool(forKey: blackThemeMigrationKey) {
            appearance = "Dark"
            persist()
            dependencies.local.set(true, forKey: blackThemeMigrationKey)
        }
    }

    func startFirebase() {
        guard !didStartFirebase, isFirebaseConfigured else { return }
        didStartFirebase = true

        pushObservers = [
            NotificationCenter.default.addObserver(
                forName: .smartVehicleFCMRegistration, object: nil, queue: .main
            ) { [weak self] notification in
                guard let installationID = notification.object as? String else { return }
                Task { @MainActor in self?.savePushRegistration(installationID) }
            },
            NotificationCenter.default.addObserver(
                forName: .smartVehicleAPNsReady, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.apnsRegistered = true
                    self?.pushRegistrationError = nil
                    self?.reconcilePushRegistration()
                }
            },
            NotificationCenter.default.addObserver(
                forName: .smartVehicleAPNsFailed, object: nil, queue: .main
            ) { [weak self] notification in
                Task { @MainActor in
                    self?.apnsRegistered = false
                    self?.pushRegistrationError = notification.object as? String
                }
            },
        ]

        marketplaceListener = dependencies.remote.observeMarketplace { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let items): self?.marketplaceItems = items
                case .failure(let error): self?.backendError = error.localizedDescription
                }
            }
        }
        authListener = dependencies.authentication.observeChanges { [weak self] user in
            Task { @MainActor in self?.handleAuthChange(user) }
        }
    }

    func retryCloudSync() {
        backendError = nil
        guard isAuthenticated else { return }
        refreshCommunityNotifications()
        persist()
    }

    func continueWithCachedData() {
        isRestoringSession = false
    }

    func undoLastChange() {
        undoTask?.cancel()
        undoTask = nil
        let action = undoAction
        undoAction = nil
        undoCommit = nil
        undoMessage = nil
        action?()
    }

    func dismissUndo() {
        commitPendingUndo()
    }

    private func stageUndo(
        message: String,
        undo: @escaping () -> Void,
        commit: @escaping () -> Void = {}
    ) {
        commitPendingUndo()
        undoMessage = message
        undoAction = undo
        undoCommit = commit
        undoTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.commitPendingUndo()
        }
    }

    private func commitPendingUndo() {
        undoTask?.cancel()
        undoTask = nil
        let commit = undoCommit
        undoAction = nil
        undoCommit = nil
        undoMessage = nil
        commit?()
    }

    private func handleAuthChange(_ user: SessionUser?) {
        if let user, user.requiresEmailVerification, !user.isEmailVerified {
            // Firebase briefly publishes newly-created/unverified password users.
            // Never allow that transient state to unlock the app.
            try? dependencies.authentication.signOut()
            activeUserID = nil
            isAuthenticated = false
            isRestoringSession = false
            return
        }
        if user?.id == activeUserID && !(user == nil && isRestoringSession) {
            return
        }
        garageListener?.cancel()
        garageListener = nil
        profilePhotoListener?.cancel()
        profilePhotoListener = nil
        postsListener?.cancel()
        postsListener = nil
        communityNotificationsListener?.cancel()
        communityNotificationsListener = nil
        pendingSave?.cancel()
        hasUnsavedChanges = false
        activeUserID = user?.id
        resetUserData()
        dependencies.reminders.clear()

        if let user {
            postsListener = dependencies.remote.observePosts(userID: user.id) { [weak self] result in
                Task { @MainActor in
                    guard let self, self.activeUserID == user.id else { return }
                    switch result {
                    case .success(let posts): self.posts = posts
                    case .failure(let error): self.backendError = error.localizedDescription
                    }
                }
            }
            refreshCommunityNotifications()
        }

        guard let user else {
            isAuthenticated = false
            isRestoringSession = false
            dependencies.local.removeObject(forKey: "smart-vehicle-store")
            if !isSigningOut { reconcilePushRegistration() }
            return
        }

        isRestoringSession = true
        userName = pendingRegistrationName ?? user.displayName ?? "Driver"
        userEmail = user.email ?? ""
        refreshProfilePhoto()
        observeProfilePhoto(userID: user.id)
        if let cached = dependencies.local.data(forKey: "smart-vehicle-store-\(user.id)"),
            let state = try? JSONDecoder().decode(StoreState.self, from: cached)
        {
            apply(state)
        }
        isAuthenticated = true
        loadPublishConfirmations()
        publishWidgetSnapshot()
        garageListener = dependencies.remote.observeGarage(userID: user.id) { [weak self] result in
            Task { @MainActor in
                guard let self, self.activeUserID == user.id else { return }
                switch result {
                case .success(let data):
                    if let data, let state = try? JSONDecoder().decode(StoreState.self, from: data),
                        !self.hasUnsavedChanges
                    {
                        let mileageWasUpdated = self.apply(state)
                        if mileageWasUpdated {
                            self.persist()
                        } else {
                            self.writeLocalCache(data, userID: user.id)
                        }
                    } else if data == nil && self.pendingRegistrationName != nil {
                        self.persist()
                    }
                    self.isRestoringSession = false
                    self.refreshNotificationPermission()
                case .failure(let error):
                    self.backendError = error.localizedDescription
                    self.isRestoringSession = false
                    self.refreshNotificationPermission()
                }
            }
        }
    }

    private func resetUserData() {
        lockBiometricSession()
        writeWidgetSnapshot(nil)
        vehicles = []
        selectedVehicleID = nil
        maintenance = []
        fuelRecords = []
        expenses = []
        documents = []
        posts = []
        communityNotifications = []
        publishConfirmations = []
        communityNotificationError = nil
        savedMarketplaceItemIDs = []
        localCommentsByPostID = [:]
        pendingLikePostIDs = []
        userName = ""
        userEmail = ""
        userPhone = ""
        userCity = ""
        userAddress = ""
        userPostalCode = ""
        profilePhoto = nil
        vehiclePhotos = [:]
        expenseReceiptPhotos = [:]
        isPushRegistered = false
        pushInstallationID = nil
        requestedPhotoIDs.removeAll()
        photoRevisions.removeAll()
        biometricEnabled = false
        notificationsEnabled = true
        maintenanceNotifications = true
        documentNotifications = true
        vehicleNotifications = true
        appearance = "Dark"
        onboardingCompleted = false
    }

    @discardableResult
    private func apply(_ state: StoreState) -> Bool {
        vehicles = state.vehicles
        selectedVehicleID = state.selectedVehicleID
        maintenance = state.maintenance
        fuelRecords = state.fuelRecords
        expenses = state.expenses
        documents = state.documents
        if !isFirebaseConfigured { posts = state.posts }
        savedMarketplaceItemIDs = state.savedMarketplaceItemIDs ?? []
        localCommentsByPostID = state.localCommentsByPostID ?? [:]
        userName = state.userName
        userEmail = state.userEmail
        userPhone = state.userPhone ?? ""
        userCity = state.userCity ?? ""
        userAddress = state.userAddress ?? ""
        userPostalCode = state.userPostalCode ?? ""
        biometricEnabled = state.biometricEnabled
        notificationsEnabled = state.notificationsEnabled
        maintenanceNotifications = state.maintenanceNotifications ?? true
        documentNotifications = state.documentNotifications ?? true
        vehicleNotifications = state.vehicleNotifications ?? true
        appearance = state.appearance
        onboardingCompleted = state.onboardingCompleted ?? true
        refreshVehiclePhotos()
        refreshExpenseReceipts()
        let mileageWasUpdated = reconcileVehicleMileage()
        publishWidgetSnapshot()
        return mileageWasUpdated
    }

    @discardableResult
    private func reconcileVehicleMileage() -> Bool {
        var latestReadings: [UUID: Int] = [:]
        for record in fuelRecords {
            latestReadings[record.vehicleID] = max(
                latestReadings[record.vehicleID] ?? 0, record.mileage)
        }
        for record in maintenance {
            latestReadings[record.vehicleID] = max(
                latestReadings[record.vehicleID] ?? 0, record.mileage)
        }
        for record in expenses {
            latestReadings[record.vehicleID] = max(
                latestReadings[record.vehicleID] ?? 0, record.mileage)
        }
        var changed = false
        for index in vehicles.indices {
            if let reading = latestReadings[vehicles[index].id],
                reading > vehicles[index].mileage
            {
                vehicles[index].mileage = reading
                changed = true
            }
        }
        return changed
    }

    private func updateVehicleMileage(vehicleID: UUID, reading: Int) {
        guard let index = vehicles.firstIndex(where: { $0.id == vehicleID }),
            reading > vehicles[index].mileage
        else { return }
        vehicles[index].mileage = reading
    }

    func odometerWarning(vehicleID: UUID, reading: Int) -> String? {
        guard let currentMileage = vehicles.first(where: { $0.id == vehicleID })?.mileage,
            reading < currentMileage
        else { return nil }
        return "This is below the current reading of \(currentMileage.formatted()) km. It will be saved as a historical record and will not reduce the vehicle mileage."
    }

    func highestRecordedMileage(vehicleID: UUID) -> Int {
        let readings = maintenance.filter { $0.vehicleID == vehicleID }.map(\.mileage)
            + fuelRecords.filter { $0.vehicleID == vehicleID }.map(\.mileage)
            + expenses.filter { $0.vehicleID == vehicleID }.map(\.mileage)
        return readings.max() ?? 0
    }

    private func writeLocalCache(_ data: Data, userID: String) {
        dependencies.local.set(data, forKey: "smart-vehicle-store-\(userID)")
        dependencies.local.set(data, forKey: "smart-vehicle-store")
    }

    private func writeWidgetSnapshot(_ data: Data?) {
        dependencies.widget.publish(data)
    }

    private func publishWidgetSnapshot() {
        guard isAuthenticated else {
            writeWidgetSnapshot(nil)
            return
        }
        writeWidgetSnapshot(try? JSONEncoder().encode(currentState()))
    }

    func register(email: String, password: String, name: String) async throws {
        guard isFirebaseConfigured else { throw BackendError.authenticationUnavailable }
        pendingRegistrationName = name
        defer { pendingRegistrationName = nil }
        try await dependencies.authentication.register(
            email: email, password: password, name: name)
    }

    func signIn(email: String, password: String) async throws {
        guard isFirebaseConfigured else { throw BackendError.authenticationUnavailable }
        try await dependencies.authentication.signIn(email: email, password: password)
    }

    func sendPasswordReset(email: String) async throws {
        guard isFirebaseConfigured else { throw BackendError.authenticationUnavailable }
        try await dependencies.authentication.sendPasswordReset(email: email)
    }

    func continueInDemoMode() {
        guard !isFirebaseConfigured else { return }
        userName = "Demo Driver"
        userEmail = "demo@local"
        onboardingCompleted = false
        isAuthenticated = true
        loadPublishConfirmations()
        refreshPhotos()
        persist()
    }

    func signInWithGoogle() async throws {
        let tokens = try await dependencies.googleSignIn.signIn()
        try await dependencies.authentication.signInWithGoogle(
            idToken: tokens.idToken, accessToken: tokens.accessToken)
    }

    func signInWithApple(
        credential: ASAuthorizationAppleIDCredential,
        rawNonce: String
    ) async throws {
        try await dependencies.authentication.signInWithApple(
            credential: credential, rawNonce: rawNonce)
    }

    func signOut() async throws {
        guard !isSigningOut else { return }
        isSigningOut = true
        defer { isSigningOut = false }
        commitPendingUndo()
        if isFirebaseConfigured {
            await pushLifecycleTask?.value
            await pushRegistrationSaveTask?.value
            if let userID = activeUserID,
                let installationID = storedPushRegistration(for: userID)
            {
                try? await dependencies.remote.removeMessagingRegistration(
                    installationID, userID: userID)
                dependencies.local.removeObject(forKey: pushRegistrationKey(for: userID))
            }
            dependencies.pushTokens.setAutoInitEnabled(false)
            try? await dependencies.pushTokens.unregister()
            dependencies.notificationPermissions.unregisterForRemoteNotifications()
            dependencies.reminders.clear()
            pushWasActive = false
            apnsRegistered = false
            pushRegistrationError = nil
            isPushRegistered = false
            pushInstallationID = nil
            try dependencies.authentication.signOut()
            handleAuthChange(nil)
        } else {
            isAuthenticated = false
            lockBiometricSession()
            publishConfirmations = []
            profilePhoto = nil
            vehiclePhotos = [:]
            expenseReceiptPhotos = [:]
            dependencies.reminders.clear()
            persist()
        }
    }

    func finishOnboarding() {
        onboardingCompleted = true
        persist()
    }

    func updateProfile(
        name: String, email: String, phone: String, city: String, address: String,
        postalCode: String
    ) async throws {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if isFirebaseConfigured {
            let user = try await dependencies.authentication.updateDisplayName(cleanName)
            userEmail = user?.email ?? cleanEmail
        } else {
            userEmail = cleanEmail
        }
        userName = cleanName
        userPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        userCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        userAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        userPostalCode = postalCode.trimmingCharacters(in: .whitespacesAndNewlines)
        persist()
    }

    func setProfilePhoto(_ data: Data) async throws {
        let photoID = "profile-photo"
        let ownerID = activeUserID
        let wasAuthenticated = isAuthenticated
        let jpeg = try await PhotoProcessing.prepare(data, maxPixelSize: 512)
        guard activeUserID == ownerID, isAuthenticated == wasAuthenticated else {
            throw CancellationError()
        }
        try cachePhoto(jpeg, photoID: photoID)
        photoRevisions[photoID, default: 0] += 1
        profilePhoto = UIImage(data: jpeg)
        if let userID = activeUserID {
            try await dependencies.remote.savePhoto(jpeg, userID: userID, photoID: photoID)
        }
    }

    func removeProfilePhoto() throws {
        let photoID = "profile-photo"
        try deleteCachedPhoto(photoID: photoID)
        photoRevisions[photoID, default: 0] += 1
        profilePhoto = nil
        deleteRemotePhoto(photoID: photoID)
    }

    func setVehiclePhoto(_ data: Data, vehicleID: UUID) async throws {
        let ownerID = activeUserID
        let wasAuthenticated = isAuthenticated
        let jpeg = try await PhotoProcessing.prepare(data, maxPixelSize: 1200)
        guard activeUserID == ownerID, isAuthenticated == wasAuthenticated else {
            throw CancellationError()
        }
        try setPreparedVehiclePhoto(jpeg, vehicleID: vehicleID)
    }

    func setPreparedVehiclePhoto(_ jpeg: Data, vehicleID: UUID) throws {
        let photoID = vehiclePhotoID(vehicleID)
        try cachePhoto(jpeg, photoID: photoID)
        photoRevisions[photoID, default: 0] += 1
        vehiclePhotos[vehicleID] = UIImage(data: jpeg)
        uploadPhoto(jpeg, photoID: photoID)
    }

    func setExpenseReceipt(_ data: Data, expenseID: UUID) async throws {
        let ownerID = activeUserID
        let wasAuthenticated = isAuthenticated
        let jpeg = try await PhotoProcessing.prepare(data, maxPixelSize: 1200)
        guard activeUserID == ownerID, isAuthenticated == wasAuthenticated else {
            throw CancellationError()
        }
        let photoID = expenseReceiptPhotoID(expenseID)
        try cachePhoto(jpeg, photoID: photoID)
        photoRevisions[photoID, default: 0] += 1
        expenseReceiptPhotos[expenseID] = UIImage(data: jpeg)
        uploadPhoto(jpeg, photoID: photoID)
    }

    private func expenseReceiptPhotoID(_ expenseID: UUID) -> String {
        "expense-receipt-\(expenseID.uuidString)"
    }

    func refreshExpenseReceipt(_ expenseID: UUID) {
        let photoID = expenseReceiptPhotoID(expenseID)
        requestedPhotoIDs.remove(photoID)
        requestRemotePhoto(photoID: photoID)
    }

    func removeVehiclePhoto(vehicleID: UUID) throws {
        let photoID = vehiclePhotoID(vehicleID)
        try deleteCachedPhoto(photoID: photoID)
        photoRevisions[photoID, default: 0] += 1
        vehiclePhotos.removeValue(forKey: vehicleID)
        deleteRemotePhoto(photoID: photoID)
    }

    private func vehiclePhotoID(_ vehicleID: UUID) -> String {
        "vehicle-photo-\(vehicleID.uuidString)"
    }

    func saveDocumentScan(_ pages: [Data], documentID: UUID) throws {
        try dependencies.photoFiles.saveScanPages(
            pages, ownerID: activeUserID, documentID: documentID)
    }

    func documentScanPages(documentID: UUID) -> [UIImage] {
        dependencies.photoFiles.scanPages(ownerID: activeUserID, documentID: documentID)
            .compactMap(UIImage.init(data:))
    }

    func deleteDocumentScan(documentID: UUID) throws {
        try dependencies.photoFiles.deleteScanPages(
            ownerID: activeUserID, documentID: documentID)
    }

    private func cachePhoto(_ data: Data, photoID: String) throws {
        try dependencies.photoFiles.savePhoto(data, ownerID: activeUserID, photoID: photoID)
    }

    private func deleteCachedPhoto(photoID: String) throws {
        try dependencies.photoFiles.deletePhoto(ownerID: activeUserID, photoID: photoID)
    }

    private func refreshPhotos() {
        refreshProfilePhoto()
        refreshVehiclePhotos()
        refreshExpenseReceipts()
    }

    private func refreshProfilePhoto() {
        profilePhoto = dependencies.photoFiles.photoData(
            ownerID: activeUserID, photoID: "profile-photo").flatMap(UIImage.init(data:))
    }

    private func observeProfilePhoto(userID: String) {
        let photoID = "profile-photo"
        profilePhotoListener = dependencies.remote.observePhoto(
            userID: userID, photoID: photoID
        ) { [weak self] result in
            Task { @MainActor in
                guard let self, self.activeUserID == userID else { return }
                switch result {
                case .success(.image(let data)):
                    guard let image = UIImage(data: data) else { return }
                    try? self.cachePhoto(data, photoID: photoID)
                    self.profilePhoto = image
                case .success(.removed):
                    try? self.deleteCachedPhoto(photoID: photoID)
                    self.profilePhoto = nil
                case .success(.missing):
                    if let local = self.dependencies.photoFiles.photoData(
                        ownerID: userID, photoID: photoID)
                    {
                        self.uploadPhoto(local, photoID: photoID)
                    } else {
                        self.profilePhoto = nil
                    }
                case .failure(let error):
                    self.backendError = error.localizedDescription
                }
            }
        }
    }

    private func refreshVehiclePhotos() {
        var photos: [UUID: UIImage] = [:]
        for vehicle in vehicles {
            if let image = dependencies.photoFiles.photoData(
                ownerID: activeUserID, photoID: vehiclePhotoID(vehicle.id)
            ).flatMap(UIImage.init(data:)) {
                photos[vehicle.id] = image
            }
            requestRemotePhoto(photoID: vehiclePhotoID(vehicle.id))
        }
        vehiclePhotos = photos
    }

    private func refreshExpenseReceipts() {
        var photos: [UUID: UIImage] = [:]
        for expense in expenses where expense.hasReceipt == true {
            let photoID = expenseReceiptPhotoID(expense.id)
            if let image = dependencies.photoFiles.photoData(
                ownerID: activeUserID, photoID: photoID
            ).flatMap(UIImage.init(data:)) {
                photos[expense.id] = image
            }
            requestRemotePhoto(photoID: photoID)
        }
        expenseReceiptPhotos = photos
    }

    private func requestRemotePhoto(photoID: String) {
        guard let userID = activeUserID, requestedPhotoIDs.insert(photoID).inserted else { return }
        let revision = photoRevisions[photoID, default: 0]
        Task { [weak self, remote = dependencies.remote] in
            do {
                let result = try await remote.loadPhoto(
                    userID: userID, photoID: photoID)
                guard let self, self.activeUserID == userID,
                    self.photoRevisions[photoID, default: 0] == revision
                else { return }
                let image: UIImage?
                switch result {
                case .image(let data):
                    guard let decoded = UIImage(data: data) else { return }
                    try? self.cachePhoto(data, photoID: photoID)
                    image = decoded
                case .removed:
                    try? self.deleteCachedPhoto(photoID: photoID)
                    image = nil
                case .missing:
                    if photoID.hasPrefix("expense-receipt-"),
                        let local = self.dependencies.photoFiles.photoData(
                            ownerID: userID, photoID: photoID)
                    {
                        self.uploadPhoto(local, photoID: photoID)
                    }
                    return
                }
                if photoID == "profile-photo" {
                    self.profilePhoto = image
                } else if let vehicle = self.vehicles.first(where: {
                    self.vehiclePhotoID($0.id) == photoID
                }) {
                    self.vehiclePhotos[vehicle.id] = image
                } else if let expense = self.expenses.first(where: {
                    self.expenseReceiptPhotoID($0.id) == photoID
                }) {
                    self.expenseReceiptPhotos[expense.id] = image
                }
            } catch {
                if let self, self.activeUserID == userID {
                    self.requestedPhotoIDs.remove(photoID)
                }
            }
        }
    }

    private func uploadPhoto(_ data: Data, photoID: String) {
        guard let userID = activeUserID else { return }
        Task { [weak self, remote = dependencies.remote] in
            do {
                try await remote.savePhoto(data, userID: userID, photoID: photoID)
            } catch {
                if self?.activeUserID == userID { self?.backendError = error.localizedDescription }
            }
        }
    }

    private func deleteRemotePhoto(photoID: String) {
        guard let userID = activeUserID else { return }
        Task { [weak self, remote = dependencies.remote] in
            do {
                try await remote.deletePhoto(userID: userID, photoID: photoID)
            } catch {
                if self?.activeUserID == userID { self?.backendError = error.localizedDescription }
            }
        }
    }

    func publishListing(_ item: MarketplaceItem) async throws {
        guard let userID = activeUserID else { throw BackendError.signInRequired }
        var listing = item
        listing.sellerID = userID
        try await dependencies.remote.publishListing(listing, userID: userID)
        guard activeUserID == userID, !isSigningOut else { return }
        recordPublishConfirmation(kind: .listing, itemID: listing.id, preview: listing.title)
    }

    func canDeleteListing(_ item: MarketplaceItem) -> Bool {
        activeUserID != nil && item.sellerID == activeUserID
    }

    func isListingSaved(_ item: MarketplaceItem) -> Bool {
        savedMarketplaceItemIDs.contains(item.id)
    }

    func toggleSavedListing(_ item: MarketplaceItem) {
        if savedMarketplaceItemIDs.contains(item.id) {
            savedMarketplaceItemIDs.remove(item.id)
        } else {
            savedMarketplaceItemIDs.insert(item.id)
        }
        persist()
    }

    func updateListing(_ item: MarketplaceItem) async throws {
        guard let userID = activeUserID else { throw BackendError.signInRequired }
        guard canDeleteListing(item) else { throw BackendError.notOwner }
        try await dependencies.remote.updateListing(item, userID: userID)
        showSuccess = "Listing updated"
    }

    func deleteListing(_ item: MarketplaceItem) async throws {
        guard let userID = activeUserID else { throw BackendError.signInRequired }
        guard item.sellerID == userID else { throw BackendError.notOwner }
        try await dependencies.remote.deleteListing(id: item.id, userID: userID)
        savedMarketplaceItemIDs.remove(item.id)
        persist()
        showSuccess = "Listing deleted"
    }

    private var shouldRegisterPush: Bool {
        isFirebaseConfigured && activeUserID != nil && !isSigningOut
            && notificationsEnabled && notificationPermissionState.allowsAlerts
    }

    private func pushRegistrationKey(for userID: String) -> String {
        "smart-vehicle-push-installation-\(userID)"
    }

    private func storedPushRegistration(for userID: String) -> String? {
        dependencies.local.data(forKey: pushRegistrationKey(for: userID))
            .flatMap { String(data: $0, encoding: .utf8) }
    }

    private func savePushRegistration(_ installationID: String) {
        guard shouldRegisterPush, apnsRegistered, let userID = activeUserID else { return }
        let previous = pushRegistrationSaveTask
        pushRegistrationSaveTask = Task { [weak self, remote = dependencies.remote] in
            await previous?.value
            guard let self, self.activeUserID == userID, self.shouldRegisterPush else { return }
            let oldInstallationID = self.storedPushRegistration(for: userID)
            do {
                try await remote.saveMessagingRegistration(installationID, userID: userID)
                self.dependencies.local.set(
                    Data(installationID.utf8), forKey: self.pushRegistrationKey(for: userID))
                if let oldInstallationID, oldInstallationID != installationID {
                    try? await remote.removeMessagingRegistration(oldInstallationID, userID: userID)
                }
                self.pushRegistrationError = nil
                self.isPushRegistered = true
                self.pushInstallationID = installationID
            } catch {
                self.pushRegistrationError = error.localizedDescription
            }
        }
    }

    private func reconcilePushRegistration() {
        guard isFirebaseConfigured else { return }
        let previous = pushLifecycleTask
        pushLifecycleTask = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            if self.shouldRegisterPush {
                self.pushWasActive = true
                self.dependencies.pushTokens.setAutoInitEnabled(true)
                guard self.apnsRegistered else {
                    self.dependencies.notificationPermissions.registerForRemoteNotifications()
                    return
                }
                do {
                    try await self.dependencies.pushTokens.register()
                    self.pushRegistrationError = nil
                } catch {
                    self.pushRegistrationError = error.localizedDescription
                }
            } else if self.pushWasActive
                || (self.activeUserID.map { self.storedPushRegistration(for: $0) } ?? nil) != nil
            {
                self.pushRegistrationError = nil
                await self.pushRegistrationSaveTask?.value
                if let userID = self.activeUserID,
                    let installationID = self.storedPushRegistration(for: userID)
                {
                    do {
                        try await self.dependencies.remote.removeMessagingRegistration(
                            installationID, userID: userID)
                        self.dependencies.local.removeObject(forKey: self.pushRegistrationKey(for: userID))
                    } catch {
                        self.pushRegistrationError = error.localizedDescription
                    }
                }
                self.dependencies.pushTokens.setAutoInitEnabled(false)
                self.dependencies.notificationPermissions.unregisterForRemoteNotifications()
                do {
                    try await self.dependencies.pushTokens.unregister()
                } catch {
                    self.pushRegistrationError = error.localizedDescription
                }
                self.pushWasActive = false
                self.apnsRegistered = false
                self.isPushRegistered = false
                self.pushInstallationID = nil
            }
        }
    }

    func load() {
        if let data = dependencies.local.data(forKey: "smart-vehicle-store"),
            let state = try? JSONDecoder().decode(StoreState.self, from: data)
        {
            vehicles = state.vehicles
            selectedVehicleID = state.selectedVehicleID
            maintenance = state.maintenance
            fuelRecords = state.fuelRecords
            expenses = state.expenses
            documents = state.documents
            posts = state.posts
            savedMarketplaceItemIDs = state.savedMarketplaceItemIDs ?? []
            localCommentsByPostID = state.localCommentsByPostID ?? [:]
            userName = state.userName
            userEmail = state.userEmail
            userPhone = state.userPhone ?? ""
            userCity = state.userCity ?? ""
            userAddress = state.userAddress ?? ""
            userPostalCode = state.userPostalCode ?? ""
            biometricEnabled = state.biometricEnabled
            notificationsEnabled = state.notificationsEnabled
            maintenanceNotifications = state.maintenanceNotifications ?? true
            documentNotifications = state.documentNotifications ?? true
            vehicleNotifications = state.vehicleNotifications ?? true
            appearance = state.appearance
            isAuthenticated = state.isAuthenticated
            onboardingCompleted = state.onboardingCompleted ?? true
            refreshPhotos()
            if reconcileVehicleMileage() {
                persist()
            } else {
                publishWidgetSnapshot()
            }
            return
        }
        seed()
        refreshPhotos()
        persist()
    }

    private func currentState() -> StoreState {
        StoreState(
            vehicles: vehicles, selectedVehicleID: selectedVehicleID, maintenance: maintenance,
            fuelRecords: fuelRecords, expenses: expenses, documents: documents,
            posts: isFirebaseConfigured ? [] : posts,
            savedMarketplaceItemIDs: savedMarketplaceItemIDs,
            localCommentsByPostID: isFirebaseConfigured ? [:] : localCommentsByPostID,
            userName: userName, userEmail: userEmail, userPhone: userPhone,
            userCity: userCity, userAddress: userAddress, userPostalCode: userPostalCode,
            biometricEnabled: biometricEnabled,
            notificationsEnabled: notificationsEnabled,
            maintenanceNotifications: maintenanceNotifications,
            documentNotifications: documentNotifications,
            vehicleNotifications: vehicleNotifications, appearance: appearance,
            isAuthenticated: isAuthenticated, onboardingCompleted: onboardingCompleted)
    }

    func persist() {
        if let data = try? JSONEncoder().encode(currentState()) {
            writeWidgetSnapshot(isAuthenticated ? data : nil)
            if let activeUserID {
                writeLocalCache(data, userID: activeUserID)
                hasUnsavedChanges = true
                saveRevision += 1
                let revision = saveRevision
                pendingSave?.cancel()
                pendingSave = Task { [weak self, remote = dependencies.remote] in
                    try? await Task.sleep(for: .milliseconds(350))
                    guard let self, !Task.isCancelled, self.activeUserID == activeUserID else {
                        return
                    }
                    do {
                        try await remote.saveGarage(data, userID: activeUserID)
                        if self.saveRevision == revision {
                            self.hasUnsavedChanges = false
                        }
                    } catch {
                        self.backendError = error.localizedDescription
                    }
                }
            } else if !isFirebaseConfigured {
                dependencies.local.set(data, forKey: "smart-vehicle-store")
            }
        }
    }

    func addMaintenance(_ record: MaintenanceRecord) {
        maintenance.insert(record, at: 0)
        if let index = vehicles.firstIndex(where: { $0.id == record.vehicleID }) {
            if record.status == "Scheduled" {
                // A future booking must not change the vehicle's current odometer.
                // It becomes the upcoming service shown on the dashboard instead.
                vehicles[index].nextServiceMileage = max(
                    vehicles[index].mileage,
                    record.nextServiceMileage ?? record.mileage
                )
                vehicles[index].nextServiceDate = record.date
            } else {
                updateVehicleMileage(vehicleID: record.vehicleID, reading: record.mileage)
                let distance = vehicles[index].serviceMileageInterval ?? 5_000
                let months = vehicles[index].serviceMonthInterval ?? 6
                vehicles[index].nextServiceMileage = record.nextServiceMileage
                    ?? (record.mileage + distance)
                vehicles[index].nextServiceDate = record.nextReminder
                    ?? Calendar.current.date(byAdding: .month, value: months, to: record.date)
                    ?? record.date
            }
        }
        persist()
        refreshLocalReminders()
        showSuccess = record.status == "Scheduled"
            ? "Future maintenance scheduled"
            : "Maintenance saved"
    }
    func addFuel(_ record: FuelRecord) {
        let previousMileage = vehicles.first(where: { $0.id == record.vehicleID })?.mileage ?? 0
        fuelRecords.insert(record, at: 0)
        updateVehicleMileage(vehicleID: record.vehicleID, reading: record.mileage)
        persist()
        showSuccess =
            record.mileage > previousMileage
            ? "Fuel saved. Odometer updated to \(record.mileage.formatted()) km."
            : "Fuel record saved"
    }
    func addExpense(_ record: ExpenseRecord) {
        expenses.insert(record, at: 0)
        updateVehicleMileage(vehicleID: record.vehicleID, reading: record.mileage)
        persist()
        showSuccess = "Expense saved"
    }
    func addDocument(_ document: VehicleDocument) {
        documents.insert(document, at: 0)
        persist()
        refreshLocalReminders()
        showSuccess = "Document saved"
    }
    func hasDuplicateVehicle(
        registration: String,
        vin: String = "",
        excluding vehicleID: UUID? = nil
    ) -> Bool {
        let normalizedRegistration = normalizedVehicleIdentifier(registration)
        let normalizedVIN = normalizedVehicleIdentifier(vin)

        return vehicles.contains { vehicle in
            guard vehicle.id != vehicleID else { return false }
            let registrationMatches = !normalizedRegistration.isEmpty
                && normalizedVehicleIdentifier(vehicle.registration) == normalizedRegistration
            let vinMatches = !normalizedVIN.isEmpty
                && normalizedVehicleIdentifier(vehicle.vin) == normalizedVIN
            return registrationMatches || vinMatches
        }
    }

    @discardableResult
    func addVehicle(_ vehicle: Vehicle) -> Bool {
        guard !hasDuplicateVehicle(registration: vehicle.registration, vin: vehicle.vin) else {
            backendError = "This vehicle is already in your garage."
            return false
        }
        vehicles.append(vehicle)
        selectedVehicleID = vehicle.id
        persist()
        refreshLocalReminders()
        showSuccess = "Vehicle added"
        return true
    }

    private func normalizedVehicleIdentifier(_ value: String) -> String {
        value.uppercased().filter { $0.isLetter || $0.isNumber }
    }
    func updateVehicle(_ vehicle: Vehicle) {
        if let index = vehicles.firstIndex(where: { $0.id == vehicle.id }) {
            vehicles[index] = vehicle
        }
        reconcileVehicleMileage()
        persist()
        refreshLocalReminders()
    }
    func deleteVehicle(_ vehicle: Vehicle) {
        guard vehicles.contains(where: { $0.id == vehicle.id }) else { return }

        let vehicleID = vehicle.id
        let previousSelectedVehicleID = selectedVehicleID
        let vehicleIndex = vehicles.firstIndex(where: { $0.id == vehicleID }) ?? vehicles.endIndex
        let relatedMaintenance = maintenance.filter { $0.vehicleID == vehicleID }
        let relatedFuel = fuelRecords.filter { $0.vehicleID == vehicleID }
        let relatedExpenses = expenses.filter { $0.vehicleID == vehicleID }
        let relatedDocuments = documents.filter { $0.vehicleID == vehicleID }
        let vehiclePhoto = vehiclePhotos[vehicleID]
        let receiptPhotos = Dictionary(
            uniqueKeysWithValues: relatedExpenses.compactMap { expense in
                expenseReceiptPhotos[expense.id].map { (expense.id, $0) }
            })
        let photoIDs = [vehiclePhotoID(vehicleID)]
            + relatedExpenses.map { expenseReceiptPhotoID($0.id) }

        vehicles.removeAll { $0.id == vehicleID }
        maintenance.removeAll { $0.vehicleID == vehicleID }
        fuelRecords.removeAll { $0.vehicleID == vehicleID }
        expenses.removeAll { $0.vehicleID == vehicleID }
        documents.removeAll { $0.vehicleID == vehicleID }
        vehiclePhotos.removeValue(forKey: vehicleID)
        for expense in relatedExpenses {
            expenseReceiptPhotos.removeValue(forKey: expense.id)
        }

        if selectedVehicleID == vehicleID
            || !vehicles.contains(where: { $0.id == selectedVehicleID })
        {
            selectedVehicleID = vehicles.first?.id
        }
        persist()
        refreshLocalReminders()
        stageUndo(
            message: "Vehicle deleted",
            undo: { [weak self] in
                guard let self else { return }
                let insertionIndex = min(vehicleIndex, self.vehicles.endIndex)
                self.vehicles.insert(vehicle, at: insertionIndex)
                self.maintenance.append(contentsOf: relatedMaintenance)
                self.fuelRecords.append(contentsOf: relatedFuel)
                self.expenses.append(contentsOf: relatedExpenses)
                self.documents.append(contentsOf: relatedDocuments)
                if let vehiclePhoto { self.vehiclePhotos[vehicleID] = vehiclePhoto }
                for (id, photo) in receiptPhotos { self.expenseReceiptPhotos[id] = photo }
                self.selectedVehicleID = previousSelectedVehicleID ?? vehicleID
                self.persist()
                self.refreshLocalReminders()
                self.showSuccess = "Vehicle restored"
            },
            commit: { [weak self] in
                guard let self else { return }
                for photoID in photoIDs {
                    try? self.deleteCachedPhoto(photoID: photoID)
                    self.photoRevisions[photoID, default: 0] += 1
                    self.requestedPhotoIDs.remove(photoID)
                    self.deleteRemotePhoto(photoID: photoID)
                }
                for document in relatedDocuments {
                    try? self.dependencies.photoFiles.deleteScanPages(
                        ownerID: self.activeUserID, documentID: document.id)
                }
            }
        )
    }

    func deleteMaintenance(_ record: MaintenanceRecord) {
        guard maintenance.contains(where: { $0.id == record.id }) else { return }
        maintenance.removeAll { $0.id == record.id }
        persist()
        refreshLocalReminders()
        stageUndo(message: "Maintenance record deleted") { [weak self] in
            guard let self, !self.maintenance.contains(where: { $0.id == record.id }) else { return }
            self.maintenance.append(record)
            self.persist()
            self.refreshLocalReminders()
            self.showSuccess = "Maintenance record restored"
        }
    }

    func deleteFuelRecord(_ record: FuelRecord) {
        guard fuelRecords.contains(where: { $0.id == record.id }) else { return }
        fuelRecords.removeAll { $0.id == record.id }
        persist()
        stageUndo(message: "Fuel record deleted") { [weak self] in
            guard let self, !self.fuelRecords.contains(where: { $0.id == record.id }) else { return }
            self.fuelRecords.append(record)
            self.persist()
            self.showSuccess = "Fuel record restored"
        }
    }

    func deleteExpense(_ record: ExpenseRecord) {
        guard expenses.contains(where: { $0.id == record.id }) else { return }
        let receiptPhoto = expenseReceiptPhotos[record.id]
        let photoID = expenseReceiptPhotoID(record.id)
        expenses.removeAll { $0.id == record.id }
        expenseReceiptPhotos.removeValue(forKey: record.id)
        persist()
        stageUndo(
            message: "Expense deleted",
            undo: { [weak self] in
                guard let self, !self.expenses.contains(where: { $0.id == record.id }) else { return }
                self.expenses.append(record)
                if let receiptPhoto { self.expenseReceiptPhotos[record.id] = receiptPhoto }
                self.persist()
                self.showSuccess = "Expense restored"
            },
            commit: { [weak self] in
                guard let self else { return }
                try? self.deleteCachedPhoto(photoID: photoID)
                self.photoRevisions[photoID, default: 0] += 1
                self.requestedPhotoIDs.remove(photoID)
                self.deleteRemotePhoto(photoID: photoID)
            }
        )
    }

    func deleteDocument(_ document: VehicleDocument) {
        guard documents.contains(where: { $0.id == document.id }) else { return }
        documents.removeAll { $0.id == document.id }
        persist()
        refreshLocalReminders()
        stageUndo(
            message: "Document deleted",
            undo: { [weak self] in
                guard let self, !self.documents.contains(where: { $0.id == document.id }) else {
                    return
                }
                self.documents.append(document)
                self.persist()
                self.refreshLocalReminders()
                self.showSuccess = "Document restored"
            },
            commit: { [weak self] in
                guard let self else { return }
                try? self.dependencies.photoFiles.deleteScanPages(
                    ownerID: self.activeUserID, documentID: document.id)
            }
        )
    }
    func toggleLike(_ post: CommunityPost) {
        guard !pendingLikePostIDs.contains(post.id) else { return }
        if isFirebaseConfigured {
            guard let userID = activeUserID else { return }
            let shouldLike = !post.isLiked
            let actorName = userName
            pendingLikePostIDs.insert(post.id)
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index].isLiked = shouldLike
                posts[index].likes = max(0, posts[index].likes + (shouldLike ? 1 : -1))
            }
            Task { [weak self, remote = dependencies.remote] in
                do {
                    try await remote.setPostLiked(
                        shouldLike, postID: post.id, userID: userID, actorName: actorName)
                } catch {
                    guard let self, self.activeUserID == userID else { return }
                    if let index = self.posts.firstIndex(where: { $0.id == post.id }) {
                        self.posts[index].isLiked = post.isLiked
                        self.posts[index].likes = post.likes
                    }
                    self.backendError = error.localizedDescription
                }
                if self?.activeUserID == userID { self?.pendingLikePostIDs.remove(post.id) }
            }
            return
        }
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
        posts[index].isLiked.toggle()
        posts[index].likes += posts[index].isLiked ? 1 : -1
        persist()
    }
    func addPost(_ post: CommunityPost) async throws {
        var post = post
        post.createdAt = post.createdAt ?? Date()
        if isFirebaseConfigured {
            guard let userID = activeUserID else { throw BackendError.signInRequired }
            var publishedPost = post
            publishedPost.authorID = userID
            try await dependencies.remote.publishPost(publishedPost, userID: userID)
            guard activeUserID == userID, !isSigningOut else { return }
            recordPublishConfirmation(kind: .post, itemID: post.id, preview: post.text)
            showSuccess = "Post published"
            return
        }
        var localPost = post
        localPost.authorID = "local-demo"
        posts.insert(localPost, at: 0)
        persist()
        recordPublishConfirmation(kind: .post, itemID: post.id, preview: post.text)
        showSuccess = "Post published"
    }

    func canDeletePost(_ post: CommunityPost) -> Bool {
        let ownerID = activeUserID ?? (isFirebaseConfigured ? nil : "local-demo")
        return ownerID != nil && post.authorID == ownerID
    }

    func updatePost(_ post: CommunityPost) async throws {
        guard canDeletePost(post) else { throw BackendError.notOwner }
        if isFirebaseConfigured {
            guard let userID = activeUserID else { throw BackendError.signInRequired }
            try await dependencies.remote.updatePost(post, userID: userID)
        } else if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index] = post
            persist()
        }
        showSuccess = "Post updated"
    }

    func deletePost(_ post: CommunityPost) async throws {
        guard canDeletePost(post) else { throw BackendError.notOwner }
        if isFirebaseConfigured {
            guard let userID = activeUserID else { throw BackendError.signInRequired }
            try await dependencies.remote.deletePost(id: post.id, userID: userID)
        } else {
            posts.removeAll { $0.id == post.id }
            localCommentsByPostID.removeValue(forKey: post.id)
            persist()
        }
        showSuccess = "Post deleted"
    }

    func publishComment(_ comment: CommunityComment, postID: UUID) async throws {
        guard let userID = currentUserID else { throw BackendError.signInRequired }
        var comment = comment
        comment.authorID = userID
        comment.createdAt = comment.createdAt ?? Date()
        if isFirebaseConfigured {
            try await dependencies.remote.publishComment(comment, postID: postID, userID: userID)
        } else {
            localCommentsByPostID[postID, default: []].append(comment)
            if let index = posts.firstIndex(where: { $0.id == postID }) {
                posts[index].comments = localCommentsByPostID[postID]?.count ?? 0
            }
            persist()
        }
    }

    func comments(for postID: UUID) -> [CommunityComment] {
        localCommentsByPostID[postID] ?? []
    }

    func refreshCommunityNotifications() {
        communityNotificationsListener?.cancel()
        communityNotificationsListener = nil
        guard isFirebaseConfigured, let userID = activeUserID else { return }
        communityNotificationError = nil
        communityNotificationsListener = dependencies.remote.observeCommunityNotifications(
            userID: userID
        ) { [weak self] result in
            Task { @MainActor in
                guard let self, self.activeUserID == userID else { return }
                switch result {
                case .success(let notifications):
                    self.communityNotifications = notifications
                    self.communityNotificationError = nil
                case .failure(let error):
                    self.communityNotificationError =
                        "Could not load community notifications. \(error.localizedDescription)"
                }
            }
        }
    }

    private func loadPublishConfirmations() {
        guard let userID = currentUserID, isAuthenticated else { return }
        publishConfirmations = dependencies.local.data(forKey: "publish-confirmations-\(userID)")
            .flatMap { try? JSONDecoder().decode([PublishConfirmation].self, from: $0) } ?? []
    }

    private func savePublishConfirmations() {
        guard let userID = currentUserID,
            let data = try? JSONEncoder().encode(publishConfirmations) else { return }
        dependencies.local.set(data, forKey: "publish-confirmations-\(userID)")
    }

    private func recordPublishConfirmation(
        kind: PublishConfirmation.Kind, itemID: UUID, preview: String
    ) {
        guard isAuthenticated, !isSigningOut else { return }
        let id = "\(kind.rawValue)-\(itemID.uuidString)"
        guard !publishConfirmations.contains(where: { $0.id == id }) else { return }
        publishConfirmations.insert(PublishConfirmation(
            id: id, kind: kind, itemID: itemID, preview: String(preview.prefix(160)),
            createdAt: Date()), at: 0)
        publishConfirmations = Array(publishConfirmations.prefix(100))
        savePublishConfirmations()
    }

    func markPublishConfirmationRead(_ confirmation: PublishConfirmation) {
        guard let index = publishConfirmations.firstIndex(where: { $0.id == confirmation.id })
        else { return }
        publishConfirmations[index].isRead = true
        savePublishConfirmations()
    }

    func markCommunityNotificationRead(_ notification: CommunityNotification) {
        guard !notification.isRead else { return }
        if let index = communityNotifications.firstIndex(where: { $0.id == notification.id }) {
            communityNotifications[index].isRead = true
        }
        guard isFirebaseConfigured, let userID = activeUserID else { return }
        Task { [weak self, remote = dependencies.remote] in
            do {
                try await remote.markCommunityNotificationRead(
                    id: notification.id, userID: userID)
            } catch {
                guard let self, self.activeUserID == userID else { return }
                if let index = self.communityNotifications.firstIndex(where: {
                    $0.id == notification.id
                }) {
                    self.communityNotifications[index].isRead = false
                }
                self.backendError = error.localizedDescription
            }
        }
    }

    func canDeleteComment(_ comment: CommunityComment) -> Bool {
        comment.authorID == currentUserID
    }

    func deleteComment(_ comment: CommunityComment, postID: UUID) async throws {
        guard let userID = currentUserID else { throw BackendError.signInRequired }
        guard canDeleteComment(comment) else { throw BackendError.notOwner }
        if isFirebaseConfigured {
            try await dependencies.remote.deleteComment(
                id: comment.id, postID: postID, userID: userID)
        } else {
            localCommentsByPostID[postID]?.removeAll { $0.id == comment.id }
            if let index = posts.firstIndex(where: { $0.id == postID }) {
                posts[index].comments = localCommentsByPostID[postID]?.count ?? 0
            }
            persist()
        }
    }

    func observeComments(
        postID: UUID, onChange: @escaping (Result<[CommunityComment], Error>) -> Void
    ) -> ObservationToken {
        dependencies.remote.observeComments(postID: postID, onChange: onChange)
    }

    func authenticateBiometric(
        completion: @escaping (Result<Void, DeviceAuthenticationFailure>) -> Void
    ) {
        evaluateDeviceAuthentication(
            requiresBiometrics: true,
            reason: "Enable biometric protection for your garage",
            completion: completion)
    }

    func lockBiometricSession() {
        biometricLockGeneration += 1
        biometricUnlocked = false
    }

    func unlockWithDeviceAuthentication(
        completion: @escaping (Result<Void, DeviceAuthenticationFailure>) -> Void
    ) {
        guard isAuthenticated, !isSigningOut, biometricEnabled else {
            completion(.failure(.interrupted))
            return
        }
        evaluateDeviceAuthentication(
            requiresBiometrics: false,
            reason: "Unlock your vehicle information",
            completion: completion)
    }

    private func evaluateDeviceAuthentication(
        requiresBiometrics: Bool, reason: String,
        completion: @escaping (Result<Void, DeviceAuthenticationFailure>) -> Void
    ) {
        guard isAuthenticated, !isSigningOut else {
            completion(.failure(.interrupted))
            return
        }
        let generation = biometricLockGeneration
        dependencies.deviceAuthentication.evaluate(
            requiresBiometrics: requiresBiometrics, reason: reason
        ) { success, error in
            Task { @MainActor in
                guard generation == self.biometricLockGeneration,
                    self.isAuthenticated, !self.isSigningOut else {
                    completion(.failure(.interrupted))
                    return
                }
                if success {
                    self.biometricUnlocked = true
                    completion(.success(()))
                } else {
                    completion(.failure(
                        self.authenticationFailure(error, requiresBiometrics: requiresBiometrics)
                    ))
                }
            }
        }
    }

    private func authenticationFailure(
        _ error: NSError?, requiresBiometrics: Bool
    ) -> DeviceAuthenticationFailure {
        guard let error else {
            return .failed("Authentication failed. Please try again.")
        }
        switch LAError.Code(rawValue: error.code) {
        case .biometryNotEnrolled:
            return .unavailable("Set up Face ID or Touch ID in device Settings, then try again.")
        case .biometryNotAvailable:
            return .unavailable(
                "Face ID or Touch ID is unavailable. Check the app's biometric permission in device Settings."
            )
        case .biometryLockout:
            return .unavailable(
                "Biometrics are temporarily locked. Unlock your device with its passcode, then try again."
            )
        case .passcodeNotSet:
            return .unavailable("Set a device passcode in Settings, then try again.")
        case .userCancel, .appCancel, .systemCancel:
            return .cancelled
        case .authenticationFailed:
            return .failed("Authentication did not match. Please try again.")
        default:
            return .failed(
                requiresBiometrics
                    ? "Face ID or Touch ID could not be used. Check device Settings and try again."
                    : "Device authentication failed. Try again with Face ID or your device passcode."
            )
        }
    }

    var biometricUnlockTitle: String { dependencies.deviceAuthentication.unlockTitle }

    func notificationPreferencesChanged() {
        persist()
        updateNotificationBadge()
        refreshLocalReminders()
        reconcilePushRegistration()
    }

    func refreshLocalReminders() {
        guard isAuthenticated, notificationsEnabled else {
            dependencies.reminders.clear()
            return
        }
        let now = Date()
        var reminders: [ScheduledReminder] = []
        if maintenanceNotifications {
            reminders += maintenance.compactMap { record in
                guard let date = record.nextReminder, date > now else { return nil }
                return ScheduledReminder(
                    id: "maintenance.\(record.id.uuidString)", title: "Service reminder",
                    body: "Your \(record.type.lowercased()) is coming up.", date: date)
            }
        }
        if documentNotifications {
            reminders += documents.compactMap { document in
                guard document.expiryDate > now else { return nil }
                let leadDate = Calendar.current.date(
                    byAdding: .day, value: -30, to: document.expiryDate) ?? document.expiryDate
                let date = leadDate > now ? leadDate : document.expiryDate
                return ScheduledReminder(
                    id: "document.\(document.id.uuidString)", title: "Document expiring soon",
                    body: "Your \(document.type.lowercased()) expires on \(document.expiryDate.shortDate).",
                    date: date)
            }
        }
        if vehicleNotifications {
            reminders += vehicles.compactMap { vehicle in
                let hasScheduledService = maintenance.contains {
                    $0.vehicleID == vehicle.id
                        && $0.status == "Scheduled"
                        && $0.date > now
                }
                guard vehicle.nextServiceDate > now, !hasScheduledService else { return nil }
                return ScheduledReminder(
                    id: "vehicle.\(vehicle.id.uuidString)", title: "Vehicle service due",
                    body: "\(vehicle.title) is due for service.", date: vehicle.nextServiceDate)
            }
        }
        dependencies.reminders.replace(with: reminders)
    }

    func refreshNotificationPermission() {
        dependencies.notificationPermissions.check { [weak self] state in
            Task { @MainActor in
                guard let self else { return }
                self.notificationPermissionState = state
                self.updateNotificationBadge()
                self.refreshLocalReminders()
                self.reconcilePushRegistration()
            }
        }
    }

    func requestNotificationPermission(
        _ completion: @escaping (NotificationPermissionState) -> Void
    ) {
        dependencies.notificationPermissions.request { [weak self] state in
            Task { @MainActor in
                self?.notificationPermissionState = state
                self?.updateNotificationBadge()
                self?.refreshLocalReminders()
                self?.reconcilePushRegistration()
                completion(state)
            }
        }
    }

    private func updateNotificationBadge() {
        let count = isAuthenticated && notificationsEnabled ? unreadNotificationCount : 0
        dependencies.notificationPermissions.setBadgeCount(count)
        presentUnreadCommunityAlert()
    }

    private func presentUnreadCommunityAlert() {
        guard let userID = activeUserID, isAuthenticated, !isSigningOut, notificationsEnabled,
            notificationPermissionState.allowsAlerts,
            UIApplication.shared.applicationState == .active else { return }
        let key = "smart-vehicle-announced-notifications-\(userID)"
        let announced = dependencies.local.data(forKey: key)
            .flatMap { try? JSONDecoder().decode(Set<String>.self, from: $0) } ?? []
        let pending = communityNotifications.filter { !$0.isRead && !announced.contains($0.id) }
        guard let latest = pending.max(by: { $0.createdAt < $1.createdAt }) else { return }
        // Show only the latest missed activity instead of flooding the user on sign-in.
        let ids = announced.union(communityNotifications.map(\.id))
        if let data = try? JSONEncoder().encode(ids) {
            dependencies.local.set(data, forKey: key)
        }
        dependencies.notificationPermissions.presentCommunityAlert(latest, userID: userID)
    }

    private func seed() {
        let id = UUID()
        selectedVehicleID = id
        let calendar = Calendar.current
        vehicles = [
            Vehicle(
                id: id, make: "Toyota", model: "Corolla", year: 2022, registration: "CAB-2846",
                mileage: 28450, fuel: "Petrol", color: "Celestial Silver", image: "car.side.fill",
                nextServiceMileage: 30000,
                nextServiceDate: calendar.date(byAdding: .day, value: 24, to: Date())!,
                vin: "JTDBR32E720123456", engine: "1.8L 4-Cylinder", transmission: "CVT")
        ]
        maintenance = [
            MaintenanceRecord(
                vehicleID: id, type: "Oil & filter change",
                date: calendar.date(byAdding: .day, value: -32, to: Date())!, mileage: 26400,
                cost: 14500, notes: "Synthetic oil, filter replaced"),
            MaintenanceRecord(
                vehicleID: id, type: "Tire rotation",
                date: calendar.date(byAdding: .day, value: -82, to: Date())!, mileage: 23800,
                cost: 4500, notes: "Rotation and pressure check"),
            MaintenanceRecord(
                vehicleID: id, type: "Brake inspection",
                date: calendar.date(byAdding: .day, value: -150, to: Date())!, mileage: 21100,
                cost: 3200, notes: "Pads at 60% remaining"),
        ]
        fuelRecords = [
            FuelRecord(
                vehicleID: id, date: calendar.date(byAdding: .day, value: -3, to: Date())!,
                mileage: 28310, liters: 32.4, pricePerLiter: 365, station: "Ceypetco · Colombo 07"),
            FuelRecord(
                vehicleID: id, date: calendar.date(byAdding: .day, value: -12, to: Date())!,
                mileage: 27940, liters: 30.1, pricePerLiter: 365, station: "IOC · Rajagiriya"),
            FuelRecord(
                vehicleID: id, date: calendar.date(byAdding: .day, value: -23, to: Date())!,
                mileage: 27580, liters: 34.0, pricePerLiter: 365, station: "Ceypetco · Colombo 05"),
        ]
        expenses = [
            ExpenseRecord(
                vehicleID: id, title: "Annual insurance", category: "Insurance",
                date: calendar.date(byAdding: .day, value: -40, to: Date())!, mileage: 25900,
                amount: 48500, notes: "Full cover renewal"),
            ExpenseRecord(
                vehicleID: id, title: "Parking · office", category: "Parking",
                date: calendar.date(byAdding: .day, value: -2, to: Date())!, mileage: 28390,
                amount: 1200, notes: "Monthly pass"),
        ]
        documents = [
            VehicleDocument(
                vehicleID: id, type: "Insurance", number: "INS-2025-08421",
                registration: "CAB-2846",
                issueDate: calendar.date(byAdding: .month, value: -8, to: Date())!,
                expiryDate: calendar.date(byAdding: .day, value: 18, to: Date())!,
                status: "Expiring Soon"),
            VehicleDocument(
                vehicleID: id, type: "Revenue Licence", number: "RL-WP-2025-44920",
                registration: "CAB-2846",
                issueDate: calendar.date(byAdding: .month, value: -4, to: Date())!,
                expiryDate: calendar.date(byAdding: .month, value: 8, to: Date())!, status: "Valid"),
            VehicleDocument(
                vehicleID: id, type: "Emission Certificate", number: "VET-25-72281",
                registration: "CAB-2846",
                issueDate: calendar.date(byAdding: .month, value: -13, to: Date())!,
                expiryDate: calendar.date(byAdding: .day, value: -5, to: Date())!, status: "Expired"
            ),
        ]
        posts = [
            CommunityPost(
                author: "Nimal Perera", initials: "NP", vehicle: "Honda Civic 2019", time: "2h ago",
                text:
                    "A light vibration through the steering wheel at highway speeds. Tire balancing fixed it for me — sharing in case anyone else runs into this.",
                category: "Solved", comments: 8, likes: 24, image: nil),
            CommunityPost(
                author: "Sarah Jay", initials: "SJ", vehicle: "Toyota Aqua 2021", time: "5h ago",
                text:
                    "Has anyone replaced their hybrid battery recently? Curious about trusted options and what to expect for cost.",
                category: "Question", comments: 12, likes: 16),
            CommunityPost(
                author: "Ruwan Silva", initials: "RS", vehicle: "Suzuki Swift 2020",
                time: "Yesterday",
                text:
                    "Sharing a simple checklist I use before long trips. Coolant, tyre pressure, lights, and keep an emergency kit in the boot.",
                category: "Tip", comments: 5, likes: 31),
        ]
    }
}

private struct StoreState: Codable {
    var vehicles: [Vehicle]
    var selectedVehicleID: UUID?
    var maintenance: [MaintenanceRecord]
    var fuelRecords: [FuelRecord]
    var expenses: [ExpenseRecord]
    var documents: [VehicleDocument]
    var posts: [CommunityPost]
    var savedMarketplaceItemIDs: Set<UUID>?
    var localCommentsByPostID: [UUID: [CommunityComment]]?
    var userName: String
    var userEmail: String
    var userPhone: String?
    var userCity: String?
    var userAddress: String?
    var userPostalCode: String?
    var biometricEnabled: Bool
    var notificationsEnabled: Bool
    var maintenanceNotifications: Bool?
    var documentNotifications: Bool?
    var vehicleNotifications: Bool?
    var appearance: String
    var isAuthenticated: Bool
    var onboardingCompleted: Bool?
}

enum BackendError: LocalizedError {
    case signInRequired
    case appleTokenMissing
    case notOwner
    case authenticationUnavailable
    case postUnavailable

    var errorDescription: String? {
        switch self {
        case .signInRequired: "Sign in before posting a listing."
        case .appleTokenMissing: "Apple sign-in did not return an identity token. Try again."
        case .notOwner: "Only the person who published this item can edit or delete it."
        case .postUnavailable: "This community post is no longer available."
        case .authenticationUnavailable:
            "Account services are unavailable because Firebase is not configured."
        }
    }
}

enum PhotoProcessing {
    enum Error: LocalizedError {
        case invalidImage
        case tooLarge

        var errorDescription: String? {
            switch self {
            case .invalidImage: "Could not read this photo. Choose another image."
            case .tooLarge: "This photo is too detailed to save. Choose a smaller image."
            }
        }
    }

    static func prepare(_ data: Data, maxPixelSize: Int) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            try jpegData(from: data, maxPixelSize: maxPixelSize)
        }
        .value
    }

    static func jpegData(from data: Data, maxPixelSize: Int, maxBytes: Int = 500_000) throws -> Data
    {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { throw Error.invalidImage }
        let image = UIImage(cgImage: thumbnail)
        for quality in [0.78, 0.58, 0.38] {
            if let jpeg = image.jpegData(compressionQuality: quality), jpeg.count <= maxBytes {
                return jpeg
            }
        }
        throw Error.tooLarge
    }
}
