import Foundation

struct CommunityVehicleOption: Identifiable, Hashable {
    let key: String
    let title: String

    var id: String { key }
}

enum CommunityAuthorFilter: String, CaseIterable {
    case everyone = "Everyone"
    case otherDrivers = "Other drivers"
    case myPosts = "My posts"
}

struct CommunityFeedViewModel {
    static func vehicleKey(for title: String) -> String {
        var words = title.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        if let last = words.last, last.count == 4,
            let year = Int(last), (1900...2100).contains(year)
        {
            words.removeLast()
        }
        return words.joined(separator: " ").lowercased()
    }

    static func vehicleOptions(
        garage: [Vehicle], posts: [CommunityPost]
    ) -> [CommunityVehicleOption] {
        var titles: [String: String] = [:]
        for post in posts {
            var words = post.vehicle.split(separator: " ").map(String.init)
            if let last = words.last, last.count == 4,
                let year = Int(last), (1900...2100).contains(year)
            {
                words.removeLast()
            }
            let title = words.joined(separator: " ")
            let key = vehicleKey(for: title)
            if !key.isEmpty && key != "my vehicle" && key != "general" {
                titles[key] = title
            }
        }
        for vehicle in garage {
            titles[vehicleKey(for: vehicle.title)] = vehicle.title
        }
        return titles.map { CommunityVehicleOption(key: $0.key, title: $0.value) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    static func visiblePosts(
        _ posts: [CommunityPost],
        category: String,
        vehicleKey: String,
        authorFilter: CommunityAuthorFilter,
        currentUserID: String?
    ) -> [CommunityPost] {
        posts.filter { post in
            let matchesCategory: Bool
            switch category {
            case "Questions": matchesCategory = post.category == "Question" || post.category == "Problem"
            case "Solutions": matchesCategory = post.category == "Solved" || post.category == "Tip"
            default: matchesCategory = true
            }
            let matchesAuthor: Bool
            switch authorFilter {
            case .everyone: matchesAuthor = true
            case .otherDrivers:
                matchesAuthor = currentUserID != nil && post.authorID != currentUserID
            case .myPosts:
                matchesAuthor = currentUserID != nil && post.authorID == currentUserID
            }
            return matchesCategory && matchesAuthor
                && (vehicleKey.isEmpty || self.vehicleKey(for: post.vehicle) == vehicleKey)
        }
    }
}
