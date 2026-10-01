import Foundation

// Reports how many bytes under a path are still pending upload to a
// macOS File Provider-backed cloud storage service (Google Drive, Dropbox,
// iCloud Drive, etc.), using the live status the OS tracks for each item.
//
// Usage: scan_upload_status <path> [--list-pending]

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write("usage: scan_upload_status <path> [--list-pending]\n".data(using: .utf8)!)
    exit(1)
}
let rootPath = args[1]
let listPending = args.contains("--list-pending")
let rootURL = URL(fileURLWithPath: rootPath)

let keys: [URLResourceKey] = [
    .isDirectoryKey,
    .isUbiquitousItemKey,
    .ubiquitousItemIsUploadingKey,
    .ubiquitousItemIsUploadedKey,
    .ubiquitousItemUploadingErrorKey,
    .fileSizeKey,
]

let fm = FileManager.default
guard let enumerator = fm.enumerator(
    at: rootURL,
    includingPropertiesForKeys: keys,
    options: [],
    errorHandler: { url, error in
        FileHandle.standardError.write("enum error at \(url): \(error)\n".data(using: .utf8)!)
        return true
    }
) else {
    FileHandle.standardError.write("failed to enumerate \(rootPath)\n".data(using: .utf8)!)
    exit(1)
}

var totalFiles = 0
var totalBytes: Int64 = 0
var untrackedFiles = 0
var uploadingFiles = 0
var uploadingBytes: Int64 = 0
var pendingFiles = 0
var pendingBytes: Int64 = 0

for item in enumerator {
    guard let url = item as? URL else { continue }
    let values: URLResourceValues
    do {
        values = try url.resourceValues(forKeys: Set(keys))
    } catch {
        FileHandle.standardError.write("resourceValues error at \(url): \(error)\n".data(using: .utf8)!)
        continue
    }
    if values.isDirectory == true { continue }

    totalFiles += 1
    let size = Int64(values.fileSize ?? 0)
    totalBytes += size

    if values.isUbiquitousItem != true {
        untrackedFiles += 1
        continue
    }
    if values.ubiquitousItemIsUploading == true {
        uploadingFiles += 1
        uploadingBytes += size
    }
    if values.ubiquitousItemIsUploaded == false {
        pendingFiles += 1
        pendingBytes += size
        if listPending {
            let err = values.ubiquitousItemUploadingError
            FileHandle.standardError.write(
                "PENDING: \(url.path) size=\(size) uploading=\(values.ubiquitousItemIsUploading ?? false) error=\(String(describing: err))\n".data(using: .utf8)!)
        }
    }
}

print("totalFiles:", totalFiles)
print("totalBytes:", totalBytes)
print("untrackedFiles:", untrackedFiles)
print("uploadingFiles:", uploadingFiles)
print("uploadingBytes:", uploadingBytes)
print("notYetUploadedFiles:", pendingFiles)
print("notYetUploadedBytes:", pendingBytes)
