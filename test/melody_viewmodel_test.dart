import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:magic_song/models/vocal_preset.dart';
import 'package:magic_song/viewmodels/melody_viewmodel.dart';

class MockAudioRecorder extends Mock implements AudioRecorder {}

class MockAudioPlayer extends Mock implements AudioPlayer {}

void main() {
  group('MelodyViewModel State Logic', () {
    late MelodyViewModel provider;
    late MockAudioRecorder mockRecorder;
    late MockAudioPlayer mockPlayer;

    setUp(() {
      mockRecorder = MockAudioRecorder();
      mockPlayer = MockAudioPlayer();
      when(
        () => mockPlayer.playerStateStream,
      ).thenAnswer((_) => const Stream.empty());

      provider = MelodyViewModel(
        recorder: mockRecorder,
        audioPlayer: mockPlayer,
        loadSavedVoicesOnInit: false,
      );
    });

    test('initial state is correct', () {
      expect(provider.recordingState, RecordingState.idle);
      expect(provider.selectedPreset, VocalPreset.warmMelody);
      expect(provider.isPlaying, false);
      expect(provider.isManualMode, false);
      expect(provider.rawRecordingPath, null);
      expect(provider.processedRecordingPath, null);
    });

    test('setPreset updates preset and UI state', () {
      provider.setPreset(VocalPreset.lofi);

      expect(provider.selectedPreset, VocalPreset.lofi);
      expect(provider.eqBass, -3.0);
      expect(provider.eqMid, 5.0);
      expect(provider.eqTreble, -3.0);
      expect(provider.reverb, 0.0);
    });

    test('setIsManualMode resets sliders when true', () {
      // Setup some values
      provider.setPreset(VocalPreset.cathedral);
      expect(provider.reverb, 0.85);

      provider.setIsManualMode(true);
      expect(provider.isManualMode, true);
      expect(provider.eqBass, 0.0);
      expect(provider.eqMid, 0.0);
      expect(provider.eqTreble, 0.0);
      expect(provider.reverb, 0.0);
    });

    test('setIsManualMode restores preset when false', () {
      provider.setPreset(VocalPreset.brightLead);
      provider.setIsManualMode(true);

      // We are in manual mode now. Toggling off should restore the selected preset (brightLead).
      provider.setIsManualMode(false);
      expect(provider.isManualMode, false);
      expect(provider.eqBass, -2.0);
      expect(provider.eqMid, 3.6);
      expect(provider.eqTreble, 2.4);
      expect(provider.reverb, 0.1);
    });

    test('slider updates modify corresponding variables', () {
      provider.setEqBass(2.5);
      expect(provider.eqBass, 2.5);

      provider.setEqMid(-1.5);
      expect(provider.eqMid, -1.5);

      provider.setEqTreble(3.0);
      expect(provider.eqTreble, 3.0);

      provider.setReverb(0.9);
      expect(provider.reverb, 0.9);
    });
  });
}
