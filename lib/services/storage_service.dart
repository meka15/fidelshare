import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

String get uploadEndpoint => dotenv.get('UPLOAD_ENDPOINT', fallback: 'https://mekbib.alwaysdata.net/students/upload.php');
String get downloadEndpoint => dotenv.get('DOWNLOAD_ENDPOINT', fallback: 'https://mekbib.alwaysdata.net/students/download.php');

class TransferProgress {
  final int loaded;
  final int total;
  final int percentage;
  final int chunkIndex;
  final int totalChunks;

  TransferProgress({
    required this.loaded,
    required this.total,
    required this.percentage,
    required this.chunkIndex,
    required this.totalChunks,
  });
}

Future<String> uploadFile(File file, void Function(TransferProgress p) onProgress, {String? customName}) async {
  final uri = Uri.parse(uploadEndpoint);
  final length = await file.length();
  int sent = 0;

  final Stream<List<int>> stream = file.openRead().transform(
        StreamTransformer<List<int>, List<int>>.fromHandlers(
          handleData: (data, sink) {
            sent += data.length;
            final percentage = length == 0 ? 0 : ((sent / length) * 100).round();
            onProgress(TransferProgress(
              loaded: sent,
              total: length,
              percentage: percentage,
              chunkIndex: 0,
              totalChunks: 1,
            ));
            sink.add(data);
          },
        ),
      );

  final filename = customName ?? file.path.split(Platform.pathSeparator).last;
  final multipartFile = http.MultipartFile('file', stream, length, filename: filename);
  final request = http.MultipartRequest('POST', uri)..files.add(multipartFile);

  final response = await request.send();
  final body = await response.stream.bytesToString();

  if (response.statusCode >= 200 && response.statusCode < 300) {
    try {
      final json = jsonDecode(body);
      return json['url'] ?? '$uploadEndpoint$filename';
    } catch (_) {
      return '$uploadEndpoint$filename';
    }
  }

  throw Exception('Server returned status ${response.statusCode}. Make sure endpoint allows POST requests.');
}

Future<File> downloadFileChunked(
  String url,
  String fileName,
  void Function(TransferProgress p) onProgress, {
  Directory? targetDir,
}) async {
  final uri = Uri.parse(url);
  final client = http.Client();
  final request = http.Request('GET', uri);
  final response = await client.send(request);

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('Download failed with status ${response.statusCode}');
  }

  final total = response.contentLength ?? 0;
  int loaded = 0;

  Directory downloadsDir;
  if (targetDir != null) {
    downloadsDir = targetDir;
  } else if (Platform.isAndroid || Platform.isIOS) {
    downloadsDir = await getApplicationDocumentsDirectory();
  } else {
    final home = Platform.environment['HOME'] ?? Directory.current.path;
    downloadsDir = Directory('$home/Downloads');
    if (!downloadsDir.existsSync()) {
      downloadsDir.createSync(recursive: true);
    }
  }

  final filePath = '${downloadsDir.path}/$fileName';
  final file = File(filePath);
  final iosink = file.openWrite();

  try {
    await for (final chunk in response.stream) {
      iosink.add(chunk);
      loaded += chunk.length;
      if (total > 0) {
        final percentage = ((loaded / total) * 100).round();
        onProgress(TransferProgress(
          loaded: loaded,
          total: total,
          percentage: percentage,
          chunkIndex: 0,
          totalChunks: 1,
        ));
      }
    }
  } finally {
    await iosink.close();
    client.close();
  }
  
  return file;
}

String formatFileSize(int bytes) {
  if (bytes == 0) return '0 Bytes';
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
  double size = bytes.toDouble();
  int i = 0;
  while (size >= k && i < sizes.length - 1) {
    size /= k;
    i++;
  }
  return '${size.toStringAsFixed(2)} ${sizes[i]}';
}
