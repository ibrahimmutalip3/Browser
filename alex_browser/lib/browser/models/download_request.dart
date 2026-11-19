/// A download initiated by the web page (either a direct link the engine
/// can't render, or an explicit `download` attribute / Content-Disposition
/// header from the server).
class EngineDownloadRequest {
  const EngineDownloadRequest({
    required this.url,
    required this.suggestedFileName,
    this.mimeType,
    this.contentLength,
    this.userAgent,
  });

  final String url;
  final String suggestedFileName;
  final String? mimeType;
  final int? contentLength;
  final String? userAgent;
}
