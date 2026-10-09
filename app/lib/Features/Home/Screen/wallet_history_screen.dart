import 'package:dyspatch_app/core/api/dyspatch_api.dart';
import 'package:dyspatch_app/core/utils/format.dart';
import 'package:flutter/material.dart';

enum HistoryType { delivered, cancelled, topup, transfer }

class WalletHistoryEntry {
  final HistoryType type;
  final String title;
  final String description;
  final String timeAgo;
  final String dateGroup; // e.g. "Today", "Yesterday", "June 24"

  const WalletHistoryEntry({
    required this.type,
    required this.title,
    required this.description,
    required this.timeAgo,
    required this.dateGroup,
  });

  factory WalletHistoryEntry.fromJson(Map<String, dynamic> j) {
    final cat = (j['category'] ?? '') as String;
    final type = switch (cat) {
      'topup' || 'refund' || 'delivery_earning' => HistoryType.topup,
      'withdrawal' || 'withdrawal_fee' => HistoryType.transfer,
      'delivery_payment' => HistoryType.delivered,
      _ => j['type'] == 'credit' ? HistoryType.topup : HistoryType.cancelled,
    };
    final when = parseTime(j['created_at']);
    final amount = (j['amount'] ?? '') as String;
    final desc = (j['description'] ?? '') as String;
    return WalletHistoryEntry(
      type: type,
      title: (j['title'] ?? '') as String,
      description: '$desc · $amount${j['track_id'] != null ? '\nTrack ID ${j['track_id']}' : ''}',
      timeAgo: timeAgo(when),
      dateGroup: dayGroup(when),
    );
  }
}

class WalletHistoryScreen extends StatefulWidget {
  const WalletHistoryScreen({super.key});

  @override
  State<WalletHistoryScreen> createState() => _WalletHistoryScreenState();
}

class _WalletHistoryScreenState extends State<WalletHistoryScreen> {
  String _filter = "All";

  List<WalletHistoryEntry> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await DyspatchApi.transactions();
      if (!mounted) return;
      setState(() {
        _entries = rows.map(WalletHistoryEntry.fromJson).toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  List<WalletHistoryEntry> get _filteredEntries {
    if (_filter == "All") return _entries;
    if (_filter == "Top-up") {
      return _entries.where((e) => e.type == HistoryType.topup).toList();
    }
    // "Transferred"
    return _entries.where((e) => e.type == HistoryType.transfer).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Group filtered entries by dateGroup, preserving order of first appearance
    final grouped = <String, List<WalletHistoryEntry>>{};
    for (final e in _filteredEntries) {
      grouped.putIfAbsent(e.dateGroup, () => []).add(e);
    }

    return Scaffold(
      backgroundColor: cs.primary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.tertiaryContainer,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(10),
                      child: const Icon(Icons.arrow_back, size: 20),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Wallet history",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: "Montserrat",
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ── Filter chips ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _FilterChip(
                    label: "All",
                    selected: _filter == "All",
                    onTap: () => setState(() => _filter = "All"),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: "Top-up",
                    selected: _filter == "Top-up",
                    onTap: () => setState(() => _filter = "Top-up"),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: "Transferred",
                    selected: _filter == "Transferred",
                    onTap: () => setState(() => _filter = "Transferred"),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── History list ─────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF298341)))
                  : grouped.isEmpty
                  ? Center(
                      child: Text(
                        _error ?? "No transactions yet",
                        style: TextStyle(
                          fontFamily: "Montserrat",
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (final group in grouped.entries) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              group.key,
                              style: const TextStyle(
                                fontFamily: "Montserrat",
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                          for (final e in group.value) _HistoryTile(entry: e),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Filter chip
// ─────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF298341)
              : const Color(0xFF298341).withOpacity(0.10),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: "Montserrat",
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF298341),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// History tile
// ─────────────────────────────────────────────────────────────────────────

class _HistoryTile extends StatelessWidget {
  final WalletHistoryEntry entry;

  const _HistoryTile({required this.entry});

  IconData get _icon {
    switch (entry.type) {
      case HistoryType.delivered:
        return Icons.arrow_upward_rounded;
      case HistoryType.cancelled:
        return Icons.arrow_upward_rounded;
      case HistoryType.topup:
        return Icons.arrow_downward_rounded;
      case HistoryType.transfer:
        return Icons.arrow_upward_rounded;
    }
  }

  Color get _iconColor {
    switch (entry.type) {
      case HistoryType.topup:
        return const Color(0xFF298341);
      default:
        return const Color(0xFF1A1A1A);
    }
  }

  Color get _iconBg {
    switch (entry.type) {
      case HistoryType.topup:
        return const Color(0xFF298341).withOpacity(0.12);
      default:
        return Colors.grey.withOpacity(0.12);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: _iconBg, shape: BoxShape.circle),
            child: Icon(_icon, size: 17, color: _iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: const TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.description,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  entry.timeAgo,
                  style: TextStyle(
                    fontFamily: "Montserrat",
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
