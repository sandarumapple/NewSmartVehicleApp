import CoreLocation
import MapKit
import PhotosUI
import SwiftUI

struct ExploreView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 21) {
                ScreenHeading(title: "Explore", subtitle: "Good things happen on the road")
                NavigationLink {
                    MarketplaceView()
                } label: {
                    exploreCard(
                        title: "Marketplace", subtitle: "Vehicles & parts worth a look",
                        symbol: "bag.fill", tint: .blue, background: "market")
                }
                .buttonStyle(.plain).padding(.horizontal, 20)
                NavigationLink {
                    CommunityView()
                } label: {
                    exploreCard(
                        title: "Owner community", subtitle: "Real stories from fellow drivers",
                        symbol: "bubble.left.and.bubble.right.fill", tint: .appAccent,
                        background: "community")
                }
                .buttonStyle(.plain).padding(.horizontal, 20)
                NavigationLink {
                    NearbyMapView()
                } label: {
                    exploreCard(
                        title: "Nearby", subtitle: "Find fuel and vehicle services",
                        symbol: "map.fill", tint: .orange, background: "nearby")
                }
                .buttonStyle(.plain).padding(.horizontal, 20)
                Text("Made for people who love their drive.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 22).padding(.top, 4)
            }
            .padding(.vertical, 14)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(Color.appCanvas.ignoresSafeArea()).toolbar(.hidden, for: .navigationBar)
    }
    private func exploreCard(
        title: String, subtitle: String, symbol: String, tint: Color, background: String
    ) -> some View {
        SurfaceCard(padding: 20) {
            HStack(spacing: 15) {
                Image(systemName: symbol).font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tint).frame(width: 55, height: 55)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.title3.bold()).foregroundStyle(.primary)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right").font(.subheadline.bold())
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct MarketplaceView: View {
    @EnvironmentObject private var store: AppStore
    @State private var query = ""
    @AppStorage("smart-vehicle-marketplace-category") private var category = "Vehicles"
    @State private var showFilters = false
    @AppStorage("smart-vehicle-marketplace-make") private var filterMake = "All makes"
    @State private var maxPrice = 30000000.0
    @State private var hasPriceLimit = false
    @State private var showNewListing = false
    @State private var listingMode = "Browse"
    private let listingColumns = [
        GridItem(.adaptive(minimum: 155, maximum: 260), spacing: 12, alignment: .top)
    ]
    init(showMyListings: Bool = false) {
        _listingMode = State(initialValue: showMyListings ? "My listings" : "Browse")
    }
    private let categories = ["Vehicles", "Spare parts"]
    private let demoItems = [
        MarketplaceItem(
            id: UUID(uuidString: "E4ECA3D2-90DB-4D42-9A95-20E24C520001")!,
            title: "Toyota Aqua G", subtitle: "2021 · Hybrid · 38,000 km", price: "LKR 8,950,000",
            category: "Vehicles", symbol: "car.side.fill", tint: "blue", distance: "Colombo"),
        MarketplaceItem(
            id: UUID(uuidString: "E4ECA3D2-90DB-4D42-9A95-20E24C520002")!,
            title: "Honda Vezel RS", subtitle: "2020 · Hybrid · 52,000 km", price: "LKR 14,250,000",
            category: "Vehicles", symbol: "car.side.fill", tint: "purple", distance: "Nugegoda"),
        MarketplaceItem(
            id: UUID(uuidString: "E4ECA3D2-90DB-4D42-9A95-20E24C520003")!,
            title: "Toyota Corolla Axio", subtitle: "2019 · Petrol · 61,000 km",
            price: "LKR 7,800,000", category: "Vehicles", symbol: "car.side.fill", tint: "teal",
            distance: "Kandy"),
        MarketplaceItem(
            id: UUID(uuidString: "E4ECA3D2-90DB-4D42-9A95-20E24C520004")!,
            title: "Premium oil filter · 04152", subtitle: "Toyota Corolla · Genuine fit",
            price: "LKR 4,250", category: "Spare parts", symbol: "gearshape.2.fill", tint: "orange",
            distance: "Colombo 05"),
        MarketplaceItem(
            id: UUID(uuidString: "E4ECA3D2-90DB-4D42-9A95-20E24C520005")!,
            title: "Michelin Energy XM2+", subtitle: "185/65 R15 · Set of 4", price: "LKR 112,000",
            category: "Spare parts", symbol: "circle.dashed", tint: "pink", distance: "Rajagiriya"),
    ]
    private var items: [MarketplaceItem] {
        store.isFirebaseConfigured ? store.marketplaceItems : demoItems
    }
    private var effectiveShowOnlyMine: Bool {
        store.isFirebaseConfigured && listingMode == "My listings"
    }
    private var availableMakes: [String] {
        let makes = items.filter { $0.category == "Vehicles" }.compactMap {
            $0.title.split(separator: " ").first.map(String.init)
        }
        return ["All makes"] + Set(makes).sorted()
    }
    private var maximumFilterPrice: Double {
        let highest = items.filter { $0.category == category }.map(\.priceAmount).max() ?? 0
        let floor = category == "Vehicles" ? 30_000_000 : 500_000
        let step = category == "Vehicles" ? 500_000 : 1_000
        return Double(max(floor, ((highest + step - 1) / step) * step))
    }
    private var visible: [MarketplaceItem] {
        items.filter {
            $0.category == category
                && (!effectiveShowOnlyMine || $0.sellerID == store.currentUserID)
                && (listingMode != "Saved" || store.isListingSaved($0))
                && (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)
                    || $0.subtitle.localizedCaseInsensitiveContains(query))
                && (category != "Vehicles" || filterMake == "All makes"
                    || $0.title.localizedCaseInsensitiveContains(filterMake))
                && (!hasPriceLimit || Double($0.priceAmount) <= maxPrice)
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    ScreenHeading(
                        title: "Marketplace",
                        subtitle: "Vehicles, genuine parts & owner listings"
                    )
                    if store.isFirebaseConfigured {
                        Button {
                            showNewListing = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(
                                    Color.marketplaceBlue,
                                    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                                )
                                .shadow(color: Color.marketplaceBlue.opacity(0.24), radius: 7, y: 3)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Create marketplace listing")
                        .padding(.trailing, 16)
                    }
                }

                HStack(spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Search vehicles, parts or brands", text: $query)
                            .autocorrectionDisabled()
                        if !query.isEmpty {
                            Button {
                                query = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Clear marketplace search")
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                    }

                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                            }
                            .overlay(alignment: .topTrailing) {
                                if filterMake != "All makes" || hasPriceLimit {
                                    Circle().fill(Color.marketplaceBlue).frame(width: 8, height: 8)
                                        .padding(7)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Marketplace filters")
                }
                .padding(.horizontal, 16)

                Picker("Category", selection: $category) {
                    ForEach(categories, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented).padding(.horizontal, 16)
                Picker("Listings", selection: $listingMode) {
                    Text("Browse").tag("Browse")
                    Text("Saved").tag("Saved")
                    if store.isFirebaseConfigured {
                        Text("My listings").tag("My listings")
                    }
                }
                .pickerStyle(.segmented).padding(.horizontal, 16)

                if filterMake != "All makes" || hasPriceLimit {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            if filterMake != "All makes" {
                                MarketplaceFilterChip(title: filterMake, symbol: "car.side.fill") {
                                    filterMake = "All makes"
                                }
                            }
                            if hasPriceLimit {
                                MarketplaceFilterChip(
                                    title: "Up to LKR \(Int(maxPrice).formatted())",
                                    symbol: "banknote.fill"
                                ) { hasPriceLimit = false }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                if !store.isFirebaseConfigured {
                    Label("Demo listings are only shown on this device.", systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 16)
                }
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(
                            effectiveShowOnlyMine ? "My listings"
                                : listingMode == "Saved" ? "Saved listings"
                                : (category == "Vehicles" ? "Featured vehicles" : "Popular parts")
                        )
                        .font(.subheadline.weight(.semibold))
                        Text(category == "Vehicles" ? "Available near you" : "Parts shared by owners")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(visible.count) results")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.marketplaceBlue)
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(Color.marketplaceBlue.opacity(0.11), in: Capsule())
                }
                .padding(.horizontal, 16)
                if visible.isEmpty {
                    EmptyStateView(
                        symbol: "magnifyingglass",
                        title: effectiveShowOnlyMine ? "No listings here"
                            : listingMode == "Saved" ? "No saved listings"
                            : (items.isEmpty ? "No listings yet" : "No results found"),
                        message: effectiveShowOnlyMine ? "Your published listings appear here. Try the other category or create a listing."
                            : listingMode == "Saved"
                            ? "Tap the heart on a listing to keep it here."
                            : items.isEmpty
                            ? "Listings from other drivers will appear here when they publish."
                            : "Try a different search or clear your filters.",
                        action: items.isEmpty ? "Create listing" : "Clear filters"
                    ) {
                        if items.isEmpty {
                            showNewListing = true
                        } else {
                            query = ""
                            filterMake = "All makes"
                            hasPriceLimit = false
                            listingMode = "Browse"
                        }
                    }
                } else {
                    LazyVGrid(columns: listingColumns, spacing: 12) {
                        ForEach(visible) { item in
                            ZStack(alignment: .topTrailing) {
                                NavigationLink {
                                    ListingDetailView(item: item)
                                } label: {
                                    ListingCard(item: item)
                                }
                                .buttonStyle(.plain)
                                if !store.canDeleteListing(item) {
                                    Button {
                                        store.toggleSavedListing(item)
                                    } label: {
                                        Image(systemName: store.isListingSaved(item) ? "heart.fill" : "heart")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(store.isListingSaved(item) ? .red : .primary)
                                            .frame(width: 34, height: 34)
                                            .background(.regularMaterial, in: Circle())
                                    }
                                    .accessibilityLabel(
                                        store.isListingSaved(item)
                                            ? "Remove listing from saved items" : "Save listing")
                                    .padding(8)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color.appCanvas.ignoresSafeArea()).navigationTitle("Marketplace")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFilters) {
            NavigationStack {
                Form {
                    if category == "Vehicles" {
                        Section("Vehicle make") {
                            Picker("Make", selection: $filterMake) {
                                ForEach(availableMakes, id: \.self) {
                                    Text($0)
                                }
                            }
                        }
                    }
                    Section("Maximum price") {
                        Toggle("Limit price", isOn: $hasPriceLimit)
                        if hasPriceLimit {
                            Slider(
                                value: $maxPrice,
                                in: (category == "Vehicles" ? 500_000 : 1_000)...maximumFilterPrice,
                                step: category == "Vehicles" ? 500_000 : 1_000)
                            Text("Up to LKR \(Int(maxPrice).formatted())").font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Section {
                        Button("Reset filters") {
                            filterMake = "All makes"
                            maxPrice = maximumFilterPrice
                            hasPriceLimit = false
                        }
                    }
                }
                .navigationTitle("Filters")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { showFilters = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showNewListing) {
            NavigationStack {
                NewListingView(onSaved: { item in
                    listingMode = "My listings"
                    category = item.category
                    query = ""
                    filterMake = "All makes"
                    hasPriceLimit = false
                })
            }
        }
        .onChange(of: category) { _, _ in
            filterMake = "All makes"
            hasPriceLimit = false
            maxPrice = maximumFilterPrice
        }
        .onAppear {
            if !store.isFirebaseConfigured && listingMode == "My listings" {
                listingMode = "Browse"
            }
        }
    }
}

private struct MarketplaceFilterChip: View {
    let title: String
    let symbol: String
    let onClear: () -> Void

    var body: some View {
        Button(action: onClear) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                Text(title)
                Image(systemName: "xmark")
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 11)
            .frame(minHeight: 44)
            .background(Color.marketplaceBlue, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Clear \(title) filter")
    }
}

struct ListingCard: View {
    var item: MarketplaceItem
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.forName(item.tint).opacity(0.2),
                                Color.forName(item.tint).opacity(0.06),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 128)
                    .overlay {
                        if let data = item.imageData, let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: item.symbol)
                                .font(.system(size: 55, weight: .ultraLight))
                                .foregroundStyle(Color.forName(item.tint))
                        }
                    }
                    .clipped()
                Label(item.category, systemImage: item.category == "Vehicles" ? "car.side.fill" : "gearshape.2.fill")
                    .font(.appBadge)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 7).padding(.vertical, 5)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                    .padding(8)
            }
            VStack(alignment: .leading, spacing: 7) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(item.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(item.price)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)
                Label(item.distance, systemImage: "location.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(12)
        }
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.06), radius: 7, y: 3)
    }
}

private extension Color {
    static let marketplaceBlue = Color(red: 26 / 255, green: 107 / 255, blue: 1)
}

struct ListingDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var item: MarketplaceItem
    @State private var showContact = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var showEditor = false
    private var displayedItem: MarketplaceItem {
        store.marketplaceItems.first(where: { $0.id == item.id }) ?? item
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 19) {
                ZStack {
                    RoundedRectangle(cornerRadius: 25).fill(Color.forName(displayedItem.tint).opacity(0.12))
                        .frame(height: 250)
                    if let data = displayedItem.imageData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 25))
                    } else {
                        Image(systemName: displayedItem.symbol)
                            .font(.system(size: 100, weight: .ultraLight))
                            .foregroundStyle(Color.forName(displayedItem.tint))
                    }
                    VStack {
                        HStack {
                            Spacer()
                            if !store.canDeleteListing(displayedItem) {
                                Button {
                                    store.toggleSavedListing(displayedItem)
                                } label: {
                                    Image(systemName: store.isListingSaved(displayedItem) ? "heart.fill" : "heart").font(.headline)
                                        .foregroundStyle(store.isListingSaved(displayedItem) ? .red : .primary).padding(12)
                                        .background(.regularMaterial, in: Circle())
                                }
                                .accessibilityLabel(
                                    store.isListingSaved(displayedItem)
                                        ? "Remove listing from saved items" : "Save listing")
                            }
                        }
                        Spacer()
                    }
                    .padding(16)
                }
                .padding(.horizontal, 20).padding(.top, 8)
                VStack(alignment: .leading, spacing: 11) {
                    Text(displayedItem.title).font(.title.bold())
                    Text(displayedItem.price).font(.title2.bold()).foregroundStyle(Color.appAccent)
                    Label(displayedItem.distance, systemImage: "location.fill").font(.subheadline)
                        .foregroundStyle(.secondary)
                    Divider()
                    Text(displayedItem.subtitle).font(.subheadline)
                    if !store.canDeleteListing(displayedItem) {
                        Text(
                            "A customer listing shared for vehicle owners to browse. Contact the listed party to confirm availability, condition, and purchase details."
                        )
                        .font(.subheadline).foregroundStyle(.secondary).lineSpacing(3)
                    }
                }
                .padding(.horizontal, 20)
                if store.canDeleteListing(displayedItem) {
                    Button("Edit listing", systemImage: "pencil") { showEditor = true }
                        .buttonStyle(PrimaryButtonStyle()).padding(.horizontal, 20)
                    Button("Delete my listing", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .disabled(isDeleting)
                    .padding(.horizontal, 20)
                } else {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Before you buy").font(.subheadline.bold())
                            Label("Verify documents and ownership", systemImage: "checkmark.shield")
                            Label("Inspect condition in person", systemImage: "eye")
                            Label("Confirm current pricing", systemImage: "tag")
                        }
                        .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                    Button {
                        showContact = true
                    } label: {
                        Label("Contact about this listing", systemImage: "message.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle()).padding(.horizontal, 20)
                }
                if isDeleting { ProgressView("Deleting listing…").padding(.horizontal, 20) }
                if let deleteError {
                    Text(deleteError).foregroundStyle(.red).padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 25)
        }
        .background(Color.appCanvas.ignoresSafeArea()).navigationTitle("Listing")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Contact option", isPresented: $showContact) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(
                displayedItem.contact.map { "Seller contact: \($0)" }
                    ?? "This listing has no contact details. Verify the listing before arranging a purchase."
            )
        }
        .confirmationDialog(
            "Delete this listing?", isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete listing", role: .destructive) {
                isDeleting = true
                Task {
                    do {
                        try await store.deleteListing(displayedItem)
                        dismiss()
                    } catch {
                        deleteError = error.localizedDescription
                        isDeleting = false
                    }
                }
            }
        } message: {
            Text("This removes the listing for everyone.")
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack { NewListingView(existingItem: displayedItem) }
        }
    }
}

struct NewListingView: View {
    private enum ListingCategory: String, CaseIterable {
        case vehicles = "Vehicles"
        case spareParts = "Spare parts"

        var symbol: String {
            switch self {
            case .vehicles: "car.side.fill"
            case .spareParts: "gearshape.2.fill"
            }
        }

        var explanation: String {
            switch self {
            case .vehicles: "Cars, vans, and motorcycles"
            case .spareParts: "Parts, tyres, and accessories"
            }
        }
    }

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let existingItem: MarketplaceItem?
    let onSaved: (MarketplaceItem) -> Void
    @State private var title: String
    @State private var subtitle: String
    @State private var category: ListingCategory?
    @State private var price: String
    @State private var location: String
    @State private var contact: String
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var isProcessingPhoto = false
    @State private var error: String?
    @State private var isSaving = false

    init(
        existingItem: MarketplaceItem? = nil,
        onSaved: @escaping (MarketplaceItem) -> Void = { _ in }
    ) {
        self.existingItem = existingItem
        self.onSaved = onSaved
        _title = State(initialValue: existingItem?.title ?? "")
        _subtitle = State(initialValue: existingItem?.subtitle ?? "")
        _category = State(initialValue: existingItem.flatMap {
            ListingCategory(rawValue: $0.category)
        })
        _price = State(initialValue: existingItem.map { String($0.priceAmount) } ?? "")
        _location = State(initialValue: existingItem?.distance ?? "")
        _contact = State(initialValue: existingItem?.contact ?? "")
        _selectedPhoto = State(initialValue: nil)
        _photoData = State(initialValue: existingItem?.imageData)
    }

    private var enteredPrice: Int? {
        Int(price.replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var body: some View {
        Form {
            Section {
                ForEach(ListingCategory.allCases, id: \.self) { option in
                    Button {
                        category = option
                        error = nil
                    } label: {
                        HStack(spacing: 13) {
                            Image(systemName: option.symbol)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(category == option ? Color.appAccent : .secondary)
                                .frame(width: 42, height: 42)
                                .background(
                                    Color.appAccent.opacity(category == option ? 0.14 : 0.05),
                                    in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(option.rawValue).font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(option.explanation).font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: category == option ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(category == option ? Color.appAccent : .secondary)
                                .font(.title3)
                        }
                        .frame(minHeight: 55)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(option.rawValue), \(option.explanation)")
                    .accessibilityAddTraits(category == option ? .isSelected : [])
                }
            } header: {
                Text("What are you listing?")
            } footer: {
                Text("Choose one category so other drivers can find your listing.")
            }
            Section("Listing photo") {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(
                        photoData == nil ? "Choose from Photo Library" : "Change photo",
                        systemImage: photoData == nil ? "photo.badge.plus" : "photo"
                    )
                }
                .disabled(isProcessingPhoto || isSaving)

                if isProcessingPhoto {
                    ProgressView("Preparing photo…")
                }

                if let photoData, let image = UIImage(data: photoData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 190)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .clipped()

                    Button("Remove photo", role: .destructive) {
                        selectedPhoto = nil
                        self.photoData = nil
                    }
                    .disabled(isProcessingPhoto || isSaving)
                }
            }
            Section("Listing") {
                TextField(
                    category == .vehicles ? "Make and model" : "Listing title",
                    text: $title)
                TextField("Details", text: $subtitle)
                TextField("Price (LKR)", text: $price).keyboardType(.numberPad)
                TextField("Location", text: $location)
            }
            Section("Contact") {
                TextField("Phone or email", text: $contact)
                Text("Your contact detail will be visible to everyone browsing the marketplace.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let error { Text(error).foregroundStyle(.red) }
            Section {
                Button(isSaving ? "Saving…" : (existingItem == nil ? "Publish listing" : "Save changes")) {
                    publish()
                }
                    .disabled(
                        isSaving || category == nil
                            || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || contact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || (enteredPrice ?? 0) <= 0)
            }
        }
        .navigationTitle(existingItem == nil ? "New listing" : "Edit listing")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                isProcessingPhoto = true
                defer { isProcessingPhoto = false }
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        throw PhotoProcessing.Error.invalidImage
                    }
                    photoData = try await PhotoProcessing.prepare(data, maxPixelSize: 1_200)
                    error = nil
                } catch {
                    self.error = error.localizedDescription
                }
                selectedPhoto = nil
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    private func publish() {
        guard let category else {
            error = "Choose Vehicles or Spare parts."
            return
        }
        guard let amount = enteredPrice, amount > 0 else {
            error = "Enter a valid price."
            return
        }
        isSaving = true
        error = nil
        var item = existingItem ?? MarketplaceItem(
            title: "", subtitle: "", price: "", category: category.rawValue,
            symbol: "", tint: "", distance: "")
        item.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        item.subtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        item.price = "LKR \(amount.formatted())"
        item.category = category.rawValue
        item.symbol = category.symbol
        item.tint = category == .vehicles ? "blue" : "orange"
        item.distance = location.trimmingCharacters(in: .whitespacesAndNewlines)
        item.contact = contact.trimmingCharacters(in: .whitespacesAndNewlines)
        item.imageData = photoData
        Task {
            do {
                if existingItem == nil {
                    try await store.publishListing(item)
                } else {
                    try await store.updateListing(item)
                }
                onSaved(item)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            isSaving = false
        }
    }
}

struct CommunityView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showComposer = false
    @AppStorage("smart-vehicle-community-filter") private var selectedFilter = "All posts"
    @State private var vehicleQuery = ""
    @State private var showMine = false

    init(showMyPosts: Bool = false, initialVehicleQuery: String = "") {
        _showMine = State(initialValue: showMyPosts)
        _vehicleQuery = State(initialValue: initialVehicleQuery)
    }

    private var visiblePosts: [CommunityPost] {
        CommunityFeedViewModel.visiblePosts(
            store.posts, category: selectedFilter, vehicleQuery: vehicleQuery,
            authorFilter: showMine ? .myPosts : .everyone,
            currentUserID: store.currentUserID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Community Feed")
                            .font(.appScreenTitle)
                            .tracking(-0.5)
                        Text("Discussions, owner insights & helpful vehicle tips")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Button {
                        showComposer = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.communityBlue, in: RoundedRectangle(cornerRadius: 14))
                            .shadow(color: Color.communityBlue.opacity(0.25), radius: 8, y: 4)
                    }
                    .accessibilityLabel("Create community post")
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    TextField("Search vehicles or discussions", text: $vehicleQuery)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                    if !vehicleQuery.isEmpty {
                        Button {
                            vehicleQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear vehicle search")
                    }
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 42)
                .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                }
                .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CommunityFilterPill(
                            title: "All posts", symbol: "rectangle.stack.fill",
                            isSelected: selectedFilter == "All posts"
                        ) { selectedFilter = "All posts" }
                        CommunityFilterPill(
                            title: "Questions", symbol: "questionmark.bubble.fill",
                            isSelected: selectedFilter == "Questions"
                        ) { selectedFilter = "Questions" }
                        CommunityFilterPill(
                            title: "Solutions", symbol: "checkmark.seal.fill",
                            isSelected: selectedFilter == "Solutions"
                        ) { selectedFilter = "Solutions" }
                    }
                    .padding(.horizontal, 16)
                }

                HStack(spacing: 12) {
                    Label(
                        vehicleQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "Latest activity" : "Vehicle matches",
                        systemImage: "car.side.fill"
                    )
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(visiblePosts.count) posts")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.communityBlue)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.communityBlue.opacity(0.11), in: Capsule())
                }
                .padding(.horizontal, 16)

                Picker("Posts", selection: $showMine) {
                    Text("Browse").tag(false)
                    Text("My posts").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                if !store.isFirebaseConfigured {
                    Label("Demo posts are only shown on this device.", systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 16)
                }
                if visiblePosts.isEmpty {
                    EmptyStateView(
                        symbol: "bubble.left.and.bubble.right",
                        title: showMine ? "No posts here" : (store.posts.isEmpty ? "Be the first to share" : "No matching posts"),
                        message: showMine ? "Your posts appear here after you publish them."
                            : store.posts.isEmpty
                            ? "Ask a question or share an experience with other vehicle owners."
                            : "Try another vehicle or feed filter to see more discussions.",
                        action: store.posts.isEmpty ? "Create a post" : "Clear filters"
                    ) {
                        if store.posts.isEmpty {
                            showComposer = true
                        } else {
                            selectedFilter = "All posts"
                            vehicleQuery = ""
                            showMine = false
                        }
                    }
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(visiblePosts) { post in PostCard(post: post) }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color.appCanvas.ignoresSafeArea()).navigationTitle("Community")
        .navigationBarTitleDisplayMode(.inline).toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showComposer) {
            NavigationStack {
                CreatePostView(onSaved: {
                    showMine = true
                    selectedFilter = "All posts"
                    vehicleQuery = ""
                })
            }
        }
    }
}

private struct CommunityFilterPill: View {
    let title: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(
                    isSelected ? Color.communityBlue : Color.appCard,
                    in: Capsule()
                )
                .overlay {
                    Capsule().strokeBorder(
                        isSelected ? Color.clear : Color.primary.opacity(0.08),
                        lineWidth: 1
                    )
                }
                .shadow(
                    color: isSelected ? Color.communityBlue.opacity(0.2) : .clear,
                    radius: 4,
                    y: 2
                )
        }
        .buttonStyle(.plain)
    }
}

struct PostCard: View {
    @EnvironmentObject private var store: AppStore
    @State private var showDetail = false
    var post: CommunityPost
    var isInDetail = false
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 11) {
                Text(post.initials)
                    .font(.caption.bold())
                    .foregroundStyle(Color.communityBlue)
                    .frame(width: 40, height: 40)
                    .background(Color.communityBlue.opacity(0.12), in: Circle())
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 7, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 14, height: 14)
                            .background(Color.communityBlue, in: Circle())
                            .overlay(Circle().stroke(Color.appCard, lineWidth: 2))
                    }
                VStack(alignment: .leading, spacing: 3) {
                    Text(post.author).font(.subheadline.weight(.semibold))
                    HStack(spacing: 5) {
                        Text(post.vehicle).foregroundStyle(Color.communityBlue)
                        Text("·")
                        Text(post.displayTime)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                StatusBadge(text: post.category)
            }
            Text(post.text)
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.92))
                .lineSpacing(4)
                .lineLimit(6)
            if let data = post.imageData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill().frame(height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 12)).clipped()
            }
            Divider().overlay(Color.primary.opacity(0.06))
            HStack(spacing: 18) {
                Button {
                    store.toggleLike(post)
                } label: {
                    Label("\(post.likes)", systemImage: post.isLiked ? "heart.fill" : "heart")
                        .foregroundStyle(post.isLiked ? .red : .secondary)
                }
                .disabled(store.pendingLikePostIDs.contains(post.id))
                if !isInDetail {
                    Button {
                        showDetail = true
                    } label: {
                        Label(
                            store.isFirebaseConfigured ? "Discussion" : "\(post.comments) comments",
                            systemImage: "bubble.right"
                        )
                        .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if !isInDetail {
                    Button {
                        showDetail = true
                    } label: {
                        Label("Open", systemImage: "arrow.up.right")
                            .foregroundStyle(Color.communityBlue)
                            .fontWeight(.semibold)
                    }
                }
            }
            .font(.caption)
        }
        .padding(16)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
        .onTapGesture { if !isInDetail { showDetail = true } }
        .sheet(isPresented: $showDetail) { NavigationStack { PostDetailView(post: post) } }
    }
}

private extension Color {
    static let communityBlue = Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255)
}

struct CreatePostView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var existingPost: CommunityPost? = nil
    var onSaved: () -> Void = {}
    @State private var text = ""
    @State private var category = "Question"
    @State private var postingVehicleID: UUID?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var error: String?
    @State private var isSaving = false
    var body: some View {
        Form {
            Section {
                Picker("Post type", selection: $category) {
                    ForEach(["Question", "Problem", "Solved", "Tip"], id: \.self) { Text($0) }
                }
                TextField("What would you like to share?", text: $text, axis: .vertical)
                    .lineLimit(5...10)
            }
            Section("Vehicle") {
                Picker("Posting about", selection: $postingVehicleID) {
                    Text("General").tag(UUID?.none)
                    ForEach(store.vehicles) { vehicle in
                        Text(vehicle.title).tag(Optional(vehicle.id))
                    }
                }
                Text("Selecting a vehicle helps other owners find this post.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Photo") {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(
                        photoData == nil ? "Add a photo" : "Change photo",
                        systemImage: photoData == nil ? "photo" : "checkmark.circle.fill")
                }
                .onChange(of: selectedPhoto) { _, value in
                    guard let value else { return }
                    Task {
                        do {
                            guard let data = try await value.loadTransferable(type: Data.self) else {
                                throw PhotoProcessing.Error.invalidImage
                            }
                            photoData = try await PhotoProcessing.prepare(data, maxPixelSize: 1_200)
                            error = nil
                        } catch {
                            selectedPhoto = nil
                            self.error = error.localizedDescription
                        }
                    }
                }
                if let photoData, let image = UIImage(data: photoData) {
                    Image(uiImage: image).resizable().scaledToFill().frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 14)).clipped()
                    Button("Remove photo", role: .destructive) {
                        selectedPhoto = nil
                        self.photoData = nil
                    }
                }
            }
            if let error { Text(error).foregroundStyle(.red) }
            Section {
                Button(isSaving ? "Saving…" : (existingPost == nil ? "Publish post" : "Save changes")) {
                    publish()
                }
                    .disabled(
                        isSaving || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle(existingPost == nil ? "New post" : "Edit post")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let existingPost {
                text = existingPost.text
                category = existingPost.category
                postingVehicleID = existingPost.vehicleID
                    ?? store.vehicles.first {
                        existingPost.vehicle == "\($0.title) \($0.year)"
                            || existingPost.vehicle == $0.title
                    }?.id
                photoData = existingPost.imageData
            } else {
                postingVehicleID = store.selectedVehicle?.id
            }
        }
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
    }
    private func publish() {
        let selectedVehicle = store.vehicles.first { $0.id == postingVehicleID }
        let vehicleTitle = selectedVehicle.map { "\($0.title) \($0.year)" } ?? "General"
        var post = existingPost ?? CommunityPost(
            author: store.userName,
            initials: String(store.userName.split(separator: " ").prefix(2).compactMap(\.first)),
            vehicle: vehicleTitle, time: "Just now", text: "",
            category: category, comments: 0, likes: 0)
        post.vehicle = vehicleTitle
        post.vehicleID = selectedVehicle?.id
        post.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        post.category = category
        post.image = photoData == nil ? nil : "attached"
        post.imageData = photoData
        isSaving = true
        Task {
            do {
                if existingPost == nil {
                    try await store.addPost(post)
                } else {
                    try await store.updatePost(post)
                }
                onSaved()
                dismiss()
            } catch {
                self.error = error.localizedDescription
                isSaving = false
            }
        }
    }
}

struct PostDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var post: CommunityPost
    @State private var comment = ""
    @State private var replies: [CommunityComment] = []
    @State private var commentsListener: ObservationToken?
    @State private var error: String?
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var showDeleteConfirmation = false
    @State private var showEditor = false
    private var displayedPost: CommunityPost {
        store.posts.first(where: { $0.id == post.id }) ?? post
    }
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PostCard(post: displayedPost, isInDetail: true)
                        .padding(.horizontal, 16).padding(.top, 12)
                    SectionHeading(title: "Discussion").padding(.horizontal, 20)
                    ForEach(replies) { reply in
                        HStack(alignment: .top, spacing: 10) {
                            Text(String(reply.author.prefix(2)).uppercased()).font(.caption.bold())
                                .foregroundStyle(Color.appAccent).frame(width: 34, height: 34)
                                .background(Color.appMint, in: Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                Text(reply.author).font(.caption.bold())
                                Text(reply.text).font(.subheadline)
                                Button("Reply") { comment = "@\(reply.author) " }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.appAccent)
                            }
                            Spacer()
                            if store.canDeleteComment(reply) {
                                Button(role: .destructive) {
                                    deleteComment(reply)
                                } label: {
                                    Image(systemName: "trash").foregroundStyle(.red)
                                }
                                .accessibilityLabel("Delete comment")
                            }
                        }
                        .padding(13)
                        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 20)
                    }
                    if let error { Text(error).foregroundStyle(.red).padding(.horizontal, 20) }
                    Spacer(minLength: 18)
                }
            }
            HStack(spacing: 10) {
                TextField("Add a comment…", text: $comment).padding(12)
                    .background(Color.appCard, in: Capsule())
                Button {
                    sendComment()
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 30))
                        .foregroundStyle(Color.appAccent)
                }
                .accessibilityLabel("Send comment")
                .disabled(
                    isSaving || comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(12).background(.bar)
        }
        .navigationTitle("Discussion").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if store.canDeletePost(displayedPost) {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Edit post", systemImage: "pencil") { showEditor = true }
                        Button("Delete post", systemImage: "trash", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Post actions")
                    .disabled(isDeleting)
                }
            }
        }
        .confirmationDialog(
            "Delete this post?", isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete post", role: .destructive) {
                isDeleting = true
                Task {
                    do {
                        try await store.deletePost(displayedPost)
                        dismiss()
                    } catch {
                        self.error = error.localizedDescription
                        isDeleting = false
                    }
                }
            }
        } message: {
            Text("This removes the post for everyone.")
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack { CreatePostView(existingPost: displayedPost) }
        }
        .onAppear {
            guard store.isFirebaseConfigured else {
                replies = store.comments(for: post.id)
                return
            }
            replies = []
            commentsListener = store.observeComments(postID: post.id) { result in
                Task { @MainActor in
                    switch result {
                    case .success(let comments): replies = comments
                    case .failure(let failure): error = failure.localizedDescription
                    }
                }
            }
        }
        .onDisappear { commentsListener?.cancel() }
    }

    private func sendComment() {
        let message = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        let reply = CommunityComment(author: store.userName, text: message)
        isSaving = true
        Task {
            do {
                try await store.publishComment(reply, postID: post.id)
                if !store.isFirebaseConfigured {
                    replies = store.comments(for: post.id)
                }
                comment = ""
            } catch {
                self.error = error.localizedDescription
            }
            isSaving = false
        }
    }

    private func deleteComment(_ reply: CommunityComment) {
        Task {
            do {
                try await store.deleteComment(reply, postID: post.id)
                if !store.isFirebaseConfigured {
                    replies = store.comments(for: post.id)
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

@MainActor final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?
    @Published var status: CLAuthorizationStatus = .notDetermined
    private let manager = CLLocationManager()
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        status = manager.authorizationStatus
    }
    func request() {
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if status == .authorizedAlways || status == .authorizedWhenInUse {
            manager.requestLocation()
        }
    }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let authorization = manager.authorizationStatus
        Task { @MainActor [weak self] in
            self?.status = authorization
            if authorization == .authorizedAlways || authorization == .authorizedWhenInUse {
                self?.manager.requestLocation()
            }
        }
    }
    nonisolated func locationManager(
        _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
    ) {
        let latest = locations.first
        Task { @MainActor [weak self] in self?.location = latest }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

struct NearbyMapView: View {
    @StateObject private var location = LocationService()
    @AppStorage("smart-vehicle-nearby-category") private var category = "All"
    @State private var query = ""
    @State private var selected: NearbyPlace?
    @State private var places: [NearbyPlace] = []
    @State private var isLoading = false
    @State private var searchError: String?
    @State private var searchRevision = 0
    @State private var hasCenteredOnUser = false
    @State private var searchRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 6.9271, longitude: 79.8612),
        span: MKCoordinateSpan(latitudeDelta: 0.09, longitudeDelta: 0.09))
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 6.9271, longitude: 79.8612),
            span: MKCoordinateSpan(latitudeDelta: 0.09, longitudeDelta: 0.09)))

    var body: some View {
        VStack(spacing: 0) {
            Map(position: $position, selection: $selected) {
                if let current = location.location {
                    UserAnnotation()
                    Annotation("You", coordinate: current.coordinate) {
                        Image(systemName: "location.fill").foregroundStyle(.white).padding(8)
                            .background(Color.blue, in: Circle())
                    }
                }
                ForEach(places) { place in
                    Marker(
                        place.name, systemImage: place.symbol,
                        coordinate: CLLocationCoordinate2D(
                            latitude: place.latitude, longitude: place.longitude)
                    )
                    .tag(place)
                }
            }
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                searchRegion = context.region
                searchRevision += 1
            }
            .overlay(alignment: .top) {
                VStack(spacing: 9) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        TextField("Search fuel or vehicle service", text: $query)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                        if !query.isEmpty {
                            Button {
                                query = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Clear nearby search")
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 3)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            NearbyFilterPill(
                                title: "All", symbol: "square.grid.2x2.fill",
                                count: places.count, isSelected: category == "All"
                            ) { category = "All" }
                            NearbyFilterPill(
                                title: "Fuel", symbol: "fuelpump.fill",
                                count: places.filter { $0.category == "Fuel" }.count,
                                isSelected: category == "Fuel"
                            ) { category = "Fuel" }
                            NearbyFilterPill(
                                title: "Service", symbol: "wrench.and.screwdriver.fill",
                                count: places.filter { $0.category == "Service" }.count,
                                isSelected: category == "Service"
                            ) { category = "Service" }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    centerOnUser()
                } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.placeBlue, in: Circle())
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                }
                .accessibilityLabel("Center map on my location")
                .padding(14)
            }
            .frame(height: 430)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Nearby services").font(.headline)
                        Text("Fuel stations and vehicle care around you")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(places.count) places")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.placeBlue)
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(Color.placeBlue.opacity(0.11), in: Capsule())
                }
                .padding(.horizontal, 16).padding(.top, 17)
                if isLoading && places.isEmpty {
                    ProgressView("Searching this area…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let searchError {
                    ContentUnavailableView {
                        Label("Search unavailable", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(searchError)
                    } actions: {
                        Button("Try again") { searchRevision += 1 }
                    }
                } else if places.isEmpty {
                    ContentUnavailableView(
                        "No places found", systemImage: "mappin.slash",
                        description: Text("Move the map or try another search."))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 9) {
                            ForEach(places) { place in
                                Button {
                                    selected = place
                                    position = .region(
                                        MKCoordinateRegion(
                                            center: CLLocationCoordinate2D(
                                                latitude: place.latitude, longitude: place.longitude
                                            ),
                                            span: MKCoordinateSpan(
                                                latitudeDelta: 0.025, longitudeDelta: 0.025)))
                                } label: {
                                    LocationCard(place: place)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
        .background(Color.appCanvas).navigationTitle("Nearby Services")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected) { place in LocationDetailSheet(place: place) }
        .onChange(of: query) { _, _ in searchRevision += 1 }
        .onChange(of: category) { _, _ in searchRevision += 1 }
        .onReceive(location.$location) { current in
            guard let current else { return }
            if !hasCenteredOnUser {
                hasCenteredOnUser = true
                position = .region(
                    MKCoordinateRegion(
                        center: current.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.09, longitudeDelta: 0.09)))
            }
            searchRevision += 1
        }
        .onAppear { location.request() }
        .task(id: searchRevision) { await searchPlaces() }
    }

    private func centerOnUser() {
        location.request()
        guard let current = location.location else { return }
        hasCenteredOnUser = true
        position = .region(
            MKCoordinateRegion(
                center: current.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
            )
        )
    }

    @MainActor private func searchPlaces() async {
        do {
            try await Task.sleep(for: .milliseconds(300))
            try Task.checkCancellation()
            isLoading = true
            searchError = nil

            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let searchCategories = category == "All" ? ["Fuel", "Service"] : [category]
            let region = searchRegion
            let origin =
                location.location
                ?? CLLocation(
                    latitude: region.center.latitude, longitude: region.center.longitude)
            var found: [NearbyPlace] = []

            for searchCategory in searchCategories {
                let items = try await searchItems(
                    category: searchCategory, query: trimmedQuery, region: region)
                try Task.checkCancellation()
                for item in items {
                    guard let name = item.name else { continue }
                    let coordinate = item.placemark.coordinate
                    let distance = origin.distance(
                        from: CLLocation(
                            latitude: coordinate.latitude, longitude: coordinate.longitude))
                    let place = NearbyPlace(
                        id: "\(name)-\(coordinate.latitude)-\(coordinate.longitude)",
                        name: name,
                        category: searchCategory,
                        distance: distance < 1000
                            ? "\(Int(distance.rounded())) m"
                            : String(format: "%.1f km", distance / 1000),
                        distanceSource: location.location == nil ? "map center" : "you",
                        symbol: searchCategory == "Fuel"
                            ? "fuelpump.fill" : "wrench.and.screwdriver.fill",
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude,
                        address: item.placemark.title,
                        phoneNumber: item.phoneNumber,
                        websiteURL: item.url?.absoluteString)
                    if !found.contains(where: { $0.id == place.id }) {
                        found.append(place)
                    }
                }
            }
            try Task.checkCancellation()
            places = found.sorted {
                let first = origin.distance(
                    from: CLLocation(
                        latitude: $0.latitude, longitude: $0.longitude))
                let second = origin.distance(
                    from: CLLocation(
                        latitude: $1.latitude, longitude: $1.longitude))
                return first < second
            }
            isLoading = false
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            places = []
            isLoading = false
            searchError = "Could not load nearby places. Check your connection and try again."
        }
    }

    @MainActor private func searchItems(
        category: String, query: String, region: MKCoordinateRegion
    ) async throws -> [MKMapItem] {
        let search: MKLocalSearch
        if category == "Fuel" && query.isEmpty {
            let request = MKLocalPointsOfInterestRequest(coordinateRegion: region)
            request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.gasStation])
            search = MKLocalSearch(request: request)
        } else if category == "Service" && query.isEmpty {
            if #available(iOS 18.0, *) {
                let request = MKLocalPointsOfInterestRequest(coordinateRegion: region)
                request.pointOfInterestFilter = MKPointOfInterestFilter(
                    including: [.automotiveRepair])
                search = MKLocalSearch(request: request)
            } else {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = "car repair"
                request.region = region
                request.resultTypes = .pointOfInterest
                search = MKLocalSearch(request: request)
            }
        } else {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery =
                category == "Service" && !query.isEmpty ? "\(query) car repair" : query
            request.region = region
            request.resultTypes = .pointOfInterest
            if category == "Fuel" {
                request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.gasStation])
            } else if #available(iOS 18.0, *) {
                request.pointOfInterestFilter = MKPointOfInterestFilter(
                    including: [.automotiveRepair])
            }
            search = MKLocalSearch(request: request)
        }
        return try await search.start().mapItems
    }
}

private struct NearbyFilterPill: View {
    let title: String
    let symbol: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                Text(title)
                Text("\(count)")
                    .font(.appBadge)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(
                        isSelected ? Color.white.opacity(0.2) : Color.primary.opacity(0.08),
                        in: Capsule()
                    )
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(
                isSelected ? Color.placeBlue : Color.appCard.opacity(0.9),
                in: Capsule()
            )
            .overlay {
                Capsule().strokeBorder(
                    isSelected ? Color.clear : Color.primary.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct LocationCard: View {
    var place: NearbyPlace
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: place.symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(place.category == "Fuel" ? Color.orange : Color.placeBlue)
                .frame(width: 44, height: 44)
                .background(
                    (place.category == "Fuel" ? Color.orange : Color.placeBlue).opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 12)
                )
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(place.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                        .lineLimit(1)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption2).foregroundStyle(Color.placeBlue)
                }
                Text(place.address ?? place.category)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Text(place.category.uppercased())
                    .font(.appBadge).tracking(0.6)
                    .foregroundStyle(place.category == "Fuel" ? Color.orange : Color.placeBlue)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 6) {
                Text(place.distance)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(Color.appElevated, in: Capsule())
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold)).foregroundStyle(.tertiary)
            }
        }
        .padding(13)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.035), radius: 6, y: 2)
    }
}

struct LocationDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    var place: NearbyPlace

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                placeHero
                metadataCard
                quickActions
                mapPreview

                if let address = place.address, !address.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Location").font(.headline)
                        Label(address, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .background(Color.appCanvas.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    private var placeHero: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    Color.placeBlue.opacity(0.8),
                    Color(red: 0.06, green: 0.11, blue: 0.2),
                    Color.appCard,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: place.symbol)
                .font(.system(size: 92, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.28))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            LinearGradient(
                colors: [.clear, .black.opacity(0.72)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(place.name)
                        .font(.appScreenTitle)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.placeBlue)
                }
                Text(place.address ?? place.category)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(2)
            }
            .padding(16)

            VStack {
                HStack {
                    Label(place.category, systemImage: place.symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel("Close place details")
                }
                Spacer()
            }
            .padding(12)
        }
        .frame(height: 256)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
        .padding(.horizontal, 16)
    }

    private var metadataCard: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Apple Maps listing", systemImage: "map.fill")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(place.category)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.placeBlue)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(Color.placeBlue.opacity(0.12), in: Capsule())
            }
            Divider()
            HStack {
                Label("Nearby", systemImage: "circle.fill")
                    .foregroundStyle(.green)
                Spacer()
                Label("\(place.distance) from \(place.distanceSource)", systemImage: "location.fill")
                    .foregroundStyle(.secondary)
            }
            .font(.caption.weight(.medium))
        }
        .padding(16)
        .background(Color.appElevated, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .padding(.horizontal, 16)
    }

    private var quickActions: some View {
        HStack(spacing: 10) {
            Button(action: openDirections) {
                Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LocationPrimaryActionStyle())

            if let phoneNumber = place.phoneNumber,
                let url = URL(string: "tel:\(phoneNumber.filter { !$0.isWhitespace })")
            {
                Link(destination: url) {
                    Label("Call", systemImage: "phone.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LocationSecondaryActionStyle())
            }

            if let websiteURL = place.websiteURL, let url = URL(string: websiteURL) {
                Link(destination: url) {
                    Image(systemName: "safari.fill").frame(width: 20)
                }
                .buttonStyle(LocationSecondaryActionStyle())
                .accessibilityLabel("Open website")
            }
        }
        .padding(.horizontal, 16)
    }

    private var mapPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Map preview").font(.headline)
                Spacer()
                Button("Open Maps", action: openDirections)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.placeBlue)
            }
            Map(
                initialPosition: .region(
                    MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
                    )
                ),
                interactionModes: []
            ) {
                Marker(place.name, systemImage: place.symbol, coordinate: coordinate)
            }
            .frame(height: 190)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .allowsHitTesting(false)
        }
        .padding(16)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .padding(.horizontal, 16)
    }

    private func openDirections() {
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = place.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

private struct LocationPrimaryActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(height: 48)
            .background(
                Color.placeBlue.opacity(configuration.isPressed ? 0.76 : 1),
                in: RoundedRectangle(cornerRadius: 13)
            )
    }
}

private struct LocationSecondaryActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.placeBlue)
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(
                Color.appCard.opacity(configuration.isPressed ? 0.7 : 1),
                in: RoundedRectangle(cornerRadius: 13)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
    }
}

private extension Color {
    static let placeBlue = Color(red: 26 / 255, green: 107 / 255, blue: 1)
}
