import 'package:flutter/material.dart';
import 'package:dyspatch_rider/Features/Home/model/history_type.dart';

enum _HistoryFilter { all, deposited, withdrawn }

class WalletHistoryScreen extends StatefulWidget {
  const WalletHistoryScreen({super.key});

  @override
  State<WalletHistoryScreen> createState() => _WalletHistoryScreenState();
}

class _WalletHistoryScreenState extends State<WalletHistoryScreen> {
  _HistoryFilter _selected = _HistoryFilter.all;

  static const Map<_HistoryFilter, String> _labels = {
    _HistoryFilter.all: 'All',
    _HistoryFilter.deposited: 'Deposited',
    _HistoryFilter.withdrawn: 'Withdrawn',
  };

  // Sample data — replace with your real data source
  final List<WalletHistoryEntry> _entries = const [
    WalletHistoryEntry(
      title: 'Order Delivered',
      description:
          'Order #BN4821 was successfully delivered ₦10,000 has been deposited into your wallet.',
      time: '20 mins ago',
      dayGroup: 'Today',
      type: HistoryType.deposited,
    ),
    WalletHistoryEntry(
      title: 'Order Cancelled',
      description:
          "Since Order #BN4821 was cancelled during delivery, we've added ₦1,000 to your wallet as a token of our apologies.",
      time: '20 mins ago',
      dayGroup: 'Today',
      type: HistoryType.deposited,
    ),
    WalletHistoryEntry(
      title: 'Money sent successfully',
      description: 'You have sent ₦10,000 to Dan-John Chibuzor\nBank: GT Bank',
      time: '07:21 pm',
      dayGroup: 'Today',
      type: HistoryType.withdrawn,
    ),
    WalletHistoryEntry(
      title: 'Order Delivered',
      description:
          'Order #BN4821 was successfully delivered ₦10,000 has been deposited into your wallet.',
      time: 'Yesterday',
      dayGroup: 'Yesterday',
      type: HistoryType.deposited,
    ),
  ];

  List<WalletHistoryEntry> get _filtered {
    switch (_selected) {
      case _HistoryFilter.all:
        return _entries;
      case _HistoryFilter.deposited:
        return _entries.where((e) => e.type == HistoryType.deposited).toList();
      case _HistoryFilter.withdrawn:
        return _entries.where((e) => e.type == HistoryType.withdrawn).toList();
    }
  }

  Map<String, List<WalletHistoryEntry>> get _grouped {
    final map = <String, List<WalletHistoryEntry>>{};
    for (final entry in _filtered) {
      map.putIfAbsent(entry.dayGroup, () => []).add(entry);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final grouped = _grouped;

    return Scaffold(
      backgroundColor: cs.primary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.tertiaryContainer,
                      ),
                      child: const Icon(Icons.arrow_back, size: 20),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Wallet history',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Montserrat',
                        color: cs.inversePrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // ── Filter chips ──
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _HistoryFilter.values.map((filter) {
                  final isSelected = filter == _selected;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () => setState(() => _selected = filter),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF298341)
                              : const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _labels[filter]!,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF298341),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // ── History List ──
            Expanded(
              child: grouped.isEmpty
                  ? Center(
                      child: Text(
                        'No history yet',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          color: Colors.grey.shade500,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: grouped.entries.expand((groupEntry) {
                        return [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              groupEntry.key,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Montserrat',
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                          ...groupEntry.value.map(
                            (entry) => _historyTile(entry),
                          ),
                          const SizedBox(height: 20),
                        ];
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyTile(WalletHistoryEntry entry) {
    final isDeposit = entry.type == HistoryType.deposited;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDeposit
                  ? const Color(0xFF298341).withOpacity(0.12)
                  : Colors.grey.withOpacity(0.15),
            ),
            child: Icon(
              isDeposit
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              size: 15,
              color: isDeposit ? const Color(0xFF298341) : Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Montserrat',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontFamily: 'Montserrat',
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  entry.time,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                    fontFamily: 'Montserrat',
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
