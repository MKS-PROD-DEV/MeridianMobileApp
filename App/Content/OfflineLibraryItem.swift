import Foundation

struct OfflineContentItem {
  let assetId: String
  let title: String
  let fileURL: URL
  let type: OfflineContentType
}

enum OfflineLibraryItem {
  case scorm(ScormCourse)
  case file(OfflineContentItem)

  var assetId: String {
    switch self {
    case .scorm(let course):
      return course.assetId
    case .file(let item):
      return item.assetId
    }
  }

  var title: String {
    switch self {
    case .scorm(let course):
      return course.title
    case .file(let item):
      return item.title
    }
  }

  var subtitle: String {
    switch self {
    case .scorm(let course):
      let progress = ScormProgressStore.shared.progressStatus(for: course.assetId)?.rawValue
      if let progress = progress {
        return String(format: L10n.tr("courses.lesson_count_progress"), course.manifest.scos.count, progress)
      } else {
        return String(format: L10n.tr("courses.lesson_count"), course.manifest.scos.count)
      }
    case .file(let item):
      return item.type.localizedDisplayName
    }
  }

  var isScorm: Bool {
    switch self {
    case .scorm:
      return true
    case .file:
      return false
    }
  }
}
