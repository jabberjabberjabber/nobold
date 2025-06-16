#!/bin/bash

INSTALL_DIR="${INSTALL_DIR:-$HOME/.koboldcpp}"
VERBOSE=false

# Command flags
while [[ $# -gt 0 ]]; do
    case $1 in
        --install-dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --uninstall)
            UNINSTALL=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--install-dir DIR] [--verbose] [--uninstall]"
            exit 1
            ;;
    esac
done

KOBOLDCPP_VERSION="latest"
GITHUB_REPO="LostRuins/koboldcpp"
DEFAULT_PORT=5001
DEFAULT_MODEL="llama3:8b"
VENV_NAME="nobold_env"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

write_info() { echo -e "${GREEN}INFO: $1${NC}"; }
write_warning() { echo -e "${YELLOW}WARNING: $1${NC}"; }
write_error() { echo -e "${RED}ERROR: $1${NC}"; }

echo -e "${CYAN}"
echo "======================================================"
echo "                 KoboldCpp Installer                  "
echo "          OpenWebUI Compatible AI Backend             "
echo "======================================================"
echo -e "${NC}"

uninstall_koboldcpp() {
    write_info "Starting KoboldCpp uninstallation..."
    
    if systemctl is-active --quiet koboldcpp.service 2>/dev/null; then
        write_info "Stopping koboldcpp service..."
        sudo systemctl stop koboldcpp.service
    fi
    
    if systemctl is-enabled --quiet koboldcpp.service 2>/dev/null; then
        write_info "Disabling koboldcpp service..."
        sudo systemctl disable koboldcpp.service
    fi
    
    if [ -f /etc/systemd/system/koboldcpp.service ]; then
        write_info "Removing koboldcpp service..."
        sudo rm -f /etc/systemd/system/koboldcpp.service
        sudo systemctl daemon-reload
    fi
    
    if [ -f "$HOME/.bashrc" ]; then
        write_info "Removing kobold directory from PATH..."
        sed -i "\|$INSTALL_DIR/bin|d" "$HOME/.bashrc"
    fi
    
    if [ -d "$INSTALL_DIR" ]; then
        write_info "Removing kobold directory: $INSTALL_DIR"
        rm -rf "$INSTALL_DIR"
    fi
    
    write_info "Uninstall successful."
    exit 0
}

if [ "$UNINSTALL" = true ]; then
    uninstall_koboldcpp
fi

write_info "Starting installation..."
write_info "Koboldcpp directory: $INSTALL_DIR"

check_dependencies() {
    write_info "Checking dependencies..."
    
    local missing_deps=()
    
    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        missing_deps+=("curl or wget")
    fi
    
    if ! command -v python3 &> /dev/null; then
        missing_deps+=("python3")
    fi
    
    if ! command -v pip3 &> /dev/null; then
        missing_deps+=("python3-pip")
    fi
    
    if ! python3 -m venv --help &> /dev/null; then
        missing_deps+=("python3-venv")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        write_error "Missing: ${missing_deps[*]}"
        write_info "Do and retry: sudo apt update && sudo apt install -y ${missing_deps[*]}"
        exit 1
    fi
}

initialize_directories() {
    write_info "Creating kobo directories..."
    
    local dirs=(
        "$INSTALL_DIR"
        "$INSTALL_DIR/bin"
        "$INSTALL_DIR/models"
        "$INSTALL_DIR/config"
        "$INSTALL_DIR/logs"
        "$INSTALL_DIR/scripts"
    )
    
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            write_info "Created: $dir"
        fi
    done
}

get_koboldcpp_binary() {
    write_info "Downloading Kobo binary..."
    
    local binary_name="koboldcpp-linux-x64"
    local download_url="https://github.com/LostRuins/koboldcpp/releases/latest/download/$binary_name"
    local binary_path="$INSTALL_DIR/bin/koboldcpp"
    
    write_info "Downloading from: $download_url"
    write_info "Installing to: $binary_path"
    
    if command -v curl &> /dev/null; then
        curl -L -o "$binary_path" "$download_url" || {
            write_error "Failed to download kobo!"
            exit 1
        }
    else
        wget -O "$binary_path" "$download_url" || {
            write_error "Failed to download kobo!"
            exit 1
        }
    fi
    
    chmod +x "$binary_path"
    write_info "Binary downloaded successfully"
    
    if "$binary_path" --version 2>&1; then
        write_info "KoboldCpp binary verified"
    else
        write_warning "Kobo verification failed, but continuing..."
    fi
}

create_systemd_service() {
    write_info "Creating koboldcpp service..."
    
    local service_file="/tmp/koboldcpp.service"
    
    cat > "$service_file" << EOF
[Unit]
Description=KoboldCpp LLM Engine Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR/bin
ExecStart=$INSTALL_DIR/bin/koboldcpp --config $INSTALL_DIR/config/default.kcppt
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    # Install service file
    sudo cp "$service_file" /etc/systemd/system/koboldcpp.service
    sudo systemctl daemon-reload
    
    write_info "Systemd service created"
}

install_open_webui() {
    echo -e "\n${YELLOW}Install Open-WebUI?${NC}"
    echo -e "${CYAN}1. Yes${NC}"
    echo -e "${CYAN}2. No${NC}"
    echo ""
    
    local choice
    while true; do
        read -p "Enter your choice (1, 2): " choice
        case $choice in
            1)
                write_info "Installing Open-WebUI..."
                cd "$INSTALL_DIR/scripts" || exit 1
                bash install-open-webui.sh
                break
                ;;
            2)
                write_info "Skipping Open-WebUI install..."
                break
                ;;
            *)
                write_warning "Invalid choice. Please enter 1 or 2."
                ;;
        esac
    done
}

create_helper_scripts() {
    write_info "Creating helper scripts..."
    
    # Create Open-WebUI install script
    cat > "$INSTALL_DIR/scripts/install-open-webui.sh" << 'EOF'
#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/../nobold_env"
VENV_NAME="nobold_env"

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "Python is not found. Please ensure Python is installed."
    exit 1
fi

# Create virtual environment if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating new virtual environment: $VENV_NAME"
    python3 -m venv "$VENV_DIR" || {
        echo "Failed to create virtual environment."
        exit 1
    }
else
    echo "Virtual environment $VENV_NAME already exists."
fi

# Activate virtual environment
source "$VENV_DIR/bin/activate"

# Upgrade pip and install open-webui
python3 -m pip install --upgrade pip
pip install open-webui || {
    echo "Failed to install open-webui."
    exit 1
}

deactivate
echo "Open-WebUI installed successfully!"
EOF
    chmod +x "$INSTALL_DIR/scripts/install-open-webui.sh"
    
    cat > "$INSTALL_DIR/scripts/open-webui-start.sh" << 'EOF'
#!/bin/bash

export OPENAI_API_BASE_URL="http://localhost:5001/v1"
export ENABLE_OPENAI_API="True"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/../nobold_env"
VENV_NAME="nobold_env"

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "Python is not found. Please ensure Python is installed."
    exit 1
fi

# Check if virtual environment exists
if [ ! -d "$VENV_DIR" ]; then
    echo "Virtual environment not found. Please run install-open-webui.sh first."
    exit 1
fi

# Activate virtual environment
source "$VENV_DIR/bin/activate"

# Start Open-WebUI
open-webui serve
EOF
    chmod +x "$INSTALL_DIR/scripts/open-webui-start.sh"
    
    cat > "$INSTALL_DIR/scripts/start.sh" << EOF
#!/bin/bash
echo "Starting KoboldCpp..."
cd "$INSTALL_DIR"
./bin/koboldcpp --config ./config/default.kcppt
EOF
    chmod +x "$INSTALL_DIR/scripts/start.sh"
    
    cat > "$INSTALL_DIR/scripts/stop.sh" << 'EOF'
#!/bin/bash
echo "Stopping KoboldCpp..."
pkill -f koboldcpp || echo "KoboldCpp not running"
echo "KoboldCpp stopped."
EOF
    chmod +x "$INSTALL_DIR/scripts/stop.sh"
    
    write_info "Helper scripts created in: $INSTALL_DIR/scripts/"
}

add_to_path() {
    write_info "Adding KoboldCpp to PATH..."
    
    local koboldcpp_path="$INSTALL_DIR/bin"
    local bashrc="$HOME/.bashrc"
    
    if ! grep -q "$koboldcpp_path" "$bashrc" 2>/dev/null; then
        echo "" >> "$bashrc"
        echo "# KoboldCpp" >> "$bashrc"
        echo "export PATH=\"\$PATH:$koboldcpp_path\"" >> "$bashrc"
        write_info "Added to PATH: $koboldcpp_path"
        write_warning "Please run 'source ~/.bashrc' or restart your terminal to use 'koboldcpp' command"
    else
        write_info "Already in PATH"
    fi
}

copy_config_file() {
    write_info "Copying configuration file..."
    
    if [ -f "default.kcppt" ]; then
        cp "default.kcppt" "$INSTALL_DIR/config/"
        write_info "Configuration file copied"
    else
        write_warning "default.kcppt not found in current directory"
        write_info "Creating empty configuration file..."
        touch "$INSTALL_DIR/config/default.kcppt"
    fi
}

main() {
    set -e
    
    check_dependencies
    initialize_directories
    get_koboldcpp_binary
    create_helper_scripts
    install_open_webui
    copy_config_file
    create_systemd_service
    add_to_path
    
    write_info "Installation completed successfully!"
    echo ""
    write_info "To start the service: sudo systemctl start koboldcpp.service"
    write_info "To enable on boot: sudo systemctl enable koboldcpp.service"
    write_info "To check status: sudo systemctl status koboldcpp.service"
    echo ""
    write_info "To start Open-WebUI: $INSTALL_DIR/scripts/open-webui-start.sh"
    echo ""
    write_info "To uninstall: $0 --uninstall"
}

main