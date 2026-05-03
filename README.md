# App Overview

This app is a **Capacitor-based hybrid iOS application** with an **offline SCORM player** built on top of native iOS screens and `WKWebView`.

The main app runs inside a Capacitor webview, while offline SCORM playback is handled by a separate native player flow.

---

## High-Level Architecture

- **Capacitor** is used as the main app shell and JavaScript/native bridge
- The main app UI runs inside a **Capacitor webview**
- Offline SCORM packages are downloaded and stored in the app's **Documents** directory
- Native iOS screens display:
  - available offline courses
  - lessons within a course
  - the SCORM player
  - help, settings, and bug reporting
- SCORM content is served locally using a custom URL scheme:
  - `scorm://localhost/...`
- SCORM progress is persisted natively in **SQLite**
---

## How SCORM Files Are Served

SCORM packages are stored and extracted under the app’s Documents directory, typically in a structure like:

```text
Documents/assets/{assetId}/scorm/...
```

The SCORM player uses a custom `WKURLSchemeHandler` to serve files through:

```text
scorm://localhost/...
```

### How this works
1. A lesson launch file is resolved on disk
2. The launch path is converted to a local custom URL such as:

   ```text
   scorm://localhost/scormdriver/indexAPI.html
   ```

3. The player webview requests that URL
4. Native code intercepts the request using `WKURLSchemeHandler`
5. The handler maps the URL back to the correct file inside the extracted SCORM directory
6. The handler reads the file from disk and returns it with the appropriate MIME type

This approach provides a stable local web origin for:
- HTML
- JavaScript
- CSS
- images
- frames
- internal SCORM navigation

---

## Data Storage

### Files
Downloaded and extracted SCORM packages are stored in the app’s Documents directory.

### SQLite
Native SQLite storage is used for:
- SCORM progress (`sco_progress`)
- downloaded course metadata (`downloaded_courses`)
- indexed extracted file metadata (`course_files`)

### Preferences
Capacitor `Preferences` is used for lightweight app and asset metadata where needed.

---

## End-to-End Flow

### Main App Flow
1. Capacitor launches the main app webview
2. JavaScript can call native functionality through injected bridge code
3. The web app can request an offline SCORM course to open

### Offline SCORM Flow
1. Native receives the request to open a SCORM asset
2. `ScormUtils` loads and parses the course
3. The app shows the list of available offline courses
4. The user selects a course
5. The app shows the lesson list
6. The user selects a lesson
7. `ScormPlayerViewController` launches the lesson in a dedicated webview
8. SCORM content is served through `scorm://localhost/...`
9. `ScormAPIShim` handles SCORM LMS API calls
10. Learner progress is loaded from and saved to native SQLite storage

---

## Current Offline Features

- offline course browsing
- lesson selection and playback
- local SCORM progress persistence
- autosave feedback in the player
- course progress status in the offline course list
- pull-to-refresh for downloaded courses
- swipe-to-delete for full course removal
- local asset storage usage in Settings
- organization switching
- help and bug reporting screens

---

## Summary

This app is a Capacitor hybrid iOS app with a native offline SCORM subsystem.

- Capacitor powers the main app shell and JS/native bridge
- Offline SCORM packages are stored locally on device
- Native screens handle course and lesson selection
- A dedicated SCORM player webview serves content through a custom `scorm://localhost` local scheme
- A SCORM API shim and native SQLite storage provide offline learner progress tracking
