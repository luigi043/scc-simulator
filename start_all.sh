#!/bin/bash

# Initialise all SFCC services

echo "🚀 Initialising Salesforce Commerce Cloud Environment"
echo ""

# Colours
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if in correct directory
if [ ! -d "backend" ] || [ ! -d "scripts" ]; then
    echo -e "${YELLOW}⚠️  Execute this script from the project root directory${NC}"
    exit 1
fi

# Start services in background
start_service() {
    local name=$1
    local script=$2
    local dir=$3
    
    echo -e "${BLUE}▶️  Starting $name...${NC}"
    cd $dir
    nohup ./$script > /dev/null 2>&1 &
    cd ..
    sleep 1
    echo -e "${GREEN}✅ $name started${NC}"
}

# Launch menu
while true; do
    clear
    echo -e "${BLUE}=== SFCC Environment Launcher ===${NC}"
    echo ""
    echo "1. Start API Server Simulator"
    echo "2. Start Automatic Monitoring"
    echo "3. Start Batch Processing"
    echo "4. Start All Services"
    echo "5. View Service Status"
    echo "6. Stop All Services"
    echo "7. Start Main Console"
    echo "8. Exit"
    echo ""
    
    read -p "Choose: " choice
    
    case $choice in
        1) start_service "API Server" "api_server.sh" "backend" ;;
        2) start_service "Auto Monitor" "auto_monitor.sh" "scripts" ;;
        3) start_service "Batch Processor" "batch_processor.sh" "scripts" ;;
        4)
            start_service "API Server" "api_server.sh" "backend"
            start_service "Auto Monitor" "auto_monitor.sh" "scripts"
            start_service "Batch Processor" "batch_processor.sh" "scripts"
            echo ""
            echo -e "${GREEN}✅ All services started!${NC}"
            ;;
        5)
            echo -e "${YELLOW}📊 Service Status:${NC}"
            echo ""
            ps aux | grep -E "api_server|auto_monitor|batch_processor" | grep -v grep || echo "No services running"
            ;;
        6)
            echo "Stopping services..."
            pkill -f "api_server.sh"
            pkill -f "auto_monitor.sh"
            pkill -f "batch_processor.sh"
            echo -e "${GREEN}✅ Services stopped${NC}"
            ;;
        7) ./scc_simulator.sh ;;
        8) exit 0 ;;
        *) echo "Invalid option" ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done