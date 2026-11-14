enum HistoryType { deposited, withdrawn }

class WalletHistoryEntry {
  final String title;
  final String description;
  final String time;
  final String dayGroup; // e.g. "Today", "Yesterday"
  final HistoryType type;

  const WalletHistoryEntry({
    required this.title,
    required this.description,
    required this.time,
    required this.dayGroup,
    required this.type,
  });
}
