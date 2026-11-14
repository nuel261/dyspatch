// earning_tab_model.dart
class EarningTab {
  final String label;
  final String balance;
  final int ordersReceived;
  final int ordersDelivered;

  const EarningTab({
    required this.label,
    required this.balance,
    required this.ordersReceived,
    required this.ordersDelivered,
  });
}
