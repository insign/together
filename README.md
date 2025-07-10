# Together

A simple command-line tool to concatenate text and code files, respecting `.gitignore` rules.

## Why?
I often need to provide a complete project context to AI models. This tool simplifies the process of bundling all relevant files into a single text file, making it easy to upload or paste.

### Example: Manual Exclusion
You can manually specify every file or folder to ignore. This is powerful but can be verbose.

```bash
tog \
    /path/to/project/** \
    --output=ai.txt \
    --ignore-folders=vendor \
    --ignore-folders=test_files \
    --ignore-folders=bin \
    --ignore-extensions=lock,bash \
    --ignore-files=LICENSE.md
```

### Example: Using a .gitignore file (Recommended)
For a much cleaner command, you can add the same rules to a `.gitignore` file and use the `--gitignore` flag.

First, your `.gitignore` file would look like this:
```gitignore
# .gitignore
vendor/
test_files/
bin/
*.lock
*.bash
LICENSE.md
```

Then, the command becomes simple and reusable:
```bash
tog /path/to/project/** --output=ai.txt --gitignore
```

## Personal usage on this project
> Since I do this a lot of times, I use a [makefile](Makefile) on every project. The command below uses the project's own `.gitignore` to exclude development files.

```bash
⚡ make
dart ./main.dart . --output=ai.txt --gitignore
Skipping file ./.DS_Store due to encoding issues.
Adding file ./main.dart
Adding file ./README.md
Adding file ./pubspec.yaml
Adding file ./tests.dart

Output file: ai.txt
```

# Usage

1. Download the binary for your OS from the [releases page](//github.com/insign/together/releases).
2. Make it executable: `chmod +x /path/to/downloaded/tog`
3. (Optional) Move it to a directory in your PATH: `mv /path/to/downloaded/tog /usr/local/bin/`
4. Run it from your terminal: `tog <path1> <path2> ... [options]`

```
<path>                 Specifies paths to process. Use glob patterns for more control.
--output               Specifies the output file name
                       (defaults to "output.txt")
--ignore-extensions    Specifies file extensions to ignore (comma separated)
--ignore-folders       Specifies folders to globally ignore (can be used multiple times)
--ignore-files         Specifies files to globally ignore (can be used multiple times)
--gitignore            Ignores files and directories based on the .gitignore file
                       in the current directory.
```

## Glob Pattern Examples

- `src/*.dart`: Match all Dart files directly inside the `src` directory.
- `lib/docs/file.txt`: Process a single, specific file.
- `assets/*`: Match all files and directories directly inside `assets` (e.g., `assets/logo.png`), but not in subdirectories (e.g., not `assets/icons/add.svg`).
- `assets/**`: Match all files and directories inside `assets` and all of its subdirectories, recursively.
- `**/*.dart`: Match all files ending with `.dart` in the current directory and all subdirectories.
- `lib/{src,test}/*.dart`: Match Dart files in either the `src` or `test` subdirectories of `lib`.
- `**/*.{js,ts}`: Match all JavaScript and TypeScript files in any subdirectory.

## Using Dart

### Run
`dart run main.dart path/to/any/folder path/to/another/folder/* specific/file.txt`

### Compile
`make` will compile the binary for your OS to `~/bin/tog`.

```bash
tog path/to/any/folder path/to/another/folder/* specific/file.txt
```
