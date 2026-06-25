import Foundation
import UIKit

enum MediaStore {
    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("CalTrackerMedia", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func saveJPEG(_ image: UIImage, prefix: String) throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.82) else {
            throw ServiceError.imageEncoding
        }
        let filename = "\(prefix)-\(UUID().uuidString).jpg"
        try data.write(to: directory.appendingPathComponent(filename), options: .atomic)
        return filename
    }

    static func image(named filename: String?) -> UIImage? {
        guard let filename, !filename.isEmpty else { return nil }
        return UIImage(contentsOfFile: directory.appendingPathComponent(filename).path)
    }

    static func delete(_ filename: String?) {
        guard let filename, !filename.isEmpty else { return }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(filename))
    }
}
