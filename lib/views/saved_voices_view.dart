import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../viewmodels/melody_viewmodel.dart';

class SavedVoicesView extends StatelessWidget {
  const SavedVoicesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MelodyViewModel>(
      builder: (context, provider, child) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text('Saved Voices'),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: Stack(
            children: [
              const _SavedBackdrop(),
              SafeArea(
                child: provider.hasSavedVoices
                    ? ListView.separated(
                        padding: EdgeInsets.all(16.w),
                        itemCount: provider.savedVoices.length,
                        separatorBuilder: (context, index) =>
                            SizedBox(height: 12.h),
                        itemBuilder: (context, index) {
                          final voice = provider.savedVoices[index];
                          final isPlaying =
                              provider.isPlaying &&
                              provider.currentPlaybackPath == voice.path;

                          return ClipRRect(
                            borderRadius: BorderRadius.circular(18.r),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: Container(
                                padding: EdgeInsets.all(14.w),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18.r),
                                  color: Colors.white.withValues(alpha: 0.09),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.16),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      voice.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text('Effect: ${voice.profile}'),
                                    SizedBox(height: 2.h),
                                    Text(
                                      'Saved: ${voice.createdAt}',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 10.h),
                                    Wrap(
                                      spacing: 8.w,
                                      runSpacing: 8.h,
                                      children: [
                                        FilledButton.icon(
                                          onPressed: () => provider
                                              .playSavedVoice(voice.path),
                                          icon: Icon(
                                            isPlaying
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                          ),
                                          label: Text(
                                            isPlaying ? 'Stop' : 'Play',
                                          ),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () => provider
                                              .shareSavedVoice(voice.path),
                                          icon: const Icon(Icons.share_rounded),
                                          label: const Text('Share'),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () async {
                                            final confirm =
                                                await showDialog<bool>(
                                                  context: context,
                                                  builder: (dialogContext) {
                                                    return AlertDialog(
                                                      title: const Text(
                                                        'Delete Saved Voice',
                                                      ),
                                                      content: Text(
                                                        'Delete "${voice.title}" permanently?',
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                dialogContext,
                                                              ).pop(false),
                                                          child: const Text(
                                                            'Cancel',
                                                          ),
                                                        ),
                                                        FilledButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                dialogContext,
                                                              ).pop(true),
                                                          child: const Text(
                                                            'Delete',
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                ) ??
                                                false;
                                            if (confirm) {
                                              await provider.deleteSavedVoice(
                                                voice.id,
                                              );
                                            }
                                          },
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                          ),
                                          label: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.w),
                          child: Text(
                            'No saved voices yet.\nRecord in Studio and tap Save.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SavedBackdrop extends StatelessWidget {
  const _SavedBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF003C72), Color(0xFF002D56), Color(0xFF00223D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned(
          top: -30,
          right: -20,
          child: _Orb(
            size: 220,
            color: const Color(0xFFFD4F00).withValues(alpha: 0.08),
          ),
        ),
        Positioned(
          bottom: -40,
          left: -20,
          child: _Orb(
            size: 240,
            color: const Color(0xFFFD4F00).withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;

  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.w,
      height: size.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 80, spreadRadius: 20)],
      ),
    );
  }
}
