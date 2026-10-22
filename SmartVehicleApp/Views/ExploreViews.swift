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
    @State private var category = "Vehicles"
    @State private var showFilters = false
    @State private var filterMake = "All makes"
    @State private var maxPrice = 30000000.0
    @State private var hasPriceLimit = false
    @State private var showNewListing = false
    @State private var showOnlyMine = false
    init(showMyListings: Bool = false) {
        _showOnlyMine = State(initialValue: showMyListings)
    }
    private let categories = ["Vehicles", "Spare parts"]
    private let demoItems = [
        MarketplaceItem(
            title: "Toyota Aqua G", subtitle: "2021 · Hybrid · 38,000 km", price: "LKR 8,950,000",
            category: "Vehicles", symbol: "car.side.fill", tint: "blue", distance: "Colombo"),
        MarketplaceItem(
            title: "Honda Vezel RS", subtitle: "2020 · Hybrid · 52,000 km", price: "LKR 14,250,000",
            category: "Vehicles", symbol: "car.side.fill", tint: "purple", distance: "Nugegoda"),
        MarketplaceItem(
            title: "Toyota Corolla Axio", subtitle: "2019 · Petrol · 61,000 km",
            price: "LKR 7,800,000", category: "Vehicles", symbol: "car.side.fill", tint: "teal",
            distance: "Kandy"),
        MarketplaceItem(
            title: "Premium oil filter · 04152", subtitle: "Toyota Corolla · Genuine fit",
            price: "LKR 4,250", category: "Spare parts", symbol: "gearshape.2.fill", tint: "orange",
            distance: "Colombo 05"),
        MarketplaceItem(
            title: "Michelin Energy XM2+", subtitle: "185/65 R15 · Set of 4", price: "LKR 112,000",
            category: "Spare parts", symbol: "circle.dashed", tint: "pink", distance: "Rajagiriya"),
    ]
    private var items: [MarketplaceItem] {
        store.isFirebaseConfigured ? store.marketplaceItems : demoItems
    }
    private var visible: [MarketplaceItem] {
        items.filter {
            $0.category == category
                && (showOnlyMine
                    ? $0.sellerID == store.currentUserID
                    : $0.sellerID != store.currentUserID)
                && (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)
                    || $0.subtitle.localizedCaseInsensitiveContains(query))
                && (filterMake == "All makes"
                    || $0.title.localizedCaseInsensitiveContains(filterMake))
                && (!hasPriceLimit || Double($0.priceAmount) <= maxPrice)
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                HStack {
                    ScreenHeading(title: "Marketplace", subtitle: "Find your next great fit")
                    if store.isFirebaseConfigured {
                        IconButton(symbol: "plus", accessibilityLabel: "Create marketplace listing") {
                            showNewListing = true
                        }
                    }
                    IconButton(symbol: "slider.horizontal.3", accessibilityLabel: "Marketplace filters") {
                        showFilters = true
                    }
                        .padding(.trailing, 20)
                }
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search vehicles or parts", text: $query).autocorrectionDisabled()
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                        }
                        .accessibilityLabel("Clear marketplace search")
                    }
                }
                .padding(13).background(Color.appCard, in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)
                Picker("Category", selection: $category) {
                    ForEach(categories, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented).padding(.horizontal, 20)
                if store.isFirebaseConfigured {
                    Picker("Listings", selection: $showOnlyMine) {
                        Text("Browse").tag(false)
                        Text("My listings").tag(true)
                    }
                    .pickerStyle(.segmented).padding(.horizontal, 20)
                }
                if !store.isFirebaseConfigured {
                    Label("Demo listings are only shown on this device.", systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 20)
                }
                HStack {
                    SectionHeading(
                        title: showOnlyMine ? "My listings"
                            : (category == "Vehicles" ? "Featured vehicles" : "Popular parts"))
                    Spacer()
                    Text("\(visible.count) results").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                if visible.isEmpty {
                    EmptyStateView(
                        symbol: "magnifyingglass",
                        title: showOnlyMine ? "No listings here" : (items.isEmpty ? "No listings yet" : "No results found"),
                        message: showOnlyMine ? "Your published listings appear here. Try the other category or create a listing."
                            : items.isEmpty
                            ? "Listings from other drivers will appear here when they publish."
                            : "Try a different search or clear your filters.")
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(visible) { item in
                            NavigationLink {
                                ListingDetailView(item: item)
                            } label: {
                                ListingCard(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 8)
        }
        .background(Color.appCanvas.ignoresSafeArea()).navigationTitle("Marketplace")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFilters) {
            NavigationStack {
                Form {
                    Section("Vehicle make") {
                        Picker("Make", selection: $filterMake) {
                            ForEach(["All makes", "Toyota", "Honda", "Suzuki"], id: \.self) {
                                Text($0)
                            }
                        }
                    }
                    Section("Maximum price") {
                        Toggle("Limit price", isOn: $hasPriceLimit)
                        if hasPriceLimit {
                            Slider(value: $maxPrice, in: 500000...30_000_000, step: 500000)
                            Text("Up to LKR \(Int(maxPrice).formatted())").font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Section {
                        Button("Reset filters") {
                            filterMake = "All makes"
                            maxPrice = 30_000_000
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
                    showOnlyMine = true
                    category = item.category
                    query = ""
                    filterMake = "All makes"
                    hasPriceLimit = false
                })
            }
        }
    }
}

struct ListingCard: View {
    var item: MarketplaceItem
    var body: some View {
        SurfaceCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    Rectangle().fill(Color.forName(item.tint).opacity(0.12)).frame(height: 145)
                        .overlay {
                            Image(systemName: item.symbol)
                                .font(.system(size: 67, weight: .ultraLight))
                                .foregroundStyle(Color.forName(item.tint))
                        }
                    Image(systemName: "heart").font(.headline).foregroundStyle(.primary).padding(11)
                        .background(.regularMaterial, in: Circle()).padding(12)
                }
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22))
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(item.title).font(.headline)
                        Spacer()
                        Label(item.distance, systemImage: "location.fill").font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(item.subtitle).font(.caption).foregroundStyle(.secondary)
                    Text(item.price).font(.title3.bold()).foregroundStyle(Color.appAccent)
                        .padding(.top, 1)
                }
                .padding(15)
            }
            .padding(0)
        }
    }
}

struct ListingDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var item: MarketplaceItem
    @State private var isSaved = false
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
                    Image(systemName: displayedItem.symbol).font(.system(size: 100, weight: .ultraLight))
                        .foregroundStyle(Color.forName(displayedItem.tint))
                    VStack {
                        HStack {
                            Spacer()
                            if !store.canDeleteListing(displayedItem) {
                                Button {
                                    isSaved.toggle()
                                } label: {
                                    Image(systemName: isSaved ? "heart.fill" : "heart").font(.headline)
                                        .foregroundStyle(isSaved ? .red : .primary).padding(12)
                                        .background(.regularMaterial, in: Circle())
                                }
                                .accessibilityLabel(
                                    isSaved ? "Remove listing from saved items" : "Save listing")
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
    @State private var selectedFilter = "All posts"
    @State private var selectedVehicleKey = ""
    @State private var showMine = false

    init(showMyPosts: Bool = false) {
        _showMine = State(initialValue: showMyPosts)
    }

    private var vehicleOptions: [CommunityVehicleOption] {
        CommunityFeedViewModel.vehicleOptions(garage: store.vehicles, posts: store.posts)
    }

    private var visiblePosts: [CommunityPost] {
        CommunityFeedViewModel.visiblePosts(
            store.posts, category: selectedFilter, vehicleKey: selectedVehicleKey,
            authorFilter: showMine ? .myPosts
                : (store.isFirebaseConfigured ? .otherDrivers : .everyone),
            currentUserID: store.currentUserID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    ScreenHeading(title: "Community", subtitle: "Drivers helping drivers")
                    Button {
                        showComposer = true
                    } label: {
                        Image(systemName: "square.and.pencil").font(.headline)
                            .foregroundStyle(.white).frame(width: 42, height: 42)
                            .background(Color.appAccent, in: Circle())
                    }
                    .accessibilityLabel("Create community post")
                    .padding(.trailing, 20)
                }
                Picker("Feed", selection: $selectedFilter) {
                    ForEach(["All posts", "Questions", "Solutions"], id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented).padding(.horizontal, 20)
                HStack {
                    Image(systemName: "car.side.fill").foregroundStyle(Color.appAccent)
                    Picker("Vehicle", selection: $selectedVehicleKey) {
                        Text("All vehicles").tag("")
                        ForEach(vehicleOptions) { vehicle in
                            Text(vehicle.title).tag(vehicle.key)
                        }
                    }
                    .pickerStyle(.menu)
                    Spacer()
                    Text("\(visiblePosts.count) posts")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                Picker("Posts", selection: $showMine) {
                    Text("Browse").tag(false)
                    Text("My posts").tag(true)
                }
                .pickerStyle(.segmented).padding(.horizontal, 20)
                if !store.isFirebaseConfigured {
                    Label("Demo posts are only shown on this device.", systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 20)
                }
                if visiblePosts.isEmpty {
                    EmptyStateView(
                        symbol: "bubble.left.and.bubble.right",
                        title: showMine ? "No posts here" : (store.posts.isEmpty ? "Be the first to share" : "No matching posts"),
                        message: showMine ? "Your posts appear here after you publish them."
                            : store.posts.isEmpty
                            ? "Ask a question or share an experience with other vehicle owners."
                            : "Try another vehicle or feed filter to see more discussions.",
                        action: "Create a post"
                    ) { showComposer = true }
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(visiblePosts) { post in PostCard(post: post) }
                    }
                    .padding(.horizontal, 20)
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
                    selectedVehicleKey = ""
                })
            }
        }
    }
}

struct PostCard: View {
    @EnvironmentObject private var store: AppStore
    @State private var showDetail = false
    var post: CommunityPost
    var isInDetail = false
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 10) {
                Text(post.initials).font(.caption.bold()).foregroundStyle(Color.appAccent)
                    .frame(width: 39, height: 39).background(Color.appMint, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(post.author).font(.subheadline.bold())
                    Text("\(post.vehicle) · \(post.time)").font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusBadge(text: post.category)
            }
            Text(post.text).font(.subheadline).lineSpacing(3).lineLimit(5)
            if let image = post.image, !image.isEmpty {
                RoundedRectangle(cornerRadius: 15).fill(Color.appMint).frame(height: 145)
                    .overlay {
                        Image(systemName: "car.side.fill").font(.system(size: 50, weight: .light))
                            .foregroundStyle(Color.appAccent)
                    }
            }
            HStack {
                if !store.canDeletePost(post) && !isInDetail {
                    Button {
                        store.toggleLike(post)
                    } label: {
                        Label("\(post.likes)", systemImage: post.isLiked ? "heart.fill" : "heart")
                            .foregroundStyle(post.isLiked ? .red : .secondary)
                    }
                } else {
                    Label("\(post.likes)", systemImage: "heart")
                        .foregroundStyle(.secondary)
                }
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
                        Text("View discussion").foregroundStyle(Color.appAccent).fontWeight(.semibold)
                    }
                }
            }
            .font(.caption)
        }
        .padding(15).background(Color.appCard, in: RoundedRectangle(cornerRadius: 21))
        .onTapGesture { if !isInDetail { showDetail = true } }
        .sheet(isPresented: $showDetail) { NavigationStack { PostDetailView(post: post) } }
    }
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
    @State private var hasPhoto = false
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
                        hasPhoto ? "Photo attached" : "Add a photo",
                        systemImage: hasPhoto ? "checkmark.circle.fill" : "photo")
                }
                .onChange(of: selectedPhoto) { _, value in Task { hasPhoto = value != nil } }
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
                postingVehicleID = store.vehicles.first { $0.title == existingPost.vehicle }?.id
                hasPhoto = existingPost.image != nil
            } else {
                postingVehicleID = store.selectedVehicle?.id
            }
        }
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
    }
    private func publish() {
        let vehicleTitle = store.vehicles.first { $0.id == postingVehicleID }?.title ?? "General"
        var post = existingPost ?? CommunityPost(
            author: store.userName,
            initials: String(store.userName.split(separator: " ").prefix(2).compactMap(\.first)),
            vehicle: vehicleTitle, time: "Just now", text: "",
            category: category, comments: 0, likes: 0)
        post.vehicle = vehicleTitle
        post.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        post.category = category
        post.image = hasPhoto ? "attached" : nil
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
    @State private var replies: [CommunityComment] = [
        CommunityComment(
            author: "Dasun M.", text: "Check your tyre balance first — it helped on mine."),
        CommunityComment(author: "Nimal P.", text: "Thanks! I'll get it checked this weekend."),
    ]
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
            guard store.isFirebaseConfigured else { return }
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
        if !store.isFirebaseConfigured {
            replies.append(reply)
            comment = ""
            return
        }
        isSaving = true
        Task {
            do {
                try await store.publishComment(reply, postID: post.id)
                comment = ""
            } catch {
                self.error = error.localizedDescription
            }
            isSaving = false
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
    @State private var category = "All"
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
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                searchRegion = context.region
                searchRevision += 1
            }
            .overlay(alignment: .top) {
                Picker("Nearby", selection: $category) {
                    ForEach(["All", "Fuel", "Service"], id: \.self) { Text($0) }
                }
                .pickerStyle(.segmented).padding(11)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 17)).padding(12)
            }
            .frame(height: 330)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeading(title: "Nearby locations")
                    Spacer()
                    Text("\(places.count) places").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20).padding(.top, 17)
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
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
        .background(Color.appCanvas).navigationTitle("Nearby")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    location.request()
                    if let current = location.location {
                        hasCenteredOnUser = true
                        position = .region(
                            MKCoordinateRegion(
                                center: current.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)))
                    }
                } label: {
                    Image(systemName: "location.fill")
                }
                .accessibilityLabel("Center map on my location")
            }
        }
        .sheet(item: $selected) { place in LocationDetailSheet(place: place) }
        .searchable(text: $query, prompt: "Fuel or vehicle service")
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
                        longitude: coordinate.longitude)
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

struct LocationCard: View {
    var place: NearbyPlace
    var body: some View {
        SurfaceCard(padding: 13) {
            HStack(spacing: 12) {
                Image(systemName: place.symbol).foregroundStyle(Color.appAccent)
                    .frame(width: 42, height: 42)
                    .background(Color.appMint, in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name).font(.subheadline.bold()).foregroundStyle(.primary)
                    Text(place.category).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(place.distance).font(.caption.weight(.semibold))
            }
        }
    }
}

struct LocationDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    var place: NearbyPlace
    var body: some View {
        VStack(spacing: 17) {
            Capsule().fill(.tertiary).frame(width: 38, height: 5).padding(.top, 9)
            Image(systemName: place.symbol).font(.system(size: 27)).foregroundStyle(Color.appAccent)
                .frame(width: 66, height: 66)
                .background(Color.appMint, in: RoundedRectangle(cornerRadius: 21))
            Text(place.name).font(.title3.bold())
            Text("\(place.category) · \(place.distance) from \(place.distanceSource)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                let coordinate = CLLocationCoordinate2D(
                    latitude: place.latitude, longitude: place.longitude)
                let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                mapItem.name = place.name
                mapItem.openInMaps(launchOptions: [
                    MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                ])
            } label: {
                Label("Get directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            Button("Done") { dismiss() }.font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.appAccent)
        }
        .padding(22).presentationDetents([.medium])
    }
}
