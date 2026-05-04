import UIKit
import AVKit
import AVFoundation

final class OfflineVideoPlayerViewController: AVPlayerViewController {
  private let assetId: String
  private let fileURL: URL
  private var timeObserverToken: Any?
  private var pendingResumeTimeSeconds: Double?
  private var hasPresentedResumePrompt = false

  init(assetId: String, fileURL: URL, title: String?) {
    self.assetId = assetId
    self.fileURL = fileURL
    super.init(nibName: nil, bundle: nil)
    self.title = title ?? fileURL.lastPathComponent
    self.player = AVPlayer(url: fileURL)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    navigationItem.leftBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .close,
      target: self,
      action: #selector(closeTapped)
    )

    prepareResumeProgressIfNeeded()
    startObservingPlaybackTime()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    guard !hasPresentedResumePrompt else {
      player?.play()
      return
    }

    if let resumeTime = pendingResumeTimeSeconds {
      hasPresentedResumePrompt = true
      presentResumePrompt(resumeTimeSeconds: resumeTime)
    } else {
      player?.play()
    }
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    persistCurrentPlaybackTime()
  }

  deinit {
    if let token = timeObserverToken {
      player?.removeTimeObserver(token)
    }
  }

  private func prepareResumeProgressIfNeeded() {
    let relativePath = relativePathForProgress()

    guard
      let progress = ScormProgressStore.shared.loadVideoProgress(
        assetId: assetId,
        relativePath: relativePath
      ),
      progress.lastPlaybackTimeSeconds > 5
    else {
      return
    }

    pendingResumeTimeSeconds = progress.lastPlaybackTimeSeconds
  }

  private func presentResumePrompt(resumeTimeSeconds: Double) {
    let alert = UIAlertController(
      title: L10n.tr("offline_video.resume.title"),
      message: String(
        format: L10n.tr("offline_video.resume.message"),
        formattedPlaybackTime(resumeTimeSeconds)
      ),
      preferredStyle: .alert
    )

    alert.addAction(
      UIAlertAction(title: L10n.tr("offline_video.resume.action"), style: .default) { [weak self] _ in
        guard let self = self else { return }
        let time = CMTime(seconds: resumeTimeSeconds, preferredTimescale: 600)
        self.player?.seek(to: time) { _ in
          self.player?.play()
        }
      }
    )

    alert.addAction(
      UIAlertAction(title: L10n.tr("offline_video.start_over.action"), style: .cancel) { [weak self] _ in
        self?.clearSavedProgress()
        self?.player?.seek(to: .zero)
        self?.player?.play()
      }
    )

    present(alert, animated: true)
  }

  private func startObservingPlaybackTime() {
    let interval = CMTime(seconds: 5, preferredTimescale: 600)

    timeObserverToken = player?.addPeriodicTimeObserver(
      forInterval: interval,
      queue: .main
    ) { [weak self] _ in
      self?.persistCurrentPlaybackTime()
    }
  }

  private func persistCurrentPlaybackTime() {
    guard let player else { return }

    let seconds = player.currentTime().seconds
    guard seconds.isFinite, seconds >= 0 else { return }

    let duration = player.currentItem?.duration.seconds
    let safeDuration = (duration?.isFinite == true && duration! > 0) ? duration : nil

    var playbackTimeToSave = seconds
    if let safeDuration, safeDuration > 0, seconds / safeDuration >= 0.95 {
      playbackTimeToSave = 0
    }

    ScormProgressStore.shared.saveVideoProgress(
      assetId: assetId,
      relativePath: relativePathForProgress(),
      lastPlaybackTimeSeconds: playbackTimeToSave,
      durationSeconds: safeDuration
    )
  }

  private func clearSavedProgress() {
    ScormProgressStore.shared.deleteVideoProgress(
      assetId: assetId,
      relativePath: relativePathForProgress()
    )
  }

  private func relativePathForProgress() -> String {
    let baseURL = ScormUtils.assetBaseURL(assetId: assetId)
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

  private func formattedPlaybackTime(_ seconds: Double) -> String {
    let totalSeconds = Int(seconds.rounded())
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let remainingSeconds = totalSeconds % 60

    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
    } else {
      return String(format: "%d:%02d", minutes, remainingSeconds)
    }
  }

  @objc private func closeTapped() {
    persistCurrentPlaybackTime()
    dismiss(animated: true)
  }
}
