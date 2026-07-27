// web_download_stub.dart — Mobile / Desktop stub
// On mobile, the share card PNG is shown via SnackBar only.
// For full save-to-gallery support, add image_gallery_saver package.

void triggerWebDownload(String dataUrl, String filename) {
  // No-op on mobile — SnackBar confirmation is shown by the caller.
}
