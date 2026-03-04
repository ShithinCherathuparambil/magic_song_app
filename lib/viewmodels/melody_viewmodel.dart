import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart';

import '../models/saved_voice.dart';
import '../models/studio_project.dart';
import '../models/vocal_preset.dart';

enum RecordingState { idle, recording, paused, processing }

enum PlaybackSource { processed, dry }

enum ExportFormat { m4a, mp3, wav }

enum ExportQuality { low, medium, high }

class ProcessedVersion {
  final String path;
  final String label;
  final DateTime createdAt;

  const ProcessedVersion({
    required this.path,
    required this.label,
    required this.createdAt,
  });
}

class _StudioSettingsSnapshot {
  final VocalPreset selectedPreset;
  final bool isManualMode;
  final double eqBass;
  final double eqMid;
  final double eqTreble;
  final double reverb;
  final double trimStartSec;
  final double trimEndSec;
  final double fadeInSec;
  final double fadeOutSec;
  final double noiseReduction;
  final double noiseGateDb;
  final double pitchSemitones;
  final String? targetKey;

  const _StudioSettingsSnapshot({
    required this.selectedPreset,
    required this.isManualMode,
    required this.eqBass,
    required this.eqMid,
    required this.eqTreble,
    required this.reverb,
    required this.trimStartSec,
    required this.trimEndSec,
    required this.fadeInSec,
    required this.fadeOutSec,
    required this.noiseReduction,
    required this.noiseGateDb,
    required this.pitchSemitones,
    required this.targetKey,
  });
}

class MelodyViewModel extends ChangeNotifier {
  static const int _maxProcessedVersions = 12;

  final AudioRecorder audioRecorder;
  final AudioPlayer player;

  // ... state vars

  RecordingState _recordingState = RecordingState.idle;
  RecordingState get recordingState => _recordingState;

  VocalPreset _selectedPreset = VocalPreset.warmMelody;
  VocalPreset get selectedPreset => _selectedPreset;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;
  bool _isPlaybackPaused = false;
  bool get isPlaybackPaused => _isPlaybackPaused;

  String? _rawRecordingPath;
  String? get rawRecordingPath => _rawRecordingPath;

  String? _processedRecordingPath;
  String? get processedRecordingPath => _processedRecordingPath;
  String? _activeProcessedPath;
  String? get activeProcessedPath => _activeProcessedPath;
  String? _lastProcessedProfileSignature;
  bool _hasUnappliedAudioChanges = false;
  final List<ProcessedVersion> _processedVersions = [];
  List<ProcessedVersion> get processedVersions =>
      List.unmodifiable(_processedVersions);
  final List<SavedVoice> _savedVoices = [];
  List<SavedVoice> get savedVoices => List.unmodifiable(_savedVoices);
  PlaybackSource _playbackSource = PlaybackSource.processed;
  PlaybackSource get playbackSource => _playbackSource;
  String? _currentPlaybackPath;
  String? get currentPlaybackPath => _currentPlaybackPath;
  bool get hasRawRecording => _rawRecordingPath != null;
  bool get hasProcessedRecording =>
      _activeProcessedPath != null || _processedRecordingPath != null;
  bool get canApplyEffect =>
      hasRawRecording && _recordingState == RecordingState.idle && !_isPlaying;
  bool get canPlaySelectedSource =>
      _recordingState == RecordingState.idle &&
      (_isPlaying ||
          (_playbackSource == PlaybackSource.dry
              ? hasRawRecording
              : hasProcessedRecording));
  bool get hasSavedVoices => _savedVoices.isNotEmpty;

  String _statusText = 'Ready to record your melody vocal.';
  String get statusText => _statusText;
  String get workflowHint {
    if (_recordingState == RecordingState.recording ||
        _recordingState == RecordingState.paused) {
      return 'Step 1/3: Recording in progress.';
    }
    if (_recordingState == RecordingState.paused) {
      return 'Step 1/3: Recording paused. Resume or stop.';
    }
    if (_recordingState == RecordingState.processing) {
      return 'Applying effect...';
    }
    if (!hasRawRecording) {
      return 'Step 1/3: Record your dry voice.';
    }
    if (!hasProcessedRecording || _hasUnappliedAudioChanges) {
      return 'Step 2/3: Tune preset/EQ. Effect auto-applies.';
    }
    return 'Step 3/3: Choose Dry/Processed and tap Play.';
  }

  bool _isManualMode = false;
  bool get isManualMode => _isManualMode;

  double _eqBass = 0.0;
  double get eqBass => _eqBass;

  double _eqMid = 0.0;
  double get eqMid => _eqMid;

  double _eqTreble = 0.0;
  double get eqTreble => _eqTreble;

  double _reverb = 0.0;
  double get reverb => _reverb;

  double _trimStartSec = 0.0;
  double get trimStartSec => _trimStartSec;
  double _trimEndSec = 0.0;
  double get trimEndSec => _trimEndSec;
  double _fadeInSec = 0.0;
  double get fadeInSec => _fadeInSec;
  double _fadeOutSec = 0.0;
  double get fadeOutSec => _fadeOutSec;

  double _noiseReduction = 0.0;
  double get noiseReduction => _noiseReduction;
  double _noiseGateDb = -42.0;
  double get noiseGateDb => _noiseGateDb;

  double _pitchSemitones = 0.0;
  double get pitchSemitones => _pitchSemitones;
  String? _targetKey;
  String? get targetKey => _targetKey;
  String? _detectedKey;
  String? get detectedKey => _detectedKey;

  ExportFormat _exportFormat = ExportFormat.m4a;
  ExportFormat get exportFormat => _exportFormat;
  ExportQuality _exportQuality = ExportQuality.high;
  ExportQuality get exportQuality => _exportQuality;

  final List<_StudioSettingsSnapshot> _undoStack = [];
  final List<_StudioSettingsSnapshot> _redoStack = [];
  bool get canUndoSettings => _undoStack.isNotEmpty;
  bool get canRedoSettings => _redoStack.isNotEmpty;

  final List<StudioProject> _projects = [];
  List<StudioProject> get projects => List.unmodifiable(_projects);
  bool get hasProjects => _projects.isNotEmpty;

  Timer? _amplitudeTimer;
  Timer? _autoApplyTimer;
  Timer? _settingsPersistTimer;
  StreamSubscription<Amplitude>? _recordAmplitudeSubscription;
  StreamSubscription<Duration>? _playbackPositionSubscription;
  bool _autoApplyInProgress = false;
  bool _autoApplyQueued = false;
  final List<double> _amplitudes = [];
  List<double> get amplitudes => _amplitudes;
  final List<double> _capturedWaveform = [];
  double _smoothedAmplitude = 0.0;
  final int _maxAmplitudes = 40;

  MelodyViewModel({
    AudioRecorder? recorder,
    AudioPlayer? audioPlayer,
    bool loadSavedVoicesOnInit = true,
    bool loadStudioSettingsOnInit = true,
  }) : audioRecorder = recorder ?? AudioRecorder(),
       player = audioPlayer ?? AudioPlayer() {
    if (loadSavedVoicesOnInit) {
      unawaited(_loadSavedVoices());
    }
    if (loadStudioSettingsOnInit) {
      unawaited(_loadStudioSettings());
    }
    unawaited(_loadProjects());
    player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _isPlaying = false;
        _isPlaybackPaused = false;
        _currentPlaybackPath = null;
        _statusText = 'Playback completed.';
        _stopPlaybackAnimation();
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _amplitudeTimer?.cancel();
    _autoApplyTimer?.cancel();
    _settingsPersistTimer?.cancel();
    _recordAmplitudeSubscription?.cancel();
    _playbackPositionSubscription?.cancel();
    audioRecorder.dispose();
    player.dispose();
    super.dispose();
  }

  void _addAmplitude(double amp) {
    _amplitudes.add(amp);
    if (_amplitudes.length > _maxAmplitudes) {
      _amplitudes.removeAt(0);
    }
    notifyListeners();
  }

  void _startAmplitudePolling() {
    _amplitudes.clear();
    _capturedWaveform.clear();
    _smoothedAmplitude = 0.0;
    _recordAmplitudeSubscription?.cancel();
    _recordAmplitudeSubscription = audioRecorder
        .onAmplitudeChanged(const Duration(milliseconds: 70))
        .listen((amp) {
          if (_recordingState != RecordingState.recording) {
            return;
          }
          // Use current dB only; amp.max can remain elevated and flatten motion.
          final db = amp.current.clamp(-75.0, 0.0);
          final normalized = (db + 75.0) / 75.0;
          _smoothedAmplitude =
              (_smoothedAmplitude * 0.65) + (normalized * 0.35);
          _capturedWaveform.add(_smoothedAmplitude);
          _addAmplitude(_smoothedAmplitude);
        });
  }

  void _stopAmplitudeTimer({bool clearWave = true}) {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    _recordAmplitudeSubscription?.cancel();
    _recordAmplitudeSubscription = null;
    if (clearWave) {
      _amplitudes.clear();
    }
    notifyListeners();
  }

  void _startPlaybackAnimation() {
    _amplitudes.clear();
    _amplitudeTimer?.cancel();
    _playbackPositionSubscription?.cancel();
    if (_capturedWaveform.isEmpty) {
      _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 90), (
        timer,
      ) {
        final fallback =
            0.22 + (0.28 * (DateTime.now().millisecondsSinceEpoch % 100) / 100);
        _addAmplitude(fallback);
      });
      return;
    }

    _playbackPositionSubscription = player.positionStream.listen((position) {
      if (!_isPlaying || _capturedWaveform.isEmpty) {
        return;
      }
      final duration = player.duration;
      if (duration == null || duration.inMilliseconds <= 0) {
        return;
      }
      final progress = (position.inMilliseconds / duration.inMilliseconds)
          .clamp(0.0, 1.0);
      final endIndex = (progress * _capturedWaveform.length).floor().clamp(
        1,
        _capturedWaveform.length,
      );
      _setAmplitudeWindow(endIndex);
    });
  }

  void _stopPlaybackAnimation() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    _playbackPositionSubscription?.cancel();
    _playbackPositionSubscription = null;
    _amplitudes.clear();
    notifyListeners();
  }

  void _setAmplitudeWindow(int endExclusive) {
    final end = endExclusive.clamp(1, _capturedWaveform.length);
    final start = math.max(0, end - _maxAmplitudes);
    _amplitudes
      ..clear()
      ..addAll(_capturedWaveform.sublist(start, end));
    notifyListeners();
  }

  _StudioSettingsSnapshot _captureSettingsSnapshot() {
    return _StudioSettingsSnapshot(
      selectedPreset: _selectedPreset,
      isManualMode: _isManualMode,
      eqBass: _eqBass,
      eqMid: _eqMid,
      eqTreble: _eqTreble,
      reverb: _reverb,
      trimStartSec: _trimStartSec,
      trimEndSec: _trimEndSec,
      fadeInSec: _fadeInSec,
      fadeOutSec: _fadeOutSec,
      noiseReduction: _noiseReduction,
      noiseGateDb: _noiseGateDb,
      pitchSemitones: _pitchSemitones,
      targetKey: _targetKey,
    );
  }

  void _applySettingsSnapshot(_StudioSettingsSnapshot snap) {
    _selectedPreset = snap.selectedPreset;
    _isManualMode = snap.isManualMode;
    _eqBass = snap.eqBass;
    _eqMid = snap.eqMid;
    _eqTreble = snap.eqTreble;
    _reverb = snap.reverb;
    _trimStartSec = snap.trimStartSec;
    _trimEndSec = snap.trimEndSec;
    _fadeInSec = snap.fadeInSec;
    _fadeOutSec = snap.fadeOutSec;
    _noiseReduction = snap.noiseReduction;
    _noiseGateDb = snap.noiseGateDb;
    _pitchSemitones = snap.pitchSemitones;
    _targetKey = snap.targetKey;
  }

  void _pushUndoSnapshot() {
    _undoStack.add(_captureSettingsSnapshot());
    if (_undoStack.length > 60) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void undoSettings() {
    if (_undoStack.isEmpty) {
      return;
    }
    _redoStack.add(_captureSettingsSnapshot());
    final previous = _undoStack.removeLast();
    _applySettingsSnapshot(previous);
    _markProcessingDirty();
    _scheduleSettingsPersist();
    _statusText = 'Reverted previous studio change.';
    notifyListeners();
  }

  void redoSettings() {
    if (_redoStack.isEmpty) {
      return;
    }
    _undoStack.add(_captureSettingsSnapshot());
    final next = _redoStack.removeLast();
    _applySettingsSnapshot(next);
    _markProcessingDirty();
    _scheduleSettingsPersist();
    _statusText = 'Re-applied studio change.';
    notifyListeners();
  }

  void setPreset(VocalPreset preset) {
    _pushUndoSnapshot();
    _selectedPreset = preset;

    switch (preset) {
      case VocalPreset.clean:
        _eqBass = 0.0;
        _eqMid = 0.0;
        _eqTreble = 0.0;
        _reverb = 0.0;
        break;
      case VocalPreset.warmMelody:
        _eqBass = 2.0;
        _eqMid = 2.8;
        _eqTreble = 1.8;
        _reverb = 0.3;
        break;
      case VocalPreset.brightLead:
        _eqBass = -2.0;
        _eqMid = 3.6;
        _eqTreble = 2.4;
        _reverb = 0.1;
        break;
      case VocalPreset.indieMalayalam:
        _eqBass = -2.5;
        _eqMid = 2.0;
        _eqTreble = 3.0;
        _reverb = 0.4;
        break;
      case VocalPreset.modernIndie:
        _eqBass = -3.0;
        _eqMid = 3.0;
        _eqTreble = 4.0;
        _reverb = 0.3;
        break;
      case VocalPreset.cinematic:
        _eqBass = 2.0;
        _eqMid = 3.0;
        _eqTreble = 5.0;
        _reverb = 0.7;
        break;
      case VocalPreset.airyVocal:
        _eqBass = -2.0;
        _eqMid = 2.0;
        _eqTreble = 4.0;
        _reverb = 0.35;
        break;
      case VocalPreset.podcast:
        _eqBass = 3.0;
        _eqMid = 1.5;
        _eqTreble = 0.0;
        _reverb = 0.0;
        break;
      case VocalPreset.cathedral:
        _eqBass = 1.0;
        _eqMid = -1.0;
        _eqTreble = 2.0;
        _reverb = 0.85;
        break;
      case VocalPreset.lofi:
        _eqBass = -3.0;
        _eqMid = 5.0;
        _eqTreble = -3.0;
        _reverb = 0.0;
        break;
    }

    if (!_isManualMode) {
      _statusText = 'Preset switched to ${_presetName(preset)}.';
    }
    _markProcessingDirty();
    _scheduleSettingsPersist();
    notifyListeners();
  }

  void setIsManualMode(bool val) {
    _pushUndoSnapshot();
    _isManualMode = val;
    if (val) {
      _eqBass = 0.0;
      _eqMid = 0.0;
      _eqTreble = 0.0;
      _reverb = 0.0;
    } else {
      setPreset(_selectedPreset);
    }
    _markProcessingDirty();
    _scheduleSettingsPersist();
    notifyListeners();
  }

  void setEqBass(double val) {
    _pushUndoSnapshot();
    _eqBass = val;
    _markProcessingDirty();
    _scheduleSettingsPersist();
    notifyListeners();
  }

  void setEqMid(double val) {
    _pushUndoSnapshot();
    _eqMid = val;
    _markProcessingDirty();
    _scheduleSettingsPersist();
    notifyListeners();
  }

  void setEqTreble(double val) {
    _pushUndoSnapshot();
    _eqTreble = val;
    _markProcessingDirty();
    _scheduleSettingsPersist();
    notifyListeners();
  }

  void setReverb(double val) {
    _pushUndoSnapshot();
    _reverb = val;
    _markProcessingDirty();
    _scheduleSettingsPersist();
    notifyListeners();
  }

  void setTrimStartSec(double value) {
    _pushUndoSnapshot();
    _trimStartSec = value.clamp(0.0, 30.0);
    if (_trimEndSec > 0 && _trimEndSec <= _trimStartSec) {
      _trimEndSec = (_trimStartSec + 0.5).clamp(0.0, 30.0);
    }
    _markProcessingDirty();
    _scheduleSettingsPersist();
    notifyListeners();
  }

  void setTrimEndSec(double value) {
    _pushUndoSnapshot();
    _trimEndSec = value.clamp(0.0, 30.0);
    if (_trimEndSec > 0 && _trimEndSec <= _trimStartSec) {
      _trimStartSec = (_trimEndSec - 0.5).clamp(0.0, 29.5);
    }
    _markProcessingDirty();
    _scheduleSettingsPersist();
    notifyListeners();
  }

  void setFadeInSec(double value) {
    _pushUndoSnapshot();
    _fadeInSec = value.clamp(0.0, 5.0);
    _markProcessingDirty();
    _scheduleSettingsPersist();
    notifyListeners();
  }

  void setFadeOutSec(double value) {
    _pushUndoSnapshot();
    _fadeOutSec = value.clamp(0.0, 5.0);
    _markProcessingDirty();
    _scheduleSettingsPersist();
    notifyListeners();
  }

  void setNoiseReduction(double value) {
    _pushUndoSnapshot();
    _noiseReduction = value.clamp(0.0, 1.0);
    _markProcessingDirty();
    _scheduleSettingsPersist();
    notifyListeners();
  }

  void setNoiseGateDb(double value) {
    _pushUndoSnapshot();
    _noiseGateDb = value.clamp(-60.0, -20.0);
    _markProcessingDirty();
    _scheduleSettingsPersist();
    notifyListeners();
  }

  void setPitchSemitones(double value) {
    _pushUndoSnapshot();
    _pitchSemitones = value.clamp(-6.0, 6.0);
    _markProcessingDirty();
    _scheduleSettingsPersist();
    notifyListeners();
  }

  void setTargetKey(String? value) {
    _pushUndoSnapshot();
    _targetKey = value;
    _scheduleSettingsPersist();
    notifyListeners();
  }

  void setExportFormat(ExportFormat format) {
    _exportFormat = format;
    _scheduleSettingsPersist();
    notifyListeners();
  }

  void setExportQuality(ExportQuality quality) {
    _exportQuality = quality;
    _scheduleSettingsPersist();
    notifyListeners();
  }

  void setStatus(String message) {
    _statusText = message;
    notifyListeners();
  }

  String _presetName(VocalPreset preset) {
    switch (preset) {
      case VocalPreset.clean:
        return 'Clean';
      case VocalPreset.warmMelody:
        return 'Warm Melody';
      case VocalPreset.brightLead:
        return 'Bright Lead';
      case VocalPreset.indieMalayalam:
        return 'Warm Indie';
      case VocalPreset.modernIndie:
        return 'Modern Indie';
      case VocalPreset.cinematic:
        return 'Cinematic';
      case VocalPreset.airyVocal:
        return 'Airy Vocal';
      case VocalPreset.podcast:
        return 'Podcast';
      case VocalPreset.cathedral:
        return 'Cathedral';
      case VocalPreset.lofi:
        return 'Lo-Fi Telephone';
    }
  }

  Future<void> startRecording() async {
    if (_recordingState == RecordingState.paused) {
      await toggleRecordingPause();
      return;
    }
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      setStatus('Microphone permission is required to record vocals.');
      return;
    }

    final hasPermission = await audioRecorder.hasPermission();
    if (!hasPermission) {
      setStatus('Recording permission was denied by the device.');
      return;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final fileName =
        'voice_${DateTime.now().millisecondsSinceEpoch.toString()}.m4a';
    final outputPath = p.join(appDir.path, fileName);

    await audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 192000,
        sampleRate: 44100,
      ),
      path: outputPath,
    );

    await _cleanupProcessedArtifacts();
    _rawRecordingPath = outputPath;
    _processedRecordingPath = null;
    _activeProcessedPath = null;
    _lastProcessedProfileSignature = null;
    _hasUnappliedAudioChanges = false;
    _processedVersions.clear();
    _recordingState = RecordingState.recording;
    _statusText = 'Recording started. Sing your melody line.';
    _startAmplitudePolling();
    notifyListeners();
  }

  Future<void> toggleRecordingPause() async {
    if (_recordingState == RecordingState.recording) {
      await audioRecorder.pause();
      _recordingState = RecordingState.paused;
      _statusText = 'Recording paused.';
      notifyListeners();
      return;
    }
    if (_recordingState == RecordingState.paused) {
      await audioRecorder.resume();
      _recordingState = RecordingState.recording;
      _statusText = 'Recording resumed.';
      notifyListeners();
    }
  }

  Future<void> stopRecordingAndProcess() async {
    _stopAmplitudeTimer(clearWave: false);

    final recordedPath = await audioRecorder.stop();
    if (recordedPath == null) {
      _recordingState = RecordingState.idle;
      setStatus('Recording failed. Please try again.');
      return;
    }

    _rawRecordingPath = recordedPath;
    await _refreshWaveformFromFile(recordedPath);
    _recordingState = RecordingState.idle;
    _statusText = 'Recording saved. Choose preset/EQ and tap Apply Effect.';
    notifyListeners();
  }

  Future<String?> _applyVocalProcessing(
    String inputPath,
    String outputPath,
  ) async {
    final inputFile = File(inputPath);
    if (!inputFile.existsSync()) {
      return null;
    }

    final filter = _buildDynamicFilter();
    final command =
        '-y -i "$inputPath" -af "$filter" -c:a aac -b:a 192k "$outputPath"';

    final session = await FFmpegKit.execute(command);
    final rc = await session.getReturnCode();
    if (ReturnCode.isSuccess(rc)) {
      return outputPath;
    }

    return null;
  }

  String _buildDynamicFilter() {
    String hpLp = 'highpass=f=80';
    String comp = 'acompressor=threshold=-20dB:ratio=3.0:attack=10:release=150';

    if (!_isManualMode) {
      switch (_selectedPreset) {
        case VocalPreset.clean:
          hpLp = 'highpass=f=90,lowpass=f=15000';
          comp = 'acompressor=threshold=-18dB:ratio=2.2:attack=15:release=160';
          break;
        case VocalPreset.warmMelody:
          hpLp = 'highpass=f=80';
          comp = 'acompressor=threshold=-20dB:ratio=3.2:attack=10:release=180';
          break;
        case VocalPreset.brightLead:
          hpLp = 'highpass=f=100';
          comp = 'acompressor=threshold=-19dB:ratio=3.5:attack=8:release=120';
          break;
        case VocalPreset.indieMalayalam:
          hpLp = 'highpass=f=80';
          comp =
              'acompressor=threshold=-20dB:ratio=3.0:attack=25:release=100:knee=2.8';
          break;
        case VocalPreset.modernIndie:
          hpLp = 'highpass=f=80';
          comp = 'acompressor=threshold=-18dB:ratio=3:attack=20:release=100';
          break;
        case VocalPreset.cinematic:
          hpLp = 'highpass=f=70';
          comp = 'acompressor=threshold=-22dB:ratio=3.5:attack=15:release=150';
          break;
        case VocalPreset.airyVocal:
          hpLp = 'highpass=f=80';
          comp = 'acompressor=threshold=-20dB:ratio=3:attack=20:release=120';
          break;
        case VocalPreset.podcast:
          hpLp = 'highpass=f=80,lowpass=f=12000';
          comp = 'acompressor=threshold=-20dB:ratio=4.0:attack=2:release=50';
          break;
        case VocalPreset.cathedral:
          hpLp = 'highpass=f=100';
          comp = 'acompressor=threshold=-12dB:ratio=2.0:attack=20:release=200';
          break;
        case VocalPreset.lofi:
          hpLp = 'highpass=f=300,lowpass=f=3000';
          comp = 'acompressor=threshold=-30dB:ratio=10.0:attack=1:release=10';
          break;
      }
    }

    final eqParts = <String>[];
    if (_eqBass != 0) {
      eqParts.add('equalizer=f=150:t=q:w=1.0:g=${_eqBass.toStringAsFixed(1)}');
    }
    if (_eqMid != 0) {
      eqParts.add('equalizer=f=2000:t=q:w=1.0:g=${_eqMid.toStringAsFixed(1)}');
    }
    if (_eqTreble != 0) {
      eqParts.add(
        'equalizer=f=8000:t=q:w=1.0:g=${_eqTreble.toStringAsFixed(1)}',
      );
    }
    String eqString = eqParts.isEmpty ? 'anull' : eqParts.join(',');

    String reverbString = 'anull';
    if (_reverb > 0) {
      final delayCalc = 40 + (800 * (_reverb * _reverb));
      final decayCalc = 0.1 + (0.8 * _reverb);
      final outGain = 0.15 + (0.4 * _reverb);
      reverbString =
          'aecho=0.8:${outGain.toStringAsFixed(2)}:${delayCalc.toStringAsFixed(1)}:${decayCalc.toStringAsFixed(2)}';
    }

    final trimParts = <String>[];
    if (_trimStartSec > 0 || _trimEndSec > 0) {
      final args = <String>[];
      if (_trimStartSec > 0) {
        args.add('start=${_trimStartSec.toStringAsFixed(2)}');
      }
      if (_trimEndSec > 0) {
        args.add('end=${_trimEndSec.toStringAsFixed(2)}');
      }
      trimParts
        ..add('atrim=${args.join(':')}')
        ..add('asetpts=N/SR/TB');
    }

    final cleanupParts = <String>[];
    if (_noiseReduction > 0) {
      final nr = (6 + (_noiseReduction * 20)).toStringAsFixed(1);
      cleanupParts.add('afftdn=nr=$nr');
    }
    cleanupParts.add('agate=threshold=${_noiseGateDb.toStringAsFixed(1)}dB');

    final pitchParts = <String>[];
    if (_pitchSemitones.abs() > 0.01) {
      final factor = math.pow(2.0, _pitchSemitones / 12.0).toDouble();
      final atempo = (1 / factor).clamp(0.5, 2.0);
      pitchParts
        ..add('asetrate=44100*${factor.toStringAsFixed(6)}')
        ..add('aresample=44100')
        ..add('atempo=${atempo.toStringAsFixed(6)}');
    }

    final fadeParts = <String>[];
    if (_fadeInSec > 0) {
      fadeParts.add('afade=t=in:st=0:d=${_fadeInSec.toStringAsFixed(2)}');
    }
    if (_fadeOutSec > 0 && _trimEndSec > _trimStartSec) {
      final fadeOutStart = (_trimEndSec - _trimStartSec - _fadeOutSec).clamp(
        0.0,
        999.0,
      );
      fadeParts.add(
        'afade=t=out:st=${fadeOutStart.toStringAsFixed(2)}:d=${_fadeOutSec.toStringAsFixed(2)}',
      );
    }

    return [
      ...trimParts,
      ...cleanupParts,
      hpLp,
      eqString,
      comp,
      reverbString,
      ...pitchParts,
      ...fadeParts,
      'alimiter=limit=0.95',
    ].join(',');
  }

  Future<void> stopPlayback() async {
    await player.stop();
    _isPlaying = false;
    _isPlaybackPaused = false;
    _currentPlaybackPath = null;
    _stopPlaybackAnimation();
    notifyListeners();
  }

  Future<void> togglePlayback() async {
    if (_isPlaying) {
      await player.pause();
      _isPlaying = false;
      _isPlaybackPaused = true;
      _statusText = 'Playback paused.';
      _stopPlaybackAnimation();
      notifyListeners();
      return;
    }

    final candidatePath = _playbackSource == PlaybackSource.dry
        ? _rawRecordingPath
        : _activeProcessedPath ?? _processedRecordingPath;
    if (candidatePath == null) {
      setStatus(
        _playbackSource == PlaybackSource.dry
            ? 'Record your voice first.'
            : 'No processed version found. Tap Apply Effect first.',
      );
      return;
    }

    final file = File(candidatePath);
    if (!file.existsSync()) {
      setStatus('The recording file was not found on disk.');
      return;
    }
    if (_isPlaybackPaused && _currentPlaybackPath == candidatePath) {
      _isPlaying = true;
      _isPlaybackPaused = false;
      _statusText =
          'Playing ${_playbackSource == PlaybackSource.dry ? 'dry' : 'processed'} vocal.';
      _startPlaybackAnimation();
      notifyListeners();
      await player.play();
      return;
    }

    await _refreshWaveformFromFile(candidatePath);

    await player.setFilePath(candidatePath);
    _isPlaying = true;
    _isPlaybackPaused = false;
    _currentPlaybackPath = candidatePath;
    _statusText =
        'Playing ${_playbackSource == PlaybackSource.dry ? 'dry' : 'processed'} vocal.';
    _startPlaybackAnimation();
    notifyListeners();

    await player.play();
  }

  String _processingProfileSignature() {
    return '${_selectedPreset.name}|$_isManualMode|${_eqBass.toStringAsFixed(2)}|${_eqMid.toStringAsFixed(2)}|${_eqTreble.toStringAsFixed(2)}|${_reverb.toStringAsFixed(2)}|${_trimStartSec.toStringAsFixed(2)}|${_trimEndSec.toStringAsFixed(2)}|${_fadeInSec.toStringAsFixed(2)}|${_fadeOutSec.toStringAsFixed(2)}|${_noiseReduction.toStringAsFixed(2)}|${_noiseGateDb.toStringAsFixed(1)}|${_pitchSemitones.toStringAsFixed(2)}|${_targetKey ?? ''}';
  }

  void _markProcessingDirty() {
    if (_rawRecordingPath == null) {
      return;
    }

    if (!_hasUnappliedAudioChanges) {
      _statusText = 'Audio settings changed. Applying instantly...';
    }
    _hasUnappliedAudioChanges = true;
    _scheduleAutoApply();
  }

  void _scheduleAutoApply({
    Duration delay = const Duration(milliseconds: 450),
  }) {
    if (_rawRecordingPath == null) {
      return;
    }
    _autoApplyTimer?.cancel();
    _autoApplyTimer = Timer(delay, () {
      unawaited(_runAutoApply());
    });
  }

  Future<void> _runAutoApply() async {
    if (_rawRecordingPath == null) {
      return;
    }
    if (_autoApplyInProgress) {
      _autoApplyQueued = true;
      return;
    }
    if (_recordingState != RecordingState.idle) {
      _autoApplyQueued = true;
      return;
    }

    _autoApplyInProgress = true;
    final wasPlayingProcessed =
        _isPlaying && _playbackSource == PlaybackSource.processed;
    if (wasPlayingProcessed) {
      await stopPlayback();
    }

    await applyCurrentEffect(
      addToProcessedVersions: false,
      statusPrefix: 'Effect updated',
    );

    if (wasPlayingProcessed && _activeProcessedPath != null) {
      await togglePlayback();
    }

    _autoApplyInProgress = false;
    if (_autoApplyQueued) {
      _autoApplyQueued = false;
      _scheduleAutoApply(delay: const Duration(milliseconds: 120));
    }
  }

  void setPlaybackSource(PlaybackSource source) {
    _playbackSource = source;
    if (source == PlaybackSource.dry) {
      _statusText = 'Playback source set to dry recording.';
    } else {
      _statusText = 'Playback source set to processed recording.';
    }
    _scheduleSettingsPersist();
    notifyListeners();
  }

  Future<void> toggleABCompare() async {
    final nextSource = _playbackSource == PlaybackSource.dry
        ? PlaybackSource.processed
        : PlaybackSource.dry;
    final resumePosition = player.position;
    final wasPlaying = _isPlaying;
    if (_isPlaying || _isPlaybackPaused) {
      await stopPlayback();
    }
    _playbackSource = nextSource;
    _statusText =
        'A/B switched to ${nextSource == PlaybackSource.dry ? 'Dry' : 'Processed'}.';
    notifyListeners();
    if (!wasPlaying) {
      return;
    }
    await togglePlayback();
    if (player.duration != null && resumePosition > Duration.zero) {
      await player.seek(resumePosition);
    }
  }

  void setActiveProcessedVersion(String path) {
    final match = _processedVersions.where((version) => version.path == path);
    if (match.isEmpty) {
      return;
    }
    _activeProcessedPath = path;
    _playbackSource = PlaybackSource.processed;
    _statusText = 'Selected ${match.first.label}.';
    notifyListeners();
  }

  Future<bool> applyCurrentEffect({
    bool addToProcessedVersions = true,
    String statusPrefix = 'Effect applied',
  }) async {
    final rawPath = _rawRecordingPath;
    if (rawPath == null) {
      setStatus('Record your voice first.');
      return false;
    }

    final profileSignature = _processingProfileSignature();
    if (!_hasUnappliedAudioChanges &&
        _lastProcessedProfileSignature == profileSignature &&
        _activeProcessedPath != null &&
        File(_activeProcessedPath!).existsSync()) {
      _statusText = 'Current effect is already applied.';
      notifyListeners();
      return true;
    }

    _recordingState = RecordingState.processing;
    _statusText = 'Applying selected effect...';
    notifyListeners();

    final now = DateTime.now();
    final appDir = await getApplicationDocumentsDirectory();
    final outputPath = p.join(
      appDir.path,
      '${_buildProfileLabel().replaceAll(' ', '_')}_${_formatDate(now)}.m4a',
    );
    final processedPath = await _applyVocalProcessing(rawPath, outputPath);
    _recordingState = RecordingState.idle;

    if (processedPath == null) {
      _statusText = 'Could not apply selected effect. Try again.';
      notifyListeners();
      return false;
    }

    final previousProcessedPath = _processedRecordingPath;
    final previousActivePath = _activeProcessedPath;
    final version = ProcessedVersion(
      path: processedPath,
      label: '${_buildProfileLabel()} ${_formatTime(now)}',
      createdAt: now,
    );
    if (addToProcessedVersions) {
      _processedVersions.insert(0, version);
      _trimProcessedVersions();
    }
    _processedRecordingPath = processedPath;
    _activeProcessedPath = processedPath;
    _lastProcessedProfileSignature = profileSignature;
    _hasUnappliedAudioChanges = false;
    _playbackSource = PlaybackSource.processed;
    _statusText = addToProcessedVersions
        ? '$statusPrefix and saved as ${version.label}.'
        : '$statusPrefix instantly.';
    await _refreshWaveformFromFile(processedPath);
    await _deleteFileIfDisposable(
      previousProcessedPath,
      retain: {processedPath},
    );
    await _deleteFileIfDisposable(previousActivePath, retain: {processedPath});
    notifyListeners();
    return true;
  }

  String _buildProfileLabel() {
    if (_isManualMode) {
      return 'custom';
    }
    return _presetName(_selectedPreset).toLowerCase().replaceAll('-', '_');
  }

  String _formatDate(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}${two(dt.month)}${two(dt.day)}_${two(dt.hour)}${two(dt.minute)}${two(dt.second)}';
  }

  String _formatTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  Future<void> saveVoiceWithSelectedEffect() async {
    final applied = await applyCurrentEffect();
    if (!applied) {
      return;
    }

    final sourcePath = _activeProcessedPath ?? _processedRecordingPath;
    if (sourcePath == null) {
      setStatus('No processed audio found to save.');
      return;
    }

    final sourceFile = File(sourcePath);
    if (!sourceFile.existsSync()) {
      setStatus('Processed audio file is missing.');
      return;
    }

    final now = DateTime.now();
    final appDir = await getApplicationDocumentsDirectory();
    final savedFilePath = p.join(
      appDir.path,
      'saved_${_buildProfileLabel()}_${_formatDate(now)}.m4a',
    );
    await sourceFile.copy(savedFilePath);

    final savedVoice = SavedVoice(
      id: '${now.microsecondsSinceEpoch}',
      path: savedFilePath,
      title: 'Voice ${_formatTime(now)}',
      profile: _buildProfileLabel(),
      createdAt: now,
    );
    _savedVoices.insert(0, savedVoice);
    await _persistSavedVoices();
    _statusText = 'Saved voice with selected effect.';
    _scheduleSettingsPersist();
    notifyListeners();
  }

  Future<void> playSavedVoice(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      setStatus('Saved file not found.');
      return;
    }

    if (_isPlaying && _currentPlaybackPath == path) {
      await stopPlayback();
      return;
    }

    if (_isPlaying) {
      await stopPlayback();
    }
    await _refreshWaveformFromFile(path);

    await player.setFilePath(path);
    _isPlaying = true;
    _currentPlaybackPath = path;
    _statusText = 'Playing saved voice.';
    _startPlaybackAnimation();
    notifyListeners();
    await player.play();
  }

  Future<void> shareSavedVoice(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      setStatus('Saved file not found.');
      return;
    }
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          text: 'Saved voice from Magic Song Studio',
        ),
      );
    } catch (_) {
      setStatus('Failed to share saved voice.');
    }
  }

  Future<void> deleteSavedVoice(String id) async {
    final index = _savedVoices.indexWhere((voice) => voice.id == id);
    if (index == -1) {
      return;
    }

    final target = _savedVoices[index];
    if (_isPlaying && _currentPlaybackPath == target.path) {
      await stopPlayback();
    }

    _savedVoices.removeAt(index);
    final file = File(target.path);
    if (file.existsSync()) {
      try {
        await file.delete();
      } catch (_) {
        // Ignore delete errors and continue with list update.
      }
    }

    await _persistSavedVoices();
    _statusText = 'Saved voice deleted.';
    notifyListeners();
  }

  Future<void> resetCurrentSession() async {
    if (_isPlaying) {
      await stopPlayback();
    }

    if (_recordingState == RecordingState.recording) {
      try {
        await audioRecorder.stop();
      } catch (_) {
        // Ignore recorder stop errors during reset.
      }
    }

    await _cleanupProcessedArtifacts();
    _rawRecordingPath = null;
    _processedRecordingPath = null;
    _activeProcessedPath = null;
    _currentPlaybackPath = null;
    _lastProcessedProfileSignature = null;
    _hasUnappliedAudioChanges = false;
    _processedVersions.clear();
    _recordingState = RecordingState.idle;
    _statusText = 'Session reset. Ready for a new recording.';
    notifyListeners();
  }

  void _trimProcessedVersions() {
    while (_processedVersions.length > _maxProcessedVersions) {
      final removed = _processedVersions.removeLast();
      unawaited(_deleteFileIfDisposable(removed.path));
    }
  }

  Future<void> _cleanupProcessedArtifacts() async {
    final candidates = <String>{
      ?_processedRecordingPath,
      ?_activeProcessedPath,
      ..._processedVersions.map((e) => e.path),
    };
    for (final path in candidates) {
      final isSaved = _savedVoices.any((voice) => voice.path == path);
      if (isSaved) {
        continue;
      }
      final file = File(path);
      if (file.existsSync()) {
        try {
          await file.delete();
        } catch (_) {
          // Ignore cleanup failures.
        }
      }
    }
  }

  Future<void> _deleteFileIfDisposable(
    String? path, {
    Set<String> retain = const {},
  }) async {
    if (path == null || retain.contains(path)) {
      return;
    }
    final isSaved = _savedVoices.any((voice) => voice.path == path);
    final isInProcessedList = _processedVersions.any(
      (version) => version.path == path,
    );
    final isCurrentActive = _activeProcessedPath == path;
    if (isSaved || isInProcessedList || isCurrentActive) {
      return;
    }
    final file = File(path);
    if (!file.existsSync()) {
      return;
    }
    try {
      await file.delete();
    } catch (_) {
      // Ignore cleanup failures.
    }
  }

  void _scheduleSettingsPersist() {
    _settingsPersistTimer?.cancel();
    _settingsPersistTimer = Timer(const Duration(milliseconds: 250), () {
      unawaited(_persistStudioSettings());
    });
  }

  Future<void> _loadStudioSettings() async {
    final appDir = await getApplicationDocumentsDirectory();
    final jsonFile = File(p.join(appDir.path, 'studio_settings.json'));
    if (!jsonFile.existsSync()) {
      return;
    }
    try {
      final rawText = await jsonFile.readAsString();
      final decoded = jsonDecode(rawText) as Map<String, dynamic>;

      final presetName = decoded['selectedPreset'] as String?;
      final selected = VocalPreset.values.firstWhere(
        (value) => value.name == presetName,
        orElse: () => VocalPreset.warmMelody,
      );
      _selectedPreset = selected;
      _isManualMode = decoded['isManualMode'] as bool? ?? false;
      _eqBass = (decoded['eqBass'] as num?)?.toDouble() ?? _eqBass;
      _eqMid = (decoded['eqMid'] as num?)?.toDouble() ?? _eqMid;
      _eqTreble = (decoded['eqTreble'] as num?)?.toDouble() ?? _eqTreble;
      _reverb = (decoded['reverb'] as num?)?.toDouble() ?? _reverb;

      final sourceRaw = decoded['playbackSource'] as String?;
      _playbackSource = sourceRaw == PlaybackSource.dry.name
          ? PlaybackSource.dry
          : PlaybackSource.processed;
      _statusText = 'Restored previous preset and EQ settings.';
      notifyListeners();
    } catch (_) {
      // Ignore malformed settings cache.
    }
  }

  Future<void> _persistStudioSettings() async {
    final appDir = await getApplicationDocumentsDirectory();
    final jsonFile = File(p.join(appDir.path, 'studio_settings.json'));
    final payload = <String, dynamic>{
      'selectedPreset': _selectedPreset.name,
      'isManualMode': _isManualMode,
      'eqBass': _eqBass,
      'eqMid': _eqMid,
      'eqTreble': _eqTreble,
      'reverb': _reverb,
      'playbackSource': _playbackSource.name,
    };
    await jsonFile.writeAsString(jsonEncode(payload));
  }

  Future<void> _refreshWaveformFromFile(String inputPath) async {
    final inputFile = File(inputPath);
    if (!inputFile.existsSync()) {
      return;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final pcmPath = p.join(
      appDir.path,
      'waveform_${DateTime.now().microsecondsSinceEpoch}.pcm',
    );
    final command = '-y -i "$inputPath" -ac 1 -ar 16000 -f s16le "$pcmPath"';
    final session = await FFmpegKit.execute(command);
    final rc = await session.getReturnCode();
    if (!ReturnCode.isSuccess(rc)) {
      return;
    }

    final pcmFile = File(pcmPath);
    if (!pcmFile.existsSync()) {
      return;
    }

    final bytes = await pcmFile.readAsBytes();
    try {
      await pcmFile.delete();
    } catch (_) {
      // Ignore temp cleanup failures.
    }

    final waveform = _convertPcmToWaveform(bytes);
    if (waveform.isEmpty) {
      return;
    }

    _capturedWaveform
      ..clear()
      ..addAll(waveform);
    _amplitudes
      ..clear()
      ..addAll(waveform.take(_maxAmplitudes));
    notifyListeners();
  }

  List<double> _convertPcmToWaveform(Uint8List bytes) {
    if (bytes.length < 2) {
      return const [];
    }
    final data = ByteData.sublistView(bytes);
    final totalSamples = bytes.length ~/ 2;
    if (totalSamples == 0) {
      return const [];
    }

    final targetPoints = 280;
    final samplesPerBucket = (totalSamples / targetPoints)
        .ceil()
        .clamp(1, 4096)
        .toInt();
    final points = <double>[];

    var sampleIndex = 0;
    while (sampleIndex < totalSamples) {
      final end = (sampleIndex + samplesPerBucket < totalSamples)
          ? sampleIndex + samplesPerBucket
          : totalSamples;
      var sumSquares = 0.0;
      var count = 0;
      for (var i = sampleIndex; i < end; i++) {
        final v = data.getInt16(i * 2, Endian.little).toDouble() / 32768.0;
        sumSquares += v * v;
        count++;
      }
      if (count > 0) {
        final rms = math.sqrt(sumSquares / count);
        final normalized = (rms * 4.2).clamp(0.05, 1.0);
        points.add(normalized);
      }
      sampleIndex = end;
    }

    if (points.isEmpty) {
      return const [];
    }
    return points;
  }

  Future<void> _loadSavedVoices() async {
    final appDir = await getApplicationDocumentsDirectory();
    final jsonFile = File(p.join(appDir.path, 'saved_voices.json'));
    if (!jsonFile.existsSync()) {
      return;
    }
    try {
      final rawText = await jsonFile.readAsString();
      final decoded = jsonDecode(rawText) as List<dynamic>;
      _savedVoices
        ..clear()
        ..addAll(
          decoded
              .map((e) => SavedVoice.fromJson(e as Map<String, dynamic>))
              .where((voice) => File(voice.path).existsSync()),
        );
      notifyListeners();
    } catch (_) {
      // Ignore malformed cache and continue.
    }
  }

  Future<void> _persistSavedVoices() async {
    final appDir = await getApplicationDocumentsDirectory();
    final jsonFile = File(p.join(appDir.path, 'saved_voices.json'));
    final encoded = jsonEncode(_savedVoices.map((e) => e.toJson()).toList());
    await jsonFile.writeAsString(encoded);
  }

  Future<void> _loadProjects() async {
    final appDir = await getApplicationDocumentsDirectory();
    final jsonFile = File(p.join(appDir.path, 'studio_projects.json'));
    if (!jsonFile.existsSync()) {
      return;
    }
    try {
      final rawText = await jsonFile.readAsString();
      final decoded = jsonDecode(rawText) as List<dynamic>;
      _projects
        ..clear()
        ..addAll(
          decoded
              .map((e) => StudioProject.fromJson(e as Map<String, dynamic>))
              .where(
                (project) =>
                    project.rawPath == null ||
                    File(project.rawPath!).existsSync(),
              ),
        );
      notifyListeners();
    } catch (_) {
      // Ignore malformed cache and continue.
    }
  }

  Future<void> _persistProjects() async {
    final appDir = await getApplicationDocumentsDirectory();
    final jsonFile = File(p.join(appDir.path, 'studio_projects.json'));
    final encoded = jsonEncode(_projects.map((e) => e.toJson()).toList());
    await jsonFile.writeAsString(encoded);
  }

  Future<void> saveCurrentProject({
    required String name,
    String notes = '',
  }) async {
    final now = DateTime.now();
    final project = StudioProject(
      id: '${now.microsecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'Untitled Project' : name.trim(),
      notes: notes.trim(),
      createdAt: now,
      updatedAt: now,
      rawPath: _rawRecordingPath,
      processedPath: _processedRecordingPath,
      activeProcessedPath: _activeProcessedPath,
      selectedPreset: _selectedPreset.name,
      isManualMode: _isManualMode,
      eqBass: _eqBass,
      eqMid: _eqMid,
      eqTreble: _eqTreble,
      reverb: _reverb,
      trimStartSec: _trimStartSec,
      trimEndSec: _trimEndSec,
      fadeInSec: _fadeInSec,
      fadeOutSec: _fadeOutSec,
      noiseReduction: _noiseReduction,
      noiseGateDb: _noiseGateDb,
      pitchSemitones: _pitchSemitones,
      targetKey: _targetKey,
    );
    _projects.insert(0, project);
    await _persistProjects();
    _statusText = 'Project "${project.name}" saved.';
    notifyListeners();
  }

  Future<void> loadProject(String id) async {
    final idx = _projects.indexWhere((project) => project.id == id);
    if (idx == -1) {
      return;
    }
    final project = _projects[idx];
    _rawRecordingPath = project.rawPath;
    _processedRecordingPath = project.processedPath;
    _activeProcessedPath = project.activeProcessedPath;
    _selectedPreset = VocalPreset.values.firstWhere(
      (value) => value.name == project.selectedPreset,
      orElse: () => VocalPreset.warmMelody,
    );
    _isManualMode = project.isManualMode;
    _eqBass = project.eqBass;
    _eqMid = project.eqMid;
    _eqTreble = project.eqTreble;
    _reverb = project.reverb;
    _trimStartSec = project.trimStartSec;
    _trimEndSec = project.trimEndSec;
    _fadeInSec = project.fadeInSec;
    _fadeOutSec = project.fadeOutSec;
    _noiseReduction = project.noiseReduction;
    _noiseGateDb = project.noiseGateDb;
    _pitchSemitones = project.pitchSemitones;
    _targetKey = project.targetKey;
    _playbackSource = PlaybackSource.processed;
    _statusText = 'Loaded project "${project.name}".';
    if (_activeProcessedPath != null) {
      await _refreshWaveformFromFile(_activeProcessedPath!);
    } else if (_rawRecordingPath != null) {
      await _refreshWaveformFromFile(_rawRecordingPath!);
    }
    _scheduleSettingsPersist();
    notifyListeners();
  }

  Future<void> deleteProject(String id) async {
    _projects.removeWhere((project) => project.id == id);
    await _persistProjects();
    _statusText = 'Project removed.';
    notifyListeners();
  }

  Future<void> shareAudio() async {
    final candidatePath = _playbackSource == PlaybackSource.dry
        ? _rawRecordingPath
        : _activeProcessedPath ?? _processedRecordingPath;
    if (candidatePath == null) {
      setStatus('No recording available to share.');
      return;
    }

    final file = File(candidatePath);
    if (!file.existsSync()) {
      setStatus('The recording file was not found on disk.');
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(candidatePath)],
          text: 'Check out my vocal recording from Magic Song Studio!',
        ),
      );
    } catch (e) {
      setStatus('Failed to share recording.');
    }
  }
}
