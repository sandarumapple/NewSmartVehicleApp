import AuthenticationServices
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @State private var showSplash = true

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
                ProgressView("Loading your garage…")
            } else if !store.isAuthenticated {
                AuthenticationView()
            } else if !store.onboardingCompleted {
                OnboardingWizardView()
            } else if store.biometricEnabled && !store.biometricUnlocked {
                LockScreen()
            } else {
                if horizontalSizeClass == .regular {
                    iPadNavigation
                } else {
                    iPhoneNavigation
                }
            }
        }
        .preferredColorScheme(showSplash ? .dark : colorScheme)
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
            try? await Task.sleep(for: .seconds(1.4))
            if reduceMotion {
                showSplash = false
            } else {
                withAnimation(.easeOut(duration: 0.25)) { showSplash = false }
            }
        }
        .alert(
            store.backendError == nil ? "" : "Firebase error",
            isPresented: Binding(
                get: { store.showSuccess != nil || store.backendError != nil },
                set: {
                    if !$0 {
                        store.showSuccess = nil
                        store.backendError = nil
                    }
                })
        ) {
            Button("Done", role: .cancel) {
                store.showSuccess = nil
                store.backendError = nil
            }
        } message: {
            Text(store.backendError ?? store.showSuccess ?? "")
        }
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
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .tracking(-0.6)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(.white)
                        .padding(.top, 24)

                    Text("YOUR VEHICLE, SIMPLIFIED")
                        .font(.system(size: 10.5, weight: .semibold))
                        .tracking(2.7)
                        .foregroundStyle(Color(red: 0.38, green: 0.65, blue: 0.98))
                        .padding(.top, 7)

                    HStack(spacing: 8) {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                        Text("Preparing your garage")
                            .font(.system(size: 11.5, weight: .medium))
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
                        .font(.system(size: 11))
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
    @StateObject private var viewModel = AuthenticationViewModel()
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        Image(systemName: "car.side.fill").font(.system(size: 28))
                            .foregroundStyle(.white).frame(width: 64, height: 64)
                            .background(Color.appAccent, in: RoundedRectangle(cornerRadius: 20))
                        Text(viewModel.isRegister ? "Start your\nvehicle journey." : "Welcome\nback.")
                            .font(.system(size: 37, weight: .bold, design: .rounded))
                        Text("Everything your car needs, in one place.").foregroundStyle(.secondary)
                    }
                    .padding(.top, 32)
                    if viewModel.isRegister { FormField(title: "Full name", text: $viewModel.name) }
                    FormField(title: "Email address", text: $viewModel.email, keyboard: .emailAddress)
                    SecureField("Password", text: $viewModel.password).padding(14)
                        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
                    if !store.isFirebaseConfigured {
                        Text(
                            "Local demo mode. Add a Firebase project to enable real accounts and sync."
                        )
                        .font(.caption).foregroundStyle(.secondary)
                    }
                    if let error = viewModel.error {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                    Button(viewModel.isRegister ? "Create account" : "Sign in") {
                        viewModel.submit(using: store)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(viewModel.isSubmitting)
                    if viewModel.isSubmitting { ProgressView() }
                    if store.isFirebaseConfigured {
                        HStack {
                            Rectangle().frame(height: 1).foregroundStyle(.quaternary)
                            Text("or continue with").font(.caption).foregroundStyle(.secondary)
                                .fixedSize()
                            Rectangle().frame(height: 1).foregroundStyle(.quaternary)
                        }
                        Button {
                            viewModel.signInWithGoogle(using: store)
                        } label: {
                            Text("Continue with Google")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isSubmitting)
                    }
                    if store.isFirebaseConfigured
                        && Bundle.main.object(forInfoDictionaryKey: "AppleSignInConfigured")
                            as? Bool
                            == true
                    {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = viewModel.prepareAppleNonce()
                        } onCompletion: { result in
                            viewModel.completeAppleSignIn(result, using: store)
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 48)
                    }
                    Button(
                        viewModel.isRegister
                            ? "Already have an account? Sign in" : "New here? Create an account"
                    ) {
                        withAnimation { viewModel.toggleMode() }
                    }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Color.appAccent)
                    .frame(maxWidth: .infinity).padding(.top, 8)
                }
                .padding(24)
            }
            .background(Color.appCanvas).toolbar(.hidden, for: .navigationBar)
        }
    }

}
