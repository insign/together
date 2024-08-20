# Together

Simple binary that joins text/code files together

## Why?
I use this to upload to AI and ask for help or changes making the AI to know all the project context.

### Personal example at [SevenZip](https://github.com/verseles/SevenZip):
```bash
tog \
    /path/to/project/* \
    --output=ai.txt \
    --ignore-folders=vendor \
    --ignore-folders=test_files \
    --ignore-folders=bin \
    --ignore-extensions=lock,bash \
    --ignore-files=LICENSE.md \
    --ignore-files=Makefile
```

## Personal usage on this project
> Since I do this a lot of times, I use a [makefile](Makefile) on every project

```bash
⚡ make
dart ./main.dart \
    . \
    --output=ai.txt \
    --ignore-folders=.dart_tool \
    --ignore-folders=.github \
    --ignore-folders=build \
    --ignore-folders=.idea \
    --ignore-folders=.git \
    --ignore-extensions=lock \
    --ignore-files=LICENSE.md \
    --ignore-files=Makefile \
    --ignore-files=.gitignore
Skipping file ./.DS_Store due to encoding issues.
Adding file ./main.dart
Adding file ./README.md
Adding file ./pubspec.yaml

Output file: ai.txt
```

# Usage

1. Download the binary for your OS in [releases](//github.com/insign/together/releases)
2. Run once: `mv /path/to/downloaded/file ./tog && chmod +x ./tog`
3. Run on terminal: `./tog <path1> <path2> ...`

```
<path>                 Specifies paths to process. Use glob patterns for more control.
--output               Specifies the output file name
                       (defaults to "output.txt")
--ignore-extensions    Specifies file extensions to ignore (comma separated)
--ignore-folders       Specifies folders to globally ignore (can be used multiple times)
--ignore-files         Specifies files to globally ignore (can be used multiple times)
```

## Glob Pattern Examples

- `path/to/folder`: Process all files directly in the specified folder
- `path/to/folder/*`: Process all files in the specified folder and its subfolders
- `path/to/specific/file.txt`: Process a single specific file
- `**/*.dart`: Match all Dart files in any subdirectory
- `lib/{src,test}/*.dart`: Match Dart files in either the `src` or `test` subdirectories of `lib`
- `**/*.{js,ts}`: Match all JavaScript and TypeScript files in any subdirectory

## Using dart

### Run
`dart run main.dart path/to/any/folder path/to/another/folder/* specific/file.txt`

### Compile
`dart compile exe -o tog main.dart`

`./tog path/to/any/folder path/to/another/folder/* specific/file.txt`
```
