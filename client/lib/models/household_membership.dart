/// Mirror of `HouseholdMembershipDto` — a single household the user belongs
/// to, plus their role in it and whether it's the currently-active one.
class HouseholdMembership {
  final String householdId;
  final String householdName;
  final String role;
  final DateTime joinedAt;
  final bool active;

  HouseholdMembership({
    required this.householdId,
    required this.householdName,
    required this.role,
    required this.joinedAt,
    required this.active,
  });

  bool get isAdmin => role == 'ADMIN';

  factory HouseholdMembership.fromJson(Map<String, dynamic> json) =>
      HouseholdMembership(
        householdId: json['householdId'] as String,
        householdName: json['householdName'] as String,
        role: json['role'] as String,
        joinedAt: DateTime.parse(json['joinedAt'] as String),
        active: json['active'] as bool,
      );
}
