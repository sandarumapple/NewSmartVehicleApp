import SwiftUI
import Vision
import VisionKit

struct OnboardingWizardView: View {
    @EnvironmentObject private var store: AppStore
    @State private var step = 0
    @State private var name = ""
    @State private var phone = ""
    @State private var nicNumber = ""
    @State private var vehicleMake = "Toyota"
    @State private var vehicleModel = "Corolla"
    @State private var year = "2022"
    @State private var registration = ""
    @State private var mileage = ""
    @State private var fuel = "Petrol"
    @State private var scanPresented = false
    @State private var scanImage: UIImage?
    @State private var recognizedText = ""
    @State private var scanMessage: String?
    @State private var wantsBiometrics = false
    @State private var wantsNotifications = true
    @State private var wantsLocation = true
    @State private var error: String?
    @State private var isEnablingBiometrics = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 5) {
                    ForEach(0..<3) { index in
                        Capsule()
                            .fill(index <= step ? Color.appAccent : Color.appAccent.opacity(0.16))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, 22).padding(.top, 15)
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(["A little about you", "Your vehicle", "Make it yours"][step])
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                            Text(
                                [
                                    "Confirm your details and optionally scan your NIC.",
                                    "Add the vehicle you want to keep on top of.",
                                    "Choose security and reminder preferences.",
                                ][step]
                            )
                            .font(.subheadline).foregroundStyle(.secondary)
                        }
                        if step == 0 {
                            personalStep
                        } else if step == 1 {
                            vehicleStep
                        } else {
                            preferencesStep
                        }
                        if let error { Text(error).font(.caption).foregroundStyle(.red) }
                    }
                    .padding(22)
                }
                VStack(spacing: 10) {
                    Button(step == 2 ? "Finish setup" : "Continue") { advance() }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isEnablingBiometrics)
                    if isEnablingBiometrics {
                        ProgressView("Checking Face ID / Touch ID")
                    }
                    if step > 0 {
                        Button("Back") { step -= 1 }.font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.appAccent)
                            .disabled(isEnablingBiometrics)
                    }
                }
                .padding(20).background(.bar)
            }
            .background(Color.appCanvas.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip setup") { completeWithoutVehicle() }
                        .font(.caption.weight(.semibold)).foregroundStyle(Color.appAccent)
                        .disabled(isEnablingBiometrics)
                }
            }
            .sheet(isPresented: $scanPresented) {
                DocumentCameraPicker { pages in
                    scanPresented = false
                    scanImage = pages?.first
                    recognizeNIC(pages?.first)
                }
                .ignoresSafeArea()
            }
        }
        .onAppear { name = store.userName }
    }

    private var personalStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            FormField(title: "Full name", text: $name, placeholder: "Your name")
            FormField(
                title: "Phone number", text: $phone, placeholder: "+94 7X XXX XXXX",
                keyboard: .phonePad)
            SurfaceCard {
                VStack(alignment: .leading, spacing: 11) {
                    Label("NIC scan (optional)", systemImage: "person.text.rectangle")
                        .font(.subheadline.bold())
                    Text(
                        "Vision reads text from your NIC. Check and edit the number before continuing."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                    Button {
                        scanPresented = true
                    } label: {
                        Label("Scan NIC", systemImage: "viewfinder")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Color.appAccent)
                    if !recognizedText.isEmpty {
                        FormField(
                            title: "NIC number · verify this", text: $nicNumber,
                            placeholder: "Enter NIC number")
                    }
                    if let scanMessage {
                        Text(scanMessage).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    private var vehicleStep: some View {
        VStack(spacing: 14) {
            FormField(title: "Make", text: $vehicleMake)
            FormField(title: "Model", text: $vehicleModel)
            FormField(title: "Year", text: $year, keyboard: .numberPad)
            FormField(title: "Registration", text: $registration, placeholder: "ABC-1234")
            FormField(title: "Current mileage (km)", text: $mileage, keyboard: .numberPad)
            Picker("Fuel type", selection: $fuel) {
                ForEach(["Petrol", "Diesel", "Hybrid", "Electric"], id: \.self) { Text($0) }
            }
            .pickerStyle(.segmented)
        }
    }
    private var preferencesStep: some View {
        VStack(spacing: 12) {
            SurfaceCard {
                VStack(alignment: .leading, spacing: 13) {
                    Label("Helpful reminders", systemImage: "bell.badge.fill")
                        .font(.subheadline.bold())
                    Text(
                        "Maintenance and expiry dates schedule local reminders. Remote messages can arrive through Firebase."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                    Toggle("Allow notifications", isOn: $wantsNotifications)
                }
            }
            SurfaceCard {
                VStack(alignment: .leading, spacing: 13) {
                    Label("Nearby assistance", systemImage: "location.fill")
                        .font(.subheadline.bold())
                    Text("Use your location to find nearby fuel stations and vehicle services.")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("Allow location access", isOn: $wantsLocation)
                }
            }
            SurfaceCard {
                VStack(alignment: .leading, spacing: 13) {
                    Label("Secure your garage", systemImage: "faceid").font(.subheadline.bold())
                    Text(
                        "Face ID or Touch ID helps protect your vehicle information when you return to the app."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                    Toggle("Enable Face ID / Touch ID", isOn: $wantsBiometrics)
                    #if targetEnvironment(simulator)
                        Text("Simulator: enable Face ID or Touch ID enrollment from the Features menu first.")
                            .font(.caption).foregroundStyle(.secondary)
                    #endif
                }
            }
        }
    }
    private func advance() {
        error = nil
        if step == 0 {
            guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
                error = "Enter your name to continue."
                return
            }
            store.userName = name
            step = 1
        } else if step == 1 {
            guard !vehicleMake.isEmpty, !vehicleModel.isEmpty, !registration.isEmpty,
                Int(mileage) != nil, Int(year) != nil
            else {
                error = "Enter vehicle make, model, year, registration, and mileage."
                return
            }
            step = 2
        } else {
            finish()
        }
    }
    private func finish() {
        let car = Vehicle(
            make: vehicleMake, model: vehicleModel, year: Int(year) ?? 2022,
            registration: registration.uppercased(), mileage: Int(mileage) ?? 0, fuel: fuel,
            color: "Not specified", image: "car.side.fill",
            nextServiceMileage: (Int(mileage) ?? 0) + 5000,
            nextServiceDate: Calendar.current.date(byAdding: .month, value: 6, to: Date())!,
            vin: "", engine: "Not specified", transmission: "Not specified")
        if wantsBiometrics {
            guard !isEnablingBiometrics else { return }
            isEnablingBiometrics = true
            store.authenticateBiometric { result in
                isEnablingBiometrics = false
                switch result {
                case .success:
                    completeSetup(with: car, biometricsEnabled: true)
                case .failure(let failure):
                    error = failure.message
                }
            }
        } else {
            completeSetup(with: car, biometricsEnabled: false)
        }
    }
    private func completeSetup(with car: Vehicle, biometricsEnabled: Bool) {
        if wantsLocation {
            NotificationCenter.default.post(name: .init("RequestLocationPermission"), object: nil)
        }
        store.addVehicle(car)
        store.notificationsEnabled = wantsNotifications
        store.notificationPreferencesChanged()
        if wantsNotifications { store.requestNotificationPermission { _ in } }
        store.biometricEnabled = biometricsEnabled
        store.finishOnboarding()
    }
    private func completeWithoutVehicle() {
        store.notificationsEnabled = wantsNotifications
        store.notificationPreferencesChanged()
        if wantsNotifications { store.requestNotificationPermission { _ in } }
        store.finishOnboarding()
    }
    private func recognizeNIC(_ image: UIImage?) {
        guard let cgImage = image?.cgImage else {
            scanMessage = "Scan cancelled. You can enter the NIC number manually."
            return
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        DispatchQueue.global(qos: .userInitiated)
            .async {
                do {
                    try VNImageRequestHandler(cgImage: cgImage).perform([request])
                    let text =
                        request.results?.compactMap { $0.topCandidates(1).first?.string }
                        .joined(separator: " ") ?? ""
                    DispatchQueue.main.async {
                        recognizedText = text
                        let candidate =
                            text.components(separatedBy: CharacterSet.alphanumerics.inverted)
                            .first {
                                $0.count >= 9 && $0.rangeOfCharacter(from: .decimalDigits) != nil
                            }
                        nicNumber = candidate ?? ""
                        scanMessage =
                            candidate == nil
                            ? "Text was recognized, but no NIC number was certain. Please enter it manually."
                            : "Check the suggested NIC number before continuing."
                    }
                } catch {
                    DispatchQueue.main.async {
                        scanMessage = "Could not read this scan. Enter the NIC number manually."
                    }
                }
            }
    }
}
