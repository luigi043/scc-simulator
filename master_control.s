#!/bin/bash

# SFCC Master Control System
echo "🎮 Salesforce Commerce Cloud Master Control System"
echo ""

# Colours
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Function to get memory usage (cross-platform)
get_memory_usage() {
    if command -v free &> /dev/null; then
        # Linux
        free -m | awk '/Mem:/ {printf "%.0f", $3/$2*100}'
    elif command -v vm_stat &> /dev/null; then
        # macOS
        vm_stat | awk '
            /free/ {free=$3}
            /active/ {active=$3}
            /inactive/ {inactive=$3}
            /speculative/ {speculative=$3}
            /wired/ {wired=$3}
            END {
                total_memory=(free+active+inactive+speculative+wired)*4096/1048576
                used_memory=(active+inactive+speculative+wired)*4096/1048576
                printf "%.0f", used_memory/total_memory*100
            }' 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Function to get disk usage (cross-platform)
get_disk_usage() {
    if command -v df &> /dev/null; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            df -h . | awk 'NR==2 {print $5}' | sed 's/%//'
        else
            # Linux
            df -h . | awk 'NR==2 {print $5}' | sed 's/%//'
        fi
    else
        echo "0"
    fi
}

# Function to check if service is running
is_service_running() {
    local script_name=$1
    
    if ps aux | grep -v grep | grep -q "$script_name"; then
        return 0  # true
    else
        return 1  # false
    fi
}

show_master_dashboard() {
    clear
    echo -e "${PURPLE}=== 🎮 SFCC MASTER CONTROL ===${NC}"
    echo ""
    
    # Status of all services
    echo -e "${CYAN}🔄 SERVICE STATUS:${NC}"
    echo ""
    
    # API Simulator
    if is_service_running "api_server.sh"; then
        echo -e "  ${GREEN}●${NC} API Simulator: RUNNING"
    else
        echo -e "  ${RED}●${NC} API Simulator: STOPPED"
    fi
    
    # Alert System
    if is_service_running "alert_system.sh"; then
        echo -e "  ${GREEN}●${NC} Alert System: RUNNING"
    else
        echo -e "  ${RED}●${NC} Alert System: STOPPED"
    fi
    
    # Auto Monitor
    if is_service_running "auto_monitor.sh"; then
        echo -e "  ${GREEN}●${NC} Auto Monitor: RUNNING"
    else
        echo -e "  ${RED}●${NC} Auto Monitor: STOPPED"
    fi
    
    # Batch Processor
    if is_service_running "batch_processor.sh"; then
        echo -e "  ${GREEN}●${NC} Batch Processor: RUNNING"
    else
        echo -e "  ${RED}●${NC} Batch Processor: STOPPED"
    fi
    
    echo ""
    
    # System statistics
    echo -e "${CYAN}📊 SYSTEM STATISTICS:${NC}"
    echo ""
    
    TOTAL_ORDERS=$(ls orders/*.json 2>/dev/null | wc -l)
    ACTIVE_FAILURES=$(ls failures/*.json 2>/dev/null | grep -v resolved | wc -l)
    
    # Count log lines safely
    TOTAL_LOGS=0
    if [ -d "logs" ]; then
        for log_file in logs/*.log; do
            if [ -f "$log_file" ]; then
                LINES=$(wc -l < "$log_file" 2>/dev/null || echo "0")
                TOTAL_LOGS=$((TOTAL_LOGS + LINES))
            fi
        done
    fi
    
    # Backup size
    if [ -d "backups" ]; then
        BACKUP_SIZE=$(du -sh backups 2>/dev/null | cut -f1 || echo "0")
    else
        BACKUP_SIZE="0"
    fi
    
    echo "  📦 Orders: $TOTAL_ORDERS"
    echo "  🚨 Active Failures: $ACTIVE_FAILURES"
    echo "  📝 Log Lines: $TOTAL_LOGS"
    echo "  💾 Total Backup: $BACKUP_SIZE"
    
    echo ""
    
    # System health
    echo -e "${CYAN}❤️  SYSTEM HEALTH:${NC}"
    echo ""
    
    MEMORY_USAGE=$(get_memory_usage)
    if [ "$MEMORY_USAGE" -lt 70 ] 2>/dev/null; then
        echo -e "  ${GREEN}●${NC} Memory: ${MEMORY_USAGE}% (OK)"
    elif [ "$MEMORY_USAGE" -lt 85 ] 2>/dev/null; then
        echo -e "  ${YELLOW}●${NC} Memory: ${MEMORY_USAGE}% (WARNING)"
    else
        echo -e "  ${RED}●${NC} Memory: ${MEMORY_USAGE}% (CRITICAL)"
    fi
    
    DISK_USAGE=$(get_disk_usage)
    if [ "$DISK_USAGE" -lt 80 ] 2>/dev/null; then
        echo -e "  ${GREEN}●${NC} Disk: ${DISK_USAGE}% (OK)"
    elif [ "$DISK_USAGE" -lt 90 ] 2>/dev/null; then
        echo -e "  ${YELLOW}●${NC} Disk: ${DISK_USAGE}% (WARNING)"
    else
        echo -e "  ${RED}●${NC} Disk: ${DISK_USAGE}% (CRITICAL)"
    fi
    
    echo ""
    echo -e "${CYAN}🚀 QUICK ACTIONS:${NC}"
}

start_all_services() {
    echo -e "${BLUE}🚀 Starting all services...${NC}"
    
    # Check if scripts exist
    if [ ! -f "backend/api_server.sh" ]; then
        echo -e "${RED}❌ Error: backend/api_server.sh not found!${NC}"
        return 1
    fi
    
    if [ ! -f "scripts/alert_system.sh" ]; then
        echo -e "${RED}❌ Error: scripts/alert_system.sh not found!${NC}"
        return 1
    fi
    
    # Start services in background
    echo "Starting API Simulator..."
    cd backend && nohup ./api_server.sh > /dev/null 2>&1 &
    cd ..
    
    echo "Starting Alert System..."
    cd scripts && nohup ./alert_system.sh > /dev/null 2>&1 &
    cd ..
    
    echo "Starting Auto Monitor..."
    cd scripts && nohup ./auto_monitor.sh > /dev/null 2>&1 &
    cd ..
    
    echo "Starting Batch Processor..."
    cd scripts && nohup ./batch_processor.sh > /dev/null 2>&1 &
    cd ..
    
    sleep 2
    echo -e "${GREEN}✅ All services started!${NC}"
}

stop_all_services() {
    echo -e "${YELLOW}🛑 Stopping all services...${NC}"
    
    # Stop services
    pkill -f "api_server.sh" 2>/dev/null
    pkill -f "alert_system.sh" 2>/dev/null
    pkill -f "auto_monitor.sh" 2>/dev/null
    pkill -f "batch_processor.sh" 2>/dev/null
    
    echo -e "${GREEN}✅ All services stopped!${NC}"
    sleep 1
}

system_health_check() {
    echo -e "${BLUE}🔍 Running system health check...${NC}"
    echo ""
    
    # Check directories
    DIRS=("orders" "failures" "logs" "backups" "reports" "scripts" "backend")
    for dir in "${DIRS[@]}"; do
        if [ -d "$dir" ]; then
            echo -e "  ${GREEN}✓${NC} Directory $dir: OK"
        else
            echo -e "  ${YELLOW}⚠${NC} Directory $dir: MISSING"
        fi
    done
    
    echo ""
    
    # Check executable scripts
    SCRIPTS=("scc_simulator.sh" "scripts/alert_system.sh" "backend/api_server.sh")
    for script in "${SCRIPTS[@]}"; do
        if [ -f "$script" ]; then
            if [ -x "$script" ]; then
                echo -e "  ${GREEN}✓${NC} Script $script: EXECUTABLE"
            else
                echo -e "  ${YELLOW}⚠${NC} Script $script: NO PERMISSION"
                echo -e "     Run: chmod +x $script"
            fi
        else
            echo -e "  ${RED}✗${NC} Script $script: NOT FOUND"
        fi
    done
    
    echo ""
    
    # Check disk space
    echo -e "${YELLOW}💾 DISK USAGE:${NC}"
    if command -v df &> /dev/null; then
        df -h .
    else
        echo "  Command 'df' not available"
    fi
    
    echo ""
    
    # Check memory
    echo -e "${YELLOW}🧠 MEMORY USAGE:${NC}"
    MEMORY_USAGE=$(get_memory_usage)
    echo "  Memory usage: ${MEMORY_USAGE}%"
    
    echo ""
    
    # Check for Python/JSON tools
    echo -e "${YELLOW}🐍 DEPENDENCIES:${NC}"
    if command -v python3 &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} Python 3: Available"
    else
        echo -e "  ${YELLOW}⚠${NC} Python 3: Not found (some features may not work)"
    fi
    
    if command -v jq &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} jq: Available"
    else
        echo -e "  ${YELLOW}⚠${NC} jq: Not found (install with 'brew install jq' or 'apt install jq')"
    fi
}

show_log_viewer() {
    echo -e "${BLUE}📋 Unified Log Viewer${NC}"
    echo ""
    
    echo "1. Order Logs"
    echo "2. Failure Logs"
    echo "3. System Logs"
    echo "4. Deployment Logs"
    echo "5. View All Logs"
    echo "6. Clear All Logs"
    echo "7. Back"
    echo ""
    
    read -p "Choose: " log_choice
    
    case $log_choice in
        1) 
            if [ -f "logs/orders.log" ]; then
                echo -e "${YELLOW}Last 50 lines of orders.log:${NC}"
                tail -50 logs/orders.log
            else
                echo "File logs/orders.log not found"
            fi
            ;;
        2) 
            if [ -f "logs/failures.log" ]; then
                echo -e "${YELLOW}Last 50 lines of failures.log:${NC}"
                tail -50 logs/failures.log
            else
                echo "File logs/failures.log not found"
            fi
            ;;
        3) 
            if [ -f "logs/system.log" ]; then
                echo -e "${YELLOW}Last 50 lines of system.log:${NC}"
                tail -50 logs/system.log
            else
                echo "File logs/system.log not found"
            fi
            ;;
        4) 
            if [ -f "logs/deployments.log" ]; then
                echo -e "${YELLOW}Last 50 lines of deployments.log:${NC}"
                tail -50 logs/deployments.log
            else
                echo "File logs/deployments.log not found"
            fi
            ;;
        5)
            echo -e "${YELLOW}All available logs:${NC}"
            echo ""
            for log_file in logs/*.log; do
                if [ -f "$log_file" ]; then
                    echo "=== $(basename "$log_file") ==="
                    tail -10 "$log_file"
                    echo ""
                fi
            done
            ;;
        6)
            read -p "Are you sure you want to clear all logs? (y/n): " confirm
            if [ "$confirm" = "y" ]; then
                rm -f logs/*.log 2>/dev/null
                echo "✅ Logs cleared!"
            fi
            ;;
        7) return ;;
        *) echo "Invalid option" ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
}

# Main menu
while true; do
    show_master_dashboard
    
    echo ""
    echo "1. Start All Services"
    echo "2. Stop All Services"
    echo "3. Main Console (scc_simulator.sh)"
    echo "4. Alerts Dashboard"
    echo "5. Backup System"
    echo "6. Advanced Reporting"
    echo "7. Webhook Simulator"
    echo "8. Deployment Manager"
    echo "9. Health Check"
    echo "10. Log Viewer"
    echo "11. Install Dependencies"
    echo "12. Exit"
    echo ""
    
    read -p "Choose (1-12): " choice
    
    case $choice in
        1) start_all_services ;;
        2) stop_all_services ;;
        3) 
            if [ -f "scc_simulator.sh" ]; then
                ./scc_simulator.sh
            else
                echo -e "${RED}❌ scc_simulator.sh not found!${NC}"
            fi
            ;;
        4) 
            if [ -f "scripts/alert_system.sh" ]; then
                cd scripts && ./alert_system.sh
                cd ..
            else
                echo -e "${RED}❌ scripts/alert_system.sh not found!${NC}"
            fi
            ;;
        5) 
            if [ -f "scripts/backup_system.sh" ]; then
                cd scripts && ./backup_system.sh
                cd ..
            else
                echo -e "${RED}❌ scripts/backup_system.sh not found!${NC}"
            fi
            ;;
        6) 
            if [ -f "scripts/advanced_reporting.sh" ]; then
                cd scripts && ./advanced_reporting.sh
                cd ..
            else
                echo -e "${RED}❌ scripts/advanced_reporting.sh not found!${NC}"
            fi
            ;;
        7) 
            if [ -f "backend/webhook_simulator.sh" ]; then
                cd backend && ./webhook_simulator.sh
                cd ..
            else
                echo -e "${RED}❌ backend/webhook_simulator.sh not found!${NC}"
            fi
            ;;
        8) 
            if [ -f "scripts/deployment_manager.sh" ]; then
                cd scripts && ./deployment_manager.sh
                cd ..
            else
                echo -e "${RED}❌ scripts/deployment_manager.sh not found!${NC}"
            fi
            ;;
        9) system_health_check ;;
        10) show_log_viewer ;;
        11)
            echo -e "${BLUE}📦 Installing dependencies...${NC}"
            echo ""
            
            # Check and install jq
            if ! command -v jq &> /dev/null; then
                echo "Installing jq..."
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    brew install jq 2>/dev/null || echo "❌ Failed to install jq. Install manually: brew install jq"
                else
                    sudo apt-get install -y jq 2>/dev/null || sudo yum install -y jq 2>/dev/null || echo "❌ Failed to install jq"
                fi
            else
                echo "✅ jq already installed"
            fi
            
            # Check Python
            if ! command -v python3 &> /dev/null; then
                echo "⚠️  Python3 not found. Some features may not work."
                echo "   Install with: brew install python (macOS) or sudo apt install python3 (Linux)"
            else
                echo "✅ Python3 already installed"
            fi
            
            echo ""
            echo -e "${GREEN}✅ Dependency check completed!${NC}"
            ;;
        12) 
            stop_all_services
            echo -e "${GREEN}👋 Exiting Master Control...${NC}"
            exit 0
            ;;
        *) 
            echo -e "${RED}❌ Invalid option!${NC}"
            sleep 1
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done