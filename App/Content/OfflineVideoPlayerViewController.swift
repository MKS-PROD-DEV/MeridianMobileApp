/*
  Offline Video Player.
  - Plays Videos from APP Directory
*/
import UIKit
import AVKit
import AVFoundation

final class OfflineVideoPlayerViewController: AVPlayerViewController {
  init(fileURL: URL, title: String?) {
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
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    player?.play()
  }

  @objc private func closeTapped() {
    dismiss(animated: true)
  }
}
