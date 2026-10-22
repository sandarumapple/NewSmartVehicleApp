import PhotosUI
import SwiftUI
import UIKit
import Vision
import VisionKit

struct DocumentsView: View {
    @EnvironmentObject private var store: AppStore
    var vehicleID: UUID? = nil
    @State private var showScanner = false
    @State private var filter = "All"
    @State private var selectedVehicleID: UUID?
    private var vehicle: Vehicle? {
        store.vehicles.first(where: { $0.id == (vehicleID ?? selectedVehicleID) })
    }
    private var documents: [VehicleDocument] {
        let targetID = vehicleID ?? selectedVehicleID
        let vehicleDocuments = store.documents.filter {
            targetID == nil || $0.vehicleID == targetID
        }
        return filter == "All"
            ? vehicleDocuments : vehicleDocuments.filter { $0.status == filter }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeading(
                    title: "Documents",
                    subtitle: vehicle?.registration ?? "All your vehicles")
                if vehicleID == nil {
                    Picker("Vehicle", selection: $selectedVehicleID) {
                        Text("All vehicles").tag(UUID?.none)
                        ForEach(store.vehicles) { item in
                            Text(item.title).tag(Optional(item.id))
                        }
                    }
                    .pickerStyle(.menu).padding(.horizontal, 20)
                }
                Button {
                    showScanner = true
                } label: {
                    SurfaceCard {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.viewfinder").font(.system(size: 23))
                                .foregroundStyle(Color.appAccent).frame(width: 50, height: 50)
                                .background(Color.appMint, in: RoundedRectangle(cornerRadius: 15))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Scan a document").font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                Text("Camera scan · text recognition · review")
                                    .font(.caption).foregroundStyle(.secondary)
                                if let target = vehicle ?? store.selectedVehicle {
                                    Text("Add to \(target.title)")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.caption.bold())
                                .foregroundStyle(Color.appAccent)
                        }
                    }
                }
                .buttonStyle(.plain).padding(.horizontal, 20)
                HStack {
                    SectionHeading(title: "Your documents")
                    Spacer()
                    Menu {
                        ForEach(["All", "Valid", "Expiring Soon", "Expired"], id: \.self) { item in
                            Button(item) { filter = item }
                        }
                    } label: {
                        Label(filter, systemImage: "line.3.horizontal.decrease")
                            .font(.caption.weight(.semibold)).foregroundStyle(Color.appAccent)
                    }
                }
                .padding(.horizontal, 20)
                if documents.isEmpty {
                    EmptyStateView(
                        symbol: "doc.text", title: "No documents yet",
                        message:
                            "Scan your insurance, revenue licence, or emission certificate to track expiry dates.",
                        action: "Scan a document"
                    ) { showScanner = true }
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(documents) { doc in
                            NavigationLink {
                                DocumentDetailView(document: doc)
                            } label: {
                                DocumentRow(document: doc)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 10)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(Color.appCanvas.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $showScanner) {
            NavigationStack {
                DocumentScannerFlow(
                    vehicleID: vehicleID ?? selectedVehicleID ?? store.selectedVehicle?.id,
                    startWithCamera: true)
            }
        }
    }
}

struct DocumentRow: View {
    var document: VehicleDocument
    var body: some View {
        SurfaceCard(padding: 15) {
            HStack(spacing: 13) {
                Image(systemName: document.imageName).font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.appAccent).frame(width: 45, height: 45)
                    .background(Color.appMint, in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(document.type).font(.subheadline.bold()).foregroundStyle(.primary)
                        Spacer()
                        StatusBadge(text: document.status)
                    }
                    Text("\(document.registration) · \(document.number)")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Expires \(document.expiryDate.shortDate)").font(.caption2)
                        .foregroundStyle(document.status == "Expired" ? .red : .secondary)
                }
            }
        }
    }
}

struct DocumentDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State var document: VehicleDocument
    @State private var showEdit = false
    @State private var showDeleteAlert = false
    @State private var scannedPages: [UIImage] = []
    @State private var previewPage = 0
    @State private var showScanPreview = false
    @State private var deleteError: String?
    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "doc.text.fill").font(.system(size: 25))
                        .foregroundStyle(Color.appAccent).frame(width: 56, height: 56)
                        .background(Color.appMint, in: RoundedRectangle(cornerRadius: 17))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(document.type).font(.headline)
                        StatusBadge(text: document.status)
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
            }
            Section("Document information") {
                LabeledContent("Document number", value: document.number)
                LabeledContent("Vehicle registration", value: document.registration)
                LabeledContent("Issue date", value: document.issueDate.shortDate)
                LabeledContent("Expiry date", value: document.expiryDate.shortDate)
            }
            if !scannedPages.isEmpty {
                Section("Scanned pages") {
                    ForEach(scannedPages.indices, id: \.self) { index in
                        Button {
                            previewPage = index
                            showScanPreview = true
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(uiImage: scannedPages[index])
                                    .resizable().scaledToFit().frame(maxWidth: .infinity)
                                    .frame(maxHeight: 230)
                                Text("Page \(index + 1) of \(scannedPages.count) · Tap to view")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Text("Scanned pages are stored on this device.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else if (document.scanPageCount ?? 0) > 0 {
                Section("Scanned pages") {
                    Text("The scan is stored on the device where it was captured.")
                        .foregroundStyle(.secondary)
                }
            }
            Section("Expiry tracking") {
                Label(
                    document.status == "Expired"
                        ? "This document has expired"
                        : (document.status == "Expiring Soon"
                            ? "This document expires in 30 days" : "Expiry reminders are enabled"),
                    systemImage: document.status == "Expired"
                        ? "exclamationmark.triangle.fill" : "bell.badge.fill"
                )
                .foregroundStyle(document.status == "Expired" ? .red : Color.appAccent)
            }
            Section {
                Button("Edit document") { showEdit = true }
                Button("Delete document", role: .destructive) { showDeleteAlert = true }
            }
            if let deleteError { Text(deleteError).foregroundStyle(.red) }
        }
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
        .navigationTitle("Document details").navigationBarTitleDisplayMode(.inline)
        .onAppear { scannedPages = store.documentScanPages(documentID: document.id) }
        .sheet(isPresented: $showEdit) {
            NavigationStack { EditDocumentView(document: document) { document = $0 } }
        }
        .fullScreenCover(isPresented: $showScanPreview) {
            DocumentScanPreview(pages: scannedPages, selection: $previewPage)
        }
        .alert("Delete this document?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                do {
                    try store.deleteDocumentScan(documentID: document.id)
                    store.documents.removeAll { $0.id == document.id }
                    store.persist()
                    store.refreshLocalReminders()
                    dismiss()
                } catch { deleteError = error.localizedDescription }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }
}

private struct DocumentScanPreview: View {
    @Environment(\.dismiss) private var dismiss
    let pages: [UIImage]
    @Binding var selection: Int

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button("Done") { dismiss() }.foregroundStyle(.white).padding()
            }
            TabView(selection: $selection) {
                ForEach(pages.indices, id: \.self) { index in
                    Image(uiImage: pages[index]).resizable().scaledToFit()
                        .tag(index)
                        .padding(.horizontal, 12)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            Text("Page \(selection + 1) of \(pages.count)")
                .font(.caption).foregroundStyle(.white).padding(.bottom, 20)
        }
        .background(Color.black.ignoresSafeArea())
    }
}

struct EditDocumentView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State var document: VehicleDocument
    var onSave: (VehicleDocument) -> Void
    var body: some View {
        Form {
            Section("Document") {
                Picker("Type", selection: $document.type) {
                    ForEach(
                        ["Insurance", "Revenue Licence", "Emission Certificate", "Other"],
                        id: \.self
                    ) { Text($0) }
                }
                TextField("Document number", text: $document.number)
                TextField("Registration", text: $document.registration)
                DatePicker("Issue date", selection: $document.issueDate, displayedComponents: .date)
                DatePicker(
                    "Expiry date", selection: $document.expiryDate, displayedComponents: .date)
            }
            Section {
                Button("Save changes") {
                    document.status = computedDocumentStatus(document.expiryDate)
                    if let i = store.documents.firstIndex(where: { $0.id == document.id }) {
                        store.documents[i] = document
                        store.persist()
                        store.refreshLocalReminders()
                    }
                    onSave(document)
                    dismiss()
                }
            }
        }
        .navigationTitle("Edit document").navigationBarTitleDisplayMode(.inline)
    }
}

struct DocumentScannerFlow: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var vehicleID: UUID? = nil
    var startWithCamera = false
    @State private var scannedPages: [UIImage] = []
    @State private var preparedPages: [Data] = []
    @State private var recognizedText = ""
    @State private var isProcessing = false
    @State private var error: String?
    @State private var showReview = false
    @State private var showImagePicker = false
    @State private var showPhotoLibrary = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var didAutoOpenCamera = false
    @State private var scanCompleted = false
    var body: some View {
        Group {
            if showImagePicker {
                DocumentCameraPicker { pages in
                    showImagePicker = false
                    guard let pages, !pages.isEmpty else {
                        error = "Scan cancelled. You can try again or enter details manually."
                        return
                    }
                    scannedPages = pages
                    runOCR(on: pages)
                }
                .ignoresSafeArea()
                .toolbar(.hidden, for: .navigationBar)
            } else {
                scannerContent
            }
        }
        .onAppear {
            if startWithCamera && DocumentCameraPicker.isCameraSupported && !didAutoOpenCamera {
                didAutoOpenCamera = true
                showImagePicker = true
            }
        }
        .photosPicker(
            isPresented: $showPhotoLibrary, selection: $selectedPhotos,
            maxSelectionCount: 10, matching: .images
        )
        .onChange(of: selectedPhotos) { _, items in
            guard !items.isEmpty else { return }
            Task {
                isProcessing = true
                defer { selectedPhotos = [] }
                do {
                    var pages: [UIImage] = []
                    for item in items {
                        guard let data = try await item.loadTransferable(type: Data.self),
                            let image = UIImage(data: data)
                        else { throw PhotoProcessing.Error.invalidImage }
                        pages.append(image)
                    }
                    scannedPages = pages
                    runOCR(on: pages)
                } catch {
                    isProcessing = false
                    self.error = "Could not open the selected photo. Choose another image."
                }
            }
        }
        .sheet(isPresented: $showReview) {
            NavigationStack {
                OCRReviewView(
                    extractedText: recognizedText, scannedPages: preparedPages,
                    vehicleID: vehicleID
                ) {
                    scanCompleted = true
                    showReview = false
                }
            }
            .interactiveDismissDisabled()
        }
        .onChange(of: showReview) { _, isPresented in
            if !isPresented && scanCompleted { dismiss() }
        }
    }

    private var scannerContent: some View {
        VStack(spacing: 22) {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark").font(.headline).foregroundStyle(.secondary)
                        .frame(width: 38, height: 38).background(Color.appCard, in: Circle())
                }
                .accessibilityLabel("Close document scanner")
            }
            .padding(.horizontal, 20).padding(.top, 12)
            VStack(spacing: 12) {
                Image(systemName: "doc.viewfinder").font(.system(size: 38))
                    .foregroundStyle(Color.appAccent).frame(width: 88, height: 88)
                    .background(Color.appMint, in: Circle())
                Text("Scan a vehicle document").font(.title2.bold())
                Text(
                    DocumentCameraPicker.isCameraSupported
                        ? "Place your insurance, revenue licence, or emission certificate in the frame. We'll suggest details for you to review."
                        : "Choose a clear photo of your document. We'll read its text and let you review the details."
                )
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            }
            if let firstPage = scannedPages.first {
                Image(uiImage: firstPage).resizable().scaledToFit().frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16)).padding(.horizontal, 20)
                Text("\(scannedPages.count) page\(scannedPages.count == 1 ? "" : "s") captured")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if isProcessing { ProgressView("Reading document…").tint(.appAccent).padding() }
            if let error {
                Text(error).font(.caption).foregroundStyle(.red).multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            Spacer()
            VStack(spacing: 11) {
                if DocumentCameraPicker.isCameraSupported {
                    Button {
                        showImagePicker = true
                    } label: {
                        Label("Scan with Camera", systemImage: "camera.viewfinder")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isProcessing)
                }
                Button {
                    showPhotoLibrary = true
                } label: {
                    Label("Choose from Photos", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isProcessing)
                Button {
                    scannedPages = []
                    preparedPages = []
                    recognizedText = ""
                    showReview = true
                } label: {
                    Text("Enter details manually")
                }
                .buttonStyle(SecondaryButtonStyle())
                Text("Text recognition may be imperfect. You'll review every field before saving.")
                    .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(20)
        }
        .background(Color.appCanvas.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar)
    }

    private func runOCR(on pages: [UIImage]) {
        isProcessing = true
        error = nil
        DispatchQueue.global(qos: .userInitiated)
            .async {
                var pageText: [String] = []
                var pageData: [Data] = []
                for (index, page) in pages.enumerated() {
                    guard let raw = page.jpegData(compressionQuality: 0.9),
                        let jpeg = try? PhotoProcessing.jpegData(
                            from: raw, maxPixelSize: 1800, maxBytes: 900_000)
                    else {
                        DispatchQueue.main.async {
                            isProcessing = false
                            error = "Could not prepare the scan. Please retake it."
                        }
                        return
                    }
                    pageData.append(jpeg)
                    guard let cgImage = page.cgImage else { continue }
                    let request = VNRecognizeTextRequest()
                    request.recognitionLevel = .accurate
                    request.usesLanguageCorrection = true
                    request.automaticallyDetectsLanguage = true
                    if (try? VNImageRequestHandler(cgImage: cgImage).perform([request])) != nil {
                        let lines =
                            request.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
                        pageText.append("Page \(index + 1)\n" + lines.joined(separator: "\n"))
                    }
                }
                DispatchQueue.main.async {
                    preparedPages = pageData
                    recognizedText = pageText.joined(separator: "\n\n")
                    isProcessing = false
                    showReview = true
                }
            }
    }
}

struct DocumentCameraPicker: UIViewControllerRepresentable {
    var onComplete: ([UIImage]?) -> Void

    static var isCameraSupported: Bool {
        #if targetEnvironment(simulator)
            false
        #else
            VNDocumentCameraViewController.isSupported
        #endif
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIViewController {
        if Self.isCameraSupported {
            let controller = VNDocumentCameraViewController()
            controller.delegate = context.coordinator
            return controller
        }
        let picker = UIImagePickerController()
        picker.sourceType =
            UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate,
        UIImagePickerControllerDelegate, UINavigationControllerDelegate
    {
        let parent: DocumentCameraPicker
        init(_ parent: DocumentCameraPicker) { self.parent = parent }
        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan
        ) {
            let pages = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            parent.onComplete(pages.isEmpty ? nil : pages)
        }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onComplete(nil)
        }
        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController, didFailWithError error: Error
        ) { parent.onComplete(nil) }
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.originalImage] as? UIImage
            parent.onComplete(image.map { [$0] })
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onComplete(nil)
        }
    }
}

struct OCRReviewView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var extractedText: String
    var scannedPages: [Data]
    var vehicleID: UUID? = nil
    var onSaved: () -> Void
    @State private var type = "Insurance"
    @State private var number = ""
    @State private var registration = ""
    @State private var issueDate = Date()
    @State private var expiryDate =
        Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var error: String?
    @State private var issueDateFound = false
    @State private var expiryDateFound = false
    @State private var didAutofill = false
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 5) {
                    Label("Review extracted information", systemImage: "checkmark.viewfinder")
                        .font(.headline)
                    Text(
                        "OCR suggestions can be inaccurate. Please check each field before saving."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            if !scannedPages.isEmpty {
                Section("Scanned document") {
                    Text(
                        "\(scannedPages.count) page\(scannedPages.count == 1 ? "" : "s") ready to save"
                    )
                    if extractedText.isEmpty {
                        Text("No text was recognized. Enter the details below manually.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
            }
            Section("Document type") {
                Picker("Type", selection: $type) {
                    ForEach(
                        ["Insurance", "Revenue Licence", "Emission Certificate", "Other"],
                        id: \.self
                    ) { Text($0) }
                }
            }
            Section("Confirm details") {
                TextField("Document number", text: $number)
                TextField("Vehicle registration", text: $registration)
                DatePicker("Issue date", selection: $issueDate, displayedComponents: .date)
                DatePicker("Expiry date", selection: $expiryDate, displayedComponents: .date)
                if !extractedText.isEmpty && (!issueDateFound || !expiryDateFound) {
                    Text(
                        "Could not recognize \((!issueDateFound && !expiryDateFound) ? "either date" : (!issueDateFound ? "the issue date" : "the expiry date")) from the scan. Set it manually before saving."
                    )
                    .font(.caption).foregroundStyle(.orange)
                }
            }
            if !extractedText.isEmpty {
                Section("Recognized text") {
                    Text(extractedText).font(.caption.monospaced()).foregroundStyle(.secondary)
                        .lineLimit(7)
                }
            }
            if let error { Text(error).foregroundStyle(.red) }
            Section {
                Button("Confirm and save") { save() }
                    .disabled(number.isEmpty || registration.isEmpty)
            }
        }
        .navigationTitle("Verify details").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
        .onAppear { autofill() }
    }
    private func autofill() {
        guard !didAutofill else { return }
        didAutofill = true
        let upper = extractedText.uppercased()
        if upper.contains("LICENCE") || upper.contains("LICENSE") { type = "Revenue Licence" }
        if upper.contains("EMISSION") || upper.contains("EMISSIONS") {
            type = "Emission Certificate"
        }
        let tokens = extractedText.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        if let registrationGuess = tokens.first(where: {
            $0.range(of: #"^[A-Z]{2,3}\d{3,4}$"#, options: .regularExpression) != nil
        }) {
            registration = registrationGuess
        }
        if let numberGuess = tokens.first(where: {
            $0.count >= 8 && $0.rangeOfCharacter(from: .decimalDigits) != nil
        }) {
            number = numberGuess
        }
        if registration.isEmpty {
            registration =
                store.vehicles.first(where: { $0.id == vehicleID })?.registration
                ?? store.selectedVehicle?.registration ?? ""
        }
        let dates = DocumentDateExtractor.extract(from: extractedText)
        if let date = dates.issue {
            issueDate = date
            issueDateFound = true
        }
        if let date = dates.expiry {
            expiryDate = date
            expiryDateFound = true
        }
    }
    private func save() {
        guard
            let vehicle =
                store.vehicles.first(where: { $0.id == vehicleID }) ?? store.selectedVehicle
        else {
            error = "Select a vehicle first."
            return
        }
        guard expiryDate >= issueDate else {
            error = "Expiry date must be after the issue date."
            return
        }
        let document = VehicleDocument(
            vehicleID: vehicle.id, type: type, number: number,
            registration: registration.uppercased(), issueDate: issueDate,
            expiryDate: expiryDate, status: computedDocumentStatus(expiryDate),
            imageName: "doc.text.fill", scanPageCount: scannedPages.count)
        do {
            try store.saveDocumentScan(scannedPages, documentID: document.id)
            store.addDocument(document)
            onSaved()
        } catch { self.error = error.localizedDescription }
    }
}

private enum DocumentDateExtractor {
    private enum Kind { case issue, expiry }
    private static let issueLabel = try! NSRegularExpression(
        pattern:
            #"\b(?:date\s*(?:of\s*)?(?:issue|issued)|issue\s*date|issued(?:\s*on)?|effective\s*(?:date|from)|valid\s*from|commencement\s*date|start\s*date)\b"#,
        options: .caseInsensitive)
    private static let expiryLabel = try! NSRegularExpression(
        pattern:
            #"\b(?:date\s*(?:of\s*)?(?:expiry|expiration)|expir(?:y|ation|es?)\s*(?:date|on)?|valid\s*(?:until|till|to)|end\s*date)\b"#,
        options: .caseInsensitive)
    private static let datePattern = try! NSRegularExpression(
        pattern:
            #"\b(?:\d{4}\s*[-./]\s*\d{1,2}\s*[-./]\s*\d{1,2}|\d{1,2}\s*[-./]\s*\d{1,2}\s*[-./]\s*\d{2,4}|\d{1,2}(?:st|nd|rd|th)?[\s,./-]+[A-Za-z]{3,9}[\s,./-]+\d{2,4}|[A-Za-z]{3,9}[\s,./-]+\d{1,2}(?:st|nd|rd|th)?[,]?\s+\d{2,4})\b"#,
        options: .caseInsensitive)

    static func extract(from text: String) -> (issue: Date?, expiry: Date?) {
        let lines = text.components(separatedBy: .newlines)
        var issue: Date?
        var expiry: Date?
        for (index, line) in lines.enumerated() {
            let source = line as NSString
            let range = NSRange(location: 0, length: source.length)
            let labels: [(NSRange, Kind)] =
                issueLabel.matches(in: line, range: range).map { ($0.range, .issue) }
                + expiryLabel.matches(in: line, range: range).map { ($0.range, .expiry) }
            let ordered = labels.sorted { $0.0.location < $1.0.location }
            for (position, label) in ordered.enumerated() {
                let start = NSMaxRange(label.0)
                let end =
                    position + 1 < ordered.count ? ordered[position + 1].0.location : source.length
                let segment = source.substring(with: NSRange(location: start, length: end - start))
                var found = dates(in: segment).first
                if found == nil && position == ordered.count - 1 && index + 1 < lines.count {
                    let next = lines[index + 1]
                    let nextRange = NSRange(location: 0, length: (next as NSString).length)
                    if issueLabel.firstMatch(in: next, range: nextRange) == nil
                        && expiryLabel.firstMatch(in: next, range: nextRange) == nil
                    {
                        found = dates(in: next).first
                    }
                }
                if let found {
                    switch label.1 {
                    case .issue: if issue == nil { issue = found }
                    case .expiry: if expiry == nil { expiry = found }
                    }
                }
            }
        }

        // Some documents print only two dates without labels. Suggest them in chronological order.
        if issue == nil && expiry == nil {
            let all = dates(in: text)
            if all.count == 2 && all[0] != all[1] {
                issue = min(all[0], all[1])
                expiry = max(all[0], all[1])
            }
        }
        return (issue, expiry)
    }

    private static func dates(in text: String) -> [Date] {
        let source = text as NSString
        return datePattern.matches(in: text, range: NSRange(location: 0, length: source.length))
            .compactMap {
                parse(source.substring(with: $0.range))
            }
    }

    private static func parse(_ raw: String) -> Date? {
        let value =
            raw.replacingOccurrences(
                of: #"(?i)(\d)(st|nd|rd|th)\b"#, with: "$1", options: .regularExpression
            )
            .replacingOccurrences(of: #"[,.\-/]+"#, with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let parts = value.split(separator: " ").map(String.init)
        guard parts.count == 3 else { return nil }
        let yearText: String
        let day: Int?
        let month: Int?
        if parts[0].count == 4, let year = Int(parts[0]) {
            yearText = parts[0]
            month = Int(parts[1])
            day = Int(parts[2])
            guard year >= 1900 else { return nil }
        } else if let first = Int(parts[0]) {
            day = first
            month = Int(parts[1]) ?? monthNumber(parts[1])
            yearText = parts[2]
        } else {
            month = monthNumber(parts[0])
            day = Int(parts[1])
            yearText = parts[2]
        }
        guard let day, let month, let rawYear = Int(yearText),
            yearText.count == 2 || yearText.count == 4
        else { return nil }
        let year = yearText.count == 2 ? 2000 + rawYear : rawYear
        guard (1900...2100).contains(year) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day))
        else { return nil }
        let checked = calendar.dateComponents([.year, .month, .day], from: date)
        return checked.year == year && checked.month == month && checked.day == day ? date : nil
    }

    private static func monthNumber(_ text: String) -> Int? {
        let months = [
            "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec",
        ]
        guard let index = months.firstIndex(of: String(text.lowercased().prefix(3))) else {
            return nil
        }
        return index + 1
    }
}

func computedDocumentStatus(_ expiry: Date) -> String {
    if expiry < Calendar.current.startOfDay(for: Date()) { return "Expired" }
    if expiry < (Calendar.current.date(byAdding: .day, value: 31, to: Date()) ?? Date()) {
        return "Expiring Soon"
    }
    return "Valid"
}
