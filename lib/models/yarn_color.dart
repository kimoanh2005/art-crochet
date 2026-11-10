class YarnColor {
  const YarnColor({
    required this.id,
    required this.name,
    required this.hexCode,
    this.brand = '',
    this.yarnCode = '',
  });

  final String id;
  final String name;
  final String hexCode;
  final String brand;
  final String yarnCode;

  YarnColor copyWith({
    String? name,
    String? hexCode,
    String? brand,
    String? yarnCode,
  }) {
    return YarnColor(
      id: id,
      name: name ?? this.name,
      hexCode: hexCode ?? this.hexCode,
      brand: brand ?? this.brand,
      yarnCode: yarnCode ?? this.yarnCode,
    );
  }
}
