import 'dart:math' as math;
import 'package:flutter/material.dart';

// ============================================================================
// 1. SOLAR EPHEMERIS & ATMOSPHERE DATA MODELS
// Parity with decompiled com.hark.android.core.ui.background & core.weather
// ============================================================================

class BackdropVector3 {
  final double x;
  final double y;
  final double z;

  const BackdropVector3({required this.x, required this.y, required this.z});

  factory BackdropVector3.fromJson(Map<String, dynamic> json) {
    return BackdropVector3(
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      z: (json['z'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'z': z};

  @override
  String toString() => 'BackdropVector3(x=$x, y=$y, z=$z)';
}

class BackdropSkyGrade {
  final double exposure;
  final double adaptation;
  final double gradientContrast;
  final double shoulder;
  final double saturation;
  final double vibrance;
  final double scotopic;
  final double twilightHue;
  final double twilightChroma;
  final double purpleLight;
  final double duskStretch;
  final double moonBoost;
  final double horizonBloom;
  final double blueHue;
  final double sunsetPink;
  final String framing;

  const BackdropSkyGrade({
    this.exposure = 0.777664168999131,
    this.adaptation = 0.24676937284934922,
    this.gradientContrast = 1.2,
    this.shoulder = 0.85,
    this.saturation = 1.38,
    this.vibrance = 0.46,
    this.scotopic = 0.6,
    this.twilightHue = 0.0,
    this.twilightChroma = 0.0,
    this.purpleLight = 0.59,
    this.duskStretch = 0.7,
    this.moonBoost = 0.0105,
    this.horizonBloom = 0.35,
    this.blueHue = -12.0,
    this.sunsetPink = 0.8,
    this.framing = 'default',
  });

  factory BackdropSkyGrade.fromJson(Map<String, dynamic> json) {
    return BackdropSkyGrade(
      exposure: (json['exposure'] as num?)?.toDouble() ?? 0.777664,
      adaptation: (json['adaptation'] as num?)?.toDouble() ?? 0.246769,
      gradientContrast: (json['gradientContrast'] as num?)?.toDouble() ?? 1.2,
      shoulder: (json['shoulder'] as num?)?.toDouble() ?? 0.85,
      saturation: (json['saturation'] as num?)?.toDouble() ?? 1.38,
      vibrance: (json['vibrance'] as num?)?.toDouble() ?? 0.46,
      scotopic: (json['scotopic'] as num?)?.toDouble() ?? 0.6,
      twilightHue: (json['twilightHue'] as num?)?.toDouble() ?? 0.0,
      twilightChroma: (json['twilightChroma'] as num?)?.toDouble() ?? 0.0,
      purpleLight: (json['purpleLight'] as num?)?.toDouble() ?? 0.59,
      duskStretch: (json['duskStretch'] as num?)?.toDouble() ?? 0.7,
      moonBoost: (json['moonBoost'] as num?)?.toDouble() ?? 0.0105,
      horizonBloom: (json['horizonBloom'] as num?)?.toDouble() ?? 0.35,
      blueHue: (json['blueHue'] as num?)?.toDouble() ?? -12.0,
      sunsetPink: (json['sunsetPink'] as num?)?.toDouble() ?? 0.8,
      framing: json['framing'] as String? ?? 'default',
    );
  }

  Map<String, dynamic> toJson() => {
        'exposure': exposure,
        'adaptation': adaptation,
        'gradientContrast': gradientContrast,
        'shoulder': shoulder,
        'saturation': saturation,
        'vibrance': vibrance,
        'scotopic': scotopic,
        'twilightHue': twilightHue,
        'twilightChroma': twilightChroma,
        'purpleLight': purpleLight,
        'duskStretch': duskStretch,
        'moonBoost': moonBoost,
        'horizonBloom': horizonBloom,
        'blueHue': blueHue,
        'sunsetPink': sunsetPink,
        'framing': framing,
      };
}

class BackdropSolarContext {
  final DateTime renderInstant;
  final double solarElevation;
  final double solarAzimuth;
  final double declination;
  final double hourAngle;
  final double sunDiskRadius;

  const BackdropSolarContext({
    required this.renderInstant,
    required this.solarElevation,
    required this.solarAzimuth,
    this.declination = 0.0,
    this.hourAngle = 0.0,
    this.sunDiskRadius = 0.045,
  });

  factory BackdropSolarContext.fromJson(Map<String, dynamic> json) {
    return BackdropSolarContext(
      renderInstant: json['renderInstant'] != null
          ? DateTime.parse(json['renderInstant'] as String)
          : DateTime.now(),
      solarElevation: (json['solarElevation'] as num?)?.toDouble() ?? 45.0,
      solarAzimuth: (json['solarAzimuth'] as num?)?.toDouble() ?? 180.0,
      declination: (json['declination'] as num?)?.toDouble() ?? 0.0,
      hourAngle: (json['hourAngle'] as num?)?.toDouble() ?? 0.0,
      sunDiskRadius: (json['sunDiskRadius'] as num?)?.toDouble() ?? 0.045,
    );
  }

  Map<String, dynamic> toJson() => {
        'renderInstant': renderInstant.toIso8601String(),
        'solarElevation': solarElevation,
        'solarAzimuth': solarAzimuth,
        'declination': declination,
        'hourAngle': hourAngle,
        'sunDiskRadius': sunDiskRadius,
      };
}

class BackdropAtmosphere {
  final int weatherCode;
  final double temperature;
  final double pressure;
  final double humidity;
  final double airDensity;

  const BackdropAtmosphere({
    this.weatherCode = 0,
    this.temperature = 20.0,
    this.pressure = 1013.25,
    this.humidity = 0.45,
    this.airDensity = 1.225,
  });

  factory BackdropAtmosphere.fromJson(Map<String, dynamic> json) {
    return BackdropAtmosphere(
      weatherCode: (json['weatherCode'] as num?)?.toInt() ?? 0,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 20.0,
      pressure: (json['pressure'] as num?)?.toDouble() ?? 1013.25,
      humidity: (json['humidity'] as num?)?.toDouble() ?? 0.45,
      airDensity: (json['airDensity'] as num?)?.toDouble() ?? 1.225,
    );
  }

  Map<String, dynamic> toJson() => {
        'weatherCode': weatherCode,
        'temperature': temperature,
        'pressure': pressure,
        'humidity': humidity,
        'airDensity': airDensity,
      };
}

class BackdropPrecipitation {
  final double rain;
  final double snow;
  final double drizzle;
  final double hail;
  final double probability;

  const BackdropPrecipitation({
    this.rain = 0.0,
    this.snow = 0.0,
    this.drizzle = 0.0,
    this.hail = 0.0,
    this.probability = 0.0,
  });

  factory BackdropPrecipitation.fromJson(Map<String, dynamic> json) {
    return BackdropPrecipitation(
      rain: (json['rain'] as num?)?.toDouble() ?? 0.0,
      snow: (json['snow'] as num?)?.toDouble() ?? 0.0,
      drizzle: (json['drizzle'] as num?)?.toDouble() ?? 0.0,
      hail: (json['hail'] as num?)?.toDouble() ?? 0.0,
      probability: (json['probability'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'rain': rain,
        'snow': snow,
        'drizzle': drizzle,
        'hail': hail,
        'probability': probability,
      };
}

/// Reverse-engineered Dalvik class: com.hark.android.core.ui.background.BackdropMotionFrame
class BackdropMotionFrame {
  final double animationTimeSeconds;
  final double solarElevation;
  final double solarAzimuth;
  final double cloudCover;
  final BackdropVector3 rayleighScattering;
  final BackdropVector3 mieScattering;
  final double ozoneAbsorption;
  final double sunIntensity;
  final double turbidity;
  final BackdropSkyGrade skyGrade;
  final BackdropSolarContext solarContext;
  final BackdropAtmosphere atmosphere;
  final BackdropPrecipitation precipitation;

  const BackdropMotionFrame({
    required this.animationTimeSeconds,
    required this.solarElevation,
    required this.solarAzimuth,
    this.cloudCover = 0.15,
    this.rayleighScattering = const BackdropVector3(x: 5.8e-6, y: 1.35e-5, z: 3.31e-5),
    this.mieScattering = const BackdropVector3(x: 2.1e-5, y: 2.1e-5, z: 2.1e-5),
    this.ozoneAbsorption = 0.0006,
    this.sunIntensity = 22.0,
    this.turbidity = 2.5,
    this.skyGrade = const BackdropSkyGrade(),
    required this.solarContext,
    this.atmosphere = const BackdropAtmosphere(),
    this.precipitation = const BackdropPrecipitation(),
  });

  BackdropMotionFrame motionForDraw({double? deltaSeconds}) {
    final nextTime = animationTimeSeconds + (deltaSeconds ?? 0.016);
    return BackdropMotionFrame(
      animationTimeSeconds: nextTime,
      solarElevation: solarElevation,
      solarAzimuth: solarAzimuth,
      cloudCover: cloudCover,
      rayleighScattering: rayleighScattering,
      mieScattering: mieScattering,
      ozoneAbsorption: ozoneAbsorption,
      sunIntensity: sunIntensity,
      turbidity: turbidity,
      skyGrade: skyGrade,
      solarContext: solarContext,
      atmosphere: atmosphere,
      precipitation: precipitation,
    );
  }

  static BackdropMotionFrame calculateForTime(DateTime time, {double cloudCover = 0.15}) {
    final hour = time.hour + (time.minute / 60.0);
    final elevation = math.sin((hour - 6.0) / 12.0 * math.pi) * 65.0;
    final azimuth = ((hour / 24.0) * 360.0) % 360.0;

    return BackdropMotionFrame(
      animationTimeSeconds: time.millisecondsSinceEpoch / 1000.0,
      solarElevation: elevation,
      solarAzimuth: azimuth,
      cloudCover: cloudCover,
      solarContext: BackdropSolarContext(
        renderInstant: time,
        solarElevation: elevation,
        solarAzimuth: azimuth,
      ),
      atmosphere: const BackdropAtmosphere(
        weatherCode: 0,
        temperature: 21.5,
        humidity: 0.42,
      ),
    );
  }

  factory BackdropMotionFrame.fromJson(Map<String, dynamic> json) {
    return BackdropMotionFrame(
      animationTimeSeconds: (json['animationTimeSeconds'] as num?)?.toDouble() ?? 0.0,
      solarElevation: (json['solarElevation'] as num?)?.toDouble() ?? 45.0,
      solarAzimuth: (json['solarAzimuth'] as num?)?.toDouble() ?? 180.0,
      cloudCover: (json['cloudCover'] as num?)?.toDouble() ?? 0.15,
      rayleighScattering: json['rayleighScattering'] != null
          ? BackdropVector3.fromJson(json['rayleighScattering'] as Map<String, dynamic>)
          : const BackdropVector3(x: 5.8e-6, y: 1.35e-5, z: 3.31e-5),
      mieScattering: json['mieScattering'] != null
          ? BackdropVector3.fromJson(json['mieScattering'] as Map<String, dynamic>)
          : const BackdropVector3(x: 2.1e-5, y: 2.1e-5, z: 2.1e-5),
      ozoneAbsorption: (json['ozoneAbsorption'] as num?)?.toDouble() ?? 0.0006,
      sunIntensity: (json['sunIntensity'] as num?)?.toDouble() ?? 22.0,
      turbidity: (json['turbidity'] as num?)?.toDouble() ?? 2.5,
      skyGrade: json['skyGrade'] != null
          ? BackdropSkyGrade.fromJson(json['skyGrade'] as Map<String, dynamic>)
          : const BackdropSkyGrade(),
      solarContext: json['solarContext'] != null
          ? BackdropSolarContext.fromJson(json['solarContext'] as Map<String, dynamic>)
          : BackdropSolarContext(
              renderInstant: DateTime.now(),
              solarElevation: 45.0,
              solarAzimuth: 180.0,
            ),
      atmosphere: json['atmosphere'] != null
          ? BackdropAtmosphere.fromJson(json['atmosphere'] as Map<String, dynamic>)
          : const BackdropAtmosphere(),
      precipitation: json['precipitation'] != null
          ? BackdropPrecipitation.fromJson(json['precipitation'] as Map<String, dynamic>)
          : const BackdropPrecipitation(),
    );
  }

  Map<String, dynamic> toJson() => {
        'animationTimeSeconds': animationTimeSeconds,
        'solarElevation': solarElevation,
        'solarAzimuth': solarAzimuth,
        'cloudCover': cloudCover,
        'rayleighScattering': rayleighScattering.toJson(),
        'mieScattering': mieScattering.toJson(),
        'ozoneAbsorption': ozoneAbsorption,
        'sunIntensity': sunIntensity,
        'turbidity': turbidity,
        'skyGrade': skyGrade.toJson(),
        'solarContext': solarContext.toJson(),
        'atmosphere': atmosphere.toJson(),
        'precipitation': precipitation.toJson(),
      };
}

// ============================================================================
// WEATHER DTO CONTRACTS (Dalvik parity com.hark.android.core.weather)
// ============================================================================

class SkyCurrentDto {
  final int weatherCode;
  final double temperature;
  final double cloudCover;
  final double windSpeed;
  final bool isDay;
  final double uvIndex;
  final double humidity;

  const SkyCurrentDto({
    this.weatherCode = 0,
    this.temperature = 19.5,
    this.cloudCover = 0.2,
    this.windSpeed = 4.2,
    this.isDay = true,
    this.uvIndex = 5.0,
    this.humidity = 48.0,
  });

  factory SkyCurrentDto.fromJson(Map<String, dynamic> json) {
    return SkyCurrentDto(
      weatherCode: (json['weatherCode'] as num?)?.toInt() ?? 0,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 19.5,
      cloudCover: (json['cloudCover'] as num?)?.toDouble() ?? 0.2,
      windSpeed: (json['windSpeed'] as num?)?.toDouble() ?? 4.2,
      isDay: json['isDay'] as bool? ?? true,
      uvIndex: (json['uvIndex'] as num?)?.toDouble() ?? 5.0,
      humidity: (json['humidity'] as num?)?.toDouble() ?? 48.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'weatherCode': weatherCode,
        'temperature': temperature,
        'cloudCover': cloudCover,
        'windSpeed': windSpeed,
        'isDay': isDay,
        'uvIndex': uvIndex,
        'humidity': humidity,
      };
}

class SkyHourlyDto {
  final DateTime timestamp;
  final double visibility;
  final double temperature;
  final double precipitationProbability;
  final double cloudCover;
  final double dewPoint;

  const SkyHourlyDto({
    required this.timestamp,
    this.visibility = 10000.0,
    this.temperature = 19.0,
    this.precipitationProbability = 0.05,
    this.cloudCover = 0.2,
    this.dewPoint = 11.0,
  });

  factory SkyHourlyDto.fromJson(Map<String, dynamic> json) {
    return SkyHourlyDto(
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      visibility: (json['visibility'] as num?)?.toDouble() ?? 10000.0,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 19.0,
      precipitationProbability:
          (json['precipitationProbability'] as num?)?.toDouble() ?? 0.05,
      cloudCover: (json['cloudCover'] as num?)?.toDouble() ?? 0.2,
      dewPoint: (json['dewPoint'] as num?)?.toDouble() ?? 11.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'visibility': visibility,
        'temperature': temperature,
        'precipitationProbability': precipitationProbability,
        'cloudCover': cloudCover,
        'dewPoint': dewPoint,
      };
}

class SkyAirQualityCurrentDto {
  final int airQualityIndex;
  final double pm25;
  final double pm10;
  final double o3;
  final double no2;

  const SkyAirQualityCurrentDto({
    this.airQualityIndex = 32,
    this.pm25 = 8.2,
    this.pm10 = 14.5,
    this.o3 = 45.0,
    this.no2 = 12.0,
  });

  factory SkyAirQualityCurrentDto.fromJson(Map<String, dynamic> json) {
    return SkyAirQualityCurrentDto(
      airQualityIndex: (json['airQualityIndex'] as num?)?.toInt() ?? 32,
      pm25: (json['pm25'] as num?)?.toDouble() ?? 8.2,
      pm10: (json['pm10'] as num?)?.toDouble() ?? 14.5,
      o3: (json['o3'] as num?)?.toDouble() ?? 45.0,
      no2: (json['no2'] as num?)?.toDouble() ?? 12.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'airQualityIndex': airQualityIndex,
        'pm25': pm25,
        'pm10': pm10,
        'o3': o3,
        'no2': no2,
      };
}

class SkyAirQualityDto {
  final SkyAirQualityCurrentDto current;

  const SkyAirQualityDto({this.current = const SkyAirQualityCurrentDto()});

  factory SkyAirQualityDto.fromJson(Map<String, dynamic> json) {
    return SkyAirQualityDto(
      current: json['current'] != null
          ? SkyAirQualityCurrentDto.fromJson(json['current'] as Map<String, dynamic>)
          : const SkyAirQualityCurrentDto(),
    );
  }

  Map<String, dynamic> toJson() => {'current': current.toJson()};
}

class SkyForecastDto {
  final SkyCurrentDto current;
  final List<SkyHourlyDto> hourly;
  final SkyAirQualityDto airQuality;

  const SkyForecastDto({
    this.current = const SkyCurrentDto(),
    this.hourly = const [],
    this.airQuality = const SkyAirQualityDto(),
  });

  factory SkyForecastDto.fromJson(Map<String, dynamic> json) {
    return SkyForecastDto(
      current: json['current'] != null
          ? SkyCurrentDto.fromJson(json['current'] as Map<String, dynamic>)
          : const SkyCurrentDto(),
      hourly: (json['hourly'] as List<dynamic>?)
              ?.map((e) => SkyHourlyDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      airQuality: json['airQuality'] != null
          ? SkyAirQualityDto.fromJson(json['airQuality'] as Map<String, dynamic>)
          : const SkyAirQualityDto(),
    );
  }

  Map<String, dynamic> toJson() => {
        'current': current.toJson(),
        'hourly': hourly.map((e) => e.toJson()).toList(),
        'airQuality': airQuality.toJson(),
      };

  BackdropMotionFrame toAtmosphere({DateTime? time}) {
    final targetTime = time ?? DateTime.now();
    return BackdropMotionFrame.calculateForTime(targetTime,
        cloudCover: current.cloudCover);
  }
}

// ============================================================================
// 2. SERVER-DRIVEN UI (SDUI) REMOTE WIDGET CONTRACTS
// ============================================================================

enum RemoteWidgetType {
  actionButton,
  miniAppCard,
  interactiveMetrics,
  metricRing,
  sparkline,
  unknown,
}

class HarkRemoteWidget {
  final String id;
  final RemoteWidgetType type;

  // Action Button Fields
  final String headline;
  final String verb;
  final String accentHex;
  final String targetWorkflow;
  final Map<String, dynamic> payload;
  final bool requiresBiometricAuth;
  final String iconName;

  // Mini App Card Fields
  final String title;
  final String subtitle;
  final String refreshCron;
  final List<String> connectorsRequired;
  final Map<String, dynamic> layout;
  final String scopedAgentPrompt;
  final bool isExpanded;

  // Interactive Metrics Fields
  final String metricTitle;
  final double metricValue;
  final double? targetValue;
  final String? unit;
  final String? trend;
  final List<double> sparklinePoints;
  final String colorHex;

  // Hierarchical nested widgets
  final List<HarkRemoteWidget> childWidgets;

  const HarkRemoteWidget({
    required this.id,
    required this.type,
    this.headline = '',
    this.verb = '',
    this.accentHex = '#0A84FF',
    this.targetWorkflow = '',
    this.payload = const {},
    this.requiresBiometricAuth = true,
    this.iconName = 'bolt',
    this.title = '',
    this.subtitle = '',
    this.refreshCron = '0 */4 * * *',
    this.connectorsRequired = const [],
    this.layout = const {},
    this.scopedAgentPrompt = '',
    this.isExpanded = false,
    this.metricTitle = '',
    this.metricValue = 0.0,
    this.targetValue,
    this.unit,
    this.trend,
    this.sparklinePoints = const [],
    this.colorHex = '#00E5FF',
    this.childWidgets = const [],
  });

  factory HarkRemoteWidget.fromJson(Map<String, dynamic> json) {
    final rawType = (json['type'] ?? json['widget_type'] ?? 'unknown').toString();
    RemoteWidgetType type;
    switch (rawType.toLowerCase()) {
      case 'action_button':
      case 'actionbutton':
        type = RemoteWidgetType.actionButton;
        break;
      case 'mini_app_card':
      case 'miniappcard':
      case 'dynamic_panel':
      case 'panel':
        type = RemoteWidgetType.miniAppCard;
        break;
      case 'interactive_metrics':
      case 'metrics':
        type = RemoteWidgetType.interactiveMetrics;
        break;
      case 'metric_ring':
        type = RemoteWidgetType.metricRing;
        break;
      case 'sparkline':
        type = RemoteWidgetType.sparkline;
        break;
      default:
        type = RemoteWidgetType.unknown;
    }

    // Children
    final rawChildren = json['widgets'] ?? json['children'];
    List<HarkRemoteWidget> children = [];
    if (rawChildren is List) {
      children = rawChildren
          .whereType<Map<String, dynamic>>()
          .map((c) => HarkRemoteWidget.fromJson(c))
          .toList();
    }

    // Sparkline points
    List<double> points = [];
    if (json['sparkline_points'] is List) {
      points = (json['sparkline_points'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
    } else if (json['data_points'] is List) {
      points = (json['data_points'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
    }

    return HarkRemoteWidget(
      id: json['id'] ?? json['panel_id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      headline: json['headline'] ?? json['title'] ?? '',
      verb: json['verb'] ?? '',
      accentHex: json['accent_hex'] ?? json['color'] ?? '#0A84FF',
      targetWorkflow: json['target_workflow'] ?? '',
      payload: json['payload'] is Map<String, dynamic>
          ? json['payload'] as Map<String, dynamic>
          : const {},
      requiresBiometricAuth: json['requires_biometric_auth'] as bool? ?? true,
      iconName: json['icon_name'] ?? 'bolt',
      title: json['title'] ?? json['headline'] ?? '',
      subtitle: json['subtitle'] ?? '',
      refreshCron: json['refresh_cron'] ?? '0 */4 * * *',
      connectorsRequired: (json['connectors_required'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      layout: json['layout'] is Map<String, dynamic>
          ? json['layout'] as Map<String, dynamic>
          : const {},
      scopedAgentPrompt: json['scoped_agent_prompt'] ?? '',
      isExpanded: json['is_expanded'] as bool? ?? false,
      metricTitle: json['metric_title'] ?? json['title'] ?? '',
      metricValue: (json['target_value'] ?? json['value'] as num?)?.toDouble() ?? 0.0,
      targetValue: (json['target_value'] as num?)?.toDouble(),
      unit: json['unit']?.toString(),
      trend: json['trend']?.toString(),
      sparklinePoints: points,
      colorHex: json['color'] ?? json['accent_hex'] ?? '#00E5FF',
      childWidgets: children,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'headline': headline,
        'verb': verb,
        'accent_hex': accentHex,
        'target_workflow': targetWorkflow,
        'payload': payload,
        'requires_biometric_auth': requiresBiometricAuth,
        'icon_name': iconName,
        'title': title,
        'subtitle': subtitle,
        'refresh_cron': refreshCron,
        'connectors_required': connectorsRequired,
        'layout': layout,
        'scoped_agent_prompt': scopedAgentPrompt,
        'is_expanded': isExpanded,
        'metric_title': metricTitle,
        'metric_value': metricValue,
        'target_value': targetValue,
        'unit': unit,
        'trend': trend,
        'sparkline_points': sparklinePoints,
        'color': colorHex,
        'widgets': childWidgets.map((c) => c.toJson()).toList(),
      };

  Color get parsedColor {
    try {
      final hex = accentHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF0A84FF);
    }
  }

  /// High-fidelity Apple-grade widget renderer
  Widget buildWidget(BuildContext context,
      {Function(String action, Map<String, dynamic> params)? onAction}) {
    switch (type) {
      case RemoteWidgetType.actionButton:
        return _buildActionButton(context, onAction);
      case RemoteWidgetType.miniAppCard:
        return _buildMiniAppCard(context, onAction);
      case RemoteWidgetType.interactiveMetrics:
      case RemoteWidgetType.metricRing:
      case RemoteWidgetType.sparkline:
        return _buildMetricWidget(context);
      case RemoteWidgetType.unknown:
        return const SizedBox.shrink();
    }
  }

  Widget _buildActionButton(BuildContext context,
      Function(String action, Map<String, dynamic> params)? onAction) {
    final color = parsedColor;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF141622).withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            onAction?.call(
              targetWorkflow.isNotEmpty ? targetWorkflow : 'execute',
              payload,
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: Icon(
                    requiresBiometricAuth
                        ? Icons.fingerprint_rounded
                        : Icons.flash_on_rounded,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headline.isNotEmpty ? headline : title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        verb.isNotEmpty ? verb : 'Execute',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniAppCard(BuildContext context,
      Function(String action, Map<String, dynamic> params)? onAction) {
    final color = parsedColor;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141724).withOpacity(0.88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.widgets_rounded, color: color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (connectorsRequired.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    connectorsRequired.first.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          if (scopedAgentPrompt.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              scopedAgentPrompt,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
          if (childWidgets.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...childWidgets.map((c) => c.buildWidget(context, onAction: onAction)),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricWidget(BuildContext context) {
    final color = parsedColor;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1E2E).withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                metricTitle.isNotEmpty ? metricTitle : title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    metricValue.toStringAsFixed(
                        metricValue.truncateToDouble() == metricValue ? 0 : 1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (unit != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      unit!,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (trend != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF30D158).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                trend!,
                style: const TextStyle(
                  color: Color(0xFF30D158),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// 3. DEEP LINK PARSER (hark-mobile:// & app.hark.com / auth.hark.com)
// ============================================================================

enum HarkRouteType {
  connectorsCallback,
  taskExecute,
  handoffStream,
  vaultUnlock,
  approvalPreview,
  unknown,
}

class HarkDeepLink {
  final Uri uri;
  final HarkRouteType routeType;
  final Map<String, String> parameters;

  const HarkDeepLink({
    required this.uri,
    required this.routeType,
    this.parameters = const {},
  });

  static HarkDeepLink? parse(String rawUri) {
    if (rawUri.trim().isEmpty) return null;
    try {
      final uri = Uri.parse(rawUri.trim());

      // Supported schemes: 'hark-mobile', 'http', 'https'
      if (uri.scheme == 'hark-mobile') {
        final host = uri.host.toLowerCase();
        final path = uri.path.toLowerCase();

        if (host == 'connectors' && (path == '/callback' || path.isEmpty)) {
          return HarkDeepLink(
            uri: uri,
            routeType: HarkRouteType.connectorsCallback,
            parameters: uri.queryParameters,
          );
        } else if (host == 'task' || path.contains('task')) {
          return HarkDeepLink(
            uri: uri,
            routeType: HarkRouteType.taskExecute,
            parameters: uri.queryParameters,
          );
        } else if (host == 'handoff' || path.contains('handoff')) {
          return HarkDeepLink(
            uri: uri,
            routeType: HarkRouteType.handoffStream,
            parameters: uri.queryParameters,
          );
        } else if (host == 'vault' || path.contains('vault')) {
          return HarkDeepLink(
            uri: uri,
            routeType: HarkRouteType.vaultUnlock,
            parameters: uri.queryParameters,
          );
        } else if (host == 'approval' || path.contains('approval')) {
          return HarkDeepLink(
            uri: uri,
            routeType: HarkRouteType.approvalPreview,
            parameters: uri.queryParameters,
          );
        }
        return HarkDeepLink(
          uri: uri,
          routeType: HarkRouteType.unknown,
          parameters: uri.queryParameters,
        );
      } else if (uri.scheme == 'https' || uri.scheme == 'http') {
        final host = uri.host.toLowerCase();
        if (host == 'app.hark.com' || host == 'auth.hark.com') {
          if (uri.path.contains('/callback') || uri.path.contains('/oauth')) {
            return HarkDeepLink(
              uri: uri,
              routeType: HarkRouteType.connectorsCallback,
              parameters: uri.queryParameters,
            );
          } else if (uri.path.contains('/task')) {
            return HarkDeepLink(
              uri: uri,
              routeType: HarkRouteType.taskExecute,
              parameters: uri.queryParameters,
            );
          } else if (uri.path.contains('/vault')) {
            return HarkDeepLink(
              uri: uri,
              routeType: HarkRouteType.vaultUnlock,
              parameters: uri.queryParameters,
            );
          }
        }
      }
      return HarkDeepLink(
        uri: uri,
        routeType: HarkRouteType.unknown,
        parameters: uri.queryParameters,
      );
    } catch (_) {
      return null;
    }
  }

  bool get isConnectorsCallback => routeType == HarkRouteType.connectorsCallback;
  bool get isTaskExecute => routeType == HarkRouteType.taskExecute;
  bool get isHandoffStream => routeType == HarkRouteType.handoffStream;
  bool get isVaultUnlock => routeType == HarkRouteType.vaultUnlock;
}
