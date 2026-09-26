import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum NavigationAudioMode {
  voiceAndChimes,
  chimesOnly,
  muted,
}

class AudioNavigationService {
  static final AudioNavigationService _instance = AudioNavigationService._internal();
  factory AudioNavigationService() => _instance;

  AudioNavigationService._internal() {
    _initTts();
  }

  AudioPlayer? _audioPlayer;

  AudioPlayer? _getOrCreatePlayer() {
    if (_audioPlayer != null) return _audioPlayer;
    try {
      _audioPlayer = AudioPlayer();
      return _audioPlayer;
    } catch (e) {
      debugPrint('[AudioNavigationService] Could not instantiate AudioPlayer: $e');
      return null;
    }
  }

  FlutterTts? _tts;
  bool _ttsInitialized = false;

  void dispose() {
    try {
      _audioPlayer?.dispose();
    } catch (_) {}
    _audioPlayer = null;
  }

  NavigationAudioMode _mode = NavigationAudioMode.voiceAndChimes;
  NavigationAudioMode get mode => _mode;

  void setMode(NavigationAudioMode mode) {
    _mode = mode;
  }

  void _initTts() {
    _asyncInitTts();
  }

  Future<void> _asyncInitTts() async {
    try {
      final tts = FlutterTts();
      await tts.setLanguage('en-US');
      await tts.setSpeechRate(0.5);
      await tts.setVolume(1.0);
      await tts.setPitch(1.0);
      _tts = tts;
      _ttsInitialized = true;
    } catch (e) {
      debugPrint('[AudioNavigationService] Could not init TTS: $e');
    }
  }

  // Pre-synthesized PCM WAV cache for zero-latency playback
  Uint8List? _cachedApproachChime;
  Uint8List? _cachedImmediateChime;
  Uint8List? _cachedOffRouteChime;
  Uint8List? _cachedArrivalChime;

  Uint8List get approachChime => _cachedApproachChime ??= _generateWav([
        const _Tone(880.0, 100), // A5
        const _Tone(0.0, 30),    // Short pause
        const _Tone(1320.0, 130), // E6 (bright bell harmonic)
      ]);

  Uint8List get immediateChime => _cachedImmediateChime ??= _generateWav([
        const _Tone(1760.0, 65), // A6 high alert
        const _Tone(0.0, 25),    // Crisp gap
        const _Tone(1760.0, 85), // A6 second beep
      ]);

  Uint8List get offRouteChime => _cachedOffRouteChime ??= _generateWav([
        const _Tone(440.0, 160), // A4
        const _Tone(0.0, 35),
        const _Tone(330.0, 220), // E4 (descending caution tone)
      ]);

  Uint8List get arrivalChime => _cachedArrivalChime ??= _generateWav([
        const _Tone(587.3, 100),  // D5
        const _Tone(880.0, 110),  // A5
        const _Tone(1174.6, 260), // D6 (triumphant triad)
      ]);

  Future<void> playApproachAlert({required String spokenText}) async {
    if (_mode == NavigationAudioMode.muted) return;

    try {
      HapticFeedback.mediumImpact();
      await _playBytes(approachChime);

      if (_mode == NavigationAudioMode.voiceAndChimes && spokenText.isNotEmpty) {
        // Allow the chime to complete before speaking
        await Future.delayed(const Duration(milliseconds: 280));
        await _speak(spokenText);
      }
    } catch (e) {
      debugPrint('[AudioNavigationService] Error in approach alert: $e');
    }
  }

  Future<void> playImmediateAlert({required String spokenText}) async {
    if (_mode == NavigationAudioMode.muted) return;

    try {
      HapticFeedback.heavyImpact();
      await _playBytes(immediateChime);

      if (_mode == NavigationAudioMode.voiceAndChimes && spokenText.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 200));
        await _speak(spokenText);
      }
    } catch (e) {
      debugPrint('[AudioNavigationService] Error in immediate alert: $e');
    }
  }

  Future<void> playOffRouteAlert() async {
    if (_mode == NavigationAudioMode.muted) return;

    try {
      HapticFeedback.vibrate();
      await _playBytes(offRouteChime);

      if (_mode == NavigationAudioMode.voiceAndChimes) {
        await Future.delayed(const Duration(milliseconds: 450));
        await _speak('Caution. Off planned route.');
      }
    } catch (e) {
      debugPrint('[AudioNavigationService] Error in off-route alert: $e');
    }
  }

  Future<void> playArrivalAlert() async {
    if (_mode == NavigationAudioMode.muted) return;

    try {
      HapticFeedback.mediumImpact();
      await _playBytes(arrivalChime);

      if (_mode == NavigationAudioMode.voiceAndChimes) {
        await Future.delayed(const Duration(milliseconds: 500));
        await _speak('You have arrived at your destination.');
      }
    } catch (e) {
      debugPrint('[AudioNavigationService] Error in arrival alert: $e');
    }
  }

  Future<void> _playBytes(Uint8List bytes) async {
    try {
      final player = _getOrCreatePlayer();
      if (player == null) return;
      await player.stop();
      await player.play(BytesSource(bytes));
    } catch (e) {
      // In widget test environments, audio channel may not have an active platform host
      debugPrint('[AudioNavigationService] audio player fallback: $e');
    }
  }

  Future<void> _speak(String text) async {
    if (!_ttsInitialized || _tts == null) return;
    try {
      await _tts?.stop();
      await _tts?.speak(text);
    } catch (e) {
      debugPrint('[AudioNavigationService] TTS speak error: $e');
    }
  }

  /// Synthesizes a mono 16-bit 44.1kHz PCM WAV in memory
  static Uint8List _generateWav(List<_Tone> tones, {int sampleRate = 44100, double volume = 0.85}) {
    int totalSamples = 0;
    for (final t in tones) {
      totalSamples += (sampleRate * (t.durationMs / 1000.0)).round();
    }

    final int dataSize = totalSamples * 2; // 16-bit = 2 bytes per sample
    final int fileSize = 36 + dataSize;
    final ByteData header = ByteData(44);

    // RIFF chunk descriptor
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, fileSize, Endian.little);
    header.setUint8(8, 0x57);  // 'W'
    header.setUint8(9, 0x41);  // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'

    // 'fmt ' sub-chunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // Subchunk1Size = 16 for PCM
    header.setUint16(20, 1, Endian.little);  // AudioFormat = 1 (PCM)
    header.setUint16(22, 1, Endian.little);  // NumChannels = 1 (Mono)
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little); // ByteRate = sampleRate * numChannels * 2
    header.setUint16(32, 2, Endian.little);  // BlockAlign = numChannels * 2
    header.setUint16(34, 16, Endian.little); // BitsPerSample = 16

    // 'data' sub-chunk
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, dataSize, Endian.little);

    final Uint8List result = Uint8List(44 + dataSize);
    result.setRange(0, 44, header.buffer.asUint8List());

    final ByteData sampleData = ByteData.view(result.buffer, 44, dataSize);
    int sampleOffset = 0;

    for (final tone in tones) {
      final int toneSampleCount = (sampleRate * (tone.durationMs / 1000.0)).round();
      final double freq = tone.freqHz;
      final int fadeSamples = math.min(150, toneSampleCount ~/ 4);

      for (int i = 0; i < toneSampleCount; i++) {
        double sampleVal = 0.0;
        if (freq > 0.0) {
          final double t = i / sampleRate;
          sampleVal = math.sin(2 * math.pi * freq * t) * volume;

          // Envelope: smooth fade-in and fade-out to prevent pop/click noise
          if (i < fadeSamples) {
            sampleVal *= (i / fadeSamples);
          } else if (i > toneSampleCount - fadeSamples) {
            sampleVal *= ((toneSampleCount - i) / fadeSamples);
          }
        }

        final int pcm16 = (sampleVal * 32767.0).clamp(-32768.0, 32767.0).round();
        sampleData.setInt16(sampleOffset, pcm16, Endian.little);
        sampleOffset += 2;
      }
    }

    return result;
  }
}

class _Tone {
  final double freqHz;
  final int durationMs;
  const _Tone(this.freqHz, this.durationMs);
}
