import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _notificationPlayer = AudioPlayer();
  final AudioPlayer _effectPlayer = AudioPlayer();

  bool _isNotificationLoopPlaying = false;
  bool _isInitialized = false;
  bool _userInteracted = false; // Track if user has interacted (for web autoplay)

  /// Initialize the audio service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Set up notification player for looping
      await _notificationPlayer.setReleaseMode(ReleaseMode.loop);
      await _notificationPlayer.setVolume(1.0);

      // Set up effect player for one-time sounds
      await _effectPlayer.setReleaseMode(ReleaseMode.stop);
      await _effectPlayer.setVolume(1.0);

      // Listen for player state changes to detect actual playback
      _notificationPlayer.onPlayerStateChanged.listen((state) {
        debugPrint('🎵 Notification player state: $state');
        if (state == PlayerState.playing) {
          _isNotificationLoopPlaying = true;
        } else if (state == PlayerState.stopped ||
            state == PlayerState.completed ||
            state == PlayerState.disposed) {
          _isNotificationLoopPlaying = false;
        }
      });

      _isInitialized = true;
      debugPrint('✅ Audio service initialized successfully (web: $kIsWeb)');
    } catch (e) {
      debugPrint('❌ Error initializing audio service: $e');
    }
  }

  /// Mark that user has interacted with the page (needed for web autoplay)
  void markUserInteracted() {
    if (!_userInteracted) {
      _userInteracted = true;
      debugPrint('✅ User interaction detected - audio playback enabled');
    }
  }

  /// Check if audio playback is available
  bool get isAudioAvailable => _isInitialized && (!kIsWeb || _userInteracted);

  /// Play notification sound in loop (for pending web orders)
  Future<void> playNotificationLoop() async {
    if (!_isInitialized) {
      debugPrint('⚠️ Audio service not initialized, attempting to initialize...');
      await initialize();
      if (!_isInitialized) return;
    }

    // On web, check if user has interacted
    if (kIsWeb && !_userInteracted) {
      debugPrint(
        '⚠️ Cannot play audio on web without user interaction. '
        'User must click/tap the page first.',
      );
      return;
    }

    if (_isNotificationLoopPlaying) {
      debugPrint('🔊 Notification loop already playing');
      return;
    }

    try {
      debugPrint('🔊 Attempting to play notification loop...');

      // Set source and play
      await _notificationPlayer.setSource(
        AssetSource('sounds/notification_new_order.mp3'),
      );
      await _notificationPlayer.setReleaseMode(ReleaseMode.loop);
      await _notificationPlayer.resume();

      _isNotificationLoopPlaying = true;
      debugPrint('🔊 Started notification loop successfully');
    } catch (e) {
      debugPrint('❌ Error playing notification loop: $e');
      _isNotificationLoopPlaying = false;
    }
  }

  /// Stop notification sound loop
  Future<void> stopNotificationLoop() async {
    if (!_isNotificationLoopPlaying) {
      debugPrint('🔇 Notification loop not playing, nothing to stop');
      return;
    }

    try {
      await _notificationPlayer.stop();
      _isNotificationLoopPlaying = false;
      debugPrint('🔇 Stopped notification loop');
    } catch (e) {
      debugPrint('❌ Error stopping notification loop: $e');
    }
  }

  /// Check if notification loop is playing
  bool get isNotificationLoopPlaying => _isNotificationLoopPlaying;

  /// Check if user has interacted (for web)
  bool get hasUserInteracted => _userInteracted;

  // =================== Sound Effects ===================

  /// Play add to cart sound
  Future<void> playAddToCart() async {
    await _playSoundEffect('sounds/add_to_cart.mp3');
  }

  /// Play add to cart failed sound
  Future<void> playAddToCartFailed() async {
    await _playSoundEffect('sounds/add_to_cart_failed.mp3');
  }

  /// Play add to desk sound
  Future<void> playAddToDesk() async {
    await _playSoundEffect('sounds/add_to_desk.mp3');
  }

  /// Play remove cart item sound
  Future<void> playRemoveCartItem() async {
    await _playSoundEffect('sounds/remove_cart_item.mp3');
  }

  /// Play remove desk item sound
  Future<void> playRemoveDeskItem() async {
    await _playSoundEffect('sounds/remove_desk_item.mp3');
  }

  /// Play clear cart sound
  Future<void> playClearCart() async {
    await _playSoundEffect('sounds/clear_cart.mp3');
  }

  /// Play clear desk sound
  Future<void> playClearDesk() async {
    await _playSoundEffect('sounds/clear_desk.mp3');
  }

  /// Play checkout done sound
  Future<void> playCheckoutDone() async {
    await _playSoundEffect('sounds/checkout_done.mp3');
  }

  // =================== Private Methods ===================

  /// Play a sound effect (one-time, not looped)
  Future<void> _playSoundEffect(String soundPath) async {
    if (!_isInitialized) {
      debugPrint('⚠️ Audio service not initialized');
      return;
    }

    try {
      await _effectPlayer.play(AssetSource(soundPath));
      debugPrint('🔊 Played sound effect: $soundPath');
    } catch (e) {
      debugPrint('❌ Error playing sound effect $soundPath: $e');
    }
  }

  /// Dispose of audio players
  Future<void> dispose() async {
    await _notificationPlayer.dispose();
    await _effectPlayer.dispose();
    _isInitialized = false;
    debugPrint('🔇 Audio service disposed');
  }
}
