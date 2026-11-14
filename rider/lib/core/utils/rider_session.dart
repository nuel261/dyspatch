enum JoinType { individualRider, studentRider, fleetOwner }

/// What kind of rider this is (picked at sign-up, stored on the server as
/// riders.join_type) plus the sign-up details collected before the OTP step.
class RiderSession {
  static JoinType joinType = JoinType.individualRider;

  static bool get isFleetOwner => joinType == JoinType.fleetOwner;

  /// Rides (bikes) in the owner's fleet. The backend doesn't manage fleets
  /// yet, so this shows the rider's own vehicle.
  static const int fleetRideCount = 1;

  // Sign-up details carried from the account-details screen to the OTP step.
  static String signupFirstName = '';
  static String signupLastName = '';
  static String signupEmail = '';

  static String get joinTypeApi => switch (joinType) {
        JoinType.studentRider => 'student',
        JoinType.fleetOwner => 'fleet',
        JoinType.individualRider => 'individual',
      };

  static void syncFrom(Map<String, dynamic>? rider) {
    switch (rider?['join_type']) {
      case 'student':
        joinType = JoinType.studentRider;
      case 'fleet':
        joinType = JoinType.fleetOwner;
      default:
        joinType = JoinType.individualRider;
    }
  }
}
