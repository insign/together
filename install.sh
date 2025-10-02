#!/bin/sh

# Together (tog) Installation Script
# Installs or updates the latest version of tog from GitHub releases

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_info() {
    printf "${BLUE}ℹ${NC} %s\n" "$1"
}

print_success() {
    printf "${GREEN}✓${NC} %s\n" "$1"
}

print_warning() {
    printf "${YELLOW}⚠${NC} %s\n" "$1"
}

print_error() {
    printf "${RED}✗${NC} %s\n" "$1"
}

# Detect OS and architecture
detect_platform() {
    local os arch binary_name

    # Detect OS
    case "$(uname -s)" in
        Linux*)
            os="linux"
            ;;
        Darwin*)
            os="darwin"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            os="windows"
            ;;
        *)
            print_error "Unsupported operating system: $(uname -s)"
            exit 1
            ;;
    esac

    # Detect architecture
    case "$(uname -m)" in
        x86_64|amd64)
            if [ "$os" = "darwin" ]; then
                arch="arm64"  # Prefer Apple Silicon for macOS
            else
                arch="x86_64"
            fi
            ;;
        arm64|aarch64)
            arch="arm64"
            ;;
        *)
            print_warning "Unsupported architecture: $(uname -m), trying x86_64"
            arch="x86_64"
            ;;
    esac

    # Construct binary name
    case "$os" in
        linux)
            binary_name="tog-linux-${arch}.gz"
            ;;
        darwin)
            binary_name="tog-darwin-${arch}.gz"
            ;;
        windows)
            # Note: GitHub releases use uppercase AMD64 for Windows
            if [ "$arch" = "x86_64" ]; then
                binary_name="tog-windows-AMD64.gz"
            else
                binary_name="tog-windows-amd64.gz"
            fi
            ;;
    esac

    echo "$binary_name"
}

# Find existing tog installation
find_existing_tog() {
    if command -v tog >/dev/null 2>&1; then
        command -v tog
    else
        echo ""
    fi
}

# Determine installation directory
get_install_dir() {
    local existing_tog="$1"

    # If tog already exists, use its directory
    if [ -n "$existing_tog" ]; then
        dirname "$existing_tog"
        return
    fi

    # Try common directories in order of preference
    local dirs="/usr/local/bin $HOME/.local/bin $HOME/bin"

    for dir in $dirs; do
        if [ -d "$dir" ] && [ -w "$dir" ]; then
            echo "$dir"
            return
        fi
    done

    # Check if /usr/local/bin exists but isn't writable (may need sudo)
    if [ -d "/usr/local/bin" ] && [ ! -w "/usr/local/bin" ]; then
        echo "/usr/local/bin"
        return
    fi

    # If no writable directory found, try to create ~/.local/bin
    local local_bin="$HOME/.local/bin"
    if mkdir -p "$local_bin" 2>/dev/null; then
        echo "$local_bin"
        return
    fi

    # Fallback to current directory
    echo "."
}

# Check if directory is in PATH
is_in_path() {
    local dir="$1"
    case ":$PATH:" in
        *":$dir:"*) return 0 ;;
        *) return 1 ;;
    esac
}

# Main installation function
install_tog() {
    local binary_name install_dir existing_tog temp_file

    print_info "Installing tog - A tool to merge text/code files"
    echo

    # Detect platform
    binary_name=$(detect_platform)
    print_info "Detected platform: $binary_name"

    # Check for existing installation
    existing_tog=$(find_existing_tog)
    if [ -n "$existing_tog" ]; then
        print_info "Found existing installation: $existing_tog"
    fi

    # Determine installation directory
    install_dir=$(get_install_dir "$existing_tog")
    print_info "Installation directory: $install_dir"

    # Check if install directory is in PATH
    if [ "$install_dir" != "." ] && ! is_in_path "$install_dir"; then
        print_warning "Directory $install_dir is not in your PATH"
        print_info "Add it to your PATH by running:"
        print_info "  echo 'export PATH=\"$install_dir:\$PATH\"' >> ~/.bashrc && source ~/.bashrc"
        print_info "Or for zsh users:"
        print_info "  echo 'export PATH=\"$install_dir:\$PATH\"' >> ~/.zshrc && source ~/.zshrc"
    fi

    # Create temporary file
    temp_file=$(mktemp)
    trap 'rm -f "$temp_file"' EXIT

    # Download binary
    local download_url="https://github.com/insign/together/releases/latest/download/$binary_name"
    print_info "Downloading from: $download_url"

    if command -v curl >/dev/null 2>&1; then
        curl -fL -o "$temp_file" "$download_url"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$temp_file" "$download_url"
    else
        print_error "Neither curl nor wget found. Please install one of them."
        exit 1
    fi

    print_success "Downloaded successfully"

    # Decompress the file
    local decompressed_file="${temp_file}.decompressed"
    if command -v gunzip >/dev/null 2>&1; then
        gunzip -c "$temp_file" > "$decompressed_file"
    elif command -v gzip >/dev/null 2>&1; then
        gzip -dc "$temp_file" > "$decompressed_file"
    else
        print_error "gzip/gunzip not found. Cannot decompress the binary."
        exit 1
    fi

    print_success "Decompressed successfully"

    # Set executable permissions
    chmod +x "$decompressed_file"

    # Move to installation directory
    local target_path="$install_dir/tog"

    # Create backup if file exists
    if [ -f "$target_path" ]; then
        cp "$target_path" "$target_path.backup"
        print_info "Created backup: $target_path.backup"
    fi

    # Copy to target location
    if cp "$decompressed_file" "$target_path" 2>/dev/null; then
        print_success "Installed tog to: $target_path"
    else
        # Handle permission denied for system directories
        if [ "$install_dir" = "/usr/local/bin" ] || [ "$install_dir" = "/usr/bin" ]; then
            print_warning "Permission denied. Trying with sudo..."
            if command -v sudo >/dev/null 2>&1; then
                if sudo cp "$decompressed_file" "$target_path"; then
                    print_success "Installed tog to: $target_path (with sudo)"
                else
                    print_error "Failed to install even with sudo"
                    print_info "Try installing to user directory instead:"
                    print_info "  mkdir -p ~/.local/bin && cp \"$decompressed_file\" ~/.local/bin/tog"
                    exit 1
                fi
            else
                print_error "sudo not available and no permission to write to $install_dir"
                print_info "Installing to ~/.local/bin instead..."
                local user_bin="$HOME/.local/bin"
                mkdir -p "$user_bin"
                if cp "$decompressed_file" "$user_bin/tog"; then
                    target_path="$user_bin/tog"
                    install_dir="$user_bin"
                    print_success "Installed tog to: $target_path"
                    if ! is_in_path "$user_bin"; then
                        print_info "Add ~/.local/bin to your PATH:"
                        print_info "  echo 'export PATH=\"$user_bin:\$PATH\"' >> ~/.bashrc && source ~/.bashrc"
                    fi
                else
                    print_error "Failed to install to $user_bin"
                    exit 1
                fi
            fi
        else
            print_error "Failed to install to $target_path"
            exit 1
        fi
    fi

    # Verify installation
    if [ -x "$target_path" ]; then
        local version=$("$target_path" --version 2>/dev/null | head -n1 || echo "unknown")
        print_success "Installation complete! Version: $version"
        echo
        print_info "Usage: tog '<path1>' '<path2>' ... [options]"
        print_info "Help: tog --help"
        print_info "Update: tog --self-update"

        if [ "$install_dir" = "." ]; then
            print_warning "Installed in current directory. Move to PATH for global access:"
            print_info "  sudo mv ./tog /usr/local/bin/"
        fi
    else
        print_error "Installation verification failed"
        exit 1
    fi

    # Clean up temporary files
    rm -f "$temp_file" "$decompressed_file"
}

# Run installation
install_tog
