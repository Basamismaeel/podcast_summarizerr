import 'dart:async';
import 'dart:ui';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import 'now_playing_service.dart';

const _uuid = Uuid();

const _bannerNotifId = 1001;
const _feedbackNotifId = 1002;

const _channelId = 'psn_now_playing';
const _channelName = 'Now Playing Tracker';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  AppDatabase? _db;

  void attachDatabase(AppDatabase db) => _db = db;

  // ── A) Initialize ──────────────────────────────────────────────────────

  Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      ),
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Persistent now playing quick-save banner',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      );
      await androidImpl.createNotificationChannel(channel);
    }
  }

  // ── B) Request Permission ──────────────────────────────────────────────
  /// If already granted → true. If permanently denied → false (no prompt).
  /// Otherwise requests once and returns the result.

  Future<bool> requestPermission() async {
    if (kIsWeb) return true;

    final status = await Permission.notification.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) return false;

    final next = await Permission.notification.request();
    return next.isGranted;
  }

  // ── C) Show Now-Playing Banner ─────────────────────────────────────────

  Future<void> showNowPlayingBanner(String title, String artist) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Persistent now playing quick-save banner',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      enableVibration: false,
      playSound: false,
      color: Color(0xFF6366F1),
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction('SAVE', '🔖 Save Moment'),
      ],
    );

    final iosDetails = DarwinNotificationDetails(
      categoryIdentifier: 'PSN_NOW_PLAYING',
      presentAlert: true,
      presentSound: false,
    );

    await _plugin.show(
      _bannerNotifId,
      defaultTargetPlatform == TargetPlatform.iOS ? '🎙 $title' : title,
      defaultTargetPlatform == TargetPlatform.iOS
          ? 'Tap to save this moment'
          : artist,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: 'SAVE_MOMENT',
    );
  }

  // ── D) Handle Notification Tap ─────────────────────────────────────────

  void _handleNotificationTap(NotificationResponse response) {
    if (response.actionId == 'SAVE' || response.payload == 'SAVE_MOMENT') {
      unawaited(_saveCurrentMoment());
      return;
    }

    final payload = response.payload ?? '';
    if (payload.startsWith('OPEN_FALLBACK:')) {
      debugPrint('[NotificationService] Fallback tap — open manual entry');
    }
  }

  // ── E) Save Current Moment ─────────────────────────────────────────────

  Future<void> _saveCurrentMoment() async {
    final info = await NowPlayingService.instance.getCurrentNowPlaying();

    if (info == null) {
      await _showFeedback(
        title: 'Nothing playing',
        body: 'Open a podcast app first',
      );
      return;
    }

    if (info.positionSeconds == null) {
      await _showFeedback(
        title: 'Tap to set timestamp manually',
        body: 'Timestamp unavailable — open app to set it',
        payload: 'OPEN_FALLBACK:${info.title}:${info.artist}',
      );
      return;
    }

    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    if (_db != null) {
      await _db!.into(_db!.listeningSessions).insert(
            ListeningSessionsCompanion.insert(
              id: id,
              title: info.title,
              artist: info.artist,
              sourceApp: Value(info.sourceApp),
              saveMethod: 'notification',
              startTimeSec: info.positionSeconds!,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }

    final ts = _formatTimestamp(info.positionSeconds!);
    await _showFeedback(
      title: '🔖 Saved',
      body: '${info.title} · $ts',
    );
  }

  Future<void> _showFeedback({
    required String title,
    required String body,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Persistent now playing quick-save banner',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      autoCancel: true,
      timeoutAfter: 3000,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );

    await _plugin.show(
      _feedbackNotifId,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  // ── F) Dismiss Banner ──────────────────────────────────────────────────

  Future<void> dismissBanner() async {
    await _plugin.cancel(_bannerNotifId);
  }

  // ── G) Update Banner ──────────────────────────────────────────────────

  Future<void> updateBanner(String title, String artist) async {
    await showNowPlayingBanner(title, artist);
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  static String _formatTimestamp(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
