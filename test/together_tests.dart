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
    // Construct an absolute path to main.dart, assuming tests are run from project root.
    final mainScriptPath = path.join(Directory.current.path, 'main.dart');
    return await Process.run(
      'dart',
      ['run', mainScriptPath, ...args],
      workingDirectory: tempDir.path,
    );
  }

  test('Basic functionality', () async {
    // Create test files
    File(path.join(tempDir.path, 'file1.txt')).writeAsStringSync('Content of file 1');
    File(path.join(tempDir.path, 'file2.dart')).writeAsStringSync('Content of file 2');
    Directory(path.join(tempDir.path, 'subdir')).createSync();
    File(path.join(tempDir.path, 'subdir', 'file3.txt')).writeAsStringSync('Content of file 3');

    // Run the application using a glob pattern
    final result = await runApp([
      '*.txt', // Glob for current directory
      '**/*.txt', // Glob for subdirectories
      '--output=output.txt',
      '--ignore-extensions=dart',
    ]);

    expect(result.exitCode, equals(0));
    print('STDOUT: ${result.stdout}');
    print('STDERR: ${result.stderr}');

    // Check the output
    final output = File(outputFile).readAsStringSync();
    // The glob package finds relative paths which include './' prefix.
    expect(output, contains('FILE: ./file1.txt'));
    expect(output, contains('Content of file 1'));
    expect(output, isNot(contains('file2.dart')));
    expect(output, contains(path.join('subdir', 'file3.txt')));
    expect(output, contains('Content of file 3'));
  });

  test('Does not process the same file twice', () async {
    // Create a test file
    File(path.join(tempDir.path, 'file1.txt'))..writeAsStringSync('Content of file 1');

    // Run the application with two arguments that match the same file
    final result = await runApp([
      'file1.txt', // a direct path
      '*.txt', // a glob pattern
      '--output=output.txt',
    ]);

    expect(result.exitCode, equals(0));
    print('STDOUT: ${result.stdout}');
    print('STDERR: ${result.stderr}');

    final output = File(outputFile).readAsStringSync();

    // Check that the file header appears only once
    final fileHeader = 'FILE: ./file1.txt';
    final firstIndex = output.indexOf(fileHeader);
    final lastIndex = output.lastIndexOf(fileHeader);

    expect(firstIndex, isNot(-1), reason: 'File header should be present in the output.');
    expect(firstIndex, equals(lastIndex), reason: 'File header should only appear once.');
    expect(output, contains('Content of file 1'));
  });

  test('Ignore folders', () async {
    Directory(path.join(tempDir.path, 'include')).createSync();
    File(path.join(tempDir.path, 'include', 'file1.txt')).writeAsStringSync('Include this');
    Directory(path.join(tempDir.path, 'exclude')).createSync();
    File(path.join(tempDir.path, 'exclude', 'file2.txt')).writeAsStringSync('Exclude this');

    final result = await runApp([
      '**/*',
      '--output=output.txt',
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
      '*.txt',
      '--output=output.txt',
      '--ignore-files=ignore.txt',
    ]);

    expect(result.exitCode, equals(0));

    final output = File(outputFile).readAsStringSync();
    expect(output, contains('Keep this'));
    expect(output, isNot(contains('Ignore this')));
  });

  test('Handles .gitignore file', () async {
    // Create a .gitignore file
    final gitignoreContent = '''
    # Comments should be ignored
    ignored_dir/
    *.log
    specific_file_to_ignore.txt
    ''';
    final gitignoreFile = File(path.join(tempDir.path, '.gitignore'));
    gitignoreFile.writeAsStringSync(gitignoreContent);

    // Create files and directories to be ignored
    Directory(path.join(tempDir.path, 'ignored_dir')).createSync();
    File(path.join(tempDir.path, 'ignored_dir', 'test.txt')).writeAsStringSync('Should be ignored by dir rule');
    File(path.join(tempDir.path, 'app.log')).writeAsStringSync('Should be ignored by extension rule');
    File(path.join(tempDir.path, 'specific_file_to_ignore.txt'))
        .writeAsStringSync('Should be ignored by specific file rule');
    Directory(path.join(tempDir.path, 'lib')).createSync();
    File(path.join(tempDir.path, 'lib', 'nested.log')).writeAsStringSync('Should be ignored by nested extension rule');

    // Create files to be included
    File(path.join(tempDir.path, 'main.dart')).writeAsStringSync('Should be included');
    File(path.join(tempDir.path, 'lib', 'code.txt')).writeAsStringSync('Should be included also');

    final result = await runApp([
      '**/*', // Process all files recursively
      '--output=output.txt',
      '--gitignore', // Use the created gitignore
    ]);

    expect(result.exitCode, equals(0));

    final output = File(outputFile).readAsStringSync();

    expect(output, contains('Should be included'));
    expect(output, contains('Should be included also'));
    expect(output, isNot(contains('Should be ignored')));
  });

  test('Multiple paths', () async {
    Directory(path.join(tempDir.path, 'dir1')).createSync();
    File(path.join(tempDir.path, 'dir1', 'file1.txt')).writeAsStringSync('Dir 1 File');
    Directory(path.join(tempDir.path, 'dir2')).createSync();
    File(path.join(tempDir.path, 'dir2', 'file2.txt')).writeAsStringSync('Dir 2 File');

    final result = await runApp([
      path.join('dir1', 'file1.txt'),
      path.join('dir2', 'file2.txt'),
      '--output=output.txt',
    ]);

    expect(result.exitCode, equals(0));

    final output = File(outputFile).readAsStringSync();
    expect(output, contains('Dir 1 File'));
    expect(output, contains('Dir 2 File'));
  });

  test('Non-existent path', () async {
    final result = await runApp([
      'non_existent_dir/**/*',
      '--output=output.txt',
    ]);

    expect(result.exitCode, equals(0));
    expect(File(outputFile).readAsStringSync(), isEmpty);
  });

  test('Empty file', () async {
    File(path.join(tempDir.path, 'empty.txt')).createSync();

    final result = await runApp([
      'empty.txt',
      '--output=output.txt',
    ]);

    expect(result.exitCode, equals(0));

    final output = File(outputFile).readAsStringSync();
    expect(output, contains('FILE: ./empty.txt'));
    expect(output.trim(), 'FILE: ./empty.txt');
  });
}
