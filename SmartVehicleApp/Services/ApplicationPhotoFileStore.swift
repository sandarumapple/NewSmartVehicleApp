import CryptoKit
import Foundation

/// Keeps user photos and scanned pages separate from the observable application state.
struct ApplicationPhotoFileStore: PhotoFileStoring {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) { self.fileManager = fileManager }

    func photoData(ownerID: String?, photoID: String) -> Data? {
        try? Data(contentsOf: photoURL(ownerID: ownerID, photoID: photoID))
    }

    func savePhoto(_ data: Data, ownerID: String?, photoID: String) throws {
        try fileManager.createDirectory(
            at: directory(ownerID: ownerID), withIntermediateDirectories: true)
        try data.write(to: photoURL(ownerID: ownerID, photoID: photoID), options: .atomic)
    }

    func deletePhoto(ownerID: String?, photoID: String) throws {
        let url = photoURL(ownerID: ownerID, photoID: photoID)
        if fileManager.fileExists(atPath: url.path) { try fileManager.removeItem(at: url) }
    }

    func saveScanPages(_ pages: [Data], ownerID: String?, documentID: UUID) throws {
        guard !pages.isEmpty else { return }
        let folder = scanDirectory(ownerID: ownerID, documentID: documentID)
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            for (index, page) in pages.enumerated() {
                let url = folder.appendingPathComponent(String(format: "page-%03d.jpg", index + 1))
                try page.write(to: url, options: [.atomic, .completeFileProtection])
            }
        } catch {
            try? fileManager.removeItem(at: folder)
            throw error
        }
    }

    func scanPages(ownerID: String?, documentID: UUID) -> [Data] {
        let folder = scanDirectory(ownerID: ownerID, documentID: documentID)
        let urls =
            (try? fileManager.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: nil))?
            .sorted { $0.lastPathComponent < $1.lastPathComponent } ?? []
        return urls.compactMap { try? Data(contentsOf: $0) }
    }

    func deleteScanPages(ownerID: String?, documentID: UUID) throws {
        let folder = scanDirectory(ownerID: ownerID, documentID: documentID)
        if fileManager.fileExists(atPath: folder.path) { try fileManager.removeItem(at: folder) }
    }

    private func directory(ownerID: String?) -> URL {
        let owner = ownerID ?? "local-demo"
        let accountKey = SHA256.hash(data: Data(owner.utf8))
            .map { String(format: "%02x", $0) }.joined()
        return fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SmartGaragePhotos", isDirectory: true)
            .appendingPathComponent(accountKey, isDirectory: true)
    }

    private func photoURL(ownerID: String?, photoID: String) -> URL {
        directory(ownerID: ownerID).appendingPathComponent(photoID).appendingPathExtension("jpg")
    }

    private func scanDirectory(ownerID: String?, documentID: UUID) -> URL {
        directory(ownerID: ownerID)
            .appendingPathComponent("document-scans", isDirectory: true)
            .appendingPathComponent(documentID.uuidString, isDirectory: true)
    }
}
