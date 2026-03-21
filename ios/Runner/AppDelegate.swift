import AVFoundation
// import AppIntents  // Requires paid Apple Developer account for Siri capability
import Flutter
import UIKit
import MediaPlayer
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    application.beginReceivingRemoteControlEvents()
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
      registerNowPlayingNotificationCategory()
    }
    // Siri Shortcuts disabled — requires paid Apple Developer account
    // if #available(iOS 16.0, *) {
    //   Task { await PodcastSafetyNetShortcuts.updateAppShortcutParameters() }
    // }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  @available(iOS 10.0, *)
  private func registerNowPlayingNotificationCategory() {
    let saveAction = UNNotificationAction(
      identifier: "SAVE",
      title: "🔖 Save Moment",
      options: [.foreground]
    )
    let category = UNNotificationCategory(
      identifier: "PSN_NOW_PLAYING",
      actions: [saveAction],
      intentIdentifiers: [],
      options: []
    )
    UNUserNotificationCenter.current().setNotificationCategories([category])
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()
    let channel = FlutterMethodChannel(
      name: "com.podcasts.safetynet/nowplaying",
      binaryMessenger: messenger
    )

    channel.setMethodCallHandler { call, result in
      guard call.method == "getNowPlaying" else {
        result(FlutterMethodNotImplemented)
        return
      }

      let authStatus = MPMediaLibrary.authorizationStatus()
      if authStatus == .notDetermined {
        MPMediaLibrary.requestAuthorization { status in
          DispatchQueue.main.async {
            Self.fetchNowPlaying(authStatus: status, flutterResult: result)
          }
        }
      } else {
        Self.fetchNowPlaying(authStatus: authStatus, flutterResult: result)
      }
    }

    let siriChannel = FlutterMethodChannel(
      name: "com.podcasts.safetynet/siri",
      binaryMessenger: messenger
    )
    siriChannel.setMethodCallHandler { call, result in
      guard call.method == "getPendingSessions" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let ud = UserDefaults(suiteName: "group.com.safetynet.podcast") else {
        result([])
        return
      }
      let pending = ud.array(forKey: "siri_sessions") as? [[String: Any]] ?? []
      ud.set([], forKey: "siri_sessions")
      ud.synchronize()
      result(pending)
    }
  }

  private static func fetchNowPlaying(authStatus: MPMediaLibraryAuthorizationStatus, flutterResult result: @escaping FlutterResult) {
    do {
      try AVAudioSession.sharedInstance().setCategory(
        .playback,
        mode: .default,
        options: .mixWithOthers
      )
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {}

    let musicPlayer = MPMusicPlayerController.systemMusicPlayer
    let npRaw = MPNowPlayingInfoCenter.default().nowPlayingInfo

    if let item = musicPlayer.nowPlayingItem {
      result([
        "title": item.title ?? "",
        "artist": item.artist ?? "",
        "position": Int(musicPlayer.currentPlaybackTime),
        "isPlaying": musicPlayer.playbackState == .playing,
      ] as [String: Any])
      return
    }

    guard let info = npRaw else {
      result(nil as Any?)
      return
    }

    let rate = mpDouble(info, key: MPNowPlayingInfoPropertyPlaybackRate)
    let elapsed = mpDouble(info, key: MPNowPlayingInfoPropertyElapsedPlaybackTime)
    let title = mpString(info, key: MPMediaItemPropertyTitle)
    let artist = mpString(info, key: MPMediaItemPropertyArtist)
    let albumTitle = mpString(info, key: MPMediaItemPropertyAlbumTitle)
    let podcastTitle = mpString(info, key: MPMediaItemPropertyPodcastTitle)

    let bestTitle: String = {
      if !title.isEmpty { return title }
      if !podcastTitle.isEmpty { return podcastTitle }
      if !albumTitle.isEmpty { return albumTitle }
      return ""
    }()

    let bestArtist: String = {
      if !artist.isEmpty { return artist }
      if !albumTitle.isEmpty && albumTitle != bestTitle { return albumTitle }
      return ""
    }()

    if bestTitle.isEmpty && bestArtist.isEmpty {
      result(nil as Any?)
      return
    }

    let displayTitle = bestTitle.isEmpty ? bestArtist : bestTitle
    let displayArtist = bestTitle.isEmpty ? "" : bestArtist
    let isPlaying = rate > 0 || musicPlayer.playbackState == .playing

    result([
      "title": displayTitle,
      "artist": displayArtist,
      "position": Int(elapsed),
      "isPlaying": isPlaying,
      "podcastTitle": podcastTitle,
      "albumTitle": albumTitle,
    ] as [String: Any])
  }

  /// MPNowPlayingInfoCenter values are often NSNumber; plain `as? Double` fails.
  private static func mpDouble(_ info: [String: Any], key: String) -> Double {
    guard let v = info[key] else { return 0 }
    if let d = v as? Double { return d }
    if let f = v as? Float { return Double(f) }
    if let n = v as? NSNumber { return n.doubleValue }
    return 0
  }

  private static func mpString(_ info: [String: Any], key: String) -> String {
    guard let v = info[key] else { return "" }
    if let s = v as? String { return s }
    if let n = v as? NSNumber { return n.stringValue }
    return ""
  }
}
