import 'package:flutter/material.dart';
import 'vocal_preset.dart';

class PresetData {
  final VocalPreset preset;
  final String title;
  final String subtitle;
  final IconData icon;

  const PresetData({
    required this.preset,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
