import Cocoa
import FlutterMacOS

class AppleScriptBridge {
  static func getCurrentlyPlaying() -> [String: Any]? {
    // Try Spotify first via direct AppleScript (fast path).
    let spotifyScript = """
      tell application "Spotify"
        if it is running then
          if player state is playing then
            set trackName to name of current track
            set artistName to artist of current track
            set podcastName to album of current track
            set position to player position
            return {trackName, artistName, podcastName, position}
          end if
        end if
      end tell
    """

    var error: NSDictionary?
    if let script = NSAppleScript(source: spotifyScript) {
      let result = script.executeAndReturnError(&error)
      if error == nil && result.numberOfItems >= 4 {
        let t = result.atIndex(1)?.stringValue ?? ""
        if !t.isEmpty {
          return [
            "title": t,
            "artist": result.atIndex(2)?.stringValue ?? "",
            "podcast": result.atIndex(3)?.stringValue ?? "",
            "position": Int(result.atIndex(4)?.int32Value ?? 0),
            "source": "spotify",
            "isPlaying": true,
          ]
        }
      }
    }

    // Use MRNowPlayingRequest (ObjC class) via JXA osascript for system-wide Now Playing.
    // This works for ALL media apps including Podcasts, Music, Spotify, etc.
    do {
      let jxaScript = """
        ObjC.import('Foundation');
        var mr = $.NSBundle.bundleWithPath('/System/Library/PrivateFrameworks/MediaRemote.framework/');
        mr.load;
        var MR = $.NSClassFromString('MRNowPlayingRequest');
        var appName = '';
        try { appName = MR.localNowPlayingPlayerPath.client.displayName.js; } catch(e) {}
        var info = MR.localNowPlayingItem.nowPlayingInfo;
        var title = '', album = '', artist = '', elapsed = 0, rate = 0;
        try { title = info.valueForKey('kMRMediaRemoteNowPlayingInfoTitle').js; } catch(e) {}
        try { album = info.valueForKey('kMRMediaRemoteNowPlayingInfoAlbum').js; } catch(e) {}
        try { artist = info.valueForKey('kMRMediaRemoteNowPlayingInfoArtist').js; } catch(e) {}
        try { elapsed = info.valueForKey('kMRMediaRemoteNowPlayingInfoElapsedTime').js; } catch(e) {}
        try { rate = info.valueForKey('kMRMediaRemoteNowPlayingInfoPlaybackRate').js; } catch(e) {}
        var pos = 0;
        try { pos = MR.localNowPlayingItem.metadata.calculatedPlaybackPosition; } catch(e) { pos = elapsed; }
        JSON.stringify({title:title, album:album, artist:artist, position:pos, rate:rate, app:appName});
        """
      let proc = Process()
      proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
      proc.arguments = ["-l", "JavaScript", "-e", jxaScript]
      let pipe = Pipe()
      proc.standardOutput = pipe
      proc.standardError = Pipe()
      try proc.run()
      proc.waitUntilExit()
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      if proc.terminationStatus == 0, !output.isEmpty,
         let jsonData = output.data(using: .utf8),
         let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
        let t = json["title"] as? String ?? ""
        let rate = json["rate"] as? Double ?? 0
        if !t.isEmpty && rate > 0 {
          let app = (json["app"] as? String ?? "").lowercased()
          let source: String
          if app.contains("spotify") {
            source = "spotify"
          } else if app.contains("podcast") {
            source = "apple_podcasts"
          } else {
            source = "apple_music"
          }
          return [
            "title": t,
            "artist": json["artist"] as? String ?? "",
            "podcast": json["album"] as? String ?? "",
            "position": Int(json["position"] as? Double ?? 0),
            "source": source,
            "isPlaying": true,
          ]
        }
      }
    } catch {}

    // Try Apple Music via direct AppleScript as final fallback.
    let musicScript = """
      tell application "Music"
        if it is running then
          if player state is playing then
            set trackName to name of current track
            set artistName to artist of current track
            set podcastName to album of current track
            set position to player position
            return {trackName, artistName, podcastName, position}
          end if
        end if
      end tell
    """

    if let script = NSAppleScript(source: musicScript) {
      error = nil
      let result = script.executeAndReturnError(&error)
      if error == nil && result.numberOfItems >= 4 {
        let t = result.atIndex(1)?.stringValue ?? ""
        let p = result.atIndex(3)?.stringValue ?? ""
        let finalTitle = t.isEmpty ? p : t
        if !finalTitle.isEmpty {
          return [
            "title": finalTitle,
            "artist": result.atIndex(2)?.stringValue ?? "",
            "podcast": p,
            "position": Int(result.atIndex(4)?.int32Value ?? 0),
            "source": "apple_music",
            "isPlaying": true,
          ]
        }
      }
    }

    return nil
  }
}
