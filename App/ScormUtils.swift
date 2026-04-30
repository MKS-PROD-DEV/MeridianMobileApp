import Foundation
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

    guard let items = try? fm.contentsOfDirectory(
      at: root,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    ) else {
      return []
    }

    return items.compactMap { url in
      let zipURL = url.appendingPathComponent("original.zip")
      return fm.fileExists(atPath: zipURL.path) ? url.lastPathComponent : nil
    }
    .sorted()
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
    let zipURL = base.appendingPathComponent("original.zip")
    if !fm.fileExists(atPath: zipURL.path) { throw ScormError.zipNotFound }

    let scormDir = base.appendingPathComponent("scorm", isDirectory: true)

    if fm.fileExists(atPath: scormDir.path) {
      return scormDir
    }

    try fm.createDirectory(at: scormDir, withIntermediateDirectories: true)

    let archive = try Archive(url: zipURL, accessMode: .read)
    for entry in archive {
      let dest = scormDir.appendingPathComponent(entry.path)
      try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
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
            let href = resourceHrefByIdentifier[identifierRef] else {
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

  func parser(_ parser: XMLParser,
              didStartElement elementName: String,
              namespaceURI: String?,
              qualifiedName qName: String?,
              attributes attributeDict: [String : String] = [:]) {
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
      if inOrganization, let orgId = currentOrganizationId, let identifier = attributeDict["identifier"] {
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

  func parser(_ parser: XMLParser,
              didEndElement elementName: String,
              namespaceURI: String?,
              qualifiedName qName: String?) {
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
