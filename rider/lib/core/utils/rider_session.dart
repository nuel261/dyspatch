enum JoinType { individualRider, studentRider, fleetOwner }

/// What the rider picked at sign-up. In-memory only until the backend
/// returns it with the account; login defaults to an individual rider.
class RiderSession {
  static JoinType joinType = JoinType.individualRider;

  static bool get isFleetOwner => joinType == JoinType.fleetOwner;

  /// Rides (bikes) in the owner's fleet — dummy until the backend sends it.
  static const int fleetRideCount = 5;
}
