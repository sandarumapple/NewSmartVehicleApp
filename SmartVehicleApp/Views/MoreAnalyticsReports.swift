import Charts
import PDFKit
import PhotosUI
import SwiftUI
import UIKit

struct MoreView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showDocumentScanner = false
    private let profileBlue = Color(red: 26 / 255, green: 107 / 255, blue: 1)
    private let profileGreen = Color(red: 16 / 255, green: 185 / 255, blue: 129 / 255)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                profileHero
                primaryVehicleSection
                overviewSection

                VStack(spacing: 22) {
                    profileGroup("Account") {
                        profileRow("Personal information", symbol: "person.crop.circle", tint: profileBlue) {
                            ProfileSettingsView()
                        }
                        profileRow("My vehicles", symbol: "car.side.fill", tint: profileBlue) {
                            VehicleListView()
                        }
                        profileRow("Security & privacy", symbol: "lock.shield", tint: profileGreen) {
                            SecuritySettingsView()
                        }
                    }
                    profileGroup("Vehicle management") {
                        profileRow("Documents", symbol: "doc.text", tint: profileBlue) {
                            DocumentsView()
                        }
                        profileRow("Maintenance history", symbol: "wrench.and.screwdriver", tint: .orange) {
                            MaintenanceListView()
                        }
                        profileRow("Vehicle reports", symbol: "doc.richtext", tint: .purple) {
                            ReportSetupView()
                        }
                        profileRow("Bills & spending", symbol: "receipt", tint: profileGreen) {
                            BillsView()
                        }
                        profileAction("Scan document", symbol: "doc.viewfinder", tint: profileBlue) {
                            showDocumentScanner = true
                        }
                    }
                    profileGroup("Community") {
                        profileRow("My community posts", symbol: "bubble.left.and.bubble.right", tint: profileBlue) {
                            CommunityView(showMyPosts: true)
                        }
                        profileRow("My marketplace listings", symbol: "bag", tint: .orange) {
                            MarketplaceView(showMyListings: true)
                        }
                    }
                    profileGroup("More") {
                        profileRow("Analytics", symbol: "chart.xyaxis.line", tint: profileBlue) {
                            AnalyticsView()
                        }
                        profileRow("Notification inbox", symbol: "bell", tint: .orange) {
                            NotificationCenterView()
                        }
                        profileRow("Nearby locations", symbol: "map", tint: profileGreen) {
                            NearbyMapView()
                        }
                    }
                }

                Button(role: .destructive) {
                    Task {
                        do { try await store.signOut() }
                        catch { store.backendError = error.localizedDescription }
                    }
                } label: {
                    Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 50)
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                }
                .disabled(store.isSigningOut)
                if store.isSigningOut { ProgressView("Signing out…").frame(maxWidth: .infinity) }
                VStack(spacing: 5) {
                    Text("Smart Garage · Version 1.0")
                    Label("Your account settings are protected", systemImage: "lock.shield")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(Color.appCanvas.ignoresSafeArea())
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .fullScreenCover(isPresented: $showDocumentScanner) {
            NavigationStack { DocumentScannerFlow(startWithCamera: true) }
        }
    }

    private var profileHero: some View {
        VStack(spacing: 10) {
            NavigationLink { ProfileSettingsView() } label: {
                ProfileAvatar(size: 96)
                    .padding(4)
                    .background(
                        LinearGradient(
                            colors: [profileBlue, .blue, profileGreen],
                            startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Circle())
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "pencil")
                            .font(.caption.bold()).foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(profileBlue, in: Circle())
                            .overlay(Circle().stroke(Color.appCanvas, lineWidth: 2))
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit profile photo and information")
            Text(store.userName).font(.title2.bold()).lineLimit(2)
            Text(store.userEmail).font(.caption).foregroundStyle(.secondary)
                .lineLimit(1).minimumScaleFactor(0.8)
            HStack(spacing: 8) {
                profileBadge("Garage member", symbol: "checkmark.seal", tint: profileBlue)
                if store.biometricEnabled {
                    profileBadge("App lock on", symbol: "lock.shield", tint: profileGreen)
                }
            }
            NavigationLink { ProfileSettingsView() } label: {
                Label("Edit profile", systemImage: "pencil")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(profileBlue)
                    .padding(.horizontal, 22).frame(minHeight: 38)
                    .background(profileBlue.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private func profileBadge(_ title: String, symbol: String, tint: Color) -> some View {
        Label(title, systemImage: symbol)
            .font(.caption2.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background(tint.opacity(0.1), in: Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(0.2)))
    }

    private var primaryVehicleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("My vehicles")
                Spacer()
                NavigationLink("View all") { VehicleListView() }
                    .font(.caption.weight(.semibold)).foregroundStyle(profileBlue)
            }
            if let vehicle = store.selectedVehicle {
                NavigationLink { VehicleDetailView(vehicle: vehicle) } label: {
                    VStack(spacing: 0) {
                        ZStack(alignment: .bottomLeading) {
                            ZStack {
                                LinearGradient(
                                    colors: [Color(red: 0.1, green: 0.18, blue: 0.31), Color.appCard],
                                    startPoint: .topLeading, endPoint: .bottomTrailing)
                                if let photo = store.vehiclePhotos[vehicle.id] {
                                    Image(uiImage: photo).resizable().scaledToFill()
                                } else if vehicle.model.localizedCaseInsensitiveContains("raize") {
                                    Image("ToyotaRaize").resizable().scaledToFill()
                                } else {
                                    Image(systemName: "car.side.fill")
                                        .font(.system(size: 92, weight: .ultraLight))
                                        .foregroundStyle(.white.opacity(0.55))
                                }
                            }
                            .frame(height: 190).clipped()
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.8)],
                                startPoint: .center, endPoint: .bottom)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(vehicle.title).font(.title3.bold()).foregroundStyle(.white)
                                Text(vehicle.registration).font(.caption).foregroundStyle(.white.opacity(0.8))
                            }
                            .padding(16)
                        }
                        .frame(height: 190)
                        .overlay(alignment: .topLeading) {
                            Label("PRIMARY VEHICLE", systemImage: "car.side.fill")
                                .font(.caption2.bold()).foregroundStyle(.white)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(.black.opacity(0.6), in: Capsule())
                                .padding(12)
                        }
                        HStack {
                            Text("\(vehicle.mileage.formatted()) km")
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Label(
                                serviceNeedsAttention(vehicle) ? "Service due soon" : "Service on track",
                                systemImage: "circle.fill"
                            )
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(serviceNeedsAttention(vehicle) ? .orange : profileGreen)
                        }
                        .padding(.horizontal, 16).frame(height: 49)
                    }
                    .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink { VehicleListView() } label: {
                    Label("Add your first vehicle", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity).frame(minHeight: 120)
                        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Account overview")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statCard("Vehicles", value: "\(store.vehicles.count)", symbol: "car.side.fill", tint: profileBlue) {
                    VehicleListView()
                }
                statCard("Documents", value: "\(store.documents.count)", symbol: "doc.text.fill", tint: .orange) {
                    DocumentsView()
                }
                statCard("Maintenance", value: "\(store.maintenance.count)", symbol: "wrench.fill", tint: profileGreen) {
                    MaintenanceListView()
                }
                statCard("Bills", value: "\(store.expenses.count + store.fuelRecords.count + store.maintenance.count)", symbol: "receipt.fill", tint: .purple) {
                    BillsView()
                }
            }
        }
    }

    private func serviceNeedsAttention(_ vehicle: Vehicle) -> Bool {
        vehicle.distanceToService <= 1_000
            || vehicle.nextServiceDate <= Date().addingTimeInterval(14 * 24 * 60 * 60)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased()).font(.caption.weight(.bold)).tracking(1.2)
            .foregroundStyle(.secondary).padding(.leading, 4)
    }

    private func statCard<Destination: View>(
        _ title: String, value: String, symbol: String, tint: Color,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol).font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint).frame(width: 34, height: 34)
                    .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 11))
                Text(value).font(.title2.bold()).foregroundStyle(.primary)
                Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 105, alignment: .leading)
            .padding(14)
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }

    private func profileGroup<Content: View>(
        _ title: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(title)
            VStack(spacing: 0, content: content)
                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func profileRow<Destination: View>(
        _ title: String, symbol: String, tint: Color,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            profileRowLabel(title, symbol: symbol, tint: tint)
        }
        .buttonStyle(.plain)
    }

    private func profileAction(
        _ title: String, symbol: String, tint: Color, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) { profileRowLabel(title, symbol: symbol, tint: tint) }
            .buttonStyle(.plain)
    }

    private func profileRowLabel(_ title: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 17, weight: .medium))
                .foregroundStyle(tint).frame(width: 36, height: 36)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
            Text(title).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14).frame(minHeight: 54)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.primary.opacity(0.06))
                .frame(height: 1).padding(.leading, 62)
        }
        .contentShape(Rectangle())
    }
}

struct ProfileAvatar: View {
    @EnvironmentObject private var store: AppStore
    var size: CGFloat = 50

    var body: some View {
        Group {
            if let photo = store.profilePhoto {
                Image(uiImage: photo).resizable().scaledToFill()
            } else {
                Text(String(store.userName.split(separator: " ").prefix(2).compactMap(\.first)))
                    .font(.system(size: size * 0.31, weight: .bold))
                    .foregroundStyle(Color.appAccent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: size, height: size)
        .background(Color.appMint)
        .clipShape(Circle())
        .accessibilityLabel("Profile photo")
    }
}

struct WidgetGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.appAccent)
                    .frame(width: 72, height: 72)
                    .background(Color.appMint, in: RoundedRectangle(cornerRadius: 18))
                Text("Your garage at a glance").font(.title2.bold())
                Text("The Smart Garage widget shows your selected vehicle, mileage, upcoming service, and document reminder.")
                    .font(.subheadline).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 14) {
                    Label("Touch and hold an empty area of your Home Screen.", systemImage: "1.circle.fill")
                    Label("Tap Edit, then Add Widget.", systemImage: "2.circle.fill")
                    Label("Search for Smart Garage and choose a widget size.", systemImage: "3.circle.fill")
                }
                .font(.subheadline)
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(20)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .background(Color.appCanvas.ignoresSafeArea())
        .navigationTitle("Home Screen widgets")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CameraPhotoPicker: UIViewControllerRepresentable {
    var onPhoto: (Data?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPhoto: onPhoto) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate,
        UINavigationControllerDelegate
    {
        let onPhoto: (Data?) -> Void

        init(onPhoto: @escaping (Data?) -> Void) { self.onPhoto = onPhoto }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            onPhoto((info[.originalImage] as? UIImage)?.jpegData(compressionQuality: 0.95))
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onPhoto(nil) }
    }
}

struct ProfileSettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var city = ""
    @State private var address = ""
    @State private var postalCode = ""
    @State private var error: String?
    @State private var isSavingProfile = false
    @State private var profileSaved = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isUpdatingPhoto = false
    @State private var showPhotoActions = false
    @State private var showPhotoLibrary = false
    @State private var showCamera = false
    var body: some View {
        let hasProfilePhoto = store.profilePhoto != nil
        Form {
            Section {
                VStack(spacing: 10) {
                    Button {
                        showPhotoActions = true
                    } label: {
                        ProfileAvatar(size: 104)
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 34, height: 34)
                                    .background(Color.appAccent, in: Circle())
                                    .overlay(Circle().stroke(.background, lineWidth: 3))
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(isUpdatingPhoto)
                    .accessibilityLabel(
                        hasProfilePhoto ? "Change profile photo" : "Add profile photo")
                    Text(store.userName).font(.headline)
                    Text(store.userEmail).font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                if isUpdatingPhoto { ProgressView("Saving photo…") }
            } header: {
                Text("Your profile")
            } footer: {
                Text(
                    store.isFirebaseConfigured
                        ? "Photos sync with your account and are cached on this device."
                        : "Photos are saved on this device in demo mode."
                )
            }
            Section {
                TextField("Full name", text: $name)
                    .textContentType(.name)
                TextField("Email", text: $email).keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(store.isFirebaseConfigured)
                TextField("Phone number", text: $phone).keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
            } header: {
                Text("Contact information")
            } footer: {
                if store.isFirebaseConfigured {
                    Text("Your email address is managed by your sign-in provider.")
                }
            }
            Section("Location") {
                TextField("City", text: $city).textInputAutocapitalization(.words)
                TextField("Street address", text: $address, axis: .vertical)
                    .lineLimit(1...3)
                    .textInputAutocapitalization(.words)
                TextField("Postal code", text: $postalCode)
                    .textInputAutocapitalization(.characters)
            }
            Section("Your garage") {
                LabeledContent("Vehicles", value: "\(store.vehicles.count)")
                LabeledContent("Active vehicle", value: store.selectedVehicle?.title ?? "None")
                LabeledContent("Documents", value: "\(store.documents.count)")
                NavigationLink("View all documents") { DocumentsView() }
                NavigationLink("View bills & spending") { BillsView() }
            }
            Section {
                Button("Save profile") {
                    Task {
                        isSavingProfile = true
                        defer { isSavingProfile = false }
                        do {
                            try await store.updateProfile(
                                name: name, email: email, phone: phone, city: city,
                                address: address, postalCode: postalCode)
                            name = store.userName
                            email = store.userEmail
                            phone = store.userPhone
                            city = store.userCity
                            address = store.userAddress
                            postalCode = store.userPostalCode
                            error = nil
                            profileSaved = true
                        } catch {
                            self.error = error.localizedDescription
                            profileSaved = false
                        }
                    }
                }
                .disabled(
                    isSavingProfile || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || !email.contains("@") || !hasUnsavedChanges)
                if isSavingProfile { ProgressView("Saving profile…") }
                if profileSaved && !hasUnsavedChanges {
                    Label("Profile updated", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            if let error { Text(error).foregroundStyle(.red) }
        }
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
        .navigationTitle("Profile").navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Profile photo", isPresented: $showPhotoActions) {
            Button("Choose from Library") { showPhotoLibrary = true }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { showCamera = true }
            }
            if hasProfilePhoto {
                Button("Remove Photo", role: .destructive) {
                    do {
                        try store.removeProfilePhoto()
                        error = nil
                    } catch { self.error = error.localizedDescription }
                }
            }
        }
        .photosPicker(isPresented: $showPhotoLibrary, selection: $selectedPhoto, matching: .images)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPhotoPicker { data in
                showCamera = false
                if let data { Task { await savePhoto(data) } }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            name = store.userName
            email = store.userEmail
            phone = store.userPhone
            city = store.userCity
            address = store.userAddress
            postalCode = store.userPostalCode
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                isUpdatingPhoto = true
                defer { isUpdatingPhoto = false }
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        throw PhotoProcessing.Error.invalidImage
                    }
                    await savePhoto(data)
                } catch { self.error = error.localizedDescription }
                selectedPhoto = nil
            }
        }
    }

    private var hasUnsavedChanges: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines) != store.userName
            || email.trimmingCharacters(in: .whitespacesAndNewlines) != store.userEmail
            || phone.trimmingCharacters(in: .whitespacesAndNewlines) != store.userPhone
            || city.trimmingCharacters(in: .whitespacesAndNewlines) != store.userCity
            || address.trimmingCharacters(in: .whitespacesAndNewlines) != store.userAddress
            || postalCode.trimmingCharacters(in: .whitespacesAndNewlines) != store.userPostalCode
    }

    private func savePhoto(_ data: Data) async {
        isUpdatingPhoto = true
        defer { isUpdatingPhoto = false }
        do {
            try await store.setProfilePhoto(data)
            error = nil
        } catch { self.error = error.localizedDescription }
    }
}
struct VehiclePreferencesView: View {
    @EnvironmentObject private var store: AppStore
    @State private var vehicleID: UUID?
    @State private var unit = "Kilometres (km)"
    var body: some View {
        Form {
            Section("Default vehicle") {
                Picker(
                    "Vehicle",
                    selection: Binding(
                        get: { vehicleID ?? store.selectedVehicle?.id },
                        set: {
                            vehicleID = $0
                            store.selectedVehicleID = $0
                            store.persist()
                        })
                ) { ForEach(store.vehicles) { Text($0.title).tag(Optional($0.id)) } }
            }
            Section("Units") {
                Picker("Distance", selection: $unit) {
                    Text("Kilometres (km)").tag("Kilometres (km)")
                    Text("Miles (mi)").tag("Miles (mi)")
                }
            }
            Section(footer: Text("Your selection is used for vehicle summaries and reminders.")) {
                EmptyView()
            }
        }
        .navigationTitle("Vehicle preferences").navigationBarTitleDisplayMode(.inline)
    }
}
struct SecuritySettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var error: String?
    @State private var isEnablingBiometrics = false
    var body: some View {
        Form {
            Section {
                Toggle(
                    "Require Face ID / Touch ID",
                    isOn: Binding(
                        get: { store.biometricEnabled },
                        set: { enabled in
                            if !enabled {
                                store.biometricEnabled = false
                                store.persist()
                                error = nil
                            } else {
                                guard !isEnablingBiometrics else { return }
                                isEnablingBiometrics = true
                                error = nil
                                store.authenticateBiometric { result in
                                    isEnablingBiometrics = false
                                    switch result {
                                    case .success:
                                        store.biometricEnabled = true
                                        store.persist()
                                    case .failure(let failure):
                                        error = failure.message
                                    }
                                }
                            }
                        }))
                    .disabled(isEnablingBiometrics)
                if isEnablingBiometrics {
                    ProgressView("Checking Face ID / Touch ID")
                }
            } footer: {
                Text("When enabled, authenticate to reopen the app after leaving it.")
            }
            if let error { Section { Text(error).foregroundStyle(.red) } }
            Section("Privacy") {
                Label("Biometric data stays on your device", systemImage: "lock.shield")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Security").navigationBarTitleDisplayMode(.inline)
    }
}
struct AppearanceSettingsView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $store.appearance) {
                    ForEach(["System", "Light", "Dark"], id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.inline)
            }
        }
        .navigationTitle("Appearance").navigationBarTitleDisplayMode(.inline)
        .onChange(of: store.appearance) { _, _ in store.persist() }
    }
}
struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        Form {
            Section("Preferences") {
                NavigationLink {
                    NotificationSettingsView()
                } label: {
                    Label("Notifications", systemImage: "bell.badge")
                }
                NavigationLink {
                    AppearanceSettingsView()
                } label: {
                    Label("Appearance", systemImage: "circle.lefthalf.filled")
                }
                NavigationLink {
                    WidgetGuideView()
                } label: {
                    Label("Home Screen widgets", systemImage: "square.grid.2x2")
                }
                NavigationLink {
                    VehiclePreferencesView()
                } label: {
                    Label("Units & region", systemImage: "speedometer")
                }
            }
            Section("Account") {
                LabeledContent("Email", value: store.userEmail)
                Label("Account", systemImage: "envelope.badge.shield.half.filled")
                Text(
                    store.isFirebaseConfigured
                        ? "Email is managed by your Firebase account."
                        : "Local demo mode is active until Firebase is configured."
                )
                .font(.caption).foregroundStyle(.secondary)
            }
            Section("Session") {
                Button("Sign out", role: .destructive) {
                    Task {
                        do {
                            try await store.signOut()
                        } catch {
                            store.backendError = error.localizedDescription
                        }
                    }
                }
                .disabled(store.isSigningOut)
                if store.isSigningOut { ProgressView("Signing out…") }
            }
        }
        .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
    }
}

private extension AnalyticsCategory {
    var color: Color {
        switch self {
        case .fuel: .appAccent
        case .maintenance: .orange
        case .other: .purple
        }
    }
}

private extension Color {
    static let analyticsBlue = Color(red: 26 / 255, green: 107 / 255, blue: 1)
}

struct AnalyticsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var range: AnalyticsRange = .sixMonths
    @AppStorage("smart-vehicle-analytics-range") private var savedRange = AnalyticsRange.sixMonths.rawValue
    @AppStorage("smart-vehicle-analytics-category") private var selectedCategory = "All"
    @State private var now = Date()

    private var viewModel: AnalyticsViewModel {
        AnalyticsViewModel(
            vehicle: store.selectedVehicle,
            fuelRecords: store.fuelRecords,
            maintenance: store.maintenance,
            expenses: store.expenses,
            range: range,
            selectedCategory: selectedCategory,
            now: now
        )
    }
    private var vehicle: Vehicle? { viewModel.vehicle }
    private var periodTransactions: [AnalyticsTransaction] { viewModel.periodTransactions }
    private var selectedTransactions: [AnalyticsTransaction] { viewModel.selectedTransactions }
    private var totalSpending: Double { viewModel.totalSpending }
    private func total(for category: AnalyticsCategory) -> Double { viewModel.total(for: category) }
    private var comparisonText: String { viewModel.comparisonText }
    private var spendingBuckets: [SpendingBucket] { viewModel.spendingBuckets }
    private var mileageReadings: [MileageReading] { viewModel.mileageReadings }
    private var recordedDistance: Int? { viewModel.recordedDistance }
    private var costPerKilometre: String { viewModel.costPerKilometre }
    private var fuelEfficiencyReadings: [FuelEfficiencyReading] {
        viewModel.fuelEfficiencyReadings
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 19) {
                ScreenHeading(
                    title: "Analytics",
                    subtitle: "Costs, mileage & vehicle health at a glance"
                )
                if let vehicle {
                    controls
                    summary
                    runningCostForecast
                    spendingChart
                    spendingBreakdown
                    fuelEfficiencyChart
                    mileageChart
                    insights(for: vehicle)
                    relatedRecords
                } else {
                    EmptyStateView(
                        symbol: "car.side", title: "No vehicle to analyse",
                        message: "Add a vehicle and records to see spending and mileage insights."
                    )
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
        }
        .background(Color.appCanvas.ignoresSafeArea()).appNavigationBar()
        .onAppear {
            now = Date()
            range = AnalyticsRange(rawValue: savedRange) ?? .sixMonths
        }
        .onChange(of: range) { _, value in savedRange = value.rawValue }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { now = Date() }
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Picker("Time range", selection: $range) {
                ForEach(AnalyticsRange.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)

            Menu {
                ForEach(store.vehicles) { car in
                    Button(car.title) {
                        store.selectedVehicleID = car.id
                        store.persist()
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "car.side.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.analyticsBlue)
                        .frame(width: 34, height: 34)
                        .background(Color.analyticsBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ACTIVE VEHICLE")
                            .font(.appBadge)
                            .tracking(0.7)
                            .foregroundStyle(.secondary)
                        Text(vehicle?.title ?? "Vehicle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    Spacer()
                    HStack(spacing: 5) {
                        Circle().fill(Color.appSuccess).frame(width: 6, height: 6)
                        Text("Synced").font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold)).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .frame(height: 54)
                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .contain)
    }

    private var summary: some View {
        VStack(spacing: 12) {
            HStack(spacing: 11) {
                analyticsMiniStat(
                    title: "Fuel",
                    value: compactMoney(total(for: .fuel)),
                    detail: "\(periodTransactions.filter { $0.category == .fuel }.count) fill-ups",
                    symbol: "fuelpump.fill",
                    tint: .blue
                )
                analyticsMiniStat(
                    title: "Maintenance",
                    value: compactMoney(total(for: .maintenance)),
                    detail: "\(periodTransactions.filter { $0.category == .maintenance }.count) records",
                    symbol: "wrench.and.screwdriver.fill",
                    tint: .green
                )
            }

            HStack(spacing: 12) {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.analyticsBlue)
                    .frame(width: 36, height: 36)
                    .background(Color.analyticsBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recorded distance").font(.caption).foregroundStyle(.secondary)
                    Text(recordedDistance.map { "\($0.formatted()) km" } ?? "—")
                        .font(.headline.weight(.bold)).monospacedDigit()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Cost per km").font(.caption2).foregroundStyle(.secondary)
                    Text(costPerKilometre)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.analyticsBlue)
                        .monospacedDigit()
                }
            }
            .padding(12)
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12))

            totalSpendHero
        }
        .padding(.horizontal, 20)
    }

    private var totalSpendHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("TOTAL SPEND", systemImage: "creditcard.fill")
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(comparisonText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(comparisonTint)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(comparisonTint.opacity(0.12), in: Capsule())
            }
            Text(money(totalSpending))
                .font(.largeTitle.bold())
                .tracking(-1)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .monospacedDigit()
            HStack {
                Text(range.title)
                Spacer()
                Text("\(periodTransactions.count) transactions")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background {
            ZStack(alignment: .bottomTrailing) {
                Color.appCard
                Circle()
                    .fill(Color.analyticsBlue.opacity(0.14))
                    .frame(width: 150, height: 150)
                    .blur(radius: 24)
                    .offset(x: 45, y: 70)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.analyticsBlue.opacity(0.18), lineWidth: 1)
        }
    }

    private var comparisonTint: Color {
        if comparisonText.hasPrefix("Down") { return .green }
        if comparisonText.hasPrefix("Up") { return .orange }
        return .secondary
    }

    private var runningCostForecast: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Running cost forecast").font(.subheadline.bold())
                Spacer()
                Text("Based on \(range.title.lowercased())")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            HStack(spacing: 11) {
                analyticsMiniStat(
                    title: "Monthly average",
                    value: compactMoney(viewModel.averageMonthlySpending),
                    detail: "Average running cost",
                    symbol: "calendar",
                    tint: .blue
                )
                analyticsMiniStat(
                    title: "Annual estimate",
                    value: compactMoney(viewModel.estimatedAnnualSpending),
                    detail: "At the current average",
                    symbol: "calendar.badge.clock",
                    tint: .purple
                )
            }
        }
        .padding(.horizontal, 20)
    }

    private func analyticsMiniStat(
        title: String, value: String, detail: String, symbol: String, tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title.uppercased())
                    .font(.appBadge)
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: symbol).font(.caption.weight(.semibold)).foregroundStyle(tint)
            }
            Text(value)
                .font(.headline.weight(.bold))
                .minimumScaleFactor(0.72)
                .lineLimit(1)
                .monospacedDigit()
            Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            Capsule().fill(tint.opacity(0.18)).frame(height: 4)
                .overlay(alignment: .leading) {
                    Capsule().fill(tint).frame(width: 48, height: 4)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12))
    }

    private var spendingChart: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Spending over time").font(.subheadline.bold())
                        Text(range.title).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("Category", selection: $selectedCategory) {
                        Text("All").tag("All")
                        ForEach(AnalyticsCategory.allCases) { category in
                            Text(category.title).tag(category.rawValue)
                        }
                    }
                    .labelsHidden().tint(.appAccent)
                }
                if selectedTransactions.isEmpty {
                    chartEmptyState("No spending recorded for this selection.")
                } else {
                    Chart(spendingBuckets) { bucket in
                        AreaMark(
                            x: .value("Period", bucket.date),
                            y: .value("Amount", bucket.amount)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.analyticsBlue.opacity(0.28), Color.analyticsBlue.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                        LineMark(
                            x: .value("Period", bucket.date),
                            y: .value("Amount", bucket.amount)
                        )
                        .foregroundStyle(Color.analyticsBlue)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)
                        PointMark(
                            x: .value("Period", bucket.date),
                            y: .value("Amount", bucket.amount)
                        )
                        .foregroundStyle(Color.analyticsBlue)
                    }
                    .frame(height: 220)
                }
                Text("Chart values come from fuel, maintenance and expense records.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
    }

    private var spendingBreakdown: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 15) {
                Text("Where the money went").font(.subheadline.bold())
                if periodTransactions.isEmpty {
                    Text("Add a fuel, maintenance or expense record to see the breakdown.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(AnalyticsCategory.allCases) { category in
                        breakdownRow(category)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func breakdownRow(_ category: AnalyticsCategory) -> some View {
        let amount = total(for: category)
        let share = totalSpending > 0 ? amount / totalSpending : 0
        return VStack(spacing: 6) {
            HStack {
                Label(category.title, systemImage: "circle.fill")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(category.color)
                Spacer()
                Text(money(amount)).monospacedDigit()
                Text("\(Int((share * 100).rounded()))%")
                    .frame(width: 40, alignment: .trailing).foregroundStyle(.secondary)
            }
            .font(.caption.weight(.semibold))
            ProgressView(value: min(1, max(0, share)), total: 1)
                .tint(category.color)
        }
    }

    private var mileageChart: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Text("Recorded mileage").font(.subheadline.bold())
                    Spacer()
                    Text("km").font(.caption).foregroundStyle(.secondary)
                }
                if mileageReadings.count < 2 {
                    chartEmptyState("Add two dated odometer readings to see a mileage trend.")
                } else {
                    Chart(mileageReadings) { reading in
                        LineMark(
                            x: .value("Date", reading.date),
                            y: .value("Mileage", reading.mileage)
                        )
                        .foregroundStyle(Color.appAccent)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        PointMark(
                            x: .value("Date", reading.date),
                            y: .value("Mileage", reading.mileage)
                        )
                        .foregroundStyle(Color.appAccent)
                    }
                    .frame(height: 190)
                }
                Text("Uses odometer readings from saved records and the current vehicle mileage.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
    }

    private var fuelEfficiencyChart: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Estimated fuel efficiency").font(.subheadline.bold())
                        Text("Calculated between consecutive fill-ups")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(Color.appSuccess)
                        .frame(width: 34, height: 34)
                        .background(Color.appSuccess.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                }

                HStack(spacing: 8) {
                    efficiencyStat("AVERAGE", value: viewModel.averageFuelEfficiency)
                    efficiencyStat("LATEST", value: viewModel.latestFuelEfficiency)
                    efficiencyStat("BEST", value: viewModel.bestFuelEfficiency)
                }

                if fuelEfficiencyReadings.isEmpty {
                    chartEmptyState(
                        "Add at least two fuel records with increasing odometer readings to estimate efficiency."
                    )
                } else {
                    Chart(fuelEfficiencyReadings) { reading in
                        LineMark(
                            x: .value("Date", reading.date),
                            y: .value("Efficiency", reading.kilometresPerLiter)
                        )
                        .foregroundStyle(Color.appSuccess)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        .interpolationMethod(.catmullRom)
                        PointMark(
                            x: .value("Date", reading.date),
                            y: .value("Efficiency", reading.kilometresPerLiter)
                        )
                        .foregroundStyle(Color.appSuccess)
                    }
                    .chartYAxisLabel("km/L")
                    .frame(height: 190)
                }

                Text("This is an estimate; partial fill-ups can affect the result.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
    }

    private func efficiencyStat(_ title: String, value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.appBadge).foregroundStyle(.secondary)
            Text(value.map { String(format: "%.1f", $0) } ?? "—")
                .font(.headline.bold()).monospacedDigit()
            Text("km/L").font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.appElevated, in: RoundedRectangle(cornerRadius: 10))
    }

    private func chartEmptyState(_ message: String) -> some View {
        Text(message)
            .font(.subheadline).foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity).frame(height: 190)
    }

    private func insights(for vehicle: Vehicle) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Insights & next steps").font(.subheadline.bold())
                if let largest = AnalyticsCategory.allCases.max(by: {
                    total(for: $0) < total(for: $1)
                }),
                    total(for: largest) > 0
                {
                    Label(
                        "\(largest.title) is your largest cost: \(money(total(for: largest))).",
                        systemImage: "chart.pie.fill"
                    )
                } else {
                    Label("No spending recorded in this range.", systemImage: "chart.bar.xaxis")
                }
                if vehicle.distanceToService == 0 || vehicle.nextServiceDate <= now {
                    Label("Your next service is due.", systemImage: "wrench.and.screwdriver.fill")
                } else {
                    Label(
                        "Next service in \(vehicle.distanceToService.formatted()) km or by \(vehicle.nextServiceDate.shortDate).",
                        systemImage: "wrench.and.screwdriver.fill"
                    )
                }
                if let document = store.documents
                    .filter({
                        $0.vehicleID == vehicle.id
                            && $0.expiryDate <= now.addingTimeInterval(30 * 86_400)
                    })
                    .min(by: { $0.expiryDate < $1.expiryDate })
                {
                    Label(
                        document.expiryDate < now
                            ? "\(document.type) has expired."
                            : "\(document.type) expires on \(document.expiryDate.shortDate).",
                        systemImage: "doc.badge.clock"
                    )
                }
            }
            .font(.caption).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
    }

    private var relatedRecords: some View {
        VStack(alignment: .leading, spacing: 11) {
            SectionHeading(title: "Explore your records")
            NavigationLink {
                ActivityHubView()
            } label: {
                Label("Fuel and expense records", systemImage: "arrow.up.right.square")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Color.appAccent)
            }
            NavigationLink {
                MaintenanceListView()
            } label: {
                Label("Maintenance history", systemImage: "arrow.up.right.square")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Color.appAccent)
            }
            NavigationLink {
                ReportSetupView()
            } label: {
                Label("Create a PDF report", systemImage: "doc.richtext")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Color.appAccent)
            }
        }
        .padding(.horizontal, 20)
    }
}

struct ReportSetupView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var vehicleID: UUID?
    @State private var startDate =
        Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var selectedSections: Set<String> = Set([
        "Vehicle Details", "Mileage", "Maintenance", "Fuel", "Expenses", "Documents", "Analytics",
    ])
    @State private var previewData: Data?
    @State private var previewTitle = "Vehicle report"
    @State private var showPreview = false
    @State private var error: String?
    private let sections = [
        "Vehicle Details", "Mileage", "Maintenance", "Fuel", "Expenses", "Documents", "Analytics",
    ]
    private var selectedVehicleBinding: Binding<UUID?> {
        Binding(
            get: { vehicleID ?? store.selectedVehicle?.id },
            set: { vehicleID = $0 }
        )
    }

    var body: some View {
        Form {
            Section("Report for") {
                Picker("Vehicle", selection: selectedVehicleBinding) {
                    ForEach(store.vehicles) { vehicle in
                        Text(vehicle.title).tag(Optional(vehicle.id))
                    }
                }
            }
            Section("Date range") {
                DatePicker("From", selection: $startDate, displayedComponents: .date)
                DatePicker("To", selection: $endDate, in: startDate..., displayedComponents: .date)
            }
            Section("Include sections") {
                ForEach(sections, id: \.self) { section in
                    Toggle(
                        section,
                        isOn: Binding(
                            get: { selectedSections.contains(section) },
                            set: {
                                if $0 {
                                    selectedSections.insert(section)
                                } else {
                                    selectedSections.remove(section)
                                }
                            }))
                }
            }
            if let error { Text(error).foregroundStyle(.red) }
            Section {
                Button {
                    generate()
                } label: {
                    Label("Generate PDF report", systemImage: "doc.richtext")
                }
                .disabled(selectedSections.isEmpty)
            }
        }
        .navigationTitle("Vehicle report").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPreview, onDismiss: clearPreviewData) {
            if let data = previewData {
                ReportPreviewView(
                    data: data, title: previewTitle)
            }
        }
    }
    private func clearPreviewData() {
        previewData = nil
    }
    private func generate() {
        guard
            let vehicle = store.vehicles.first(where: {
                $0.id == (vehicleID ?? store.selectedVehicle?.id)
            })
        else {
            error = "Choose a vehicle."
            return
        }
        do {
            let input = VehicleReportInput(
                vehicle: vehicle,
                maintenance: store.maintenance.filter { $0.vehicleID == vehicle.id },
                fuelRecords: store.fuelRecords.filter { $0.vehicleID == vehicle.id },
                expenses: store.expenses.filter { $0.vehicleID == vehicle.id },
                documents: store.documents.filter { $0.vehicleID == vehicle.id },
                start: startDate, end: endDate, sections: selectedSections)
            previewData = try VehicleReportGenerator.generate(input)
            previewTitle = "\(vehicle.title) report"
            showPreview = true
        } catch { self.error = "The report could not be generated. Please try again." }
    }
}

struct ReportPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let data: Data
    let title: String
    @State private var share = false
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                PDFKitPreview(data: data).background(Color(uiColor: .secondarySystemBackground))
                HStack(spacing: 12) {
                    ShareLink(
                        item: PDFDataItem(data: data),
                        preview: SharePreview(title, image: Image(systemName: "doc.richtext"))
                    ) { Label("Share PDF", systemImage: "square.and.arrow.up") }
                    .buttonStyle(PrimaryButtonStyle())
                    Button {
                        saveToFiles()
                    } label: {
                        Label("Save PDF", systemImage: "arrow.down.to.line")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(16).background(.bar)
            }
            .navigationTitle("Report preview").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } } }
        }
    }
    private func saveToFiles() {
        let picker = UIDocumentPickerViewController(forExporting: [writeTemporaryPDF()])
        UIApplication.shared.topMostController?.present(picker, animated: true)
    }
    private func writeTemporaryPDF() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "Vehicle-Report.pdf")
        try? data.write(to: url)
        return url
    }
}
struct PDFDataItem: Transferable {
    var data: Data
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { $0.data }
    }
}
struct PDFKitPreview: UIViewRepresentable {
    let data: Data
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .secondarySystemBackground
        view.document = PDFDocument(data: data)
        return view
    }
    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = PDFDocument(data: data)
    }
}


extension UIApplication {
    var topMostController: UIViewController? {
        connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    }
}
