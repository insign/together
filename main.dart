import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('output',
        defaultsTo: 'output.txt', help: 'Specifies the output file name')
    ..addOption('ignore-extensions',
        help: 'Specifies file extensions to ignore (comma separated)')
    ..addMultiOption('ignore-folders',
        help:
            'Specifies folders to globally ignore (can be used multiple times)')
    ..addMultiOption('ignore-files',
        help:
            'Specifies files to globally ignore (can be used multiple times)');

  final argResults = parser.parse(arguments);

  final paths = argResults.rest;
  final outputFile = argResults['output'] as String;
  final ignoreExtensions = (argResults['ignore-extensions'] as String? ?? '')
      .split(',')
      .where((s) => s.isNotEmpty)
      .toList();
  final ignoreFolders = argResults['ignore-folders'] as List<String>;
  final ignoreFiles =
      (argResults['ignore-files'] as List<String>).toList(); // Make it mutable

  if (paths.isEmpty) {
    print('Usage: dart run main.dart [options] <path1> <path2> ...');
    print(parser.usage);
    exit(0);
  }

  // Ensure the output file itself is never processed.
  ignoreFiles.add(path.basename(outputFile));

  final outputFileStream = File(outputFile).openWrite();
  final processedFilePaths = <String>{};

  final futures = paths.map((pathPattern) {
    return processPath(pathPattern, outputFileStream, outputFile,
        ignoreExtensions, ignoreFolders, ignoreFiles, processedFilePaths);
  });

  await Future.wait(futures);

  await outputFileStream.close();
  print('\nOutput file: $outputFile');
}

Future<void> processPath(
    String pathPattern,
    IOSink outputFileStream,
    String outputFile,
    List<String> ignoreExtensions,
    List<String> ignoreFolders,
    List<String> ignoreFiles,
    Set<String> processedFilePaths) async {
  // Use case-insensitive matching for better cross-platform compatibility.
  final glob = Glob(pathPattern, caseSensitive: false);

  // glob.list() efficiently finds all matching entities without needing manual recursion.
  await for (final entity in glob.list()) {
    if (entity is File) {
      await processFile(entity as File, outputFileStream, outputFile,
          ignoreExtensions, ignoreFolders, ignoreFiles, processedFilePaths);
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
    Set<String> processedFilePaths) async {
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
