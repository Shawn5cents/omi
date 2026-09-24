enum OmiPlusAssistantTarget {
  omi,
  auto,
  chatgpt,
  claude,
  gemini,
  local,
  all;

  static OmiPlusAssistantTarget fromStorage(String? value) {
    return OmiPlusAssistantTarget.values.firstWhere(
      (target) => target.name == value,
      orElse: () => OmiPlusAssistantTarget.omi,
    );
  }
}

class OmiPlusSettings {
  const OmiPlusSettings({
    this.enabled = false,
    this.assistantTarget = OmiPlusAssistantTarget.omi,
    this.localSttEnabled = false,
    this.localTtsEnabled = false,
  });

  final bool enabled;
  final OmiPlusAssistantTarget assistantTarget;
  final bool localSttEnabled;
  final bool localTtsEnabled;

  OmiPlusSettings copyWith({
    bool? enabled,
    OmiPlusAssistantTarget? assistantTarget,
    bool? localSttEnabled,
    bool? localTtsEnabled,
  }) {
    return OmiPlusSettings(
      enabled: enabled ?? this.enabled,
      assistantTarget: assistantTarget ?? this.assistantTarget,
      localSttEnabled: localSttEnabled ?? this.localSttEnabled,
      localTtsEnabled: localTtsEnabled ?? this.localTtsEnabled,
    );
  }
}
