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
- SCORM content is served locally using a custom URL scheme:
  - `scorm://localhost/...`
- SCORM progress is persisted natively in **SQLite**

---

## Main Components

### `AppDelegate.swift`
Standard iOS app entry point.

Responsibilities:
- app startup
- Capacitor URL handling hooks
- debug logging for app Documents path

---

### `MyViewController.swift`
Main Capacitor bridge controller.

This file is the central coordinator for the app and is responsible for:
- hosting the main Capacitor webview
- injecting helper JavaScript into the main webview
- receiving JavaScript messages from the web app
- managing online/offline mode
- presenting offline course and SCORM flows

It subclasses:

```swift
CAPBridgeViewController
```

---

### `nativeAssetStore.js`
Injected JavaScript helper for local asset operations.

It exposes:

```js
window.NativeAssetStore
```

Functions include:
- downloading files
- saving asset metadata
- reading asset metadata
- saving progress metadata
- reading progress metadata
- storing last launch state

It uses Capacitor plugins such as:
- `Filesystem`
- `Preferences`

---

### `ScormUtils.swift`
Utility layer for SCORM storage and parsing.

Responsibilities:
- resolving the app Documents directory
- managing `assets/{assetId}`
- saving downloaded ZIP files
- unzipping SCORM packages
- finding `imsmanifest.xml`
- parsing the SCORM manifest
- building course and lesson models
- indexing extracted course files

This is the core utility for local SCORM package management.

---

### `ScormCourseListViewController.swift`
Native screen that displays available offline SCORM courses.

Responsibilities:
- rendering the list of downloaded courses
- navigating to the lesson list for a selected course

---

### `ScormLessonListViewController.swift`
Native screen that displays lessons/SCOs for a selected SCORM course.

Responsibilities:
- listing lessons from the parsed SCORM manifest
- resolving the launch file for a selected SCO
- opening the SCORM player

---

### `ScormPlayerViewController.swift`
Native SCORM playback screen.

Responsibilities:
- creating and hosting a dedicated `WKWebView`
- injecting the SCORM API shim JavaScript
- loading the selected lesson
- handling JS/native messages for SCORM storage
- serving SCORM files through a custom URL scheme
- supporting popup content

SCORM content is loaded using:

```text
scorm://localhost/...
```

---

### `ScormAPIShim.swift`
Injected JavaScript that provides the SCORM runtime bridge.

Responsibilities:
- implementing the SCORM API methods used by offline content
- exposing LMS-style APIs such as:
  - `LMSInitialize`
  - `LMSFinish`
  - `LMSCommit`
  - `LMSGetValue`
  - `LMSSetValue`
- loading saved learner state from native storage
- saving updated learner state back to native storage
- installing the API across frames/windows
- auto-persisting progress periodically

This is the layer that allows offline SCORM content to function correctly without an LMS backend.

---

### `PopupWebViewController`
Native modal controller used for popup windows.

Responsibilities:
- hosting popup `WKWebView` instances
- presenting popup content modally
- allowing the user to close popup windows

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

## Summary

This app is a Capacitor hybrid iOS app with a native offline SCORM subsystem.

- Capacitor powers the main app shell and JS/native bridge
- Offline SCORM packages are stored locally on device
- Native screens handle course and lesson selection
- A dedicated SCORM player webview serves content through a custom `scorm://localhost` local scheme
- A SCORM API shim and native SQLite storage provide offline learner progress tracking
