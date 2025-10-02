import 'dart:io';
import 'dart:convert';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:http/http.dart' as http;
import 'package:together/pubspec.dart' as pubspec;

Future<void> main(List<String> arguments) async {
  if (arguments.isNotEmpty && (arguments.first == '-v' || arguments.first == '--version')) {
    _showVersion(arguments);
  }

  final parser = ArgParser()
    ..addOption('output', defaultsTo: 'output.txt', help: 'Specifies the output file name')
    ..addOption('ignore-extensions', help: 'Specifies file extensions to ignore (comma separated)')
    ..addMultiOption('ignore-folders', help: 'Specifies folders to globally ignore (can be used multiple times)')
    ..addMultiOption('ignore-files', help: 'Specifies files to globally ignore (can be used multiple times)')
    ..addMultiOption('ignore-wild',
        help: 'Specifies wildcard patterns to ignore files/folders (can be used multiple times, e.g., *react*)')
    ..addFlag('gitignore',
        negatable: false, help: 'Ignores files and directories based on the .gitignore file in the current directory.')
    ..addFlag('version', abbr: 'v', negatable: false, help: 'Show the version of ${pubspec.name}.')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help message.')
    ..addFlag('self-update', negatable: false, help: 'Download and install the latest version from GitHub.');

  final argResults = parser.parse(arguments);
  if (argResults['version'] as bool) {
    _showVersion(arguments);
  }

  if (argResults['help'] as bool) {
    _showUsage(parser);
  }

  if (argResults['self-update'] as bool) {
    await _selfUpdate();
  }

  final paths = argResults.rest;
  final outputFile = argResults['output'] as String;

  // Garante que o diretório de saída exista
  final outputDir = path.dirname(outputFile);
  if (outputDir.isNotEmpty) {
    await Directory(outputDir).create(recursive: true);
  }

  final ignoreExtensions =
      (argResults['ignore-extensions'] as String? ?? '').split(',').where((s) => s.isNotEmpty).toList();
  final ignoreFolders = argResults['ignore-folders'] as List<String>;
  final ignoreFiles = (argResults['ignore-files'] as List<String>).toList(); // Make it mutable
  final ignoreWild = argResults['ignore-wild'] as List<String>;

  if (paths.isEmpty) {
    _showUsage(parser);
  }

  final gitignoreGlobs = <Glob>[];
  if (argResults['gitignore'] as bool) {
    const gitignorePath = '.gitignore';
    final gitignoreFile = File(gitignorePath);

    if (await gitignoreFile.exists()) {
      final lines = await gitignoreFile.readAsLines();
      for (var line in lines) {
        line = line.trim();
        if (line.isNotEmpty && !line.startsWith('#')) {
          var pattern = line;
          if (pattern.endsWith('/')) {
            pattern = '$pattern**';
          }
          // Patterns without slashes should match files anywhere in the tree.
          if (!pattern.contains('/')) {
            gitignoreGlobs.add(Glob('**/$pattern', caseSensitive: false));
          }
          // Add the original pattern as well for paths relative to the root.
          gitignoreGlobs.add(Glob(pattern, caseSensitive: false));
        }
      }
    } else {
      print("Warning: --gitignore flag was used, but .gitignore file not found in the current directory.");
    }
  }

  // Ensure the output file itself is never processed.
  ignoreFiles.add(path.basename(outputFile));

  final outputFileStream = File(outputFile).openWrite();
  final processedFilePaths = <String>{};

  final futures = paths.map((pathPattern) {
    return processPath(pathPattern, outputFileStream, outputFile, ignoreExtensions, ignoreFolders, ignoreFiles,
        ignoreWild, gitignoreGlobs, processedFilePaths);
  });

  await Future.wait(futures);

  await outputFileStream.close();
  print('\nOutput file: $outputFile');
}

Never _showUsage(ArgParser parser) {
  print('Usage: dart run main.dart [options] <path1> <path2> ...');
  print(parser.usage);
  exit(0);
}

Future<void> _selfUpdate() async {
  try {
    print('Checking for updates...');

    // Get current executable path
    final currentExecutable = Platform.resolvedExecutable;
    final executableFile = File(currentExecutable);

    // Check if we can write to the executable location
    if (!await executableFile.parent.exists()) {
      print('Error: Cannot access executable directory');
      exit(1);
    }

    // Fetch latest release info
    final response = await http.get(
      Uri.parse('https://api.github.com/repos/insign/together/releases/latest'),
    );

    if (response.statusCode != 200) {
      print('Error: Failed to fetch release information (HTTP ${response.statusCode})');
      exit(1);
    }

    final releaseData = json.decode(response.body) as Map<String, dynamic>;
    final latestVersion = releaseData['tag_name'] as String;
    final currentVersion = 'v${pubspec.version}';

    print('Current version: $currentVersion');
    print('Latest version: $latestVersion');

    if (latestVersion == currentVersion) {
      print('Already up to date!');
      exit(0);
    }

    // Determine platform-specific binary name
    final possibleBinaryNames = _getPossibleBinaryNames();

    if (possibleBinaryNames.isEmpty) {
      print('Error: Unsupported platform: ${Platform.operatingSystem}');
      exit(1);
    }

    // Find the download URL for our platform
    final assets = releaseData['assets'] as List<dynamic>;
    String? downloadUrl;
    String? foundBinaryName;

    // Try each possible binary name in order of preference
    for (final binaryName in possibleBinaryNames) {
      for (final asset in assets) {
        final assetMap = asset as Map<String, dynamic>;
        if (assetMap['name'] == binaryName) {
          downloadUrl = assetMap['browser_download_url'] as String;
          foundBinaryName = binaryName;
          break;
        }
      }
      if (downloadUrl != null) break;
    }

    if (downloadUrl == null) {
      print('Error: No compatible binary found for this platform.');
      print('Tried: ${possibleBinaryNames.join(', ')}');
      print('Available: ${assets.map((a) => a['name']).join(', ')}');
      exit(1);
    }

    print('Found binary: $foundBinaryName');

    print('Downloading $latestVersion...');

    // Download the new binary
    final downloadResponse = await http.get(Uri.parse(downloadUrl));
    if (downloadResponse.statusCode != 200) {
      print('Error: Failed to download binary (HTTP ${downloadResponse.statusCode})');
      exit(1);
    }

    // Create backup of current executable
    final backupPath = '$currentExecutable.backup';
    try {
      await executableFile.copy(backupPath);
      print('Created backup at: $backupPath');
    } catch (e) {
      print('Warning: Could not create backup: $e');
    }

    // Write new binary using atomic replacement technique
    try {
      final tempPath = '$currentExecutable.new';
      final tempFile = File(tempPath);

      // Write new binary to temporary file
      await tempFile.writeAsBytes(downloadResponse.bodyBytes);

      // Make it executable on Unix systems
      if (Platform.isLinux || Platform.isMacOS) {
        await Process.run('chmod', ['+x', tempPath]);
      }

      // Atomic replacement: rename current to .old, then new to current
      final oldPath = '$currentExecutable.old';
      await executableFile.rename(oldPath);
      await tempFile.rename(currentExecutable);

      print('Successfully updated to $latestVersion!');

      // Clean up old version
      try {
        await File(oldPath).delete();
        print('Old version cleaned up.');
      } catch (e) {
        print('Note: Old version remains at: $oldPath');
      }

      // Clean up backup
      try {
        await File(backupPath).delete();
      } catch (e) {
        // Ignore backup cleanup errors
      }
    } catch (e) {
      print('Error: Failed to update binary: $e');

      // Clean up any temporary files
      try {
        final tempFile = File('$currentExecutable.new');
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}

      // Restore backup if it exists
      final backup = File(backupPath);
      if (await backup.exists()) {
        try {
          await backup.copy(currentExecutable);
          await backup.delete();
          print('Restored from backup.');
        } catch (restoreError) {
          print('Error: Failed to restore backup: $restoreError');
          print('Manual recovery needed from: $backupPath');
        }
      }
      exit(1);
    }
  } catch (e) {
    print('Error during self-update: $e');
    exit(1);
  }

  exit(0);
}

List<String> _getPossibleBinaryNames() {
  final possibleNames = <String>[];

  if (Platform.isLinux) {
    // Try x86_64 first, then other common architectures
    possibleNames.addAll([
      'tog-linux-x86_64',
      'tog-linux-amd64',
      'tog-linux-arm64',
    ]);
  } else if (Platform.isMacOS) {
    // Try ARM first (Apple Silicon), then Intel
    possibleNames.addAll([
      'tog-darwin-arm64',
      'tog-darwin-x86_64',
      'tog-darwin-amd64',
    ]);
  } else if (Platform.isWindows) {
    // Try AMD64 first, then other variants
    possibleNames.addAll([
      'tog-windows-amd64',
      'tog-windows-x86_64',
      'tog-windows-AMD64', // GitHub sometimes uses uppercase
    ]);
  }

  return possibleNames;
}

Never _showVersion(List<String> args) {
  final version = pubspec.version;

  if (args.first == '-v') {
    print(version);
  } else {
    final name = pubspec.name;
    final desc = pubspec.description.split('.').first;
    print('$name v$version - $desc');
  }

  exit(0);
}

Future<void> processPath(
    String pathPattern,
    IOSink outputFileStream,
    String outputFile,
    List<String> ignoreExtensions,
    List<String> ignoreFolders,
    List<String> ignoreFiles,
    List<String> ignoreWild,
    List<Glob> gitignoreGlobs,
    Set<String> processedFilePaths) async {
  // Use case-insensitive matching for better cross-platform compatibility.
  final glob = Glob(pathPattern, caseSensitive: false);

  // glob.list() efficiently finds all matching entities without needing manual recursion.
  await for (final entity in glob.list()) {
    if (entity is File) {
      await processFile(entity as File, outputFileStream, outputFile, ignoreExtensions, ignoreFolders, ignoreFiles,
          ignoreWild, gitignoreGlobs, processedFilePaths);
    }
  }
}

Future<void> processFile(
    File file,
    IOSink outputFileStream,
    String outputFile,
    List<String> ignoreExtensions,
    List<String> ignoreFolders,
    List<String> ignoreFiles,
    List<String> ignoreWild,
    List<Glob> gitignoreGlobs,
    Set<String> processedFilePaths) async {
  // Use normalized, relative path for consistent matching.
  final relativePath = path.normalize(file.path);

  // Check against .gitignore patterns first.
  if (gitignoreGlobs.any((glob) => glob.matches(relativePath))) {
    return;
  }

  // Check against ignore-wild patterns.
  for (final pattern in ignoreWild) {
    final glob = Glob(pattern, caseSensitive: false);

    // Check if pattern matches the relative path
    if (glob.matches(relativePath)) {
      return;
    }

    // Check if pattern matches just the filename
    final filename = path.basename(relativePath);
    if (glob.matches(filename)) {
      return;
    }

    // Check if pattern matches any directory name in the path
    final pathSegments = relativePath.split(path.separator);
    for (final segment in pathSegments) {
      if (segment.isNotEmpty && glob.matches(segment)) {
        return;
      }
    }
  }

  // Use the file's absolute path for reliable duplicate checking.
  final absolutePath = file.absolute.path;
  if (processedFilePaths.contains(absolutePath)) {
    return;
  }

  final filename = path.basename(file.path);

  if (ignoreFiles.contains(filename)) {
    return;
  }

  final String extWithDot = path.extension(file.path);
  final String extension = extWithDot.isNotEmpty ? extWithDot.substring(1) : '';

  if (ignoreExtensions.contains(extension)) {
    return;
  }

  // Check if any part of the path is an ignored folder.
  final pathSegments = file.path.split(path.separator);
  if (ignoreFolders.any((ignored) => pathSegments.contains(ignored))) {
    return;
  }

  // Add the file to the processed set before any async operation to prevent race conditions.
  processedFilePaths.add(absolutePath);

  try {
    final String fileContent = await file.readAsString();
    // Use the original path from glob for a user-friendly output header.
    print('Adding file ${file.path}');
    outputFileStream.writeln('FILE: ${file.path}');
    outputFileStream.write(fileContent);
    outputFileStream.writeln();
  } catch (e) {
    if (e is FileSystemException) {
      print('Skipping file ${file.path} due to encoding issues.');
    } else {
      rethrow;
    }
  }
}
