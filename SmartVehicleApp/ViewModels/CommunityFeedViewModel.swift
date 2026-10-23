import Foundation

enum CommunityAuthorFilter: String, CaseIterable {
    case everyone = "Everyone"
    case otherDrivers = "Other drivers"
    case myPosts = "My posts"
}

struct CommunityFeedViewModel {
    static func vehicleKey(for title: String) -> String {
        title.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: " ").lowercased()
    }

    static func visiblePosts(
        _ posts: [CommunityPost],
        category: String,
        vehicleQuery: String,
        authorFilter: CommunityAuthorFilter,
        currentUserID: String?
    ) -> [CommunityPost] {
        let normalizedQuery = vehicleKey(for: vehicleQuery)
        let queryTerms = normalizedQuery.split(separator: " ")

        return posts.filter { post in
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
            let normalizedVehicle = vehicleKey(for: post.vehicle)
            let matchesVehicle = queryTerms.isEmpty
                || queryTerms.allSatisfy { normalizedVehicle.contains($0) }
            return matchesCategory && matchesAuthor && matchesVehicle
        }
    }
}
