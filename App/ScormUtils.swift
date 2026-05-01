import Foundation
import UniformTypeIdentifiers
import ZIPFoundation

enum ScormError: Error {
  case zipNotFound
  case manifestNotFound
  case launchNotFound
}

struct ScormCourse {
  let assetId: String
  let title: String
  let scormDir: URL
  let manifest: ScormManifestData
}

struct ScormSco: Codable {
  let itemIdentifier: String
  let resourceIdentifier: String
  let title: String
  let href: String
}

struct ScormManifestData {
  let title: String?
  let scos: [ScormSco]

  var firstSco: ScormSco? { scos.first }
}

final class ScormUtils {

  static func documentsURL() -> URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
  }

  static func assetBaseURL(assetId: String) -> URL {
    documentsURL().appendingPathComponent("assets").appendingPathComponent(assetId)
  }

  static func assetsRootURL() -> URL {
    documentsURL().appendingPathComponent("assets", isDirectory: true)
  }

  static func availableAssetIds() -> [String] {
    let fm = FileManager.default
    let root = assetsRootURL()

    guard
      let items = try? fm.contentsOfDirectory(
        at: root,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
      )
    else {
      return []
    }

    return items.compactMap { url in
      guard zipFileURL(in: url) != nil else { return nil }
      return url.lastPathComponent
    }
    .sorted()
  }

  static func saveDownloadedZip(assetId: String, from sourceURL: URL) throws {
    let fm = FileManager.default
    let root = assetsRootURL()
    let assetDir = assetBaseURL(assetId: assetId)
    let destinationURL = assetDir.appendingPathComponent(sourceURL.lastPathComponent)

    try fm.createDirectory(at: root, withIntermediateDirectories: true)
    try fm.createDirectory(at: assetDir, withIntermediateDirectories: true)

    if fm.fileExists(atPath: destinationURL.path) {
      try fm.removeItem(at: destinationURL)
    }

    try fm.copyItem(at: sourceURL, to: destinationURL)
  }

  static func replaceDownloadedZip(assetId: String, filename: String, data: Data) throws {
    let fm = FileManager.default
    let root = assetsRootURL()
    let assetDir = assetBaseURL(assetId: assetId)
    let destinationURL = assetDir.appendingPathComponent(filename)

    try fm.createDirectory(at: root, withIntermediateDirectories: true)
    try fm.createDirectory(at: assetDir, withIntermediateDirectories: true)

    if fm.fileExists(atPath: destinationURL.path) {
      try fm.removeItem(at: destinationURL)
    }

    try data.write(to: destinationURL, options: .atomic)
  }

  static func loadCourse(assetId: String) throws -> ScormCourse {
    let scormDir = try unzipIfNeeded(assetId: assetId)

    guard let manifestURL = findManifestURL(scormDir: scormDir) else {
      throw ScormError.manifestNotFound
    }

    let xml = try String(contentsOf: manifestURL, encoding: .utf8)
    guard let manifest = parseManifest(manifestXML: xml), !manifest.scos.isEmpty else {
      throw ScormError.launchNotFound
    }

    let cleanedTitle = manifest.title?.trimmingCharacters(in: .whitespacesAndNewlines)
    let title = (cleanedTitle?.isEmpty == false) ? cleanedTitle! : assetId

    ScormProgressStore.shared.saveDownloadedCourse(
      assetId: assetId,
      title: title,
      scormDirPath: scormDir.path,
      manifestTitle: manifest.title,
      scoCount: manifest.scos.count,
      downloadStatus: "downloaded"
    )

    let indexedFiles = buildCourseFileIndex(assetId: assetId, scormDir: scormDir)
    ScormProgressStore.shared.replaceCourseFiles(assetId: assetId, files: indexedFiles)

    return ScormCourse(
      assetId: assetId,
      title: title,
      scormDir: scormDir,
      manifest: manifest
    )
  }

  static func loadAllCourses() -> [ScormCourse] {
    availableAssetIds().compactMap { assetId in
      try? loadCourse(assetId: assetId)
    }
  }

  static func unzipIfNeeded(assetId: String) throws -> URL {
    let fm = FileManager.default
    let base = assetBaseURL(assetId: assetId)

    guard let zipURL = zipFileURL(in: base) else {
      throw ScormError.zipNotFound
    }

    let scormDir = base.appendingPathComponent("scorm", isDirectory: true)

    if fm.fileExists(atPath: scormDir.path) {
      return scormDir
    }

    try fm.createDirectory(at: scormDir, withIntermediateDirectories: true)

    let archive = try Archive(url: zipURL, accessMode: .read)
    for entry in archive {
      let dest = scormDir.appendingPathComponent(entry.path)
      try fm.createDirectory(
        at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
      _ = try archive.extract(entry, to: dest)
    }

    return scormDir
  }

  static func findManifestURL(scormDir: URL) -> URL? {
    let fm = FileManager.default
    if let e = fm.enumerator(at: scormDir, includingPropertiesForKeys: nil) {
      for case let url as URL in e {
        if url.lastPathComponent.lowercased() == "imsmanifest.xml" {
          return url
        }
      }
    }
    return nil
  }

  static func parseManifest(manifestXML: String) -> ScormManifestData? {
    let parser = ManifestParser(xml: manifestXML)
    return parser.parse()
  }

  static func findLaunchHref(manifestXML: String) -> String? {
    parseManifest(manifestXML: manifestXML)?.firstSco?.href
  }

  private static func zipFileURL(in directory: URL) -> URL? {
    let fm = FileManager.default

    guard
      let items = try? fm.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
      )
    else {
      return nil
    }

    return
      items
      .filter { $0.pathExtension.lowercased() == "zip" }
      .sorted {
        $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent)
          == .orderedAscending
      }
      .first
  }

  private static func buildCourseFileIndex(assetId: String, scormDir: URL) -> [CourseFileRecord] {
    let fm = FileManager.default
    let now = Date().timeIntervalSince1970
    var results: [CourseFileRecord] = []

    guard
      let enumerator = fm.enumerator(
        at: scormDir,
        includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
        options: [.skipsHiddenFiles]
      )
    else {
      return []
    }

    for case let fileURL as URL in enumerator {
      let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
      guard values?.isRegularFile == true else { continue }

      let relativePath = relativePath(from: scormDir, to: fileURL)
      let mimeType = mimeTypeForFile(at: fileURL)
      let sizeBytes = Int64(values?.fileSize ?? 0)

      results.append(
        CourseFileRecord(
          assetId: assetId,
          relativePath: relativePath,
          absolutePath: fileURL.path,
          mimeType: mimeType,
          sizeBytes: sizeBytes,
          createdAt: now,
          updatedAt: now
        )
      )
    }

    return results.sorted { $0.relativePath < $1.relativePath }
  }

  private static func relativePath(from baseURL: URL, to fileURL: URL) -> String {
    let basePath = baseURL.standardizedFileURL.path
    let filePath = fileURL.standardizedFileURL.path

    guard filePath.hasPrefix(basePath) else {
      return fileURL.lastPathComponent
    }

    var relative = String(filePath.dropFirst(basePath.count))
    if relative.hasPrefix("/") {
      relative.removeFirst()
    }
    return relative
  }

  private static func mimeTypeForFile(at fileURL: URL) -> String? {
    let ext = fileURL.pathExtension
    guard !ext.isEmpty else { return nil }

    if let type = UTType(filenameExtension: ext),
      let mimeType = type.preferredMIMEType
    {
      return mimeType
    }

    return nil
  }
}

private final class ManifestParser: NSObject, XMLParserDelegate {
  private let data: Data

  private var defaultOrganizationId: String?
  private var currentOrganizationId: String?
  private var currentResourceIdentifier: String?
  private var currentResourceHref: String?

  private var inOrganizations = false
  private var inOrganization = false
  private var inResources = false
  private var inItem = false

  private var currentText = ""

  private struct ItemNode {
    let identifier: String
    let identifierRef: String?
    var title: String
    let organizationId: String
  }

  private var manifestTitle: String?
  private var currentItem: ItemNode?
  private var items: [ItemNode] = []
  private var resourceHrefByIdentifier: [String: String] = [:]

  init(xml: String) {
    self.data = Data(xml.utf8)
  }

  func parse() -> ScormManifestData? {
    let parser = XMLParser(data: data)
    parser.delegate = self
    guard parser.parse() else { return nil }

    let chosenOrgId = defaultOrganizationId ?? items.first?.organizationId
    let chosenItems = items.filter { $0.organizationId == chosenOrgId }

    let scos: [ScormSco] = chosenItems.compactMap { item in
      guard let identifierRef = item.identifierRef,
        let href = resourceHrefByIdentifier[identifierRef]
      else {
        return nil
      }

      return ScormSco(
        itemIdentifier: item.identifier,
        resourceIdentifier: identifierRef,
        title: item.title.isEmpty ? item.identifier : item.title,
        href: href
      )
    }

    return ScormManifestData(
      title: manifestTitle,
      scos: scos
    )
  }

  func parser(
    _ parser: XMLParser,
    didStartElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?,
    attributes attributeDict: [String: String] = [:]
  ) {
    let name = qName ?? elementName
    currentText = ""

    switch name {
    case "organizations":
      inOrganizations = true
      defaultOrganizationId = attributeDict["default"]

    case "organization":
      inOrganization = true
      currentOrganizationId = attributeDict["identifier"]

    case "item":
      if inOrganization, let orgId = currentOrganizationId,
        let identifier = attributeDict["identifier"]
      {
        inItem = true
        currentItem = ItemNode(
          identifier: identifier,
          identifierRef: attributeDict["identifierref"],
          title: "",
          organizationId: orgId
        )
      }

    case "resources":
      inResources = true

    case "resource":
      if inResources {
        currentResourceIdentifier = attributeDict["identifier"]
        currentResourceHref = attributeDict["href"]
      }

    default:
      break
    }
  }

  func parser(_ parser: XMLParser, foundCharacters string: String) {
    currentText += string
  }

  func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    let name = qName ?? elementName
    let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

    switch name {
    case "title":
      if inItem, var item = currentItem, !text.isEmpty {
        item = ItemNode(
          identifier: item.identifier,
          identifierRef: item.identifierRef,
          title: text,
          organizationId: item.organizationId
        )
        currentItem = item
      } else if inOrganization && manifestTitle == nil && !text.isEmpty {
        manifestTitle = text
      }

    case "item":
      if let item = currentItem {
        items.append(item)
      }
      currentItem = nil
      inItem = false

    case "resource":
      if let id = currentResourceIdentifier, let href = currentResourceHref {
        resourceHrefByIdentifier[id] = href
      }
      currentResourceIdentifier = nil
      currentResourceHref = nil

    case "organization":
      inOrganization = false
      currentOrganizationId = nil

    case "organizations":
      inOrganizations = false

    case "resources":
      inResources = false

    default:
      break
    }

    currentText = ""
  }
}
