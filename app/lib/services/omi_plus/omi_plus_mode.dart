class OmiPlusMode {
  const OmiPlusMode._();

  /// Private Omi+ builds keep Omi device functionality but do not depend on
  /// Omi/Firebase identity, Omi subscriptions, or Omi-hosted AI/cloud state.
  static const bool standalone = bool.fromEnvironment('OMI_PLUS_STANDALONE', defaultValue: false);
}
