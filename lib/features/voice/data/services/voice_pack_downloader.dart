import 'dart:io';

/// Fetches a pack archive to disk, reporting how many bytes have arrived.
///
/// Kept separate from the installer so the installer's logic (verify, unpack,
/// rename) can be tested without a network, and so a future mirror or a
/// user-provided file can replace the transport without touching the rest.
abstract interface class VoicePackDownloader {
  /// Streams [url] into [destination], emitting the running byte count.
  Stream<int> download(String url, File destination);
}

/// The real transport: one HTTPS GET, streamed straight to a file.
///
/// Nothing about the user is sent. There is no account, no token, and no
/// identifier — this is a plain public file download.
class HttpVoicePackDownloader implements VoicePackDownloader {
  HttpVoicePackDownloader({HttpClient Function()? clientFactory})
    : _clientFactory = clientFactory ?? HttpClient.new;

  final HttpClient Function() _clientFactory;

  @override
  Stream<int> download(String url, File destination) async* {
    final client = _clientFactory();
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.userAgentHeader, 'Lujayn voice download');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'The voice download failed with status ${response.statusCode}.',
        );
      }

      final sink = destination.openWrite();
      var received = 0;
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          yield received;
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
    } finally {
      client.close(force: true);
    }
  }
}
