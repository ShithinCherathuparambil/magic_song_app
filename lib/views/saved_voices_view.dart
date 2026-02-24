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
              Positioned(
                top: -40.h,
                left: -40.w,
                child: Container(
                  width: 260.w,
                  height: 260.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00FFCC).withValues(alpha: 0.14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00FFCC).withValues(alpha: 0.18),
                        blurRadius: 90.r,
                        spreadRadius: 35.r,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: -40.h,
                right: -40.w,
                child: Container(
                  width: 240.w,
                  height: 240.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF7B2CBF).withValues(alpha: 0.12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7B2CBF).withValues(alpha: 0.18),
                        blurRadius: 90.r,
                        spreadRadius: 35.r,
                      ),
                    ],
                  ),
                ),
              ),
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

                          return Container(
                            padding: EdgeInsets.all(14.w),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.14),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  voice.title,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Effect: ${voice.profile}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Saved: ${voice.createdAt}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                SizedBox(height: 10.h),
                                Wrap(
                                  spacing: 10.w,
                                  runSpacing: 8.h,
                                  children: [
                                    FilledButton.icon(
                                      onPressed: () =>
                                          provider.playSavedVoice(voice.path),
                                      icon: Icon(
                                        isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                      ),
                                      label: Text(isPlaying ? 'Stop' : 'Play'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          provider.shareSavedVoice(voice.path),
                                      icon: const Icon(Icons.share_rounded),
                                      label: const Text('Share'),
                                    ),
                                    IconButton(
                                      onPressed: () async {
                                        final confirmed = await showDialog<bool>(
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
                                                  onPressed: () => Navigator.of(
                                                    dialogContext,
                                                  ).pop(false),
                                                  child: const Text('Cancel'),
                                                ),
                                                FilledButton(
                                                  onPressed: () => Navigator.of(
                                                    dialogContext,
                                                  ).pop(true),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            );
                                          },
                                        );

                                        if (confirmed == true) {
                                          await provider.deleteSavedVoice(
                                            voice.id,
                                          );
                                        }
                                      },
                                      tooltip: 'Delete',
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.w),
                          child: Text(
                            'No saved voices yet.\nRecord and tap Save in Studio.',
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
