import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../models/preset_data.dart';
import '../models/vocal_preset.dart';
import '../routes/app_routes.dart';
import '../viewmodels/melody_viewmodel.dart';

class MelodyRecorderView extends StatefulWidget {
  const MelodyRecorderView({super.key});

  @override
  State<MelodyRecorderView> createState() => _MelodyRecorderViewState();
}

const List<PresetData> _availablePresets = [
  PresetData(
    preset: VocalPreset.clean,
    title: 'Clean',
    subtitle: 'Light Touch',
    icon: Icons.mic_none,
  ),
  PresetData(
    preset: VocalPreset.warmMelody,
    title: 'Warm Melody',
    subtitle: 'Recommended',
    icon: Icons.waves,
  ),
  PresetData(
    preset: VocalPreset.brightLead,
    title: 'Bright Lead',
    subtitle: 'Crisp & Punchy',
    icon: Icons.graphic_eq,
  ),
  PresetData(
    preset: VocalPreset.indieMalayalam,
    title: 'Warm Indie',
    subtitle: 'Warm & Emotional',
    icon: Icons.auto_awesome,
  ),
  PresetData(
    preset: VocalPreset.podcast,
    title: 'Podcast',
    subtitle: 'Radio Broadcast',
    icon: Icons.mic_external_on,
  ),
  PresetData(
    preset: VocalPreset.cathedral,
    title: 'Cathedral',
    subtitle: 'Epic Reverb',
    icon: Icons.account_balance,
  ),
  PresetData(
    preset: VocalPreset.lofi,
    title: 'Lo-Fi',
    subtitle: 'Telephone Effect',
    icon: Icons.phone_in_talk,
  ),
];

class _MelodyRecorderViewState extends State<MelodyRecorderView>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final provider = context.read<MelodyViewModel>();
    await provider.startRecording();
    if (provider.recordingState == RecordingState.recording) {
      _pulseController.repeat(reverse: true);
    }
  }

  Future<void> _stopRecordingAndProcess() async {
    _pulseController.stop();
    _pulseController.reset();

    final provider = context.read<MelodyViewModel>();
    await provider.stopRecordingAndProcess();
  }

  Future<void> _togglePlayback() async {
    final provider = context.read<MelodyViewModel>();
    await provider.togglePlayback();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MelodyViewModel>(
      builder: (context, provider, child) {
        final isBusy = provider.recordingState == RecordingState.processing;
        final isRecording = provider.recordingState == RecordingState.recording;
        final hasRaw = provider.hasRawRecording;
        final hasProcessed = provider.hasProcessedRecording;
        final canApply = provider.canApplyEffect;
        final canPlay = provider.canPlaySelectedSource;

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: Text(
              'Magic Song Studio',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5.sp,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            actions: [
              IconButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.savedVoices),
                icon: const Icon(Icons.library_music_rounded),
                tooltip: 'Saved Voices',
              ),
            ],
          ),
          body: Stack(
            children: [
              // Background Gradient
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF0D0D12),
                      Color(0xFF1A1A2E),
                      Color(0xFF0F3433),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              // Glow Orbs
              Positioned(
                top: -50.h,
                left: -50.w,
                child: Container(
                  width: 300.w,
                  height: 300.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00FFCC).withValues(alpha: 0.15),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00FFCC).withValues(alpha: 0.2),
                        blurRadius: 100.r,
                        spreadRadius: 50.r,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: -50.h,
                right: -50.w,
                child: Container(
                  width: 300.w,
                  height: 300.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF7B2CBF).withValues(alpha: 0.15),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7B2CBF).withValues(alpha: 0.2),
                        blurRadius: 100.r,
                        spreadRadius: 50.r,
                      ),
                    ],
                  ),
                ),
              ),
              // Main Content
              SafeArea(
                child: ListView(
                  padding: EdgeInsets.symmetric(
                    // horizontal: 24.w,
                    vertical: 16.h,
                  ),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Vocal Processing Tools',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 20.sp,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            'Manual',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.white70,
                            ),
                          ),
                          Switch(
                            value: provider.isManualMode,
                            onChanged: isBusy || isRecording
                                ? null
                                : (val) {
                                    provider.setIsManualMode(val);
                                    provider.setStatus(
                                      val
                                          ? 'Switched to Manual EQ & Reverb.'
                                          : 'Switched to Presets.',
                                    );
                                  },
                            activeThumbColor: const Color(0xFF00FFCC),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                    if (!provider.isManualMode) ...[
                      SizedBox(
                        height: 180.h,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.symmetric(horizontal: 24.w),
                          itemCount: _availablePresets.length,
                          separatorBuilder: (context, index) =>
                              SizedBox(width: 16.w),
                          itemBuilder: (context, index) {
                            final presetData = _availablePresets[index];
                            return _PresetCard(
                              title: presetData.title,
                              subtitle: presetData.subtitle,
                              icon: presetData.icon,
                              isSelected:
                                  provider.selectedPreset == presetData.preset,
                              onTap: isBusy || isRecording
                                  ? null
                                  : () => provider.setPreset(presetData.preset),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 24.h),
                    ],

                    // Recorder Section
                    Center(
                      child: Column(
                        children: [
                          _AudioVisualizerWidget(
                            amplitudes: provider.amplitudes,
                          ),
                          SizedBox(height: 24.h),
                          _StatusBadge(
                            statusText: provider.statusText,
                            isBusy: isBusy,
                          ),
                          SizedBox(height: 14.h),
                          _WorkflowHint(
                            text: provider.workflowHint,
                            hasRaw: hasRaw,
                            hasProcessed: hasProcessed,
                          ),
                          SizedBox(height: 48.h),
                          GestureDetector(
                            onTap: isBusy
                                ? null
                                : isRecording
                                ? _stopRecordingAndProcess
                                : _startRecording,
                            child: AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: isRecording
                                      ? _pulseAnimation.value
                                      : 1.0,
                                  child: Container(
                                    width: 100.w,
                                    height: 100.w,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: isRecording
                                            ? [
                                                const Color(0xFFFF3366),
                                                const Color(0xFFFF6B6B),
                                              ]
                                            : [
                                                const Color(0xFF00FFCC),
                                                const Color(0xFF00B3FF),
                                              ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: isRecording
                                              ? const Color(
                                                  0xFFFF3366,
                                                ).withValues(alpha: 0.5)
                                              : const Color(
                                                  0xFF00FFCC,
                                                ).withValues(alpha: 0.5),
                                          blurRadius: 30.r,
                                          spreadRadius: 5.r,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      isRecording
                                          ? Icons.stop_rounded
                                          : Icons.mic_rounded,
                                      size: 48.sp,
                                      color: Colors.white,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          SizedBox(height: 24.h),
                          Text(
                            isRecording
                                ? 'Tap to Stop Recording'
                                : 'Tap to Record',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 48.h),
                          // Playback Controls
                          AnimatedOpacity(
                            opacity: hasRaw ? 1.0 : 0.5,
                            duration: const Duration(milliseconds: 300),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 24.w,
                                vertical: 16.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(30.r),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Wrap(
                                    spacing: 8.w,
                                    children: [
                                      ChoiceChip(
                                        label: const Text('Processed'),
                                        selected:
                                            provider.playbackSource ==
                                            PlaybackSource.processed,
                                        onSelected: isBusy || isRecording
                                            ? null
                                            : (_) => provider.setPlaybackSource(
                                                PlaybackSource.processed,
                                              ),
                                      ),
                                      ChoiceChip(
                                        label: const Text('Dry'),
                                        selected:
                                            provider.playbackSource ==
                                            PlaybackSource.dry,
                                        onSelected: isBusy || isRecording
                                            ? null
                                            : (_) => provider.setPlaybackSource(
                                                PlaybackSource.dry,
                                              ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 14.h),
                                  Wrap(
                                    spacing: 10.w,
                                    runSpacing: 10.h,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      FilledButton.tonalIcon(
                                        onPressed: canApply
                                            ? () =>
                                                  provider.applyCurrentEffect()
                                            : null,
                                        icon: const Icon(Icons.auto_fix_high),
                                        label: Text(
                                          hasProcessed
                                              ? 'Re-Apply Effect'
                                              : 'Apply Effect',
                                        ),
                                      ),
                                      FilledButton.icon(
                                        onPressed: canPlay
                                            ? _togglePlayback
                                            : null,
                                        icon: Icon(
                                          provider.isPlaying
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                        ),
                                        label: Text(
                                          provider.isPlaying ? 'Pause' : 'Play',
                                        ),
                                      ),
                                      FilledButton.tonalIcon(
                                        onPressed: canApply
                                            ? () => provider
                                                  .saveVoiceWithSelectedEffect()
                                            : null,
                                        icon: const Icon(Icons.save_rounded),
                                        label: const Text('Save'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: hasRaw
                                            ? () => provider.shareAudio()
                                            : null,
                                        icon: const Icon(Icons.share_rounded),
                                        label: const Text('Share'),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 10.h),
                                  Text(
                                    !hasRaw
                                        ? 'Record first to enable effects and playback.'
                                        : provider.playbackSource ==
                                                  PlaybackSource.processed &&
                                              !hasProcessed
                                        ? 'Apply Effect to create processed audio.'
                                        : 'Tip: Compare Dry and Processed before sharing.',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.65,
                                      ),
                                      fontSize: 12.sp,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 30.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: _GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (provider.processedVersions.isNotEmpty) ...[
                              Text(
                                'Saved Versions',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              SizedBox(height: 10.h),
                              Wrap(
                                spacing: 8.w,
                                runSpacing: 8.h,
                                children: provider.processedVersions
                                    .map(
                                      (version) => ChoiceChip(
                                        label: Text(
                                          version.label,
                                          style: TextStyle(fontSize: 12.sp),
                                        ),
                                        selected:
                                            provider.activeProcessedPath ==
                                            version.path,
                                        onSelected: (_) =>
                                            provider.setActiveProcessedVersion(
                                              version.path,
                                            ),
                                      ),
                                    )
                                    .toList(),
                              ),
                              SizedBox(height: 16.h),
                            ],
                            _StudioSlider(
                              label: 'Bass',
                              value: provider.eqBass,
                              min: -10,
                              max: 10,
                              onChanged: isBusy || isRecording
                                  ? null
                                  : (val) => provider.setEqBass(val),
                            ),
                            _StudioSlider(
                              label: 'Mid',
                              value: provider.eqMid,
                              min: -10,
                              max: 10,
                              onChanged: isBusy || isRecording
                                  ? null
                                  : (val) => provider.setEqMid(val),
                            ),
                            _StudioSlider(
                              label: 'Treble',
                              value: provider.eqTreble,
                              min: -10,
                              max: 10,
                              onChanged: isBusy || isRecording
                                  ? null
                                  : (val) => provider.setEqTreble(val),
                            ),
                            _StudioSlider(
                              label: 'Studio Reverb',
                              value: provider.reverb,
                              min: 0,
                              max: 1,
                              onChanged: isBusy || isRecording
                                  ? null
                                  : (val) => provider.setReverb(val),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AudioVisualizerWidget extends StatelessWidget {
  final List<double> amplitudes;

  const _AudioVisualizerWidget({required this.amplitudes});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60.h,
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: CustomPaint(
        painter: _AudioWaveformPainter(amplitudes: amplitudes, maxBars: 40),
      ),
    );
  }
}

class _AudioWaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final int maxBars;

  _AudioWaveformPainter({required this.amplitudes, required this.maxBars});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final double barWidth = (size.width - ((maxBars - 1) * 4).w) / maxBars;
    final double maxBarHeight = size.height;
    final double centerY = size.height / 2;

    int startIndex = amplitudes.length - maxBars;
    if (startIndex < 0) startIndex = 0;

    for (int i = 0; i < maxBars; i++) {
      int ampIndex = startIndex + i;
      double amp = 0.05; // Base minimum amplitude
      if (ampIndex >= 0 && ampIndex < amplitudes.length) {
        amp = amplitudes[ampIndex];
      }

      final barHeight = amp * maxBarHeight;
      final x = i * (barWidth + 4.w);

      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x + barWidth / 2, centerY),
          width: barWidth,
          height: barHeight,
        ),
        Radius.circular(10.r),
      );

      paint.shader = const LinearGradient(
        colors: [Color(0xFF00FFCC), Color(0xFF00B3FF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect.outerRect);

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // We want to repaint frequently when animating
  }
}

class _StatusBadge extends StatelessWidget {
  final String statusText;
  final bool isBusy;

  const _StatusBadge({required this.statusText, required this.isBusy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isBusy) ...[
            SizedBox(
              width: 14.w,
              height: 14.h,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00FFCC)),
              ),
            ),
            SizedBox(width: 12.w),
          ],
          Flexible(
            child: Text(
              statusText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowHint extends StatelessWidget {
  final String text;
  final bool hasRaw;
  final bool hasProcessed;

  const _WorkflowHint({
    required this.text,
    required this.hasRaw,
    required this.hasProcessed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 10.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          alignment: WrapAlignment.center,
          children: [
            _StepChip(label: '1 Record', isDone: hasRaw),
            _StepChip(label: '2 Apply', isDone: hasProcessed),
            _StepChip(label: '3 Play', isDone: hasRaw && hasProcessed),
          ],
        ),
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  final String label;
  final bool isDone;

  const _StepChip({required this.label, required this.isDone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: isDone
            ? const Color(0xFF00FFCC).withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDone
              ? const Color(0xFF00FFCC).withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: isDone ? 0.95 : 0.75),
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  const _PresetCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 140.w,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00FFCC).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00FFCC).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2.w : 1.w,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF00FFCC).withValues(alpha: 0.2),
                    blurRadius: 15.r,
                    spreadRadius: 1.r,
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF00FFCC) : Colors.white54,
              size: 28.sp,
            ),
            SizedBox(height: 8.h),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12.sp,
                color: isSelected ? Colors.white70 : Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudioSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;

  const _StudioSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                value.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFF00FFCC),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
              thumbColor: const Color(0xFF00FFCC),
              overlayColor: const Color(0xFF00FFCC).withValues(alpha: 0.2),
              trackHeight: 4.h,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
