import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

/// Encapsulates audio recording and playback functionality.
class AudioService {
  AudioRecorder recorder = AudioRecorder();
  final AudioPlayer player = AudioPlayer();

  StreamSubscription<Amplitude>? _amplitudeSubscription;
  StreamSubscription<void>? _playerCompleteSubscription;
  Timer? _silenceTimer;

  /// Callback when the player finishes playing audio.
  void Function()? onPlayerComplete;

  AudioService() {
    _playerCompleteSubscription = player.onPlayerComplete.listen((_) {
      onPlayerComplete?.call();
    });
  }

  /// Check microphone permission.
  Future<bool> hasPermission() => recorder.hasPermission();

  /// Start recording audio. Returns the file path.
  Future<String> startRecording() async {
    String path = '';
    if (!kIsWeb) {
      final dir = await getTemporaryDirectory();
      path =
          '${dir.path}/mg_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    }
    await recorder.start(const RecordConfig(), path: path);
    return path;
  }

  /// Listen to amplitude changes for silence detection.
  /// [onSpeechDetected] is called when speech is detected.
  /// [onSilenceTimeout] is called after [silenceMs] of silence following speech.
  void listenAmplitude({
    required void Function() onSilenceTimeout,
    int silenceMs = 1800,
    double threshold = -28.0,
  }) {
    bool speechDetected = false;
    _amplitudeSubscription?.cancel();
    _silenceTimer?.cancel();

    _amplitudeSubscription = recorder
        .onAmplitudeChanged(const Duration(milliseconds: 150))
        .listen((amp) {
      if (amp.current > threshold) {
        speechDetected = true;
        _silenceTimer?.cancel();
        _silenceTimer = Timer(Duration(milliseconds: silenceMs), () {
          if (speechDetected) {
            onSilenceTimeout();
          }
        });
      }
    });

    // Auto-timeout if no speech after 8s
    Future.delayed(const Duration(seconds: 8), () {
      if (!speechDetected) onSilenceTimeout();
    });
  }

  /// Stop recording and return the file path.
  Future<String?> stopRecording() async {
    _silenceTimer?.cancel();
    _amplitudeSubscription?.cancel();
    final path = await recorder.stop();
    recorder.dispose();
    recorder = AudioRecorder(); // Recreate to avoid stream reuse errors
    return path;
  }

  /// Play audio from a URL.
  Future<void> playAudio(String url) async {
    await player.stop();
    await player.play(UrlSource(url));
  }

  /// Stop audio playback.
  Future<void> stopAudio() => player.stop();

  /// Clean up resources.
  void dispose() {
    _silenceTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    recorder.dispose();
    player.dispose();
  }
}
