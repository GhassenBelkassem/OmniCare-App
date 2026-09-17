/// Presentation-only metadata for the patient doctor profile screen.
///
/// IMPORTANT:
///
/// This data does NOT come from any Doctor API yet.
///
/// It exists only to allow the patient-facing UI/UX to be completed before
/// richer public presentation data (portraits, cabinet photos, etc.) is
/// exposed by the backend.
///
/// Backend-authoritative fields MUST continue to come from [DoctorListItem]
/// / [DoctorDetail]:
///
/// - id, name, specialty, experienceYears, languages, acceptingNewPatients
/// - areasOfCare, expertise, biography, patientAgeGroups
/// - practiceLocations (name, address, city, distanceKm, openingHours, etc.)
/// - availability
///
/// Nothing from this file must ever enter a request submission payload.
library;

/// A presentation-only image that knows whether it is a local asset or a
/// network URL. Used exclusively in the presentation layer — never in API DTOs.
enum DoctorPresentationImageSource { asset, network }

class DoctorPresentationImage {
  const DoctorPresentationImage.asset(this.value)
    : source = DoctorPresentationImageSource.asset;
  const DoctorPresentationImage.network(this.value)
    : source = DoctorPresentationImageSource.network;

  final String value;
  final DoctorPresentationImageSource source;

  bool get isAsset => source == DoctorPresentationImageSource.asset;
  bool get isNetwork => source == DoctorPresentationImageSource.network;
}

/// Presentation-only metadata for a single doctor.
///
/// Contains portrait images, cabinet gallery images, and other
/// presentation-only data that supplements the backend-authoritative
/// [DoctorDetail].
class DoctorPresentationMetadata {
  const DoctorPresentationMetadata({
    required this.portrait,
    this.cabinetGallery = const [],
  });

  /// The doctor's portrait image (presentation-only).
  final DoctorPresentationImage portrait;

  /// Local asset paths for cabinet/practice gallery photos.
  final List<DoctorPresentationImage> cabinetGallery;
}

/// UI-only catalog with presentation-only doctor data.
///
/// Follows the same pattern as [ClinicPresentationCatalog] — isolated from
/// backend/domain models.
///
/// The repository's current doctor image files are illustrated artwork, so
/// portraits remain empty and render the initials fallback until approved
/// professional local portraits are provided.
abstract final class DoctorPresentationCatalog {
  /// Shared cabinet gallery images for demo doctors.
  /// Uses the existing clinic demo assets.
  static const List<DoctorPresentationImage> _cabinetDemoImages = [
    DoctorPresentationImage.asset(
      'assets/images/clinics/demo/clinic_reception.jpg',
    ),
    DoctorPresentationImage.asset('assets/images/clinics/demo/clinic_room.jpg'),
    DoctorPresentationImage.asset(
      'assets/images/clinics/demo/clinic_hallway.jpg',
    ),
    DoctorPresentationImage.asset(
      'assets/images/clinics/demo/clinic_waiting.jpg',
    ),
    DoctorPresentationImage.asset(
      'assets/images/clinics/demo/clinic_exterior.jpg',
    ),
  ];

  static const Map<String, DoctorPresentationMetadata> _byDoctorId = {
    'doc-1': DoctorPresentationMetadata(
      portrait: DoctorPresentationImage.asset(''),
      cabinetGallery: _cabinetDemoImages,
    ),
    'doc-2': DoctorPresentationMetadata(
      portrait: DoctorPresentationImage.asset(''),
      cabinetGallery: _cabinetDemoImages,
    ),
    'doc-3': DoctorPresentationMetadata(
      portrait: DoctorPresentationImage.asset(''),
      cabinetGallery: _cabinetDemoImages,
    ),
    'doc-4': DoctorPresentationMetadata(
      portrait: DoctorPresentationImage.asset(''),
      cabinetGallery: _cabinetDemoImages,
    ),
    'doc-5': DoctorPresentationMetadata(
      portrait: DoctorPresentationImage.asset(''),
      cabinetGallery: _cabinetDemoImages,
    ),
  };

  /// Returns the [DoctorPresentationMetadata] for a given doctor ID.
  ///
  /// Falls back to a default with no images if the doctor is not in the
  /// catalog.
  static DoctorPresentationMetadata forDoctor(String doctorId) {
    return _byDoctorId[doctorId] ??
        const DoctorPresentationMetadata(
          portrait: DoctorPresentationImage.asset(''),
        );
  }
}
