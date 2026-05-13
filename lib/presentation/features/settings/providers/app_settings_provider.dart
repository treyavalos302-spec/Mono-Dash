import 'dart:convert';

import 'package:flutter/widgets.dart' show Brightness;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/localization/generated/app_localizations.dart';

part 'app_settings_provider.g.dart';

enum AppIconVariant {
  defaultIcon('default', null, 'assets/icons/1panel_mate_app_icon_2.png'),
  dark('icon_dark', 'icon_dark', 'assets/icons/mono-dash-appicon-dark.png'),
  adaptive('adaptive', null, 'assets/icons/1panel_mate_app_icon_2.png');

  const AppIconVariant(
    this.storageName,
    this.alternateIconName,
    this.assetPath,
  );

  final String storageName;
  final String? alternateIconName;
  final String assetPath;

  String labelOf(AppLocalizations l10n) => switch (this) {
    AppIconVariant.defaultIcon => l10n.settings_appIcon_default,
    AppIconVariant.dark => l10n.settings_appIcon_dark,
    AppIconVariant.adaptive => l10n.settings_appIcon_adaptive,
  };

  String? effectiveAlternateIconName(Brightness brightness) => switch (this) {
    AppIconVariant.defaultIcon => null,
    AppIconVariant.dark => alternateIconName,
    AppIconVariant.adaptive =>
      brightness == Brightness.dark
          ? AppIconVariant.dark.alternateIconName
          : null,
  };

  String effectiveAssetPath(Brightness brightness) => switch (this) {
    AppIconVariant.adaptive =>
      brightness == Brightness.dark
          ? AppIconVariant.dark.assetPath
          : AppIconVariant.defaultIcon.assetPath,
    _ => assetPath,
  };

  static AppIconVariant fromName(String? name) {
    return values.firstWhere(
      (variant) =>
          variant.storageName == name || variant.alternateIconName == name,
      orElse: () => AppIconVariant.defaultIcon,
    );
  }
}

enum ServerCardStyle {
  terminal('terminal'),
  simple('simple');

  const ServerCardStyle(this.name);

  final String name;

  String labelOf(AppLocalizations l10n) => switch (this) {
    ServerCardStyle.terminal => l10n.settings_cardStyle_terminal,
    ServerCardStyle.simple => l10n.settings_cardStyle_simple,
  };

  static ServerCardStyle fromName(String? name) {
    return values.firstWhere(
      (style) => style.name == name,
      orElse: () => ServerCardStyle.simple,
    );
  }
}

enum AppAppearanceMode {
  system('system'),
  light('light'),
  dark('dark');

  const AppAppearanceMode(this.name);

  final String name;

  String labelOf(AppLocalizations l10n) => switch (this) {
    AppAppearanceMode.system => l10n.common_systemDefault,
    AppAppearanceMode.light => l10n.settings_appearance_modeLight,
    AppAppearanceMode.dark => l10n.settings_appearance_modeDark,
  };

  static AppAppearanceMode fromName(String? name) {
    return values.firstWhere(
      (mode) => mode.name == name,
      orElse: () => AppAppearanceMode.system,
    );
  }
}

class AppSettings {
  const AppSettings({
    this.appIconVariant = AppIconVariant.defaultIcon,
    this.serverCardStyle = ServerCardStyle.simple,
    this.appearanceMode = AppAppearanceMode.system,
    this.requestTimeoutSeconds = 60,
    this.serversAutoRefreshEnabled = true,
    this.serversRefreshIntervalSeconds = 5,
    this.customHeaders = const {},
  });

  final AppIconVariant appIconVariant;
  final ServerCardStyle serverCardStyle;
  final AppAppearanceMode appearanceMode;
  final int requestTimeoutSeconds;
  final bool serversAutoRefreshEnabled;
  final int serversRefreshIntervalSeconds;
  final Map<String, String> customHeaders;

  AppSettings copyWith({
    AppIconVariant? appIconVariant,
    ServerCardStyle? serverCardStyle,
    AppAppearanceMode? appearanceMode,
    int? requestTimeoutSeconds,
    bool? serversAutoRefreshEnabled,
    int? serversRefreshIntervalSeconds,
    Map<String, String>? customHeaders,
  }) {
    return AppSettings(
      appIconVariant: appIconVariant ?? this.appIconVariant,
      serverCardStyle: serverCardStyle ?? this.serverCardStyle,
      appearanceMode: appearanceMode ?? this.appearanceMode,
      requestTimeoutSeconds:
          requestTimeoutSeconds ?? this.requestTimeoutSeconds,
      serversAutoRefreshEnabled:
          serversAutoRefreshEnabled ?? this.serversAutoRefreshEnabled,
      serversRefreshIntervalSeconds:
          serversRefreshIntervalSeconds ?? this.serversRefreshIntervalSeconds,
      customHeaders: customHeaders ?? this.customHeaders,
    );
  }
}

@riverpod
class AppSettingsController extends _$AppSettingsController {
  static const _appIconVariantKey = 'app_icon_variant';
  static const _serverCardStyleKey = 'server_card_style';
  static const _appearanceModeKey = 'appearance_mode';
  static const _requestTimeoutSecondsKey = 'request_timeout_seconds';
  static const _serversAutoRefreshEnabledKey = 'servers_auto_refresh_enabled';
  static const _serversRefreshIntervalSecondsKey =
      'servers_refresh_interval_seconds';
  static const _customHeadersKey = 'custom_headers';
  static const defaultRequestTimeoutSeconds = 60;
  static const defaultServersRefreshIntervalSeconds = 5;

  @override
  Future<AppSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettings(
      appIconVariant: AppIconVariant.fromName(
        prefs.getString(_appIconVariantKey),
      ),
      serverCardStyle: ServerCardStyle.fromName(
        prefs.getString(_serverCardStyleKey),
      ),
      appearanceMode: AppAppearanceMode.fromName(
        prefs.getString(_appearanceModeKey),
      ),
      requestTimeoutSeconds:
          prefs.getInt(_requestTimeoutSecondsKey) ??
          defaultRequestTimeoutSeconds,
      serversAutoRefreshEnabled:
          prefs.getBool(_serversAutoRefreshEnabledKey) ?? true,
      serversRefreshIntervalSeconds:
          prefs.getInt(_serversRefreshIntervalSecondsKey) ??
          defaultServersRefreshIntervalSeconds,
      customHeaders: _decodeHeaders(prefs.getString(_customHeadersKey)),
    );
    return settings;
  }

  Future<void> setAppIconVariant(AppIconVariant variant) async {
    final previous = state.valueOrNull ?? const AppSettings();
    state = AsyncValue.data(previous.copyWith(appIconVariant: variant));

    final prefs = await SharedPreferences.getInstance();
    if (variant == AppIconVariant.defaultIcon) {
      await prefs.remove(_appIconVariantKey);
    } else {
      await prefs.setString(_appIconVariantKey, variant.storageName);
    }
  }

  Future<void> setServerCardStyle(ServerCardStyle style) async {
    final previous = state.valueOrNull ?? const AppSettings();
    state = AsyncValue.data(previous.copyWith(serverCardStyle: style));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverCardStyleKey, style.name);
  }

  Future<void> setAppearanceMode(AppAppearanceMode mode) async {
    final previous = state.valueOrNull ?? const AppSettings();
    state = AsyncValue.data(previous.copyWith(appearanceMode: mode));

    final prefs = await SharedPreferences.getInstance();
    if (mode == AppAppearanceMode.system) {
      await prefs.remove(_appearanceModeKey);
    } else {
      await prefs.setString(_appearanceModeKey, mode.name);
    }
  }

  Future<void> setRequestTimeoutSeconds(int seconds) async {
    final value = seconds.clamp(5, 300);
    final previous = state.valueOrNull ?? const AppSettings();
    state = AsyncValue.data(previous.copyWith(requestTimeoutSeconds: value));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_requestTimeoutSecondsKey, value);
  }

  Future<void> setServersAutoRefreshEnabled(bool enabled) async {
    final previous = state.valueOrNull ?? const AppSettings();
    state = AsyncValue.data(
      previous.copyWith(serversAutoRefreshEnabled: enabled),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_serversAutoRefreshEnabledKey, enabled);
  }

  Future<void> setServersRefreshIntervalSeconds(int seconds) async {
    final value = seconds.clamp(1, 300);
    final previous = state.valueOrNull ?? const AppSettings();
    state = AsyncValue.data(
      previous.copyWith(serversRefreshIntervalSeconds: value),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_serversRefreshIntervalSecondsKey, value);
  }

  Future<void> setCustomHeaders(Map<String, String> headers) async {
    final normalized = Map<String, String>.unmodifiable(headers);
    final previous = state.valueOrNull ?? const AppSettings();
    state = AsyncValue.data(previous.copyWith(customHeaders: normalized));

    final prefs = await SharedPreferences.getInstance();
    if (normalized.isEmpty) {
      await prefs.remove(_customHeadersKey);
    } else {
      await prefs.setString(_customHeadersKey, jsonEncode(normalized));
    }
  }

  static Map<String, String> _decodeHeaders(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      return const {};
    }
  }
}
