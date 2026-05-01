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

final class ScormProgressStore {
  static let shared = ScormProgressStore()

  private var db: OpaquePointer?

  private init() {
    openDatabase()
    createTablesIfNeeded()
    migrateSchemaIfNeeded()
  }

  deinit {
    if db != nil {
      sqlite3_close(db)
    }
  }

  private func databaseURL() -> URL {
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    return documents.appendingPathComponent("scorm_progress.sqlite")
  }

  private func openDatabase() {
    let path = databaseURL().path
    print("SQLite DB path:", path)

    if sqlite3_open(path, &db) != SQLITE_OK {
      print("SQLite open error:", String(cString: sqlite3_errmsg(db)))
    }
  }

  private func createTablesIfNeeded() {
    let scoProgressSQL = """
      CREATE TABLE IF NOT EXISTS sco_progress (
        asset_id TEXT NOT NULL,
        sco_id TEXT NOT NULL,
        cmi_json TEXT NOT NULL,
        updated_at REAL NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        last_synced_at REAL,
        sync_error TEXT,
        PRIMARY KEY (asset_id, sco_id)
      );
      """

    if sqlite3_exec(db, scoProgressSQL, nil, nil, nil) != SQLITE_OK {
      print("SQLite create table error (sco_progress):", String(cString: sqlite3_errmsg(db)))
    } else {
      print("SQLite table ready: sco_progress")
    }

    let downloadedCoursesSQL = """
      CREATE TABLE IF NOT EXISTS downloaded_courses (
        asset_id TEXT PRIMARY KEY NOT NULL,
        title TEXT NOT NULL,
        scorm_dir_path TEXT NOT NULL,
        manifest_title TEXT,
        sco_count INTEGER NOT NULL DEFAULT 0,
        download_status TEXT NOT NULL DEFAULT 'downloaded',
        created_at REAL NOT NULL,
        updated_at REAL NOT NULL
      );
      """

    if sqlite3_exec(db, downloadedCoursesSQL, nil, nil, nil) != SQLITE_OK {
      print("SQLite create table error (downloaded_courses):", String(cString: sqlite3_errmsg(db)))
    } else {
      print("SQLite table ready: downloaded_courses")
    }

    let courseFilesSQL = """
      CREATE TABLE IF NOT EXISTS course_files (
        asset_id TEXT NOT NULL,
        relative_path TEXT NOT NULL,
        absolute_path TEXT NOT NULL,
        mime_type TEXT,
        size_bytes INTEGER NOT NULL DEFAULT 0,
        created_at REAL NOT NULL,
        updated_at REAL NOT NULL,
        PRIMARY KEY (asset_id, relative_path)
      );
      """

    if sqlite3_exec(db, courseFilesSQL, nil, nil, nil) != SQLITE_OK {
      print("SQLite create table error (course_files):", String(cString: sqlite3_errmsg(db)))
    } else {
      print("SQLite table ready: course_files")
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

    let sql = "ALTER TABLE \(table) ADD COLUMN \(column) \(definition);"
    if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
      print("SQLite alter table error (\(table).\(column)):", String(cString: sqlite3_errmsg(db)))
    } else {
      print("SQLite added column:", "\(table).\(column)")
    }
  }

  private func tableHasColumn(table: String, column: String) -> Bool {
    let sql = "PRAGMA table_info(\(table));"
    var statement: OpaquePointer?

    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
      print("SQLite pragma prepare error:", String(cString: sqlite3_errmsg(db)))
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

    let sql = """
      SELECT cmi_json
      FROM sco_progress
      WHERE asset_id = ? AND sco_id = ?
      LIMIT 1;
      """

    var statement: OpaquePointer?

    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
      print("SQLite prepare load error:", String(cString: sqlite3_errmsg(db)))
      return nil
    }

    defer { sqlite3_finalize(statement) }

    sqlite3_bind_text(statement, 1, (assetId as NSString).utf8String, -1, nil)
    sqlite3_bind_text(statement, 2, (scoId as NSString).utf8String, -1, nil)

    if sqlite3_step(statement) == SQLITE_ROW,
      let cString = sqlite3_column_text(statement, 0)
    {
      print("SQLite load hit:", assetId, scoId)
      return String(cString: cString)
    }

    print("SQLite load miss:", assetId, scoId)
    return nil
  }

  func saveCMI(assetId: String, scoId: String, cmiJSON: String) {
    print("SQLite save request:", assetId, scoId)

    let sql = """
      INSERT INTO sco_progress (asset_id, sco_id, cmi_json, updated_at, sync_status, last_synced_at, sync_error)
      VALUES (?, ?, ?, ?, 'pending', NULL, NULL)
      ON CONFLICT(asset_id, sco_id)
      DO UPDATE SET
        cmi_json = excluded.cmi_json,
        updated_at = excluded.updated_at,
        sync_status = 'pending',
        last_synced_at = NULL,
        sync_error = NULL;
      """

    var statement: OpaquePointer?

    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
      print("SQLite prepare save error:", String(cString: sqlite3_errmsg(db)))
      return
    }

    defer { sqlite3_finalize(statement) }

    sqlite3_bind_text(statement, 1, (assetId as NSString).utf8String, -1, nil)
    sqlite3_bind_text(statement, 2, (scoId as NSString).utf8String, -1, nil)
    sqlite3_bind_text(statement, 3, (cmiJSON as NSString).utf8String, -1, nil)
    sqlite3_bind_double(statement, 4, Date().timeIntervalSince1970)

    if sqlite3_step(statement) != SQLITE_DONE {
      print("SQLite save error:", String(cString: sqlite3_errmsg(db)))
    } else {
      print("SQLite save success:", assetId, scoId)
    }
  }

  func markCMISynced(assetId: String, scoId: String) {
    let sql = """
      UPDATE sco_progress
      SET sync_status = 'synced',
          last_synced_at = ?,
          sync_error = NULL
      WHERE asset_id = ? AND sco_id = ?;
      """

    var statement: OpaquePointer?

    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
      print("SQLite prepare mark synced error:", String(cString: sqlite3_errmsg(db)))
      return
    }

    defer { sqlite3_finalize(statement) }

    sqlite3_bind_double(statement, 1, Date().timeIntervalSince1970)
    sqlite3_bind_text(statement, 2, (assetId as NSString).utf8String, -1, nil)
    sqlite3_bind_text(statement, 3, (scoId as NSString).utf8String, -1, nil)

    if sqlite3_step(statement) != SQLITE_DONE {
      print("SQLite mark synced error:", String(cString: sqlite3_errmsg(db)))
    }
  }

  func markCMISyncFailed(assetId: String, scoId: String, errorMessage: String) {
    let sql = """
      UPDATE sco_progress
      SET sync_status = 'failed',
          sync_error = ?
      WHERE asset_id = ? AND sco_id = ?;
      """

    var statement: OpaquePointer?

    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
      print("SQLite prepare mark failed error:", String(cString: sqlite3_errmsg(db)))
      return
    }

    defer { sqlite3_finalize(statement) }

    sqlite3_bind_text(statement, 1, (errorMessage as NSString).utf8String, -1, nil)
    sqlite3_bind_text(statement, 2, (assetId as NSString).utf8String, -1, nil)
    sqlite3_bind_text(statement, 3, (scoId as NSString).utf8String, -1, nil)

    if sqlite3_step(statement) != SQLITE_DONE {
      print("SQLite mark failed error:", String(cString: sqlite3_errmsg(db)))
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

    let sql = """
      INSERT INTO downloaded_courses (
        asset_id, title, scorm_dir_path, manifest_title, sco_count, download_status, created_at, updated_at
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(asset_id)
      DO UPDATE SET
        title = excluded.title,
        scorm_dir_path = excluded.scorm_dir_path,
        manifest_title = excluded.manifest_title,
        sco_count = excluded.sco_count,
        download_status = excluded.download_status,
        updated_at = excluded.updated_at;
      """

    var statement: OpaquePointer?

    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
      print("SQLite prepare save downloaded course error:", String(cString: sqlite3_errmsg(db)))
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
      print("SQLite save downloaded course error:", String(cString: sqlite3_errmsg(db)))
    } else {
      print("SQLite save downloaded course success:", assetId)
    }
  }

  func replaceCourseFiles(assetId: String, files: [CourseFileRecord]) {
    deleteCourseFiles(assetId: assetId)

    let sql = """
      INSERT INTO course_files (
        asset_id, relative_path, absolute_path, mime_type, size_bytes, created_at, updated_at
      )
      VALUES (?, ?, ?, ?, ?, ?, ?);
      """

    var statement: OpaquePointer?

    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
      print("SQLite prepare replace course files error:", String(cString: sqlite3_errmsg(db)))
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
        print("SQLite insert course file error:", String(cString: sqlite3_errmsg(db)))
      }
    }

    print("SQLite indexed course files:", assetId, files.count)
  }

  func loadDownloadedCourses() -> [DownloadedCourseRecord] {
    let sql = """
      SELECT asset_id, title, scorm_dir_path, manifest_title, sco_count, download_status, created_at, updated_at
      FROM downloaded_courses
      ORDER BY updated_at DESC;
      """

    var statement: OpaquePointer?
    var results: [DownloadedCourseRecord] = []

    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
      print("SQLite prepare load downloaded courses error:", String(cString: sqlite3_errmsg(db)))
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
    let sql = """
      SELECT asset_id, relative_path, absolute_path, mime_type, size_bytes, created_at, updated_at
      FROM course_files
      WHERE asset_id = ?
      ORDER BY relative_path ASC;
      """

    var statement: OpaquePointer?
    var results: [CourseFileRecord] = []

    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
      print("SQLite prepare load course files error:", String(cString: sqlite3_errmsg(db)))
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
    let sql = "DELETE FROM downloaded_courses WHERE asset_id = ?;"
    var statement: OpaquePointer?

    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
      print("SQLite prepare delete downloaded course error:", String(cString: sqlite3_errmsg(db)))
      return
    }

    defer { sqlite3_finalize(statement) }

    sqlite3_bind_text(statement, 1, (assetId as NSString).utf8String, -1, nil)

    if sqlite3_step(statement) != SQLITE_DONE {
      print("SQLite delete downloaded course error:", String(cString: sqlite3_errmsg(db)))
    }
  }

  func deleteCourseFiles(assetId: String) {
    let sql = "DELETE FROM course_files WHERE asset_id = ?;"
    var statement: OpaquePointer?

    guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
      print("SQLite prepare delete course files error:", String(cString: sqlite3_errmsg(db)))
      return
    }

    defer { sqlite3_finalize(statement) }

    sqlite3_bind_text(statement, 1, (assetId as NSString).utf8String, -1, nil)

    if sqlite3_step(statement) != SQLITE_DONE {
      print("SQLite delete course files error:", String(cString: sqlite3_errmsg(db)))
    }
  }

  func clearAll() {
    print("SQLite clear all")

    let sqlStatements = [
      "DELETE FROM sco_progress;",
      "DELETE FROM downloaded_courses;",
      "DELETE FROM course_files;",
    ]

    for sql in sqlStatements {
      if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
        print("SQLite clear error:", String(cString: sqlite3_errmsg(db)))
      }
    }
  }
}
