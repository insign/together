import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;

void main(List<String> arguments) {
  final parser = ArgParser()
    ..addMultiOption('folder', help: 'Specifies a folder to merge files (can be used multiple times)')
    ..addMultiOption('folder-recursive', help: 'Specifies a folder to merge files recursively (can be used multiple times)')
    ..addOption('output', defaultsTo: 'output.txt', help: 'Specifies the output file name')
    ..addOption('ignore-extensions', help: 'Specifies file extensions to ignore (comma separated)')
    ..addMultiOption('ignore-folders', help: 'Specifies folders to globally ignore (can be used multiple times)')
    ..addMultiOption('ignore-files', help: 'Specifies files to globally ignore (can be used multiple times)');

  final argResults = parser.parse(arguments);

  final folders = argResults['folder'] as List<String>;
  final recursiveFolders = argResults['folder-recursive'] as List<String>;
  final outputFile = argResults['output'] as String;
  final ignoreExtensions = (argResults['ignore-extensions'] as String? ?? '').split(',');
  final ignoreFolders = argResults['ignore-folders'] as List<String>;
  final ignoreFiles = argResults['ignore-files'] as List<String>;

  if (folders.isEmpty && recursiveFolders.isEmpty) {
    print(parser.usage);
    exit(0);
  }

  final outputFileStream = File(outputFile).openWrite();

  for (final folder in folders) {
    processFolder(folder, outputFileStream, outputFile, ignoreExtensions, ignoreFolders, ignoreFiles, recursive: false);
  }

  for (final folder in recursiveFolders) {
    processFolder(folder, outputFileStream, outputFile, ignoreExtensions, ignoreFolders, ignoreFiles, recursive: true);
  }

  outputFileStream.close();
  print('\nOutput file: $outputFile');
}

void processFolder(String folderPath, IOSink outputFileStream, String outputFile,
    List<String> ignoreExtensions, List<String> ignoreFolders, List<String> ignoreFiles, {bool recursive = false}) {
  final folder = Directory(folderPath);

  for (final file in folder.listSync(recursive: recursive).whereType<File>()) {
    final filename = path.basename(file.path);

    if (file.path == outputFile || path.join(folderPath, outputFile) == file.path) {
      continue;
    }

    if (ignoreFiles.contains(filename)) {
      continue;
    }

    final String extWithDot = path.extension(file.path);
    final String extension = extWithDot.isNotEmpty ? extWithDot.substring(1) : 'xxxx';

    if (ignoreExtensions.contains(extension)) {
      continue;
    }

    if (ignoreFolders.any((ignoredFolder) => file.path.contains(ignoredFolder))) {
      continue;
    }

    try {
      final String fileContent = file.readAsStringSync();
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
}
