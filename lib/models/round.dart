class Round {
  final int equipo; // 1 or 2
  int puntos;

  Round({
    required this.equipo,
    required this.puntos,
  });

  Map<String, dynamic> toMap() {
    return {
      'equipo': equipo,
      'puntos': puntos,
    };
  }

  factory Round.fromMap(Map<String, dynamic> map) {
    return Round(
      equipo: (map['equipo'] as num?)?.toInt() ?? 1,
      puntos: (map['puntos'] as num?)?.toInt() ?? 0,
    );
  }
}
