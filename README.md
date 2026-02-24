# magic_song

Flutter app for melody vocal practice:
- Record voice
- Apply vocal EQ/effects presets
- Play processed output
- Keep a YouTube reference URL as tonal target

## Implemented
- Voice recording (`record` package, AAC 44.1kHz/192kbps)
- Offline vocal processing with FFmpeg filters:
  - high-pass / low-pass
  - EQ bands
  - compressor
  - limiter
  - short echo on melody preset
- Playback with `just_audio`
- Presets:
  - Clean
  - Warm Melody (recommended)
  - Bright Lead

## Platform permissions
- Android: `RECORD_AUDIO`, `MODIFY_AUDIO_SETTINGS`
- iOS: `NSMicrophoneUsageDescription`

## Run
```bash
flutter pub get
flutter run
```

## Reference used
YouTube URL (provided):
`https://www.youtube.com/watch?v=166NHp0hEQE&list=RD166NHp0hEQE&start_radio=1`

Resolved metadata:
- Title: `Thoomanjin Nenjilothungi Cover | Soulful Rendition | Evergreen Malayalam Song`
- Channel: `Patrick Michael`
