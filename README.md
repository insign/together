# Together

A simple command-line tool to concatenate text and code files, respecting `.gitignore` rules.

## Why?
I often need to provide a complete project context to AI models. This tool simplifies the process of bundling all relevant files into a single text file, making it easy to upload or paste.

### Example: Manual Exclusion
You can manually specify every file or folder to ignore. This is powerful but can be verbose.

```bash
tog \
    '/path/to/project/**' \
    --output=ai.txt \
    --ignore-folders=vendor \
    --ignore-folders=test_files \
    --ignore-folders=bin \
    --ignore-extensions=lock,bash \
    --ignore-files=LICENSE.md \
    --ignore-wild='*react*' \
    --ignore-wild='*test*'
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
tog '/path/to/project/**' --output=ai.txt --gitignore
```

### Example: Using Wildcard Patterns
You can use wildcard patterns to ignore files or folders that match specific patterns anywhere in their path:

```bash
# Ignore any file or folder containing 'react' in the name
tog '/path/to/project/**' --output=ai.txt --ignore-wild='*react*'

# Ignore multiple patterns
tog '/path/to/project/**' --output=ai.txt --ignore-wild='*test*' --ignore-wild='*spec*' --ignore-wild='*node_modules*'

# Combine with other ignore options
tog '/path/to/project/**' --output=ai.txt --ignore-wild='*react*' --ignore-extensions=log,tmp

# Common use cases with --ignore-wild
# Ignore all Node.js related files and folders
tog '/path/to/project/**' --output=ai.txt --ignore-wild='*node_modules*' --ignore-wild='*package-lock*'

# Ignore all test-related files
tog '/path/to/project/**' --output=ai.txt --ignore-wild='*test*' --ignore-wild='*spec*' --ignore-wild='*__tests__*'

# Ignore build artifacts and cache files
tog '/path/to/project/**' --output=ai.txt --ignore-wild='*build*' --ignore-wild='*dist*' --ignore-wild='*cache*' --ignore-wild='*.tmp*'

# Ignore framework-specific files (React, Vue, Angular)
tog '/path/to/project/**' --output=ai.txt --ignore-wild='*react*' --ignore-wild='*vue*' --ignore-wild='*angular*'
```

### Example: Self-Update
Keep your `tog` binary up to date with the latest version from GitHub:

```bash
# Check for updates and install the latest version
tog --self-update
```

The self-update feature will:
- Check the latest release on GitHub
- Download the appropriate binary for your operating system (Linux, macOS, or Windows)
- Create a backup of the current version
- Replace the current binary atomically
- Clean up temporary files

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

# Installation

## Quick Install (One-liner)

Install or update `tog` with a single command:

```bash
# Automatic installer (recommended)
curl -fsSL https://raw.githubusercontent.com/insign/together/main/install.sh | sh
```

Or using wget:
```bash
wget -qO- https://raw.githubusercontent.com/insign/together/main/install.sh | sh
```

### Direct One-liners (no script)

**Linux:**
```bash
curl -L "https://github.com/insign/together/releases/latest/download/tog-linux-x86_64.gz" | gunzip > tog && chmod +x tog && sudo mv tog /usr/local/bin/
```

**macOS:**
```bash
curl -L "https://github.com/insign/together/releases/latest/download/tog-darwin-arm64.gz" | gunzip > tog && chmod +x tog && mv tog /usr/local/bin/
```

**Windows (PowerShell):**
```powershell
iwr -Uri "https://github.com/insign/together/releases/latest/download/tog-windows-amd64" -OutFile "tog.exe"
```

## Manual Installation

1. Download the binary for your OS from the [releases page](//github.com/insign/together/releases).
2. Make it executable: `chmod +x /path/to/downloaded/tog`
3. (Optional) Move it to a directory in your PATH: `mv /path/to/downloaded/tog /usr/local/bin/`



# Updates

Keep your `tog` installation up to date:

## Automatic Update
```bash
# Update to the latest version
tog --self-update
```

## Reinstall with Script
```bash
# Reinstall/update using the installation script
curl -fsSL https://raw.githubusercontent.com/insign/together/main/install.sh | sh
```

The `--self-update` command will:
- Check for the latest version on GitHub
- Download the appropriate binary for your OS
- Create a backup of your current version
- Replace the binary atomically
- Clean up temporary files

# Troubleshooting

## Installation Issues

### Permission Denied
If you get permission errors when installing:
```bash
# Try installing to user directory
mkdir -p ~/.local/bin
curl -L "https://github.com/insign/together/releases/latest/download/tog-linux-x86_64.gz" | gunzip > ~/.local/bin/tog
chmod +x ~/.local/bin/tog

# Add to PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Command Not Found
If `tog` command is not found after installation:
1. Check if the installation directory is in your PATH: `echo $PATH`
2. Add the directory to your PATH:
   ```bash
   # For bash users
   echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
   
   # For zsh users  
   echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
   ```

### Self-Update Issues
If `tog --self-update` fails:
- Ensure you have write permissions to the tog binary location
- Try running with sudo if installed system-wide: `sudo tog --self-update`
- As alternative, reinstall using the installation script

## Usage Issues

### Glob Patterns Not Working
Always wrap glob patterns in single quotes:
```bash
# ✓ Correct
tog 'src/**/*.dart' --output=files.txt

# ✗ Wrong (shell will expand the pattern)
tog src/**/*.dart --output=files.txt
```

### Large File Processing
For very large projects:
- Use `--ignore-wild` to exclude unnecessary files: `--ignore-wild='*node_modules*'`
- Use `--gitignore` to respect .gitignore rules
- Consider using more specific glob patterns instead of `**/*`

# Usage

Run it from your terminal: `tog '<path1>' '<path2>' ... [options]`

> **Important Note on Glob Patterns:**
> Always wrap glob patterns (paths containing `*` or `**`) in single quotes (e.g., `'src/**/*.dart'`). This prevents your shell (like Bash or ZSH) from expanding the pattern itself, ensuring that `tog` receives it correctly and can search recursively as intended.

```
<path>                 Specifies paths to process. Use single quotes for glob patterns (e.g., 'src/**') to ensure correct expansion.
--output               Specifies the output file name
                       (defaults to "output.txt")
--ignore-extensions    Specifies file extensions to ignore (comma separated)
--ignore-folders       Specifies folders to globally ignore (can be used multiple times)
--ignore-files         Specifies files to globally ignore (can be used multiple times)
--ignore-wild          Specifies wildcard patterns to ignore files/folders (can be used multiple times, e.g., *react*)
--gitignore            Ignores files and directories based on the .gitignore file
                       in the current directory.
-h, --help             Show this help message.
--self-update          Download and install the latest version from GitHub.
```

## Glob Pattern Examples

The `**` pattern is powerful. It matches directories recursively. Using it correctly is key to leveraging `tog`.

- `'src/*.dart'`: Match all Dart files directly inside the `src` directory.
- `'lib/docs/file.txt'`: Process a single, specific file (quotes are optional but good practice).
- `'assets/**'`: **The key pattern.** Match everything inside `assets`, including files in `assets` itself and in all subdirectories, recursively. This is the most common way to process an entire folder.
- `'**/*.dart'`: Match all files ending with `.dart` in the current directory and all subdirectories.
- `'api/app/Http/Controllers/**'`: Match all files and folders inside `Controllers`, recursively.
- `'api/app/Http/Controllers/**/*.php'`: Match only files ending with `.php` inside `Controllers` and its subdirectories.

## Using Dart

### Run
`dart run main.dart 'path/to/folder/**' 'specific/file.txt'`

### Compile
`make` will compile the binary for your OS to `~/bin/tog`.

```bash
tog 'path/to/any/folder/**' 'specific/file.txt'
```