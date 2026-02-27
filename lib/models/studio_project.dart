class StudioProject {
  final String id;
  final String name;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? rawPath;
  final String? processedPath;
  final String? activeProcessedPath;
  final String selectedPreset;
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

  const StudioProject({
    required this.id,
    required this.name,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.rawPath,
    required this.processedPath,
    required this.activeProcessedPath,
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'rawPath': rawPath,
    'processedPath': processedPath,
    'activeProcessedPath': activeProcessedPath,
    'selectedPreset': selectedPreset,
    'isManualMode': isManualMode,
    'eqBass': eqBass,
    'eqMid': eqMid,
    'eqTreble': eqTreble,
    'reverb': reverb,
    'trimStartSec': trimStartSec,
    'trimEndSec': trimEndSec,
    'fadeInSec': fadeInSec,
    'fadeOutSec': fadeOutSec,
    'noiseReduction': noiseReduction,
    'noiseGateDb': noiseGateDb,
    'pitchSemitones': pitchSemitones,
    'targetKey': targetKey,
  };

  factory StudioProject.fromJson(Map<String, dynamic> json) {
    return StudioProject(
      id: json['id'] as String,
      name: json['name'] as String,
      notes: json['notes'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      rawPath: json['rawPath'] as String?,
      processedPath: json['processedPath'] as String?,
      activeProcessedPath: json['activeProcessedPath'] as String?,
      selectedPreset: json['selectedPreset'] as String,
      isManualMode: json['isManualMode'] as bool? ?? false,
      eqBass: (json['eqBass'] as num?)?.toDouble() ?? 0.0,
      eqMid: (json['eqMid'] as num?)?.toDouble() ?? 0.0,
      eqTreble: (json['eqTreble'] as num?)?.toDouble() ?? 0.0,
      reverb: (json['reverb'] as num?)?.toDouble() ?? 0.0,
      trimStartSec: (json['trimStartSec'] as num?)?.toDouble() ?? 0.0,
      trimEndSec: (json['trimEndSec'] as num?)?.toDouble() ?? 0.0,
      fadeInSec: (json['fadeInSec'] as num?)?.toDouble() ?? 0.0,
      fadeOutSec: (json['fadeOutSec'] as num?)?.toDouble() ?? 0.0,
      noiseReduction: (json['noiseReduction'] as num?)?.toDouble() ?? 0.0,
      noiseGateDb: (json['noiseGateDb'] as num?)?.toDouble() ?? -42.0,
      pitchSemitones: (json['pitchSemitones'] as num?)?.toDouble() ?? 0.0,
      targetKey: json['targetKey'] as String?,
    );
  }
}
