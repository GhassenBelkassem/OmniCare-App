/// Picks the file to upload in the « Documents » editor (G2.1-A4): PDF, JPG
/// or PNG. The app never holds the file as bytes in state:
/// - Android, iOS, desktop: the picked file's path ([PathDocumentSource]);
/// - web: the browser file, read in slices on each send
///   ([StreamDocumentSource]), so « Réessayer » can send it again.
/// Returns `null` when the patient cancels.
library;

export 'document_file_picker_io.dart'
    if (dart.library.js_interop) 'document_file_picker_web.dart';
