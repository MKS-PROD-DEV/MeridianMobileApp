import Foundation
import SQLite3

struct DownloadedCourseRecord {
  let assetId: String
  let title: String
  let scormDirPath: String
  let manifestTitle: String?
  let scoCount: Int
  let downloadStatus: String
  let createdAt: TimeInterval
  let updatedAt: TimeInterval
}

struct CourseFileRecord {
  let assetId: String
  let relativePath: String
  let absolutePath: String
  let mimeType: String?
  let sizeBytes: Int64
  let createdAt: TimeInterval
  let updatedAt: TimeInterval
}

enum CourseProgressStatus: String {
  case started = "Started"
  case inProgress = "In Progress"
  case completed = "Completed"
}

final class ScormProgressStore {
  static let shared = ScormProgressStore()

  private var database: OpaquePointer?

  private init() {
    openDatabase()
    createTablesIfNeeded()
    migrateSchemaIfNeeded()
  }

  deinit {
    if database != nil {
      sqlite3_close(database)
    }
  }

  private func databaseURL() -> URL {
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    return documents.appendingPathComponent("scorm_progress.sqlite")
  }

  private func openDatabase() {
    let path = databaseURL().path
    print("SQLite DB path:", path)

    if sqlite3_open(path, &database) != SQLITE_OK {
      print("SQLite open error:", String(cString: sqlite3_errmsg(database)))
    }
  }

  private func createTablesIfNeeded() {
    createTable(sql: ScormProgressStoreSQL.createScoProgressTable, name: "sco_progress")
    createTable(sql: ScormProgressStoreSQL.createDownloadedCoursesTable, name: "downloaded_courses")
    createTable(sql: ScormProgressStoreSQL.createCourseFilesTable, name: "course_files")
  }

  private func createTable(sql: String, name: String) {
    if sqlite3_exec(database, sql, nil, nil, nil) != SQLITE_OK {
      print("SQLite create table error (\(name)):", String(cString: sqlite3_errmsg(database)))
    } else {
      print("SQLite table ready:", name)
    }
  }

  private func migrateSchemaIfNeeded() {
    addColumnIfNeeded(
      table: "sco_progress",
      column: "sync_status",
      definition: "TEXT NOT NULL DEFAULT 'pending'"
    )

    addColumnIfNeeded(
      table: "sco_progress",
      column: "last_synced_at",
      definition: "REAL"
    )

    addColumnIfNeeded(
      table: "sco_progress",
      column: "sync_error",
      definition: "TEXT"
    )
  }

  private func addColumnIfNeeded(table: String, column: String, definition: String) {
    guard !tableHasColumn(table: table, column: column) else { return }

    let sql = ScormProgressStoreSQL.alterTableAddColumn(
      table: table,
      column: column,
      definition: definition
    )

    if sqlite3_exec(database, sql, nil, nil, nil) != SQLITE_OK {
      print("SQLite alter table error (\(table).\(column)):", String(cString: sqlite3_errmsg(database)))
    } else {
      print("SQLite added column:", "\(table).\(column)")
    }
  }

  private func tableHasColumn(table: String, column: String) -> Bool {
    let sql = ScormProgressStoreSQL.pragmaTableInfo(table: table)
    var statement: OpaquePointer?

    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
      print("SQLite pragma prepare error:", String(cString: sqlite3_errmsg(database)))
      return false
    }

    defer { sqlite3_finalize(statement) }

    while sqlite3_step(statement) == SQLITE_ROW {
      if let cString = sqlite3_column_text(statement, 1) {
        let existingColumn = String(cString: cString)
        if existingColumn == column {
          return true
        }
      }
    }

    return false
  }

  func loadCMI(assetId: String, scoId: String) -> String? {
    print("SQLite load request:", assetId, scoId)

    let sql = ScormProgressStoreSQL.loadCMI
    var statement: OpaquePointer?

    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
      print("SQLite prepare load error:", String(cString: sqlite3_errmsg(database)))
      return nil
    }

    defer { sqlite3_finalize(statement) }

    sqlite3_bind_text(statement, 1, (assetId as NSString).utf8String, -1, nil)
    sqlite3_bind_text(statement, 2, (scoId as NSString).utf8String, -1, nil)

    if sqlite3_step(statement) == SQLITE_ROW,
      let cString = sqlite3_column_text(statement, 0) {
      print("SQLite load hit:", assetId, scoId)
      return String(cString: cString)
    }

    print("SQLite load miss:", assetId, scoId)
    return nil
  }

  func saveCMI(assetId: String, scoId: String, cmiJSON: String) {
    print("SQLite save request:", assetId, scoId)

    let sql = ScormProgressStoreSQL.saveCMI
    var statement: OpaquePointer?

    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
      print("SQLite prepare save error:", String(cString: sqlite3_errmsg(database)))
      return
    }

    defer { sqlite3_finalize(statement) }

    sqlite3_bind_text(statement, 1, (assetId as NSString).utf8String, -1, nil)
    sqlite3_bind_text(statement, 2, (scoId as NSString).utf8String, -1, nil)
    sqlite3_bind_text(statement, 3, (cmiJSON as NSString).utf8String, -1, nil)
    sqlite3_bind_double(statement, 4, Date().timeIntervalSince1970)

    if sqlite3_step(statement) != SQLITE_DONE {
      print("SQLite save error:", String(cString: sqlite3_errmsg(database)))
    } else {
      print("SQLite save success:", assetId, scoId)
    }
  }

  func markCMISynced(assetId: String, scoId: String) {
    let sql = ScormProgressStoreSQL.markCMISynced
    var statement: OpaquePointer?

    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
      print("SQLite prepare mark synced error:", String(cString: sqlite3_errmsg(database)))
      return
    }

    defer { sqlite3_finalize(statement) }

    sqlite3_bind_double(statement, 1, Date().timeIntervalSince1970)
    sqlite3_bind_text(statement, 2, (assetId as NSString).utf8String, -1, nil)
    sqlite3_bind_text(statement, 3, (scoId as NSString).utf8String, -1, nil)

    if sqlite3_step(statement) != SQLITE_DONE {
      print("SQLite mark synced error:", String(cString: sqlite3_errmsg(database)))
    }
  }

  func markCMISyncFailed(assetId: String, scoId: String, errorMessage: String) {
    let sql = ScormProgressStoreSQL.markCMISyncFailed
    var statement: OpaquePointer?

    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
      print("SQLite prepare mark failed error:", String(cString: sqlite3_errmsg(database)))
      return
    }

    defer { sqlite3_finalize(statement) }

    sqlite3_bind_text(statement, 1, (errorMessage as NSString).utf8String, -1, nil)
    sqlite3_bind_text(statement, 2, (assetId as NSString).utf8String, -1, nil)
    sqlite3_bind_text(statement, 3, (scoId as NSString).utf8String, -1, nil)

    if sqlite3_step(statement) != SQLITE_DONE {
      print("SQLite mark failed error:", String(cString: sqlite3_errmsg(database)))
    }
  }

  func saveDownloadedCourse(
    assetId: String,
    title: String,
    scormDirPath: String,
    manifestTitle: String?,
    scoCount: Int,
    downloadStatus: String = "downloaded"
  ) {
    let now = Date().timeIntervalSince1970
    let sql = ScormProgressStoreSQL.saveDownloadedCourse
    var statement: OpaquePointer?

    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
      print("SQLite prepare save downloaded course error:", String(cString: sqlite3_errmsg(database)))
      return
    }

    defer { sqlite3_finalize(statement) }

    sqlite3_bind_text(statement, 1, (assetId as NSString).utf8String, -1, nil)
    sqlite3_bind_text(statement, 2, (title as NSString).utf8String, -1, nil)
    sqlite3_bind_text(statement, 3, (scormDirPath as NSString).utf8String, -1, nil)

    if let manifestTitle = manifestTitle {
      sqlite3_bind_text(statement, 4, (manifestTitle as NSString).utf8String, -1, nil)
    } else {
      sqlite3_bind_null(statement, 4)
    }

    sqlite3_bind_int(statement, 5, Int32(scoCount))
    sqlite3_bind_text(statement, 6, (downloadStatus as NSString).utf8String, -1, nil)
    sqlite3_bind_double(statement, 7, now)
    sqlite3_bind_double(statement, 8, now)

    if sqlite3_step(statement) != SQLITE_DONE {
      print("SQLite save downloaded course error:", String(cString: sqlite3_errmsg(database)))
    } else {
      print("SQLite save downloaded course success:", assetId)
    }
  }

  func replaceCourseFiles(assetId: String, files: [CourseFileRecord]) {
    deleteCourseFiles(assetId: assetId)

    let sql = ScormProgressStoreSQL.replaceCourseFile
    var statement: OpaquePointer?

    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
      print("SQLite prepare replace course files error:", String(cString: sqlite3_errmsg(database)))
      return
    }

    defer { sqlite3_finalize(statement) }

    for file in files {
      sqlite3_reset(statement)
      sqlite3_clear_bindings(statement)

      sqlite3_bind_text(statement, 1, (file.assetId as NSString).utf8String, -1, nil)
      sqlite3_bind_text(statement, 2, (file.relativePath as NSString).utf8String, -1, nil)
      sqlite3_bind_text(statement, 3, (file.absolutePath as NSString).utf8String, -1, nil)

      if let mimeType = file.mimeType {
        sqlite3_bind_text(statement, 4, (mimeType as NSString).utf8String, -1, nil)
      } else {
        sqlite3_bind_null(statement, 4)
      }

      sqlite3_bind_int64(statement, 5, file.sizeBytes)
      sqlite3_bind_double(statement, 6, file.createdAt)
      sqlite3_bind_double(statement, 7, file.updatedAt)

      if sqlite3_step(statement) != SQLITE_DONE {
        print("SQLite insert course file error:", String(cString: sqlite3_errmsg(database)))
      }
    }

    print("SQLite indexed course files:", assetId, files.count)
  }

  func loadDownloadedCourses() -> [DownloadedCourseRecord] {
    let sql = ScormProgressStoreSQL.loadDownloadedCourses
    var statement: OpaquePointer?
    var results: [DownloadedCourseRecord] = []

    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
      print("SQLite prepare load downloaded courses error:", String(cString: sqlite3_errmsg(database)))
      return []
    }

    defer { sqlite3_finalize(statement) }

    while sqlite3_step(statement) == SQLITE_ROW {
      guard
        let assetIdCString = sqlite3_column_text(statement, 0),
        let titleCString = sqlite3_column_text(statement, 1),
        let scormDirPathCString = sqlite3_column_text(statement, 2),
        let downloadStatusCString = sqlite3_column_text(statement, 5)
      else {
        continue
      }

      let manifestTitle: String?
      if let manifestTitleCString = sqlite3_column_text(statement, 3) {
        manifestTitle = String(cString: manifestTitleCString)
      } else {
        manifestTitle = nil
      }

      results.append(
        DownloadedCourseRecord(
          assetId: String(cString: assetIdCString),
          title: String(cString: titleCString),
          scormDirPath: String(cString: scormDirPathCString),
          manifestTitle: manifestTitle,
          scoCount: Int(sqlite3_column_int(statement, 4)),
          downloadStatus: String(cString: downloadStatusCString),
          createdAt: sqlite3_column_double(statement, 6),
          updatedAt: sqlite3_column_double(statement, 7)
        )
      )
    }

    return results
  }

  func loadCourseFiles(assetId: String) -> [CourseFileRecord] {
    let sql = ScormProgressStoreSQL.loadCourseFiles
    var statement: OpaquePointer?
    var results: [CourseFileRecord] = []

    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
      print("SQLite prepare load course files error:", String(cString: sqlite3_errmsg(database)))
      return []
    }

    defer { sqlite3_finalize(statement) }

    sqlite3_bind_text(statement, 1, (assetId as NSString).utf8String, -1, nil)

    while sqlite3_step(statement) == SQLITE_ROW {
      guard
        let assetIdCString = sqlite3_column_text(statement, 0),
        let relativePathCString = sqlite3_column_text(statement, 1),
        let absolutePathCString = sqlite3_column_text(statement, 2)
      else {
        continue
      }

      let mimeType: String?
      if let mimeTypeCString = sqlite3_column_text(statement, 3) {
        mimeType = String(cString: mimeTypeCString)
      } else {
        mimeType = nil
      }

      results.append(
        CourseFileRecord(
          assetId: String(cString: assetIdCString),
          relativePath: String(cString: relativePathCString),
          absolutePath: String(cString: absolutePathCString),
          mimeType: mimeType,
          sizeBytes: sqlite3_column_int64(statement, 4),
          createdAt: sqlite3_column_double(statement, 5),
          updatedAt: sqlite3_column_double(statement, 6)
        )
      )
    }

    return results
  }

  func deleteDownloadedCourse(assetId: String) {
    let sql = ScormProgressStoreSQL.deleteDownloadedCourse
    var statement: OpaquePointer?

    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
      print("SQLite prepare delete downloaded course error:", String(cString: sqlite3_errmsg(database)))
      return
    }

    defer { sqlite3_finalize(statement) }

    sqlite3_bind_text(statement, 1, (assetId as NSString).utf8String, -1, nil)

    if sqlite3_step(statement) != SQLITE_DONE {
      print("SQLite delete downloaded course error:", String(cString: sqlite3_errmsg(database)))
    }
  }

  func deleteCourseFiles(assetId: String) {
    let sql = ScormProgressStoreSQL.deleteCourseFiles
    var statement: OpaquePointer?

    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
      print("SQLite prepare delete course files error:", String(cString: sqlite3_errmsg(database)))
      return
    }

    defer { sqlite3_finalize(statement) }

    sqlite3_bind_text(statement, 1, (assetId as NSString).utf8String, -1, nil)

    if sqlite3_step(statement) != SQLITE_DONE {
      print("SQLite delete course files error:", String(cString: sqlite3_errmsg(database)))
    }
  }

  func deleteCourseProgress(assetId: String) {
    let sql = ScormProgressStoreSQL.deleteCourseProgress
    var statement: OpaquePointer?

    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
      print("SQLite prepare delete course progress error:", String(cString: sqlite3_errmsg(database)))
      return
    }

    defer { sqlite3_finalize(statement) }

    sqlite3_bind_text(statement, 1, (assetId as NSString).utf8String, -1, nil)

    if sqlite3_step(statement) != SQLITE_DONE {
      print("SQLite delete course progress error:", String(cString: sqlite3_errmsg(database)))
    }
  }

  func progressStatus(for assetId: String) -> CourseProgressStatus? {
    let sql = ScormProgressStoreSQL.loadCourseProgressRows
    var statement: OpaquePointer?
    var foundAnyProgress = false
    var foundCompleted = false

    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
      print("SQLite prepare load course progress rows error:", String(cString: sqlite3_errmsg(database)))
      return nil
    }

    defer { sqlite3_finalize(statement) }

    sqlite3_bind_text(statement, 1, (assetId as NSString).utf8String, -1, nil)

    while sqlite3_step(statement) == SQLITE_ROW {
      guard let cString = sqlite3_column_text(statement, 0) else { continue }
      foundAnyProgress = true

      let json = String(cString: cString).lowercased()
      if json.contains("\"cmi.core.lesson_status\":\"completed\"")
        || json.contains("\"cmi.core.lesson_status\":\"passed\"")
        || json.contains("\"lesson_status\":\"completed\"")
        || json.contains("\"lesson_status\":\"passed\"") {
        foundCompleted = true
      }
    }

    guard foundAnyProgress else { return nil }
    return foundCompleted ? .completed : .inProgress
  }

  func clearAll() {
    print("SQLite clear all")

    for sql in ScormProgressStoreSQL.clearAllStatements {
      let result = sqlite3_exec(database, sql, nil, nil, nil)
      if result != SQLITE_OK {
        print("SQLite clear error:", String(cString: sqlite3_errmsg(database)))
      }
    }
  }
}
