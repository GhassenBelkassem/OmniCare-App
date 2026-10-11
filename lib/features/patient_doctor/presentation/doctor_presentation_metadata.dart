/// Source-aware image value used by the existing Doctor Detail image widgets.
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
