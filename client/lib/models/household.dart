/// Mirror of `HouseholdDto`.
class Household {
  final String id;
  final String name;

  Household({required this.id, required this.name});

  factory Household.fromJson(Map<String, dynamic> json) => Household(
        id: json['id'] as String,
        name: json['name'] as String,
      );
}
