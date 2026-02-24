import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart';

import '../models/saved_voice.dart';
import '../models/vocal_preset.dart';

enum RecordingState { idle, recording, processing }

enum PlaybackSource { processed, dry }

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

class MelodyViewModel extends ChangeNotifier {
  final AudioRecorder audioRecorder;
  final AudioPlayer player;

  // ... state vars

  RecordingState _recordingState = RecordingState.idle;
  RecordingState get recordingState => _recordingState;

  VocalPreset _selectedPreset = VocalPreset.warmMelody;
  VocalPreset get selectedPreset => _selectedPreset;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

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
    if (_recordingState == RecordingState.recording) {
      return 'Step 1/3: Finish recording.';
    }
    if (_recordingState == RecordingState.processing) {
      return 'Applying effect...';
    }
    if (!hasRawRecording) {
      return 'Step 1/3: Record your dry voice.';
    }
    if (!hasProcessedRecording || _hasUnappliedAudioChanges) {
      return 'Step 2/3: Tap Apply Effect.';
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

  Timer? _amplitudeTimer;
  Timer? _autoApplyTimer;
  bool _autoApplyInProgress = false;
  bool _autoApplyQueued = false;
  final List<double> _amplitudes = [];
  List<double> get amplitudes => _amplitudes;
  final int _maxAmplitudes = 40;

  MelodyViewModel({
    AudioRecorder? recorder,
    AudioPlayer? audioPlayer,
    bool loadSavedVoicesOnInit = true,
  }) : audioRecorder = recorder ?? AudioRecorder(),
       player = audioPlayer ?? AudioPlayer() {
    if (loadSavedVoicesOnInit) {
      unawaited(_loadSavedVoices());
    }
    player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _isPlaying = false;
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
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) async {
      if (_recordingState == RecordingState.recording) {
        final amp = await audioRecorder.getAmplitude();
        // Normalize roughly between 0.0 and 1.0 (Record returns dB from -160 to 0)
        final db = amp.current.clamp(-60.0, 0.0);
        final normalized = (db + 60.0) / 60.0;
        _addAmplitude(normalized);
      }
    });
  }

  void _stopAmplitudeTimer() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    _amplitudes.clear();
    notifyListeners();
  }

  void _startPlaybackAnimation() {
    _amplitudes.clear();
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      // Simulate playback amplitude
      final randomAmp =
          0.2 + (0.6 * (DateTime.now().millisecondsSinceEpoch % 100) / 100);
      _addAmplitude(randomAmp);
    });
  }

  void _stopPlaybackAnimation() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    _amplitudes.clear();
    notifyListeners();
  }

  void setPreset(VocalPreset preset) {
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
    notifyListeners();
  }

  void setIsManualMode(bool val) {
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
    notifyListeners();
  }

  void setEqBass(double val) {
    _eqBass = val;
    _markProcessingDirty();
    notifyListeners();
  }

  void setEqMid(double val) {
    _eqMid = val;
    _markProcessingDirty();
    notifyListeners();
  }

  void setEqTreble(double val) {
    _eqTreble = val;
    _markProcessingDirty();
    notifyListeners();
  }

  void setReverb(double val) {
    _reverb = val;
    _markProcessingDirty();
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
      case VocalPreset.podcast:
        return 'Podcast';
      case VocalPreset.cathedral:
        return 'Cathedral';
      case VocalPreset.lofi:
        return 'Lo-Fi Telephone';
    }
  }

  Future<void> startRecording() async {
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

  Future<void> stopRecordingAndProcess() async {
    _stopAmplitudeTimer();

    final recordedPath = await audioRecorder.stop();
    if (recordedPath == null) {
      _recordingState = RecordingState.idle;
      setStatus('Recording failed. Please try again.');
      return;
    }

    _rawRecordingPath = recordedPath;
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

    return '$hpLp,$eqString,$comp,$reverbString,alimiter=limit=0.95';
  }

  Future<void> stopPlayback() async {
    await player.stop();
    _isPlaying = false;
    _currentPlaybackPath = null;
    _stopPlaybackAnimation();
    notifyListeners();
  }

  Future<void> togglePlayback() async {
    if (_isPlaying) {
      await player.stop();
      _isPlaying = false;
      _currentPlaybackPath = null;
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

    await player.setFilePath(candidatePath);
    _isPlaying = true;
    _currentPlaybackPath = candidatePath;
    _statusText =
        'Playing ${_playbackSource == PlaybackSource.dry ? 'dry' : 'processed'} vocal.';
    _startPlaybackAnimation();
    notifyListeners();

    await player.play();
  }

  String _processingProfileSignature() {
    return '${_selectedPreset.name}|$_isManualMode|${_eqBass.toStringAsFixed(2)}|${_eqMid.toStringAsFixed(2)}|${_eqTreble.toStringAsFixed(2)}|${_reverb.toStringAsFixed(2)}';
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
    notifyListeners();
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

    final version = ProcessedVersion(
      path: processedPath,
      label: '${_buildProfileLabel()} ${_formatTime(now)}',
      createdAt: now,
    );
    if (addToProcessedVersions) {
      _processedVersions.insert(0, version);
    }
    _processedRecordingPath = processedPath;
    _activeProcessedPath = processedPath;
    _lastProcessedProfileSignature = profileSignature;
    _hasUnappliedAudioChanges = false;
    _playbackSource = PlaybackSource.processed;
    _statusText = addToProcessedVersions
        ? '$statusPrefix and saved as ${version.label}.'
        : '$statusPrefix instantly.';
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
