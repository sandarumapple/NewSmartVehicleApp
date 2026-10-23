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
                        item.category = document.data()["category"] as? String ?? item.category
                        item.title = document.data()["title"] as? String ?? item.title
                        item.subtitle = document.data()["subtitle"] as? String ?? item.subtitle
                        item.contact = document.data()["contact"] as? String ?? item.contact
                        item.distance = document.data()["location"] as? String ?? item.distance
                        if let amount = document.data()["priceAmount"] as? NSNumber {
                            item.price = "LKR \(amount.intValue.formatted())"
                        }
                        item.symbol = item.category == "Vehicles" ? "car.side.fill" : "gearshape.2.fill"
                        item.tint = item.category == "Vehicles" ? "blue" : "orange"
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
                "title": item.title,
                "subtitle": item.subtitle,
                "priceAmount": item.priceAmount,
                "contact": item.contact ?? "",
                "location": item.distance,
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
            .updateData([
                "payload": data,
                "category": item.category,
                "title": item.title,
                "subtitle": item.subtitle,
                "priceAmount": item.priceAmount,
                "contact": item.contact ?? "",
                "location": item.distance,
            ])
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
                        post.author = document.data()["authorName"] as? String ?? post.author
                        post.initials = String(
                            post.author.split(separator: " ").prefix(2).compactMap(\.first))
                        post.text = document.data()["text"] as? String ?? post.text
                        post.category = document.data()["category"] as? String ?? post.category
                        post.vehicle = document.data()["vehicle"] as? String ?? post.vehicle
                        if let rawVehicleID = document.data()["vehicleID"] as? String {
                            post.vehicleID = UUID(uuidString: rawVehicleID)
                        }
                        post.createdAt = (document.data()["createdAt"] as? Timestamp)?.dateValue()
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
                "authorName": post.author,
                "text": post.text,
                "category": post.category,
                "vehicle": post.vehicle,
                "vehicleID": post.vehicleID?.uuidString ?? "",
                "likedBy": [String](),
                "createdAt": FieldValue.serverTimestamp(),
            ])
    }

    static func deletePost(id: UUID, userID: String) async throws {
        let post = Firestore.firestore().collection("communityPosts").document(id.uuidString)
        while true {
            let snapshot = try await post.collection("comments").limit(to: 400).getDocuments()
            guard !snapshot.documents.isEmpty else { break }
            let batch = Firestore.firestore().batch()
            snapshot.documents.forEach { batch.deleteDocument($0.reference) }
            try await batch.commit()
        }
        try await post.delete()
    }

    static func updatePost(_ post: CommunityPost, userID: String) async throws {
        let data = try JSONEncoder().encode(post)
        try await Firestore.firestore().collection("communityPosts")
            .document(post.id.uuidString)
            .updateData([
                "payload": data,
                "text": post.text,
                "category": post.category,
                "vehicle": post.vehicle,
                "vehicleID": post.vehicleID?.uuidString ?? "",
            ])
    }

    static func setPostLiked(
        _ liked: Bool, postID: UUID, userID: String, actorName: String
    ) async throws {
        let post = Firestore.firestore().collection("communityPosts").document(postID.uuidString)
        let snapshot = try await post.getDocument()
        guard let postData = snapshot.data() else { throw BackendError.postUnavailable }
        let change: FieldValue =
            liked
            ? .arrayUnion([userID]) : .arrayRemove([userID])
        let batch = Firestore.firestore().batch()
        batch.updateData(["likedBy": change], forDocument: post)
        if liked {
            addCommunityNotification(
                to: batch, type: "like", postID: postID, postData: postData,
                actorID: userID, actorName: actorName, sourceID: userID)
        }
        try await batch.commit()
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
                        guard var comment = try? JSONDecoder().decode(
                            CommunityComment.self, from: data)
                        else { return nil }
                        comment.authorID = document.data()["authorID"] as? String
                        comment.author = document.data()["authorName"] as? String ?? comment.author
                        comment.text = document.data()["text"] as? String ?? comment.text
                        comment.createdAt = (document.data()["createdAt"] as? Timestamp)?.dateValue()
                        return comment
                    } ?? []
                onChange(.success(comments))
            }
    }

    static func publishComment(
        _ comment: CommunityComment, postID: UUID, userID: String
    ) async throws {
        let data = try JSONEncoder().encode(comment)
        let post = Firestore.firestore().collection("communityPosts").document(postID.uuidString)
        let snapshot = try await post.getDocument()
        guard let postData = snapshot.data() else { throw BackendError.postUnavailable }
        let batch = Firestore.firestore().batch()
        batch.setData([
            "payload": data,
            "authorID": userID,
            "authorName": comment.author,
            "text": comment.text,
            "createdAt": FieldValue.serverTimestamp(),
        ], forDocument: post.collection("comments").document(comment.id.uuidString))
        addCommunityNotification(
            to: batch, type: "comment", postID: postID, postData: postData,
            actorID: userID, actorName: comment.author, sourceID: comment.id.uuidString)
        try await batch.commit()
    }

    private static func addCommunityNotification(
        to batch: WriteBatch, type: String, postID: UUID, postData: [String: Any],
        actorID: String, actorName: String, sourceID: String
    ) {
        guard let recipientID = postData["authorID"] as? String,
            !recipientID.isEmpty, recipientID != actorID else { return }
        // Each new reaction gets its own event. Reusing a like ID would attempt an
        // update to another user's inbox, which the security rules rightly deny.
        let notification = Firestore.firestore().collection("users").document(recipientID)
            .collection("notifications").document()
        let name = actorName.trimmingCharacters(in: .whitespacesAndNewlines)
        batch.setData([
            "type": type,
            "actorID": actorID,
            "actorName": String((name.isEmpty ? "A driver" : name).prefix(80)),
            "recipientID": recipientID,
            "postID": postID.uuidString,
            "sourceID": sourceID,
            "postPreview": String((postData["text"] as? String ?? "").prefix(160)),
            "isRead": false,
            "createdAt": FieldValue.serverTimestamp(),
        ], forDocument: notification)
    }

    static func deleteComment(id: UUID, postID: UUID, userID: String) async throws {
        try await Firestore.firestore().collection("communityPosts")
            .document(postID.uuidString).collection("comments")
            .document(id.uuidString).delete()
    }

    static func observeCommunityNotifications(
        userID: String,
        onChange: @escaping (Result<[CommunityNotification], Error>) -> Void
    ) -> ListenerRegistration {
        Firestore.firestore().collection("users").document(userID)
            .collection("notifications")
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }
                let notifications: [CommunityNotification] =
                    snapshot?.documents.compactMap { document -> CommunityNotification? in
                    let data = document.data()
                    guard let type = data["type"] as? String,
                        let actorName = data["actorName"] as? String,
                        let rawPostID = data["postID"] as? String,
                        let postID = UUID(uuidString: rawPostID)
                    else { return nil }
                    return CommunityNotification(
                        id: document.documentID,
                        type: type,
                        actorName: actorName,
                        postID: postID,
                        postPreview: data["postPreview"] as? String ?? "",
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        isRead: data["isRead"] as? Bool ?? false)
                    } ?? []
                onChange(.success(notifications))
            }
    }

    static func markCommunityNotificationRead(id: String, userID: String) async throws {
        try await Firestore.firestore().collection("users").document(userID)
            .collection("notifications").document(id)
            .updateData(["isRead": true])
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
