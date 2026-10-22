import CryptoKit
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging
import Foundation

enum FirebaseBackend {
    static var isConfigured: Bool { FirebaseApp.app() != nil }

    static func configureIfAvailable() {
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            return
        }
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    static func observeGarage(
        userID: String,
        onChange: @escaping (Result<Data?, Error>) -> Void
    ) -> ListenerRegistration {
        garageDocument(userID: userID)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                } else {
                    onChange(.success(snapshot?.data()?["payload"] as? Data))
                }
            }
    }

    static func saveGarage(_ data: Data, userID: String) async throws {
        try await garageDocument(userID: userID)
            .setData([
                "payload": data,
                "updatedAt": FieldValue.serverTimestamp(),
            ])
    }

    static func loadPhoto(userID: String, photoID: String) async throws -> PhotoLoadResult {
        let snapshot = try await photoDocument(userID: userID, photoID: photoID).getDocument()
        return photoResult(from: snapshot.data())
    }

    static func observePhoto(
        userID: String, photoID: String,
        onChange: @escaping (Result<PhotoLoadResult, Error>) -> Void
    ) -> ListenerRegistration {
        photoDocument(userID: userID, photoID: photoID)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                } else {
                    onChange(.success(photoResult(from: snapshot?.data())))
                }
            }
    }

    static func savePhoto(_ data: Data, userID: String, photoID: String) async throws {
        try await photoDocument(userID: userID, photoID: photoID)
            .setData(["payload": data, "updatedAt": FieldValue.serverTimestamp()])
    }

    static func deletePhoto(userID: String, photoID: String) async throws {
        try await photoDocument(userID: userID, photoID: photoID)
            .setData(["removed": true, "updatedAt": FieldValue.serverTimestamp()])
    }

    static func observeMarketplace(
        onChange: @escaping (Result<[MarketplaceItem], Error>) -> Void
    ) -> ListenerRegistration {
        Firestore.firestore().collection("marketplace")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }
                let items =
                    snapshot?.documents
                    .compactMap { document -> MarketplaceItem? in
                        guard let data = document.data()["payload"] as? Data else { return nil }
                        guard var item = try? JSONDecoder().decode(MarketplaceItem.self, from: data)
                        else { return nil }
                        item.sellerID = document.data()["sellerID"] as? String
                        return item
                    } ?? []
                onChange(.success(items))
            }
    }

    static func publishListing(_ item: MarketplaceItem, userID: String) async throws {
        let data = try JSONEncoder().encode(item)
        try await Firestore.firestore().collection("marketplace")
            .document(item.id.uuidString)
            .setData([
                "payload": data,
                "sellerID": userID,
                "category": item.category,
                "createdAt": FieldValue.serverTimestamp(),
            ])
    }

    static func deleteListing(id: UUID, userID: String) async throws {
        try await Firestore.firestore().collection("marketplace")
            .document(id.uuidString).delete()
    }

    static func updateListing(_ item: MarketplaceItem, userID: String) async throws {
        let data = try JSONEncoder().encode(item)
        try await Firestore.firestore().collection("marketplace")
            .document(item.id.uuidString)
            .updateData(["payload": data, "category": item.category])
    }

    static func observePosts(
        userID: String?,
        onChange: @escaping (Result<[CommunityPost], Error>) -> Void
    ) -> ListenerRegistration {
        Firestore.firestore().collection("communityPosts")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }
                let posts =
                    snapshot?.documents
                    .compactMap { document -> CommunityPost? in
                        guard let data = document.data()["payload"] as? Data,
                            var post = try? JSONDecoder().decode(CommunityPost.self, from: data)
                        else { return nil }
                        let likedBy = document.data()["likedBy"] as? [String] ?? []
                        post.likes = likedBy.count
                        post.isLiked = userID.map { likedBy.contains($0) } ?? false
                        post.authorID = document.data()["authorID"] as? String
                        return post
                    } ?? []
                onChange(.success(posts))
            }
    }

    static func publishPost(_ post: CommunityPost, userID: String) async throws {
        let data = try JSONEncoder().encode(post)
        try await Firestore.firestore().collection("communityPosts")
            .document(post.id.uuidString)
            .setData([
                "payload": data,
                "authorID": userID,
                "likedBy": [String](),
                "createdAt": FieldValue.serverTimestamp(),
            ])
    }

    static func deletePost(id: UUID, userID: String) async throws {
        try await Firestore.firestore().collection("communityPosts")
            .document(id.uuidString).delete()
    }

    static func updatePost(_ post: CommunityPost, userID: String) async throws {
        let data = try JSONEncoder().encode(post)
        try await Firestore.firestore().collection("communityPosts")
            .document(post.id.uuidString)
            .updateData(["payload": data])
    }

    static func setPostLiked(_ liked: Bool, postID: UUID, userID: String) async throws {
        let change: FieldValue =
            liked
            ? .arrayUnion([userID]) : .arrayRemove([userID])
        try await Firestore.firestore().collection("communityPosts")
            .document(postID.uuidString).updateData(["likedBy": change])
    }

    static func observeComments(
        postID: UUID,
        onChange: @escaping (Result<[CommunityComment], Error>) -> Void
    ) -> ListenerRegistration {
        Firestore.firestore().collection("communityPosts")
            .document(postID.uuidString).collection("comments")
            .order(by: "createdAt")
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }
                let comments =
                    snapshot?.documents
                    .compactMap { document -> CommunityComment? in
                        guard let data = document.data()["payload"] as? Data else { return nil }
                        return try? JSONDecoder().decode(CommunityComment.self, from: data)
                    } ?? []
                onChange(.success(comments))
            }
    }

    static func publishComment(
        _ comment: CommunityComment, postID: UUID, userID: String
    ) async throws {
        let data = try JSONEncoder().encode(comment)
        try await Firestore.firestore().collection("communityPosts")
            .document(postID.uuidString).collection("comments")
            .document(comment.id.uuidString)
            .setData([
                "payload": data,
                "authorID": userID,
                "createdAt": FieldValue.serverTimestamp(),
            ])
    }

    static func saveMessagingRegistration(_ installationID: String, userID: String) async throws {
        try await Firestore.firestore().collection("users").document(userID)
            .collection("devices").document(deviceID(for: installationID))
            .setData([
                "installationID": installationID,
                "updatedAt": FieldValue.serverTimestamp(),
            ])
    }

    static func removeMessagingRegistration(_ installationID: String, userID: String) async throws {
        try await Firestore.firestore().collection("users").document(userID)
            .collection("devices").document(deviceID(for: installationID)).delete()
    }

    private static func garageDocument(userID: String) -> DocumentReference {
        Firestore.firestore().collection("users").document(userID)
            .collection("private").document("garage")
    }

    private static func photoDocument(userID: String, photoID: String) -> DocumentReference {
        Firestore.firestore().collection("users").document(userID)
            .collection("private").document(photoID)
    }

    private static func photoResult(from data: [String: Any]?) -> PhotoLoadResult {
        guard let data else { return .missing }
        if data["removed"] as? Bool == true { return .removed }
        if let payload = data["payload"] as? Data { return .image(payload) }
        return .missing
    }

    private static func deviceID(for installationID: String) -> String {
        SHA256.hash(data: Data(installationID.utf8))
            .map { String(format: "%02x", $0) }.joined()
    }
}
