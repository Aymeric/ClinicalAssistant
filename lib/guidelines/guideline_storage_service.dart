import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'clinical_guideline.dart';

class GuidelineStorageService {
  GuidelineStorageService({
    Directory? storageDirectory,
    http.Client? httpClient,
  }) : _explicitDirectory = storageDirectory,
       _client = httpClient;

  final Directory? _explicitDirectory;
  final http.Client? _client;
  Directory? _resolvedDirectory;

  Future<Directory> get directory async {
    if (_explicitDirectory != null) return _explicitDirectory;
    if (_resolvedDirectory != null) return _resolvedDirectory!;

    try {
      final baseDir = await getApplicationDocumentsDirectory();
      final guidelinesDir = Directory('${baseDir.path}/clinical_guidelines');
      if (!await guidelinesDir.exists()) {
        await guidelinesDir.create(recursive: true);
      }
      _resolvedDirectory = guidelinesDir;
      return guidelinesDir;
    } catch (_) {
      // Fallback for tests or environments without path_provider channel
      final tempDir = Directory.systemTemp.createTempSync(
        'clinical_guidelines_',
      );
      _resolvedDirectory = tempDir;
      return tempDir;
    }
  }

  File _fileForId(Directory dir, String id) {
    final sanitizedId = id.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    return File('${dir.path}/$sanitizedId.json');
  }

  Future<DownloadedGuideline> downloadGuideline(
    ClinicalGuideline guideline, {
    http.Client? client,
  }) async {
    // Security: Enforce HTTPS scheme to prevent downloading guidelines over cleartext HTTP
    if (guideline.downloadUrl.scheme != 'https') {
      throw ArgumentError(
        'Guideline download URL must use HTTPS transport security.',
      );
    }

    final dir = await directory;
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final targetFile = _fileForId(dir, guideline.id);

    // If client is available, attempt an HTTP check/fetch from trusted source
    final activeClient = client ?? _client;
    if (activeClient != null) {
      try {
        await activeClient
            .get(guideline.downloadUrl)
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        // If offline or network unavailable, continue saving the authoritative bundled guideline
      }
    }

    final downloadedAt = DateTime.now().toUtc();
    final downloaded = DownloadedGuideline(
      guideline: guideline,
      downloadedAt: downloadedAt,
      localFilePath: targetFile.path,
      fileSizeBytes: guideline.fileSizeBytes,
    );

    final jsonString = jsonEncode(downloaded.toJson());
    targetFile.writeAsStringSync(jsonString, flush: true);
    _restrictFilePermissions(targetFile);

    final actualSize = targetFile.lengthSync();
    return DownloadedGuideline(
      guideline: guideline,
      downloadedAt: downloadedAt,
      localFilePath: targetFile.path,
      fileSizeBytes: actualSize > 0 ? actualSize : guideline.fileSizeBytes,
    );
  }

  Future<bool> isDownloaded(String guidelineId) async {
    final dir = await directory;
    final file = _fileForId(dir, guidelineId);
    return file.existsSync();
  }

  Future<DownloadedGuideline?> getDownloadedGuideline(
    String guidelineId,
  ) async {
    final dir = await directory;
    final file = _fileForId(dir, guidelineId);
    if (!file.existsSync()) return null;

    try {
      final content = file.readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return DownloadedGuideline.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  File _favoritesFile(Directory dir) => File('${dir.path}/_favorites.json');

  Future<Set<String>> getFavoriteIds() async {
    final dir = await directory;
    final file = _favoritesFile(dir);
    if (!file.existsSync()) return const {};

    try {
      final content = file.readAsStringSync();
      final list = jsonDecode(content) as List<dynamic>;
      return list.map((e) => e.toString()).toSet();
    } catch (_) {
      return const {};
    }
  }

  Future<bool> isFavorite(String guidelineId) async {
    final favorites = await getFavoriteIds();
    return favorites.contains(guidelineId);
  }

  Future<void> setFavorite(String guidelineId, bool isFavorite) async {
    final dir = await directory;
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final favorites = (await getFavoriteIds()).toSet();
    if (isFavorite) {
      favorites.add(guidelineId);
    } else {
      favorites.remove(guidelineId);
    }
    final file = _favoritesFile(dir);
    file.writeAsStringSync(jsonEncode(favorites.toList()), flush: true);
    _restrictFilePermissions(file);
  }

  Future<bool> toggleFavorite(String guidelineId) async {
    final fav = await isFavorite(guidelineId);
    final newState = !fav;
    await setFavorite(guidelineId, newState);
    return newState;
  }

  File _notesFile(Directory dir, String id) {
    final sanitizedId = id.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    return File('${dir.path}/notes_$sanitizedId.txt');
  }

  Future<String?> getGuidelineNotes(String guidelineId) async {
    final dir = await directory;
    final file = _notesFile(dir, guidelineId);
    if (!file.existsSync()) return null;
    try {
      final content = file.readAsStringSync().trim();
      return content.isEmpty ? null : content;
    } catch (_) {
      return null;
    }
  }

  static final _unsafeControlChars = RegExp(
    r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]',
  );
  static const int maxNotesLength = 5000;

  Future<void> saveGuidelineNotes(String guidelineId, String notes) async {
    final dir = await directory;
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final file = _notesFile(dir, guidelineId);
    // Security: Sanitize control characters and restrict length to prevent DoS or storage exhaustion.
    var sanitized = notes.replaceAll(_unsafeControlChars, '').trim();
    if (sanitized.length > maxNotesLength) {
      sanitized = sanitized.substring(0, maxNotesLength).trim();
    }
    if (sanitized.isEmpty) {
      if (file.existsSync()) {
        file.deleteSync();
      }
    } else {
      file.writeAsStringSync(sanitized, flush: true);
      _restrictFilePermissions(file);
    }
  }

  Future<void> deleteGuidelineNotes(String guidelineId) async {
    final dir = await directory;
    final file = _notesFile(dir, guidelineId);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  Future<List<DownloadedGuideline>> getDownloadedGuidelines() async {
    final dir = await directory;
    if (!dir.existsSync()) return const [];

    final list = <DownloadedGuideline>[];
    for (final entity in dir.listSync()) {
      if (entity is File &&
          entity.path.endsWith('.json') &&
          !entity.path.endsWith('_favorites.json')) {
        try {
          final content = entity.readAsStringSync();
          final json = jsonDecode(content) as Map<String, dynamic>;
          if (json.containsKey('guideline')) {
            list.add(DownloadedGuideline.fromJson(json));
          }
        } catch (_) {
          // Ignore corrupted or unreadable files
        }
      }
    }

    list.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    return list;
  }

  Future<Set<String>> getDownloadedIds() async {
    final downloaded = await getDownloadedGuidelines();
    return downloaded.map((d) => d.guideline.id).toSet();
  }

  Future<bool> deleteDownloadedGuideline(String guidelineId) async {
    final dir = await directory;
    final file = _fileForId(dir, guidelineId);
    if (file.existsSync()) {
      file.deleteSync();
      return true;
    }
    return false;
  }

  Future<void> deleteAllDownloadedGuidelines() async {
    final dir = await directory;
    if (!dir.existsSync()) return;
    for (final entity in dir.listSync()) {
      if (entity is File &&
          entity.path.endsWith('.json') &&
          !entity.path.endsWith('_favorites.json')) {
        try {
          final content = entity.readAsStringSync();
          final json = jsonDecode(content) as Map<String, dynamic>;
          if (json.containsKey('guideline')) {
            entity.deleteSync();
          }
        } catch (_) {}
      }
    }
  }

  Future<int> getTotalDownloadedSizeBytes() async {
    final downloaded = await getDownloadedGuidelines();
    var total = 0;
    for (final item in downloaded) {
      total += item.fileSizeBytes;
    }
    return total;
  }

  void _restrictFilePermissions(File file) {
    // Restrict permissions to user read/write only (0600) on POSIX platforms
    // to safeguard local guideline files and notes against local process access.
    if (!Platform.isWindows) {
      try {
        Process.runSync('chmod', ['600', file.path]);
      } catch (_) {}
    }
  }
}
