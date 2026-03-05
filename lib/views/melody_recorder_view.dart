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
    subtitle: 'Balanced',
    icon: Icons.waves_rounded,
  ),
  PresetData(
    preset: VocalPreset.modernIndie,
    title: 'Modern Indie',
    subtitle: 'Crisp + Air',
    icon: Icons.music_note_rounded,
  ),
  PresetData(
    preset: VocalPreset.cinematic,
    title: 'Cinematic',
    subtitle: 'Wide + Epic',
    icon: Icons.movie_filter_rounded,
  ),
  PresetData(
    preset: VocalPreset.airyVocal,
    title: 'Airy Vocal',
    subtitle: 'Studio Blend',
    icon: Icons.tune_rounded,
  ),
  PresetData(
    preset: VocalPreset.brightLead,
    title: 'Bright Lead',
    subtitle: 'Forward',
    icon: Icons.graphic_eq,
  ),
  PresetData(
    preset: VocalPreset.indieMalayalam,
    title: 'Warm Indie',
    subtitle: 'Emotional',
    icon: Icons.auto_awesome,
  ),
  PresetData(
    preset: VocalPreset.podcast,
    title: 'Podcast',
    subtitle: 'Broadcast',
    icon: Icons.mic_external_on,
  ),
  PresetData(
    preset: VocalPreset.cathedral,
    title: 'Cathedral',
    subtitle: 'Long Space',
    icon: Icons.account_balance,
  ),
  PresetData(
    preset: VocalPreset.lofi,
    title: 'Lo-Fi',
    subtitle: 'Telephone',
    icon: Icons.phone_in_talk,
  ),
];

class _MelodyRecorderViewState extends State<MelodyRecorderView> {
  String _lastStatusText = '';
  DateTime? _lastBackPressTime;

  Future<void> _startRecording() async {
    final provider = context.read<MelodyViewModel>();
    await provider.startRecording();
  }

  Future<void> _stopRecording() async {
    final provider = context.read<MelodyViewModel>();
    await provider.stopRecordingAndProcess();
  }

  Future<void> _togglePlayback() async {
    final provider = context.read<MelodyViewModel>();
    await provider.togglePlayback();
  }

  Future<void> _resetSession() async {
    final provider = context.read<MelodyViewModel>();
    final shouldReset =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Start New Recording?'),
              content: const Text(
                'Current unsaved recording session will be cleared.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Reset'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (shouldReset) {
      await provider.resetCurrentSession();
    }
  }

  void _maybeShowCriticalToast(String statusText) {
    final lower = statusText.toLowerCase();
    final isCritical =
        lower.contains('failed') ||
        lower.contains('denied') ||
        lower.contains('required') ||
        lower.contains('not found') ||
        lower.contains('missing') ||
        lower.contains('could not');
    if (!isCritical || !mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(statusText),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MelodyViewModel>(
      builder: (context, provider, child) {
        final isBusy = provider.recordingState == RecordingState.processing;
        final isRecording = provider.recordingState == RecordingState.recording;
        final hasRaw = provider.hasRawRecording;
        final hasProcessed = provider.hasProcessedRecording;
        final canPlay = provider.canPlaySelectedSource;

        if (provider.statusText != _lastStatusText) {
          _lastStatusText = provider.statusText;
          _maybeShowCriticalToast(provider.statusText);
        }

        IconData primaryIcon;
        String primaryLabel;
        Future<void> Function()? primaryAction;
        if (isRecording) {
          primaryIcon = Icons.stop_rounded;
          primaryLabel = 'Stop Recording';
          primaryAction = _stopRecording;
        } else if (!hasRaw) {
          primaryIcon = Icons.mic_rounded;
          primaryLabel = 'Start Recording';
          primaryAction = isBusy ? null : _startRecording;
        } else if (provider.isPlaying) {
          primaryIcon = Icons.pause_rounded;
          primaryLabel = 'Pause';
          primaryAction = canPlay ? _togglePlayback : null;
        } else {
          primaryIcon = Icons.play_arrow_rounded;
          primaryLabel = 'Play';
          primaryAction = canPlay ? _togglePlayback : null;
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, dynamic result) {
            if (didPop) return;
            final now = DateTime.now();
            final isWarningSufficient =
                _lastBackPressTime == null ||
                now.difference(_lastBackPressTime!) >
                    const Duration(seconds: 2);

            if (isWarningSufficient) {
              _lastBackPressTime = now;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Press back again to exit'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
            } else {
              // Exits the application when double tapped within 2 seconds
              // For a production app this removes the Flutter Engine activity
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text('Magic Song Studio'),
              actions: [
                IconButton(
                  tooltip: 'Saved Voices',
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.savedVoices),
                  icon: const Icon(Icons.library_music_rounded),
                ),
              ],
            ),
            body: Stack(
              children: [
                const _Backdrop(),
                SafeArea(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(0.w, 10.h, 0.w, 24.h),
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: _HeaderRow(
                          manualMode: provider.isManualMode,
                          disabled: isBusy || isRecording,
                          onManualChanged: (val) {
                            provider.setIsManualMode(val);
                            provider.setStatus(
                              val
                                  ? 'Manual controls enabled.'
                                  : 'Preset mode enabled.',
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 14.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: _StatusPanel(
                          statusText: provider.statusText,
                          hintText: provider.workflowHint,
                          hasRaw: hasRaw,
                          hasProcessed: hasProcessed,
                          isBusy: isBusy,
                        ),
                      ),
                      SizedBox(height: 14.h),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(left: 14.w, top: 10.h),
                            child: Text(
                              'Preset Bank',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          SizedBox(height: 10.h),
                          if (!provider.isManualMode)
                            SizedBox(
                              height: 146.h,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: EdgeInsets.symmetric(horizontal: 14.w),
                                itemCount: _availablePresets.length,
                                separatorBuilder: (context, index) =>
                                    SizedBox(width: 12.w),
                                itemBuilder: (context, index) {
                                  final preset = _availablePresets[index];
                                  return _PresetTile(
                                    data: preset,
                                    selected:
                                        provider.selectedPreset ==
                                        preset.preset,
                                    onTap: isBusy || isRecording
                                        ? null
                                        : () =>
                                              provider.setPreset(preset.preset),
                                  );
                                },
                              ),
                            )
                          else
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              child: Text(
                                'Manual mode is on. EQ and reverb are editable below.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 14.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: _GlassPanel(
                          child: Column(
                            children: [
                              _AudioVisualizerWidget(
                                amplitudes: provider.amplitudes,
                              ),
                              SizedBox(height: 10.h),
                              Text(
                                'Playback Source',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              SizedBox(height: 6.h),
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
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: primaryAction,
                                  icon: Icon(primaryIcon),
                                  label: Text(primaryLabel),
                                ),
                              ),
                              SizedBox(height: 10.h),
                              Wrap(
                                spacing: 8.w,
                                runSpacing: 8.h,
                                alignment: WrapAlignment.center,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: hasRaw
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
                                  OutlinedButton.icon(
                                    onPressed: hasRaw ? _resetSession : null,
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('New'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 14.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: _GlassPanel(
                          child: Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              title: const Text('Advanced EQ & Reverb'),
                              subtitle: const Text('Manual fine control'),
                              children: [
                                _StudioSlider(
                                  label: 'Bass',
                                  value: provider.eqBass,
                                  min: -10,
                                  max: 10,
                                  onChanged: isBusy || isRecording
                                      ? null
                                      : (v) => provider.setEqBass(v),
                                ),
                                _StudioSlider(
                                  label: 'Mid',
                                  value: provider.eqMid,
                                  min: -10,
                                  max: 10,
                                  onChanged: isBusy || isRecording
                                      ? null
                                      : (v) => provider.setEqMid(v),
                                ),
                                _StudioSlider(
                                  label: 'Treble',
                                  value: provider.eqTreble,
                                  min: -10,
                                  max: 10,
                                  onChanged: isBusy || isRecording
                                      ? null
                                      : (v) => provider.setEqTreble(v),
                                ),
                                _StudioSlider(
                                  label: 'Reverb',
                                  value: provider.reverb,
                                  min: 0,
                                  max: 1,
                                  onChanged: isBusy || isRecording
                                      ? null
                                      : (v) => provider.setReverb(v),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (provider.processedVersions.isNotEmpty) ...[
                        SizedBox(height: 14.h),
                        _GlassPanel(
                          child: Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              title: const Text('Processed Snapshots'),
                              subtitle: const Text(
                                'Jump to previous snapshots',
                              ),
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Wrap(
                                    spacing: 8.w,
                                    runSpacing: 8.h,
                                    children: provider.processedVersions
                                        .map(
                                          (version) => ChoiceChip(
                                            label: Text(version.label),
                                            selected:
                                                provider.activeProcessedPath ==
                                                version.path,
                                            onSelected: (_) => provider
                                                .setActiveProcessedVersion(
                                                  version.path,
                                                ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                                SizedBox(height: 6.h),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F1218), Color(0xFF141922), Color(0xFF181D27)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned(
          top: -80,
          left: -40,
          child: _GlowOrb(
            size: 260,
            color: const Color(0xFFF4C95D).withValues(alpha: 0.08),
          ),
        ),
        Positioned(
          top: 220,
          right: -30,
          child: _GlowOrb(
            size: 220,
            color: const Color(0xFFF4C95D).withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.w,
      height: size.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 95, spreadRadius: 25)],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final bool manualMode;
  final bool disabled;
  final ValueChanged<bool> onManualChanged;

  const _HeaderRow({
    required this.manualMode,
    required this.disabled,
    required this.onManualChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Voice Craft',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                'Record, sculpt, and compare your voice.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
              ),
            ],
          ),
        ),
        Text(
          'Manual',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
        Switch(
          value: manualMode,
          onChanged: disabled ? null : onManualChanged,
          activeThumbColor: const Color(0xFFF4C95D),
          activeTrackColor: const Color(0x66F4C95D),
        ),
      ],
    );
  }
}

class _StatusPanel extends StatelessWidget {
  final String statusText;
  final String hintText;
  final bool hasRaw;
  final bool hasProcessed;
  final bool isBusy;

  const _StatusPanel({
    required this.statusText,
    required this.hintText,
    required this.hasRaw,
    required this.hasProcessed,
    required this.isBusy,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isBusy)
                const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              Expanded(
                child: Text(
                  statusText,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            hintText,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            children: [
              _StepChip(label: 'Record', done: hasRaw),
              _StepChip(label: 'Processed', done: hasProcessed),
              _StepChip(label: 'Ready', done: hasRaw && hasProcessed),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  final String label;
  final bool done;

  const _StepChip({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: done
            ? const Color(0xFFF4C95D).withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.10),
        border: Border.all(
          color: done
              ? const Color(0xFFF4C95D).withValues(alpha: 0.60)
              : Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Text(label),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;

  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  final PresetData data;
  final bool selected;
  final VoidCallback? onTap;

  const _PresetTile({required this.data, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 128.w,
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.r),
          color: selected
              ? const Color(0xFFF4C95D).withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: selected
                ? const Color(0xFFF4C95D).withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(data.icon, color: Colors.white, size: 24.sp),
            SizedBox(height: 8.h),
            Text(
              data.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.sp),
            ),
            SizedBox(height: 2.h),
            Text(
              data.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioVisualizerWidget extends StatelessWidget {
  final List<double> amplitudes;

  const _AudioVisualizerWidget({required this.amplitudes});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60.h,
      width: double.infinity,
      child: CustomPaint(
        painter: _AudioWaveformPainter(amplitudes: amplitudes, maxBars: 44),
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
    final paint = Paint()..style = PaintingStyle.fill;
    final barWidth = (size.width - ((maxBars - 1) * 3).w) / maxBars;
    final centerY = size.height / 2;

    int startIndex = amplitudes.length - maxBars;
    if (startIndex < 0) {
      startIndex = 0;
    }

    for (int i = 0; i < maxBars; i++) {
      final idx = startIndex + i;
      var amp = 0.06;
      if (idx >= 0 && idx < amplitudes.length) {
        amp = amplitudes[idx];
      }

      final barHeight = amp * size.height;
      final x = i * (barWidth + 3.w);
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x + barWidth / 2, centerY),
          width: barWidth,
          height: barHeight,
        ),
        Radius.circular(8.r),
      );

      paint.shader = const LinearGradient(
        colors: [Color(0xFFE5B94A), Color(0xFFFFE4A3)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect.outerRect);

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
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
            children: [Text(label), Text(value.toStringAsFixed(1))],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFFE5B94A),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
              thumbColor: const Color(0xFFF4C95D),
              overlayColor: const Color(0x66F4C95D),
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
