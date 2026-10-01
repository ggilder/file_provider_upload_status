# file\_provider\_upload\_status

Reports how many bytes under a path are still pending upload to a
macOS File Provider-backed cloud storage service (Google Drive, Dropbox,
iCloud Drive, etc.), using live OS-level status instead of the cloud
provider's own local sync database.

## Why

Google Drive for macOS integrates with the system via the [File
Provider](https://developer.apple.com/documentation/fileprovider) framework.
However, its desktop app does not reliably report how much remains to be
synced.

## Mechanism

Every file inside a File Provider domain supports a set of standard
`NSURL` resource keys — the same ones Finder reads to show upload/sync
badges — regardless of which provider backs the domain:

- `isUbiquitousItem` — is this item part of a File Provider domain at all?
- `ubiquitousItemIsUploaded` — has the current content finished uploading?
- `ubiquitousItemIsUploading` — is it actively uploading right now?
- `ubiquitousItemUploadingError` — did the last upload attempt fail?

These keys were originally named for iCloud Drive ("ubiquitous" is
Apple's internal term for iCloud-synced items), but macOS resolves them
through the generic File Provider extension for the containing volume, so
they work identically for third-party providers like Google Drive and
Dropbox. Asking the OS directly via these keys reflects the File Provider
daemon's live state, not any provider app's cache of it.

The tool walks a directory tree with `FileManager.enumerator`, prefetching
these keys for every item in one pass, and sums file sizes for anything
where `ubiquitousItemIsUploaded == false`.

## Build

```
swiftc -O scan_upload_status.swift -o scan_upload_status
```

## Usage

```
./scan_upload_status <path> [--list-pending]
```

`--list-pending` additionally prints each not-yet-uploaded file (path,
size, live uploading/error state) to stderr.

Output:

```
totalFiles: 29290
totalBytes: 189203145417
untrackedFiles: 0
uploadingFiles: 0
uploadingBytes: 0
notYetUploadedFiles: 10
notYetUploadedBytes: 137256
```

To estimate an ETA, run it a few times a few minutes apart and divide the
drop in `notYetUploadedBytes` by the elapsed time.

## Caveats

- Requires the path to be inside an actual File Provider domain (e.g.
  `~/Library/CloudStorage/...`). Plain local files will show
  `isUbiquitousItem == false` and are skipped from the pending count.
- Scans every item's live status via IPC to the File Provider daemon, so
  it's noticeably slower than a plain filesystem walk (~30-40s for
  ~29,000 items) — this is talking to a live daemon per item, not reading
  cached metadata.
- Reflects *content* upload status only, not Drive-specific states like
  "pinned for offline" vs "stream-only."
