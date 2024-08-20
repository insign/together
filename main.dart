import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('output', defaultsTo: 'output.txt', help: 'Specifies the output file name')
    ..addOption('ignore-extensions', help: 'Specifies file extensions to ignore (comma separated)')
    ..addMultiOption('ignore-folders', help: 'Specifies folders to globally ignore (can be used multiple times)')
    ..addMultiOption('ignore-files', help: 'Specifies files to globally ignore (can be used multiple times)');

  final argResults = parser.parse(arguments);

  final paths = argResults.rest;
  final outputFile = argResults['output'] as String;
  final ignoreExtensions = (argResults['ignore-extensions'] as String? ?? '').split(',');
  final ignoreFolders = argResults['ignore-folders'] as List<String>;
  final ignoreFiles = argResults['ignore-files'] as List<String>;

  if (paths.isEmpty) {
    print('Usage: dart run main.dart [options] <path1> <path2> ...');
    print(parser.usage);
    exit(0);
  }

  final outputFileStream = File(outputFile).openWrite();

  final futures = paths.map((pathPattern) {
    final absolutePathPattern = path.isAbsolute(pathPattern)
        ? pathPattern
        : path.join(Directory.current.path, pathPattern);
    return processPath(absolutePathPattern, outputFileStream, outputFile, ignoreExtensions, ignoreFolders, ignoreFiles);
  });

  await Future.wait(futures);

  await outputFileStream.close();
  print('\nOutput file: $outputFile');
}

Future<void> processPath(String pathPattern, IOSink outputFileStream, String outputFile,
    List<String> ignoreExtensions, List<String> ignoreFolders, List<String> ignoreFiles) async {
  final glob = Glob(pathPattern);
  final rootDir = path.dirname(pathPattern);

  // Process files in the root directory
  final rootDirEntity = Directory(rootDir);
  if (await rootDirEntity.exists()) {
    final entities = await rootDirEntity.list().toList();
    final fileFutures = entities.map((entity) async {
      if (entity is File && glob.matches(entity.path)) {
        await processFile(entity, outputFileStream, outputFile, ignoreExtensions, ignoreFolders, ignoreFiles);
      }
    });
    await Future.wait(fileFutures);
  }

  // Process files in subdirectories
  final entities = await glob.list().toList();
  final futures = entities.map((entity) async {
    if (entity is File) {
      await processFile(entity as File, outputFileStream, outputFile, ignoreExtensions, ignoreFolders, ignoreFiles);
    } else if (entity is Directory) {
      await processPath(path.join(entity.path, '**'), outputFileStream, outputFile, ignoreExtensions, ignoreFolders, ignoreFiles);
    }
  });
  await Future.wait(futures);
}

Future<void> processFile(File file, IOSink outputFileStream, String outputFile,
    List<String> ignoreExtensions, List<String> ignoreFolders, List<String> ignoreFiles) async {
  final filename = path.basename(file.path);

  if (file.path == outputFile || path.basename(file.path) == outputFile) {
    return;
  }

  if (ignoreFiles.contains(filename)) {
    return;
  }

  final String extWithDot = path.extension(file.path);
  final String extension = extWithDot.isNotEmpty ? extWithDot.substring(1) : '';

  if (ignoreExtensions.contains(extension)) {
    return;
  }

  if (ignoreFolders.any((ignoredFolder) => file.path.contains(ignoredFolder))) {
    return;
  }

  try {
    final String fileContent = await file.readAsString();
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
