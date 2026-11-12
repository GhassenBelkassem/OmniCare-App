import '../../patient_doctor/data/doctor_detail_models.dart';

const _days = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
const _months = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

/// « jeu. 13 nov. à 10:20 » in Africa/Tunis, whatever the phone's time zone.
String formatTunisDayTime(DateTime instant) {
  final wall = toTunisWallClock(instant);
  final hour = wall.hour.toString().padLeft(2, '0');
  final minute = wall.minute.toString().padLeft(2, '0');
  return '${_days[wall.weekday - 1]} ${wall.day} ${_months[wall.month - 1]} '
      'à $hour:$minute';
}
