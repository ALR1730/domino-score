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
      equipo: map['equipo'] as int? ?? 1,
      puntos: map['puntos'] as int? ?? 0,
    );
  }
}
