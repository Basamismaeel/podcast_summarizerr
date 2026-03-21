enum SummaryStyle {
  insights,
  deepNotes,
  actionItems,
  smartChapters,
  keyQuotes;

  String get label => switch (this) {
        insights => 'Key Insights',
        deepNotes => 'Deep Notes',
        actionItems => 'Action Items',
        smartChapters => 'Smart Chapters',
        keyQuotes => 'Key Quotes',
      };

  String get icon => switch (this) {
        insights => '💡',
        deepNotes => '📝',
        actionItems => '✅',
        smartChapters => '📖',
        keyQuotes => '💬',
      };

  String toJson() => name;

  static SummaryStyle? fromJson(String? value) {
    if (value == null) return null;
    return SummaryStyle.values.where((e) => e.name == value).firstOrNull;
  }
}

enum SessionStatus {
  recording,
  queued,
  summarizing,
  done,
  error;

  String get label => switch (this) {
        recording => 'Recording',
        queued => 'Queued',
        summarizing => 'Summarizing',
        done => 'Done',
        error => 'Failed',
      };

  String toJson() => name;

  static SessionStatus fromJson(String value) =>
      SessionStatus.values.firstWhere((e) => e.name == value,
          orElse: () => SessionStatus.queued);
}

enum SaveMethod {
  notification,
  shake,
  siri,
  googleAssistant,
  manual;

  String get label => switch (this) {
        notification => 'Notification',
        shake => 'Shake',
        siri => 'Siri',
        googleAssistant => 'Google Assistant',
        manual => 'Manual',
      };

  String toJson() => name;

  static SaveMethod fromJson(String value) => SaveMethod.values
      .firstWhere((e) => e.name == value, orElse: () => SaveMethod.manual);
}
