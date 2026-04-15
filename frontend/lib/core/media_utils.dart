bool isRemoteMediaPath(String? path) {
  if (path == null || path.isEmpty) {
    return false;
  }
  final uri = Uri.tryParse(path);
  if (uri == null) {
    return false;
  }
  return uri.scheme == 'http' || uri.scheme == 'https';
}
