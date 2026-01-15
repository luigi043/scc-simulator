#!/bin/bash

# Universal Salesforce Commerce Cloud Simulator Installation

echo "🚀 Salesforce Commerce Cloud Simulator Installation"
echo "===================================================="
echo ""

# Colours
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Detect operating system
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macOS"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "Linux"
    elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        echo "Windows"
    else
        echo "Unknown"
    fi
}

OS=$(detect_os)
echo -e "${BLUE}System detected:${NC} $OS"
echo ""

# Create directory structure
echo -e "${BLUE}Creating directory structure...${NC}"
mkdir -p scc-simulator/{backend,logs,orders,failures,scripts,backups,reports,webhook_events}
cd scc-simulator

echo -e "${GREEN}✅ Structure created:${NC}"
echo "  scc-simulator/"
echo "  ├── backend/"
echo "  ├── logs/"
echo "  ├── orders/"
echo "  ├── failures/"
echo "  ├── scripts/"
echo "  ├── backups/"
echo "  ├── reports/"
echo "  └── webhook_events/"

echo ""

# Give execution permission to main scripts
echo -e "${BLUE}Configuring permissions...${NC}"
chmod +x *.sh 2>/dev/null || true
chmod +x scripts/*.sh 2>/dev/null || true
chmod +x backend/*.sh 2>/dev/null || true

echo -e "${GREEN}✅ Permissions configured${NC}"
echo ""

# Check and install dependencies
echo -e "${BLUE}Checking dependencies...${NC}"

# Check jq
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}❌ jq not found${NC}"
    echo -e "${BLUE}Installing jq...${NC}"
    
    case $OS in
        "macOS")
            if command -v brew &> /dev/null; then
                brew install jq
            else
                echo -e "${RED}❌ Homebrew not found. Install manually:${NC}"
                echo "  brew install jq"
                echo "Or download from: https://stedolan.github.io/jq/download/"
            fi
            ;;
        "Linux")
            if command -v apt-get &> /dev/null; then
                sudo apt-get update && sudo apt-get install -y jq
            elif command -v yum &> /dev/null; then
                sudo yum install -y jq
            else
                echo -e "${RED}❌ Package manager not supported. Install jq manually.${NC}"
            fi
            ;;
        *)
            echo -e "${RED}❌ System not supported. Install jq manually.${NC}"
            echo "Visit: https://stedolan.github.io/jq/download/"
            ;;
    esac
else
    echo -e "${GREEN}✅ jq already installed${NC}"
fi

echo ""

# Check Python
if ! command -v python3 &> /dev/null; then
    echo -e "${YELLOW}⚠️  Python3 not found${NC}"
    echo "Some features may require Python3."
    echo "Recommended to install:"
    case $OS in
        "macOS") echo "  brew install python" ;;
        "Linux") echo "  sudo apt install python3" ;;
    esac
else
    echo -e "${GREEN}✅ Python3 already installed${NC}"
fi

echo ""

# Check bc for mathematical calculations
if ! command -v bc &> /dev/null; then
    echo -e "${YELLOW}⚠️  bc not found${NC}"
    echo "Installing bc for calculations..."
    case $OS in
        "macOS") brew install bc 2>/dev/null || echo "Skip if not needed" ;;
        "Linux") sudo apt-get install -y bc 2>/dev/null || sudo yum install -y bc 2>/dev/null ;;
    esac
else
    echo -e "${GREEN}✅ bc already installed${NC}"
fi

echo ""

# Check multitail for log monitoring
if ! command -v multitail &> /dev/null; then
    echo -e "${YELLOW}ℹ️  multitail not found (optional)${NC}"
    echo "For better log monitoring, install multitail:"
    case $OS in
        "macOS") echo "  brew install multitail" ;;
        "Linux") echo "  sudo apt install multitail" ;;
    esac
else
    echo -e "${GREEN}✅ multitail already installed${NC}"
fi

echo ""

# Create basic configuration files
echo -e "${BLUE}Creating configuration files...${NC}"

# Basic settings
cat > .env << 'EOF'
# Salesforce Commerce Cloud Simulator Configuration
ENVIRONMENT=development
LOG_LEVEL=INFO
API_PORT=8080
WEBHOOK_PORT=9090
BACKUP_RETENTION_DAYS=7
FAILURE_RETRY_LIMIT=3
EOF

cat > README.md << 'EOF'
# Salesforce Commerce Cloud Simulator

Complete SFCC environment simulator for development and testing.

## 🚀 Quick Start

```bash
# Start the system
./master_control.sh

# Or use the main console
./scc_simulator.sh