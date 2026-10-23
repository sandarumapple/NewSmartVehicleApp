import AuthenticationServices
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @State private var showSplash = true
    @AppStorage("smart-vehicle-did-show-launch-splash") private var didShowLaunchSplash = false

    private var colorScheme: ColorScheme? {
        switch store.appearance {
        case "Dark": return .dark
        case "Light": return .light
        default: return nil
        }
    }

    var body: some View {
        Group {
            if showSplash {
                SplashView()
            } else if store.isRestoringSession {
                SessionRestoreView {
                    store.continueWithCachedData()
                }
            } else if !store.isAuthenticated {
                AuthenticationView()
                    .id("authentication")
                    .toolbar(.hidden, for: .tabBar)
            } else if !store.onboardingCompleted {
                OnboardingWizardView()
            } else if store.biometricEnabled && !store.biometricUnlocked {
                LockScreen()
            } else {
                Group {
                    if horizontalSizeClass == .regular {
                        iPadNavigation
                    } else {
                        iPhoneNavigation
                    }
                }
                .id("main-navigation")
            }
        }
        .preferredColorScheme(showSplash ? .dark : colorScheme)
        .overlay(alignment: .top) {
            if let error = store.backendError {
                AppFeedbackBanner(
                    message: friendlyMessage(for: error),
                    isError: true,
                    retry: { store.retryCloudSync() },
                    dismiss: { store.backendError = nil }
                )
                .padding(.horizontal, 16).padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            } else if let success = store.showSuccess {
                AppFeedbackBanner(
                    message: success,
                    isError: false,
                    dismiss: { store.showSuccess = nil }
                )
                .padding(.horizontal, 16).padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.22), value: store.backendError)
        .animation(.easeOut(duration: 0.22), value: store.showSuccess)
        .overlay(alignment: .bottom) {
            if let undoMessage = store.undoMessage {
                UndoActionBanner(
                    message: undoMessage,
                    undo: { store.undoLastChange() },
                    dismiss: { store.dismissUndo() }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, store.isAuthenticated ? 70 : 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.22), value: store.undoMessage)
        .onChange(of: store.isAuthenticated) { _, _ in
            selectedTab = 0
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background && store.biometricEnabled {
                store.lockBiometricSession()
            } else if phase == .active {
                store.refreshNotificationPermission()
            }
        }
        .task {
            store.startFirebase()
            guard showSplash else { return }
            try? await Task.sleep(for: .milliseconds(didShowLaunchSplash ? 100 : 550))
            didShowLaunchSplash = true
            if reduceMotion {
                showSplash = false
            } else {
                withAnimation(.easeOut(duration: 0.25)) { showSplash = false }
            }
        }
        .task(id: store.showSuccess) {
            guard store.showSuccess != nil else { return }
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            withAnimation { store.showSuccess = nil }
        }
    }

    private func friendlyMessage(for message: String) -> String {
        let value = message.lowercased()
        if value.contains("network") || value.contains("offline")
            || value.contains("internet") || value.contains("timed out")
        {
            return "You're offline or the connection is unstable. Your saved data is still available."
        }
        if value.contains("permission") {
            return "This action isn't available for your account. Refresh and try again."
        }
        if value.contains("unauthenticated") || value.contains("sign in") {
            return "Your session needs to be refreshed. Please sign in again."
        }
        if value.contains("already in your garage") { return message }
        return "We couldn't sync that change. Check your connection and try again."
    }

    private var iPhoneNavigation: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { HomeView(selectedTab: $selectedTab) }
                .tabItem { Label("Home", systemImage: "house.fill") }.tag(0)
            NavigationStack { VehicleListView() }
                .tabItem { Label("Garage", systemImage: "car.side.fill") }.tag(1)
            NavigationStack { ActivityHubView() }
                .tabItem { Label("Activity", systemImage: "wrench.and.screwdriver.fill") }.tag(2)
            NavigationStack { ExploreView() }
                .tabItem { Label("Explore", systemImage: "safari.fill") }.tag(3)
            NavigationStack { MoreView() }
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }.tag(4)
        }
        .tint(.appAccent)
        .toolbarBackground(Color.appCanvas, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }

    private var iPadNavigation: some View {
        NavigationSplitView {
            List(
                selection: Binding<Int?>(
                    get: { selectedTab },
                    set: { if let selection = $0 { selectedTab = selection } }
                )
            ) {
                Label("Home", systemImage: "house.fill").tag(0)
                Label("Garage", systemImage: "car.side.fill").tag(1)
                Label("Activity", systemImage: "wrench.and.screwdriver.fill").tag(2)
                Label("Explore", systemImage: "safari.fill").tag(3)
                Label("Profile", systemImage: "person.crop.circle").tag(4)
            }
            .navigationTitle("Smart Garage")
            .listStyle(.sidebar)
        } detail: {
            NavigationStack { selectedSection }
                .id(selectedTab)
        }
        .tint(.appAccent)
    }

    @ViewBuilder private var selectedSection: some View {
        switch selectedTab {
        case 1: VehicleListView()
        case 2: ActivityHubView()
        case 3: ExploreView()
        case 4: MoreView()
        default: HomeView(selectedTab: $selectedTab)
        }
    }
}

private struct SessionRestoreView: View {
    let continueWithCache: () -> Void
    @State private var isTakingLonger = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ProgressView().controlSize(.large).tint(.appAccent)
                Text("Loading your garage…").font(.headline)
                Text(
                    isTakingLonger
                        ? "This is taking longer than expected. You can continue with data saved on this device."
                        : "Restoring your vehicles and records."
                )
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 340)
                LoadingSkeletonList(rows: 3)
                    .frame(maxWidth: 430)
                if isTakingLonger {
                    Button("Continue with saved data", action: continueWithCache)
                        .buttonStyle(SecondaryButtonStyle()).frame(maxWidth: 320)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity)
        }
        .background(Color.appCanvas.ignoresSafeArea())
        .task {
            try? await Task.sleep(for: .seconds(4))
            withAnimation { isTakingLonger = true }
        }
    }
}

private struct SplashView: View {
    @State private var loading = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.039, green: 0.051, blue: 0.078),
                        Color(red: 0.031, green: 0.043, blue: 0.063),
                        Color(red: 0.024, green: 0.031, blue: 0.047),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 410, height: 410)
                    .blur(radius: 75)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                ForEach([180.0, 310.0, 450.0, 560.0], id: \.self) { diameter in
                    Circle()
                        .stroke(
                            Color(red: 0.38, green: 0.65, blue: 0.98).opacity(0.06),
                            style: StrokeStyle(
                                lineWidth: 1,
                                dash: diameter == 180 || diameter == 450 ? [5, 8] : []
                            )
                        )
                        .frame(width: diameter, height: diameter)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }

                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    Image(systemName: "car.side.fill")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 88, height: 88)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.15, green: 0.42, blue: 0.95),
                                    Color(red: 0.04, green: 0.14, blue: 0.38),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 24)
                        )
                        .padding(3)
                        .background(
                            Color(red: 0.38, green: 0.65, blue: 0.98).opacity(0.3),
                            in: RoundedRectangle(cornerRadius: 27)
                        )
                        .shadow(color: .blue.opacity(0.35), radius: 24, y: 10)
                        .accessibilityHidden(true)

                    Text("Smart Vehicle Maintenance")
                        .font(.title2.bold())
                        .tracking(-0.6)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(.white)
                        .padding(.top, 24)

                    Text("YOUR VEHICLE, SIMPLIFIED")
                        .font(.appBadge)
                        .tracking(2.7)
                        .foregroundStyle(Color(red: 0.38, green: 0.65, blue: 0.98))
                        .padding(.top, 7)

                    HStack(spacing: 8) {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                        Text("Preparing your garage")
                            .font(.appMetadata.weight(.medium))
                            .foregroundStyle(Color(red: 0.8, green: 0.84, blue: 0.9))
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(.white.opacity(0.04), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.09)))
                    .padding(.top, 20)

                    Spacer(minLength: 0)

                    VStack(spacing: 12) {
                        GeometryReader { track in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(red: 0.12, green: 0.16, blue: 0.23))
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                .blue, Color(red: 0.38, green: 0.65, blue: 0.98),
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: track.size.width * 0.55, height: 3)
                                    .offset(x: loading ? track.size.width * 0.45 : 0)
                                    .animation(
                                        .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                                        value: loading
                                    )
                            }
                        }
                        .frame(height: 6)

                        HStack {
                            Label("Loading your garage", systemImage: "circle.fill")
                                .labelStyle(.titleAndIcon)
                            Spacer()
                            Text(
                                "v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")"
                            )
                            .monospaced()
                        }
                        .font(.appMetadata)
                        .foregroundStyle(Color(red: 0.58, green: 0.64, blue: 0.72))
                    }
                    .frame(maxWidth: 280)
                    .padding(.bottom, 55)
                }
                .padding(.horizontal, 24)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color(red: 0.024, green: 0.031, blue: 0.047))
        .ignoresSafeArea()
        .task { loading = true }
    }
}

struct LockScreen: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var message: String?
    @State private var isAuthenticating = false
    @State private var didAttemptAutomatically = false
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "car.side.fill").font(.system(size: 32)).foregroundStyle(.white)
                .frame(width: 76, height: 76)
                .background(Color.appAccent, in: RoundedRectangle(cornerRadius: 24))
            Text("Your garage is locked").font(.title2.bold())
            Text("Authenticate to continue").foregroundStyle(.secondary)
            Button {
                attemptUnlock()
            } label: {
                Label(store.biometricUnlockTitle, systemImage: "lock.shield")
                    .frame(maxWidth: 240)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isAuthenticating)
            if let message { Text(message).font(.caption).foregroundStyle(.red) }
        }
        .padding(32)
        .onAppear { attemptAutomaticallyIfActive() }
        .onChange(of: scenePhase) { _, _ in attemptAutomaticallyIfActive() }
    }

    private func attemptAutomaticallyIfActive() {
        guard scenePhase == .active, !didAttemptAutomatically else { return }
        didAttemptAutomatically = true
        attemptUnlock()
    }

    private func attemptUnlock() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        message = nil
        store.unlockWithDeviceAuthentication { result in
            isAuthenticating = false
            if case .failure(let failure) = result {
                message = failure.message
            }
        }
    }
}

struct AuthenticationView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = AuthenticationViewModel()
    @State private var showPasswordReset = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let usesWideLayout = geometry.size.width >= 600
                let compactHeight = geometry.size.height < 900
                let contentWidth: CGFloat = geometry.size.width < 900 ? 440 : 500
                let panelHorizontalPadding: CGFloat = geometry.size.width < 900 ? 28 : 40
                let panelVerticalPadding: CGFloat = compactHeight ? 16 : 28
                let outerVerticalInset: CGFloat = compactHeight ? 10 : 24

                ScrollView {
                    VStack(spacing: 0) {
                    VStack(spacing: 10) {
                        AuthenticationBrandMark()
                            .padding(.bottom, 4)
                        Text(
                            viewModel.isRegister
                                ? "Create your account" : "Welcome back"
                        )
                        .font(.appScreenTitle)
                        .tracking(-0.5)

                        Text(
                            viewModel.isRegister
                                ? "Your smarter vehicle journey starts here."
                                : "Everything your car needs, in one place."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 18)
                    .padding(.bottom, 26)

                    VStack(alignment: .leading, spacing: 16) {
                        if store.isFirebaseConfigured {
                            if viewModel.isRegister {
                                FormField(title: "Full name", text: $viewModel.name)
                                    .textContentType(.name)
                            }
                            FormField(
                                title: "Email address", text: $viewModel.email,
                                keyboard: .emailAddress
                            )
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.emailAddress)
                            PasswordEntryField(
                                title: "Password",
                                text: $viewModel.password,
                                contentType: viewModel.isRegister ? .newPassword : .password
                            )
                            if viewModel.isRegister {
                                PasswordEntryField(
                                    title: "Confirm password",
                                    text: $viewModel.confirmPassword,
                                    contentType: .newPassword
                                )
                            } else {
                                Button("Forgot password?") {
                                    viewModel.preparePasswordReset()
                                    showPasswordReset = true
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.appAccent)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .disabled(viewModel.isSubmitting)
                            }
                        } else {
                            Text(
                                "Firebase is not configured, so real account sign-in is unavailable. "
                                    + "You can continue with an isolated demo profile."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
                        }
                        if let error = viewModel.error {
                            Label(error, systemImage: "exclamationmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 4)
                        }
                        if let notice = viewModel.notice {
                            Label(notice, systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                                .padding(.horizontal, 4)
                        }
                        if store.isFirebaseConfigured {
                            Button {
                                viewModel.submit(using: store)
                            } label: {
                                ZStack {
                                    Text(viewModel.isRegister ? "Create Account" : "Sign In")
                                        .opacity(viewModel.isSubmitting ? 0 : 1)
                                    if viewModel.isSubmitting {
                                        ProgressView().tint(.white)
                                    }
                                }
                            }
                            .buttonStyle(AuthenticationPrimaryButtonStyle())
                            .disabled(viewModel.isSubmitting)

                            HStack(spacing: 12) {
                                Rectangle().frame(height: 1)
                                Text("OR")
                                    .font(.caption2.weight(.medium))
                                    .tracking(0.8)
                                    .fixedSize()
                                Rectangle().frame(height: 1)
                            }
                            .foregroundStyle(Color.secondary.opacity(0.35))
                            .padding(.vertical, 2)

                            SignInWithAppleButton(.signIn) { request in
                                request.requestedScopes = [.fullName, .email]
                                request.nonce = viewModel.prepareAppleNonce()
                            } onCompletion: { result in
                                viewModel.completeAppleSignIn(result, using: store)
                            }
                            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                            .frame(height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .disabled(viewModel.isSubmitting)

                            Button {
                                viewModel.signInWithGoogle(using: store)
                            } label: {
                                HStack(spacing: 10) {
                                    Image("GoogleLogo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 18, height: 18)
                                        .accessibilityHidden(true)
                                    Text("Continue with Google")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                            }
                            .buttonStyle(AuthenticationSocialButtonStyle())
                            .disabled(viewModel.isSubmitting)

                            Button {
                                withAnimation { viewModel.toggleMode() }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(
                                        viewModel.isRegister
                                            ? "Already have an account?" : "Don't have an account?"
                                    )
                                    .foregroundStyle(.secondary)
                                    Text(viewModel.isRegister ? "Sign In" : "Create Account")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.authBlue)
                                }
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 12)
                            .disabled(viewModel.isSubmitting)
                        } else {
                            Button("Continue in demo mode") { store.continueInDemoMode() }
                                .buttonStyle(AuthenticationPrimaryButtonStyle())
                        }
                    }
                    }
                    .frame(maxWidth: usesWideLayout ? contentWidth : 430)
                    .padding(.horizontal, usesWideLayout ? panelHorizontalPadding : 20)
                    .padding(.top, usesWideLayout ? panelVerticalPadding : 0)
                    .padding(.bottom, usesWideLayout ? panelVerticalPadding : 32)
                    .background {
                        if usesWideLayout {
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .fill(Color.appCanvas.opacity(0.94))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                                }
                                .shadow(color: .black.opacity(0.12), radius: 28, y: 12)
                        }
                    }
                    .frame(
                        maxWidth: .infinity,
                        minHeight: usesWideLayout
                            ? max(0, geometry.size.height - (outerVerticalInset * 2)) : nil,
                        alignment: usesWideLayout ? .center : .top
                    )
                    .padding(.horizontal, usesWideLayout ? 24 : 0)
                    .padding(.vertical, usesWideLayout ? outerVerticalInset : 0)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .background {
                    LinearGradient(
                        colors: [
                            Color.appCanvas,
                            Color.authBlue.opacity(usesWideLayout ? 0.11 : 0.055),
                            Color.appCanvas,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showPasswordReset) {
            PasswordResetView(viewModel: viewModel)
                .environmentObject(store)
        }
    }
}

private struct AuthenticationBrandMark: View {
    var body: some View {
        Image(systemName: "car.side.fill")
            .font(.system(size: 29, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 70, height: 70)
            .background {
                LinearGradient(
                    colors: [Color.authBlue.opacity(0.95), Color.blue.opacity(0.55), .black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.blue.opacity(0.35), lineWidth: 1)
            }
            .shadow(color: Color.authBlue.opacity(0.38), radius: 18, y: 8)
            .accessibilityHidden(true)
    }
}

private struct AuthenticationPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                Color.authBlue.opacity(configuration.isPressed ? 0.78 : 1),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
    }
}

private struct AuthenticationSocialButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .background(
                Color.appCard.opacity(configuration.isPressed ? 0.72 : 1),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
            }
    }
}

private extension Color {
    static let authBlue = Color(red: 0.039, green: 0.518, blue: 1)
}

private struct PasswordEntryField: View {
    let title: String
    @Binding var text: String
    let contentType: UITextContentType
    @State private var isRevealed = false

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if isRevealed {
                    TextField(title, text: $text)
                } else {
                    SecureField(title, text: $text)
                }
            }
            .textContentType(contentType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash.fill" : "eye.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRevealed ? "Hide \(title)" : "Show \(title)")
        }
        .padding(14)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct PasswordResetView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AuthenticationViewModel

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Reset your password")
                    .font(.title2.bold())
                Text("Enter your account email and we'll send a secure reset link.")
                    .foregroundStyle(.secondary)
                FormField(
                    title: "Email address", text: $viewModel.resetEmail,
                    keyboard: .emailAddress
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.emailAddress)
                if let error = viewModel.resetError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
                if let confirmation = viewModel.resetConfirmation {
                    Label(confirmation, systemImage: "envelope.badge.fill")
                        .font(.caption).foregroundStyle(.green)
                }
                Button(viewModel.resetConfirmation == nil ? "Send reset link" : "Done") {
                    if viewModel.resetConfirmation == nil {
                        viewModel.requestPasswordReset(using: store)
                    } else {
                        dismiss()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.isResettingPassword)
                if viewModel.isResettingPassword {
                    ProgressView("Sending…").frame(maxWidth: .infinity)
                }
                Spacer()
            }
            .padding(24)
            .background(Color.appCanvas)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isResettingPassword)
                }
            }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled(viewModel.isResettingPassword)
    }
}
