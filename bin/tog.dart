import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
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
    ..addFlag('gitignore',
        negatable: false, help: 'Ignores files and directories based on the .gitignore file in the current directory.')
    ..addFlag('version', abbr: 'v', negatable: false, help: 'Show the version of ${pubspec.name}.');

  final argResults = parser.parse(arguments);
  if (argResults['version'] as bool) {
    _showVersion(arguments);
  }

  final paths = argResults.rest;
  final outputFile = argResults['output'] as String;
  final ignoreExtensions =
      (argResults['ignore-extensions'] as String? ?? '').split(',').where((s) => s.isNotEmpty).toList();
  final ignoreFolders = argResults['ignore-folders'] as List<String>;
  final ignoreFiles = (argResults['ignore-files'] as List<String>).toList(); // Make it mutable

  if (paths.isEmpty) {
    print('Usage: dart run main.dart [options] <path1> <path2> ...');
    print(parser.usage);
    exit(0);
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
        gitignoreGlobs, processedFilePaths);
  });

  await Future.wait(futures);

  await outputFileStream.close();
  print('\nOutput file: $outputFile');
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
    List<Glob> gitignoreGlobs,
    Set<String> processedFilePaths) async {
  // Use case-insensitive matching for better cross-platform compatibility.
  final glob = Glob(pathPattern, caseSensitive: false);

  // glob.list() efficiently finds all matching entities without needing manual recursion.
  await for (final entity in glob.list()) {
    if (entity is File) {
      await processFile(entity as File, outputFileStream, outputFile, ignoreExtensions, ignoreFolders, ignoreFiles,
          gitignoreGlobs, processedFilePaths);
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
    List<Glob> gitignoreGlobs,
    Set<String> processedFilePaths) async {
  // Use normalized, relative path for consistent matching.
  final relativePath = path.normalize(file.path);

  // Check against .gitignore patterns first.
  if (gitignoreGlobs.any((glob) => glob.matches(relativePath))) {
    return;
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
