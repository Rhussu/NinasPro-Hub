// Cálculos del calendario de clases (US-02). Replican las funciones SQL
// fechas_sesiones() y periodo_academico_de() para la vista previa del asistente.

/// Fechas de las clases semanales entre [inicio] y [termino] (ambas incluidas)
/// que caen en [diaSemana] (DateTime.monday..DateTime.sunday).
List<DateTime> fechasSesiones(DateTime inicio, DateTime termino, int diaSemana) {
  final fin = DateTime(termino.year, termino.month, termino.day);
  var dia = DateTime(inicio.year, inicio.month, inicio.day);
  while (dia.weekday != diaSemana) {
    dia = DateTime(dia.year, dia.month, dia.day + 1);
  }
  final fechas = <DateTime>[];
  while (!dia.isAfter(fin)) {
    fechas.add(dia);
    dia = DateTime(dia.year, dia.month, dia.day + 7);
  }
  return fechas;
}

/// Período académico de una fecha: '2026-1' (enero a junio) o '2026-2' (julio a diciembre)
String periodoAcademico(DateTime fecha) => '${fecha.year}-${fecha.month >= 7 ? 2 : 1}';

/// Año y semestre de un período '2026-2'. Si no tiene ese formato, se usa [respaldo].
({int anio, int semestre}) partesPeriodo(String periodo, DateTime respaldo) {
  final m = RegExp(r'^(\d{4})-S?([12])$').firstMatch(periodo);
  if (m == null) return (anio: respaldo.year, semestre: respaldo.month >= 7 ? 2 : 1);
  return (anio: int.parse(m[1]!), semestre: int.parse(m[2]!));
}

/// 'HH:mm' de una hora de Postgres ('10:00:00')
String? horaCorta(String? hora) => hora == null || hora.length < 5 ? hora : hora.substring(0, 5);
