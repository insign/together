import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory tempDir;
  late String outputFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('together_test_');
    outputFile = path.join(tempDir.path, 'output.txt');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  Future<ProcessResult> runApp(List<String> args) async {
    return await Process.run(
      'dart',
      ['run', 'main.dart', ...args],
    );
  }

  test('Basic functionality', () async {
    // Create test files
    File(path.join(tempDir.path, 'file1.txt')).writeAsStringSync('Content of file 1');
    File(path.join(tempDir.path, 'file2.dart')).writeAsStringSync('Content of file 2');
    Directory(path.join(tempDir.path, 'subdir')).createSync();
    File(path.join(tempDir.path, 'subdir', 'file3.txt')).writeAsStringSync('Content of file 3');

    // Run the application
    final result = await runApp([
      tempDir.path,
      '--output=$outputFile',
      '--ignore-extensions=dart',
    ]);

    expect(result.exitCode, equals(0));
    print('STDOUT: ${result.stdout}');
    print('STDERR: ${result.stderr}');

    // Check the output
    final output = File(outputFile).readAsStringSync();
    expect(output, contains('FILE: ${path.join(tempDir.path, 'file1.txt')}'));
    expect(output, contains('Content of file 1'));
    expect(output, isNot(contains('file2.dart')));
    expect(output, contains('FILE: ${path.join(tempDir.path, 'subdir', 'file3.txt')}'));
    expect(output, contains('Content of file 3'));
  });

  test('Ignore folders', () async {
    Directory(path.join(tempDir.path, 'include')).createSync();
    File(path.join(tempDir.path, 'include', 'file1.txt')).writeAsStringSync('Include this');
    Directory(path.join(tempDir.path, 'exclude')).createSync();
    File(path.join(tempDir.path, 'exclude', 'file2.txt')).writeAsStringSync('Exclude this');

    final result = await runApp([
      tempDir.path,
      '--output=$outputFile',
      '--ignore-folders=exclude',
    ]);

    expect(result.exitCode, equals(0));

    final output = File(outputFile).readAsStringSync();
    expect(output, contains('Include this'));
    expect(output, isNot(contains('Exclude this')));
  });

  test('Ignore files', () async {
    File(path.join(tempDir.path, 'keep.txt')).writeAsStringSync('Keep this');
    File(path.join(tempDir.path, 'ignore.txt')).writeAsStringSync('Ignore this');

    final result = await runApp([
      tempDir.path,
      '--output=$outputFile',
      '--ignore-files=ignore.txt',
    ]);

    expect(result.exitCode, equals(0));

    final output = File(outputFile).readAsStringSync();
    expect(output, contains('Keep this'));
    expect(output, isNot(contains('Ignore this')));
  });

  test('Multiple paths', () async {
    Directory(path.join(tempDir.path, 'dir1')).createSync();
    File(path.join(tempDir.path, 'dir1', 'file1.txt')).writeAsStringSync('Dir 1 File');
    Directory(path.join(tempDir.path, 'dir2')).createSync();
    File(path.join(tempDir.path, 'dir2', 'file2.txt')).writeAsStringSync('Dir 2 File');

    final result = await runApp([
      path.join(tempDir.path, 'dir1'),
      path.join(tempDir.path, 'dir2'),
      '--output=$outputFile',
    ]);

    expect(result.exitCode, equals(0));

    final output = File(outputFile).readAsStringSync();
    expect(output, contains('Dir 1 File'));
    expect(output, contains('Dir 2 File'));
  });

  test('Non-existent path', () async {
    final nonExistentPath = path.join(tempDir.path, 'non_existent');

    final result = await runApp([
      nonExistentPath,
      '--output=$outputFile',
    ]);

    expect(result.exitCode, equals(0));
    expect(result.stdout.split('\n'), hasLength(3));
    expect(result.stdout, contains('Output file: $outputFile'));
    expect(File(outputFile).readAsStringSync(), isEmpty);
  });

  test('Empty file', () async {
    File(path.join(tempDir.path, 'empty.txt')).createSync();

    final result = await runApp([
      tempDir.path,
      '--output=$outputFile',
    ]);

    expect(result.exitCode, equals(0));

    final output = File(outputFile).readAsStringSync();
    expect(output, contains('FILE: ${path.join(tempDir.path, 'empty.txt')}'));
    // Allow for a possible newline after the file path
    expect(output.split('\n').where((line) => line.trim().isNotEmpty).length, inInclusiveRange(1, 2));
  });
}
