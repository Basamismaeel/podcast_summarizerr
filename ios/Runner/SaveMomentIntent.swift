import AppIntents
import Foundation
import MediaPlayer

enum SiriAppGroup {
  static let suiteName = "group.com.safetynet.podcast"
  static let pendingKey = "siri_sessions"
}

@available(iOS 16.0, *)
struct SaveMomentIntent: AppIntent {
  static var title: LocalizedStringResource = "Save Podcast Moment"

  static var description = IntentDescription(
    "Saves the current podcast moment for AI summary"
  )

  static var openAppWhenRun: Bool = false

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let info = MPNowPlayingInfoCenter.default().nowPlayingInfo

    let title = (info?[MPMediaItemPropertyTitle] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let artist = (info?[MPMediaItemPropertyArtist] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let positionSeconds = Self.elapsedSeconds(from: info)

    let episodeTitle = (title?.isEmpty == false) ? title! : "Unknown Episode"
    let showName = (artist?.isEmpty == false) ? artist! : "Unknown Podcast"

    guard let ud = UserDefaults(suiteName: SiriAppGroup.suiteName) else {
      return .result(dialog: "Could not open shared storage. Add App Group in Xcode.")
    }

    var pending = ud.array(forKey: SiriAppGroup.pendingKey) as? [[String: Any]] ?? []
    let entry: [String: Any] = [
      "title": episodeTitle,
      "artist": showName,
      "position": positionSeconds,
      "ts": Int(Date().timeIntervalSince1970 * 1000),
    ]
    pending.append(entry)
    ud.set(pending, forKey: SiriAppGroup.pendingKey)
    ud.synchronize()

    let mins = positionSeconds / 60
    let secs = positionSeconds % 60
    let timestamp = String(format: "%d:%02d", mins, secs)

    return .result(dialog: "Saved \(episodeTitle) at \(timestamp)")
  }

  private static func elapsedSeconds(from info: [String: Any]?) -> Int {
    guard let info = info else { return 0 }
    let v = info[MPNowPlayingInfoPropertyElapsedPlaybackTime]
    if let d = v as? Double { return Int(d) }
    if let n = v as? NSNumber { return n.intValue }
    return 0
  }
}

@available(iOS 16.0, *)
struct PodcastSafetyNetShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: SaveMomentIntent(),
      phrases: [
        "Save podcast moment with \(.applicationName)",
        "Save this moment with \(.applicationName)",
        "Remember this podcast with \(.applicationName)",
      ],
      shortTitle: "Save Moment",
      systemImageName: "bookmark.fill"
    )
  }
}
