/// Mirror of `HouseholdDto`.
class Household {
  final String id;
  final String name;
  final String? avatarUrl;

  Household({required this.id, required this.name, this.avatarUrl});

  factory Household.fromJson(Map<String, dynamic> json) => Household(
        id: json['id'] as String,
        name: json['name'] as String,
        avatarUrl: json['avatarUrl'] as String?,
      );
}
