/*
  Script Repo.
  - SQL Queries
*/
import Foundation

enum ScormProgressStoreSQL {
  static let createScoProgressTable = """
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

  static let createDownloadedCoursesTable = """
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

  static let createCourseFilesTable = """
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

  static let loadCMI = """
    SELECT cmi_json
    FROM sco_progress
    WHERE asset_id = ? AND sco_id = ?
    LIMIT 1;
    """

  static let saveCMI = """
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

  static let markCMISynced = """
    UPDATE sco_progress
    SET sync_status = 'synced',
      last_synced_at = ?,
      sync_error = NULL
    WHERE asset_id = ? AND sco_id = ?;
    """

  static let markCMISyncFailed = """
    UPDATE sco_progress
    SET sync_status = 'failed',
      sync_error = ?
    WHERE asset_id = ? AND sco_id = ?;
    """

  static let saveDownloadedCourse = """
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

  static let replaceCourseFile = """
    INSERT INTO course_files (
      asset_id, relative_path, absolute_path, mime_type, size_bytes, created_at, updated_at
    )
    VALUES (?, ?, ?, ?, ?, ?, ?);
    """

  static let loadDownloadedCourses = """
    SELECT asset_id, title, scorm_dir_path, manifest_title, sco_count, download_status, created_at, updated_at
    FROM downloaded_courses
    ORDER BY updated_at DESC;
    """

  static let loadCourseFiles = """
    SELECT asset_id, relative_path, absolute_path, mime_type, size_bytes, created_at, updated_at
    FROM course_files
    WHERE asset_id = ?
    ORDER BY relative_path ASC;
    """

  static let loadCourseProgressRows = """
    SELECT cmi_json
    FROM sco_progress
    WHERE asset_id = ?;
    """

  static let loadLastAccessedAt = """
    SELECT MAX(updated_at)
    FROM sco_progress
    WHERE asset_id = ?;
    """
  static let deleteDownloadedCourse = "DELETE FROM downloaded_courses WHERE asset_id = ?;"
  static let deleteCourseFiles = "DELETE FROM course_files WHERE asset_id = ?;"
  static let deleteCourseProgress = "DELETE FROM sco_progress WHERE asset_id = ?;"

  static func alterTableAddColumn(table: String, column: String, definition: String) -> String {
    "ALTER TABLE \(table) ADD COLUMN \(column) \(definition);"
  }

  static func pragmaTableInfo(table: String) -> String {
    "PRAGMA table_info(\(table));"
  }

  static let clearAllStatements = [
    "DELETE FROM sco_progress;",
    "DELETE FROM downloaded_courses;",
    "DELETE FROM course_files;"
  ]
}
