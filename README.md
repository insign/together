Simple binary that joins text/code files together

# Why?
I use this to upload to AI and ask for help or changes making the AI to know all the project context.
### Personal example at [SevenZip](https://github.com/verseles/SevenZip):
```bash
tog \
	--output=ai.txt \
	--folder-recursive="." \
	--ignore-folders=vendor \
	--ignore-folders=test_files \
	--ignore-folders=bin \
	--ignore-extensions=lock,bash \
	--ignore-files=LICENSE.md \
	--ignore-files=makefile
```

## Personal usage on this project
> Since I do this a lot of times, I use a [makefile](makefile) on every project

```bash
⚡ make
dart ./main.dart \
	--output=ai.txt \
	--folder-recursive="." \
	--ignore-folders=.dart_tool \
	--ignore-folders=.github \
	--ignore-folders=build \
	--ignore-folders=.idea \
	--ignore-folders=.git \
	--ignore-extensions=lock \
	--ignore-files=LICENSE.md \
	--ignore-files=makefile \
	--ignore-files=.gitignore
Skipping file ./.DS_Store due to encoding issues.
Adding file ./main.dart
Adding file ./README.md
Adding file ./pubspec.yaml

Output file: ai.txt
```
# Usage

Download the binary in (releases)[./releases] than run on terminal: `./tog --folder-recursive=/path/to/any/folder`

```
--folder               Specifies a folder to merge files (can be used multiple times)
--folder-recursive     Specifies a folder to merge files recursively (can be used multiple times)
--output               Specifies the output file name
                       (defaults to "output.txt")
--ignore-extensions    Specifies file extensions to ignore (comma separated)
--ignore-folders       Specifies folders to globally ignore (can be used multiple times)
--ignore-files         Specifies files to globally ignore (can be used multiple times)
```

## Using dart

### Run
`dart run main.dart --folder-recursive=/path/to/any/folder`

### Compile
`dart compile exe -o tog main.dart`

`./tog  --folder-recursive=/path/to/any/folder`
