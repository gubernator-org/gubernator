/// Regulatory & Security Compliance models (ENS, NIS2, CIS Docker, ISO 27001, DORA).
library;

// ---------------------------------------------------------------------------
// ESQUEMA NACIONAL DE SEGURIDAD (ENS RD 311/2022) MODELS
// ---------------------------------------------------------------------------

class ENSMeasureModel {
  final String id;
  final String name;
  final String area;
  final String dimension;
  final List<String> applicableLevels;
  final String status; // COMPLIANT, PARTIAL, NON_COMPLIANT
  final double score;
  final String evidence;
  final String recommendation;
  final double weight;

  ENSMeasureModel({
    required this.id,
    required this.name,
    required this.area,
    required this.dimension,
    required this.applicableLevels,
    required this.status,
    required this.score,
    required this.evidence,
    required this.recommendation,
    required this.weight,
  });

  bool get isCompliant => status == 'COMPLIANT';
  bool get isPartial => status == 'PARTIAL';
  bool get isNonCompliant => status == 'NON_COMPLIANT';

  factory ENSMeasureModel.fromJson(Map<String, dynamic> json) {
    final levels = <String>[];
    if (json['applicable_levels'] != null && json['applicable_levels'] is List) {
      for (final l in json['applicable_levels']) {
        levels.add(l.toString());
      }
    }
    return ENSMeasureModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      area: json['area'] ?? '',
      dimension: json['dimension'] ?? '',
      applicableLevels: levels,
      status: json['status'] ?? 'NON_COMPLIANT',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      evidence: json['evidence'] ?? '',
      recommendation: json['recommendation'] ?? '',
      weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class ENSSummaryModel {
  final String evaluatedAt;
  final String clusterStatus;
  final double basicoScore;
  final double medioScore;
  final double altoScore;
  final String overallCategory; // BASICO, MEDIO, ALTO, INSUFICIENTE
  final int compliantCount;
  final int partialCount;
  final int nonCompliantCount;
  final int totalMeasures;
  final List<ENSMeasureModel> measures;

  ENSSummaryModel({
    required this.evaluatedAt,
    required this.clusterStatus,
    required this.basicoScore,
    required this.medioScore,
    required this.altoScore,
    required this.overallCategory,
    required this.compliantCount,
    required this.partialCount,
    required this.nonCompliantCount,
    required this.totalMeasures,
    required this.measures,
  });

  factory ENSSummaryModel.fromJson(Map<String, dynamic> json) {
    final mList = <ENSMeasureModel>[];
    if (json['measures'] != null && json['measures'] is List) {
      for (final m in json['measures']) {
        if (m is Map<String, dynamic>) {
          mList.add(ENSMeasureModel.fromJson(m));
        }
      }
    }
    return ENSSummaryModel(
      evaluatedAt: json['evaluated_at'] ?? '',
      clusterStatus: json['cluster_status'] ?? 'ACTIVE',
      basicoScore: (json['basico_score'] as num?)?.toDouble() ?? 0.0,
      medioScore: (json['medio_score'] as num?)?.toDouble() ?? 0.0,
      altoScore: (json['alto_score'] as num?)?.toDouble() ?? 0.0,
      overallCategory: json['overall_category'] ?? 'INSUFICIENTE',
      compliantCount: (json['compliant_count'] as num?)?.toInt() ?? 0,
      partialCount: (json['partial_count'] as num?)?.toInt() ?? 0,
      nonCompliantCount: (json['non_compliant_count'] as num?)?.toInt() ?? 0,
      totalMeasures: (json['total_measures'] as num?)?.toInt() ?? 0,
      measures: mList,
    );
  }
}

// -----------------------------------------------------------------------------
// NIS 2 Directive (EU 2022/2555) Compliance Models
// -----------------------------------------------------------------------------

class NIS2MeasureModel {
  final String id;
  final String article;
  final String name;
  final String domain;
  final List<String> applicableEntities;
  final String status; // COMPLIANT, PARTIAL, NON_COMPLIANT
  final double score;
  final double weight;
  final String evidence;
  final String remediation;

  NIS2MeasureModel({
    required this.id,
    required this.article,
    required this.name,
    required this.domain,
    required this.applicableEntities,
    required this.status,
    required this.score,
    required this.weight,
    required this.evidence,
    required this.remediation,
  });

  bool get isCompliant => status == 'COMPLIANT';
  bool get isPartial => status == 'PARTIAL';
  bool get isNonCompliant => status == 'NON_COMPLIANT';

  factory NIS2MeasureModel.fromJson(Map<String, dynamic> json) {
    final entities = <String>[];
    if (json['applicable_entities'] != null && json['applicable_entities'] is List) {
      for (final e in json['applicable_entities']) {
        entities.add(e.toString());
      }
    }
    return NIS2MeasureModel(
      id: json['id'] ?? '',
      article: json['article'] ?? '',
      name: json['name'] ?? '',
      domain: json['domain'] ?? '',
      applicableEntities: entities,
      status: json['status'] ?? 'NON_COMPLIANT',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
      evidence: json['evidence'] ?? '',
      remediation: json['remediation'] ?? '',
    );
  }
}

class NIS2SummaryModel {
  final String evaluatedAt;
  final String clusterStatus;
  final double essentialScore;
  final double importantScore;
  final String overallReadiness; // HIGH, MEDIUM, BASIC, INSUFFICIENT
  final int compliantCount;
  final int partialCount;
  final int nonCompliantCount;
  final int totalMeasures;
  final List<NIS2MeasureModel> measures;

  NIS2SummaryModel({
    required this.evaluatedAt,
    required this.clusterStatus,
    required this.essentialScore,
    required this.importantScore,
    required this.overallReadiness,
    required this.compliantCount,
    required this.partialCount,
    required this.nonCompliantCount,
    required this.totalMeasures,
    required this.measures,
  });

  factory NIS2SummaryModel.fromJson(Map<String, dynamic> json) {
    final mList = <NIS2MeasureModel>[];
    if (json['measures'] != null && json['measures'] is List) {
      for (final m in json['measures']) {
        if (m is Map<String, dynamic>) {
          mList.add(NIS2MeasureModel.fromJson(m));
        }
      }
    }
    return NIS2SummaryModel(
      evaluatedAt: json['evaluated_at'] ?? '',
      clusterStatus: json['cluster_status'] ?? 'ACTIVE',
      essentialScore: (json['essential_score'] as num?)?.toDouble() ?? 0.0,
      importantScore: (json['important_score'] as num?)?.toDouble() ?? 0.0,
      overallReadiness: json['overall_readiness'] ?? 'INSUFFICIENT',
      compliantCount: (json['compliant_count'] as num?)?.toInt() ?? 0,
      partialCount: (json['partial_count'] as num?)?.toInt() ?? 0,
      nonCompliantCount: (json['non_compliant_count'] as num?)?.toInt() ?? 0,
      totalMeasures: (json['total_measures'] as num?)?.toInt() ?? 0,
      measures: mList,
    );
  }
}

// -----------------------------------------------------------------------------
// CIS Docker Benchmark v1.6.0 Compliance Models
// -----------------------------------------------------------------------------

class CISDockerCheckModel {
  final String id;
  final String section;
  final String title;
  final String level; // "Level 1" or "Level 2"
  final bool scored;
  final String status; // "PASS", "WARN", "FAIL", "INFO"
  final String evidence;
  final String remediation;
  final String audit;

  CISDockerCheckModel({
    required this.id,
    required this.section,
    required this.title,
    required this.level,
    required this.scored,
    required this.status,
    required this.evidence,
    required this.remediation,
    required this.audit,
  });

  bool get isPass => status == 'PASS';
  bool get isWarn => status == 'WARN';
  bool get isFail => status == 'FAIL';
  bool get isInfo => status == 'INFO';
  bool get isLevel1 => level == 'Level 1';
  bool get isLevel2 => level == 'Level 2';

  factory CISDockerCheckModel.fromJson(Map<String, dynamic> json) {
    return CISDockerCheckModel(
      id: json['id'] ?? '',
      section: json['section'] ?? '',
      title: json['title'] ?? '',
      level: json['level'] ?? 'Level 1',
      scored: json['scored'] ?? true,
      status: json['status'] ?? 'FAIL',
      evidence: json['evidence'] ?? '',
      remediation: json['remediation'] ?? '',
      audit: json['audit'] ?? '',
    );
  }
}

class CISDockerSummaryModel {
  final String evaluatedAt;
  final String benchmarkVersion;
  final int totalChecks;
  final int passCount;
  final int warnCount;
  final int failCount;
  final int infoCount;
  final double scorePercent;
  final double level1Score;
  final double level2Score;
  final String postureGrade;
  final List<CISDockerCheckModel> checks;

  CISDockerSummaryModel({
    required this.evaluatedAt,
    required this.benchmarkVersion,
    required this.totalChecks,
    required this.passCount,
    required this.warnCount,
    required this.failCount,
    required this.infoCount,
    required this.scorePercent,
    required this.level1Score,
    required this.level2Score,
    required this.postureGrade,
    required this.checks,
  });

  factory CISDockerSummaryModel.fromJson(Map<String, dynamic> json) {
    final cList = <CISDockerCheckModel>[];
    if (json['checks'] != null && json['checks'] is List) {
      for (final c in json['checks']) {
        if (c is Map<String, dynamic>) {
          cList.add(CISDockerCheckModel.fromJson(c));
        }
      }
    }
    return CISDockerSummaryModel(
      evaluatedAt: json['evaluated_at'] ?? '',
      benchmarkVersion: json['benchmark_version'] ?? 'v1.6.0',
      totalChecks: (json['total_checks'] as num?)?.toInt() ?? 0,
      passCount: (json['pass_count'] as num?)?.toInt() ?? 0,
      warnCount: (json['warn_count'] as num?)?.toInt() ?? 0,
      failCount: (json['fail_count'] as num?)?.toInt() ?? 0,
      infoCount: (json['info_count'] as num?)?.toInt() ?? 0,
      scorePercent: (json['score_percent'] as num?)?.toDouble() ?? 0.0,
      level1Score: (json['level1_score'] as num?)?.toDouble() ?? 0.0,
      level2Score: (json['level2_score'] as num?)?.toDouble() ?? 0.0,
      postureGrade: json['posture_grade'] ?? 'B',
      checks: cList,
    );
  }
}

// -----------------------------------------------------------------------------
// ISO/IEC 27001:2022 ANNEX A COMPLIANCE MODELS
// -----------------------------------------------------------------------------

class ISO27001ControlModel {
  final String id;
  final String theme; // "A.5 Organizational" or "A.8 Technological"
  final String title;
  final String description;
  final String status; // "COMPLIANT", "PARTIAL", "NON_COMPLIANT"
  final double score;
  final double weight;
  final String evidence;
  final String remediation;
  final String audit;

  ISO27001ControlModel({
    required this.id,
    required this.theme,
    required this.title,
    required this.description,
    required this.status,
    required this.score,
    required this.weight,
    required this.evidence,
    required this.remediation,
    required this.audit,
  });

  bool get isCompliant => status == 'COMPLIANT';
  bool get isPartial => status == 'PARTIAL';
  bool get isNonCompliant => status == 'NON_COMPLIANT';
  bool get isThemeA5 => theme.contains('A.5');
  bool get isThemeA8 => theme.contains('A.8');

  factory ISO27001ControlModel.fromJson(Map<String, dynamic> json) {
    return ISO27001ControlModel(
      id: json['id'] ?? '',
      theme: json['theme'] ?? 'A.8 Technological',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'NON_COMPLIANT',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
      evidence: json['evidence'] ?? '',
      remediation: json['remediation'] ?? '',
      audit: json['audit'] ?? '',
    );
  }
}

class ISO27001SummaryModel {
  final String evaluatedAt;
  final String standardVersion;
  final int totalControls;
  final int compliantCount;
  final int partialCount;
  final int nonCompliantCount;
  final double overallScore;
  final double themeA5Score;
  final double themeA8Score;
  final String postureGrade;
  final String statementOfApplicability;
  final List<ISO27001ControlModel> controls;

  ISO27001SummaryModel({
    required this.evaluatedAt,
    required this.standardVersion,
    required this.totalControls,
    required this.compliantCount,
    required this.partialCount,
    required this.nonCompliantCount,
    required this.overallScore,
    required this.themeA5Score,
    required this.themeA8Score,
    required this.postureGrade,
    required this.statementOfApplicability,
    required this.controls,
  });

  factory ISO27001SummaryModel.fromJson(Map<String, dynamic> json) {
    final cList = <ISO27001ControlModel>[];
    if (json['controls'] != null && json['controls'] is List) {
      for (final c in json['controls']) {
        if (c is Map<String, dynamic>) {
          cList.add(ISO27001ControlModel.fromJson(c));
        }
      }
    }
    return ISO27001SummaryModel(
      evaluatedAt: json['evaluated_at'] ?? '',
      standardVersion: json['standard_version'] ?? 'ISO/IEC 27001:2022',
      totalControls: (json['total_controls'] as num?)?.toInt() ?? 0,
      compliantCount: (json['compliant_count'] as num?)?.toInt() ?? 0,
      partialCount: (json['partial_count'] as num?)?.toInt() ?? 0,
      nonCompliantCount: (json['non_compliant_count'] as num?)?.toInt() ?? 0,
      overallScore: (json['overall_score'] as num?)?.toDouble() ?? 0.0,
      themeA5Score: (json['theme_a5_score'] as num?)?.toDouble() ?? 0.0,
      themeA8Score: (json['theme_a8_score'] as num?)?.toDouble() ?? 0.0,
      postureGrade: json['posture_grade'] ?? 'B',
      statementOfApplicability: json['statement_of_applicability'] ?? '',
      controls: cList,
    );
  }
}

// -----------------------------------------------------------------------------
// DORA (Regulation EU 2022/2554) Compliance Models
// -----------------------------------------------------------------------------

class DORAMeasureModel {
  final String id;
  final String pillar;
  final String article;
  final String title;
  final String description;
  final String status; // COMPLIANT, PARTIAL, NON_COMPLIANT
  final double score;
  final double weight;
  final String evidence;
  final String remediation;

  DORAMeasureModel({
    required this.id,
    required this.pillar,
    required this.article,
    required this.title,
    required this.description,
    required this.status,
    required this.score,
    required this.weight,
    required this.evidence,
    required this.remediation,
  });

  bool get isCompliant => status == 'COMPLIANT';
  bool get isPartial => status == 'PARTIAL';
  bool get isNonCompliant => status == 'NON_COMPLIANT';

  factory DORAMeasureModel.fromJson(Map<String, dynamic> json) {
    return DORAMeasureModel(
      id: json['id'] ?? '',
      pillar: json['pillar'] ?? '',
      article: json['article'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'NON_COMPLIANT',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
      evidence: json['evidence'] ?? '',
      remediation: json['remediation'] ?? '',
    );
  }
}

class DORASummaryModel {
  final String evaluatedAt;
  final String standardVersion;
  final double overallScore;
  final String overallReadiness; // HIGH, MEDIUM, BASIC, INSUFFICIENT
  final double pillar1Score;
  final double pillar2Score;
  final double pillar3Score;
  final double pillar4Score;
  final double pillar5Score;
  final int compliantCount;
  final int partialCount;
  final int nonCompliantCount;
  final int totalMeasures;
  final List<DORAMeasureModel> measures;

  DORASummaryModel({
    required this.evaluatedAt,
    required this.standardVersion,
    required this.overallScore,
    required this.overallReadiness,
    required this.pillar1Score,
    required this.pillar2Score,
    required this.pillar3Score,
    required this.pillar4Score,
    required this.pillar5Score,
    required this.compliantCount,
    required this.partialCount,
    required this.nonCompliantCount,
    required this.totalMeasures,
    required this.measures,
  });

  factory DORASummaryModel.fromJson(Map<String, dynamic> json) {
    final mList = <DORAMeasureModel>[];
    if (json['measures'] != null && json['measures'] is List) {
      for (final m in json['measures']) {
        if (m is Map<String, dynamic>) {
          mList.add(DORAMeasureModel.fromJson(m));
        }
      }
    }
    return DORASummaryModel(
      evaluatedAt: json['evaluated_at'] ?? '',
      standardVersion: json['standard_version'] ?? 'Regulation (EU) 2022/2554 (DORA)',
      overallScore: (json['overall_score'] as num?)?.toDouble() ?? 0.0,
      overallReadiness: json['overall_readiness'] ?? 'INSUFFICIENT',
      pillar1Score: (json['pillar1_score'] as num?)?.toDouble() ?? 0.0,
      pillar2Score: (json['pillar2_score'] as num?)?.toDouble() ?? 0.0,
      pillar3Score: (json['pillar3_score'] as num?)?.toDouble() ?? 0.0,
      pillar4Score: (json['pillar4_score'] as num?)?.toDouble() ?? 0.0,
      pillar5Score: (json['pillar5_score'] as num?)?.toDouble() ?? 0.0,
      compliantCount: (json['compliant_count'] as num?)?.toInt() ?? 0,
      partialCount: (json['partial_count'] as num?)?.toInt() ?? 0,
      nonCompliantCount: (json['non_compliant_count'] as num?)?.toInt() ?? 0,
      totalMeasures: (json['total_measures'] as num?)?.toInt() ?? 0,
      measures: mList,
    );
  }
}

// -----------------------------------------------------------------------------
// Unified Continuous Compliance & Regulatory Suite Models
// -----------------------------------------------------------------------------

class StandardScoreModel {
  final String name;
  final String code; // "ENS", "NIS2", "CIS", "ISO27001"
  final double score;
  final String status;
  final String category;
  final int compliantCount;
  final int totalMeasures;
  final String evaluatedAt;

  StandardScoreModel({
    required this.name,
    required this.code,
    required this.score,
    required this.status,
    required this.category,
    required this.compliantCount,
    required this.totalMeasures,
    required this.evaluatedAt,
  });

  factory StandardScoreModel.fromJson(Map<String, dynamic> json) {
    return StandardScoreModel(
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'NON_COMPLIANT',
      category: json['category'] ?? '',
      compliantCount: (json['compliant_count'] as num?)?.toInt() ?? 0,
      totalMeasures: (json['total_measures'] as num?)?.toInt() ?? 0,
      evaluatedAt: json['evaluated_at'] ?? '',
    );
  }
}

class ComplianceOverviewModel {
  final String evaluatedAt;
  final String triggerSource;
  final double overallScore;
  final String overallStatus;
  final List<StandardScoreModel> standards;
  final List<String> degradedStandards;

  ComplianceOverviewModel({
    required this.evaluatedAt,
    required this.triggerSource,
    required this.overallScore,
    required this.overallStatus,
    required this.standards,
    required this.degradedStandards,
  });

  factory ComplianceOverviewModel.fromJson(Map<String, dynamic> json) {
    final stds = <StandardScoreModel>[];
    if (json['standards'] != null && json['standards'] is List) {
      for (final item in json['standards']) {
        if (item is Map<String, dynamic>) {
          stds.add(StandardScoreModel.fromJson(item));
        }
      }
    }
    final degraded = <String>[];
    if (json['degraded_standards'] != null && json['degraded_standards'] is List) {
      for (final d in json['degraded_standards']) {
        degraded.add(d.toString());
      }
    }
    return ComplianceOverviewModel(
      evaluatedAt: json['evaluated_at'] ?? '',
      triggerSource: json['trigger_source'] ?? '',
      overallScore: (json['overall_score'] as num?)?.toDouble() ?? 0.0,
      overallStatus: json['overall_status'] ?? 'ACTION_REQUIRED',
      standards: stds,
      degradedStandards: degraded,
    );
  }

  StandardScoreModel? getStandard(String code) {
    for (final s in standards) {
      if (s.code.toUpperCase() == code.toUpperCase()) return s;
    }
    return null;
  }
}
