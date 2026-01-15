#!/bin/bash

# Auto Monitor for SFCC - Cross-Platform Version
LOG_FILE="../logs/auto_monitor.log"
ALERT_FILE="../logs/alerts.log"

echo "🔍 Starting SFCC Auto Monitor"
echo "Log: $LOG_FILE"
echo ""

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to get memory usage (cross-platform)
get_memory_usage() {
    if command -v free &> /dev/null; then
        # Linux
        free -m | awk '/Mem:/ {printf "%.1f", $3/$2*100}'
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
                printf "%.1f", used_memory/total_memory*100
            }' 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Function to get CPU usage (cross-platform)
get_cpu_usage() {
    if command -v top &> /dev/null; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            top -l 1 | awk '/CPU usage:/ {print $3}' | tr -d '%' 2>/dev/null || echo "0"
        else
            # Linux
            top -bn1 | grep "Cpu(s)" | awk '{print $2}' 2>/dev/null || echo "0"
        fi
    else
        echo "0"
    fi
}

monitor_failures() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] Checking failures...${NC}"
    
    # Check for new failures
    NEW_FAILURES=0
    if [ -d "../failures" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            NEW_FAILURES=$(find ../failures -name "*.json" -mmin -5 -type f 2>/dev/null | wc -l | tr -d ' ')
        else
            # Linux
            NEW_FAILURES=$(find ../failures -name "*.json" -mmin -5 2>/dev/null | wc -l)
        fi
    fi
    
    if [ "$NEW_FAILURES" -gt 0 ]; then
        echo -e "${RED}⚠️  $NEW_FAILURES new failures detected!${NC}" | tee -a $ALERT_FILE
        
        # Detail failures
        find ../failures -name "*.json" -mmin -5 2>/dev/null | head -5 | while read file; do
            TYPE=$(grep -o '"type":"[^"]*"' "$file" 2>/dev/null | cut -d'"' -f4 || echo "UNKNOWN")
            echo "  - $TYPE: $(basename "$file")" | tee -a $ALERT_FILE
        done
    fi
}

monitor_orders() {
    # Check for orders stuck for too long
    STUCK_ORDERS=0
    
    if [ -d "../orders" ]; then
        for file in ../orders/*.json; do
            [ -f "$file" ] || continue
            
            # Check if it's a pending order
            if grep -q '"status":"PENDING"' "$file" 2>/dev/null; then
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    # macOS
                    FILE_AGE=$(($(date +%s) - $(stat -f %m "$file")))
                else
                    # Linux
                    FILE_AGE=$(($(date +%s) - $(stat -c %Y "$file")))
                fi
                
                if [ $FILE_AGE -gt 300 ]; then  # More than 5 minutes
                    STUCK_ORDERS=$((STUCK_ORDERS + 1))
                fi
            fi
        done
    fi
    
    if [ "$STUCK_ORDERS" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  $STUCK_ORDERS orders stuck for too long${NC}" | tee -a $ALERT_FILE
    fi
}

monitor_system() {
    # Check resource usage
    CPU_USAGE=$(get_cpu_usage)
    MEM_USAGE=$(get_memory_usage)
    
    # Convert to number for comparison
    CPU_NUM=$(echo "$CPU_USAGE" | bc 2>/dev/null || echo "0")
    MEM_NUM=$(echo "$MEM_USAGE" | bc 2>/dev/null || echo "0")
    
    if (( $(echo "$CPU_NUM > 80" | bc -l 2>/dev/null || echo "0") )); then
        echo -e "${RED}🚨 High CPU: ${CPU_USAGE}%${NC}" | tee -a $ALERT_FILE
    fi
    
    if (( $(echo "$MEM_NUM > 85" | bc -l 2>/dev/null || echo "0") )); then
        echo -e "${RED}🚨 High Memory: ${MEM_USAGE}%${NC}" | tee -a $ALERT_FILE
    fi
}

generate_report() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] Generating report...${NC}"
    
    REPORT="../logs/daily_report_$(date +%Y%m%d).txt"
    
    {
        echo "=== SFCC Daily Report ==="
        echo "Generated: $(date)"
        echo ""
        echo "📊 ORDERS"
        echo "Total: $(ls ../orders/*.json 2>/dev/null | wc -l)"
        echo "Pending: $(grep -l '"status":"PENDING"' ../orders/*.json 2>/dev/null | wc -l)"
        echo "Failed: $(grep -l '"status":"FAILED"' ../orders/*.json 2>/dev/null | wc -l)"
        echo ""
        echo "🚨 FAILURES"
        echo "Active: $(ls ../failures/*.json 2>/dev/null | grep -v resolved | wc -l)"
        echo "Resolved: $(ls ../failures/resolved_*.json 2>/dev/null | wc -l)"
        echo ""
        echo "🔄 SUCCESS RATES"
        TOTAL_ORDERS=$(ls ../orders/*.json 2>/dev/null | wc -l)
        FAILED_ORDERS=$(grep -l '"status":"FAILED"' ../orders/*.json 2>/dev/null | wc -l)
        
        if [ $TOTAL_ORDERS -gt 0 ]; then
            SUCCESS_RATE=$(( (TOTAL_ORDERS - FAILED_ORDERS) * 100 / TOTAL_ORDERS ))
            echo "Success: ${SUCCESS_RATE}%"
        else
            echo "Success: 0%"
        fi
        
        echo ""
        echo "📈 RECOMMENDATIONS"
        
        FAILURE_COUNT=$(ls ../failures/*.json 2>/dev/null | grep -v resolved | wc -l)
        if [ "$FAILURE_COUNT" -gt 5 ]; then
            echo "⚠️  Too many active failures. Consider escalating to development team."
        fi
        
        STUCK_ORDERS_COUNT=0
        for file in ../orders/*.json 2>/dev/null; do
            [ -f "$file" ] || continue
            if grep -q '"status":"PENDING"' "$file" 2>/dev/null; then
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    FILE_AGE=$(($(date +%s) - $(stat -f %m "$file")))
                else
                    FILE_AGE=$(($(date +%s) - $(stat -c %Y "$file")))
                fi
                
                if [ $FILE_AGE -gt 600 ]; then  # More than 10 minutes
                    STUCK_ORDERS_COUNT=$((STUCK_ORDERS_COUNT + 1))
                fi
            fi
        done
        
        if [ "$STUCK_ORDERS_COUNT" -gt 0 ]; then
            echo "🔄 Old pending orders. Execute manual retry."
        fi
    } > "$REPORT" 2>/dev/null
    
    echo "Report saved to: $REPORT"
}

# Check if we're in the correct directory
if [ ! -d "../logs" ]; then
    echo -e "${RED}Error: logs directory not found!${NC}"
    echo "Execute this script from the scripts/ directory"
    exit 1
fi

# Main monitoring loop
echo "🔄 Monitoring started. Press Ctrl+C to stop."
echo ""

while true; do
    {
        echo ""
        echo "=== Monitoring Cycle $(date +'%H:%M:%S') ==="
        monitor_failures
        monitor_orders
        monitor_system
        echo ""
    } | tee -a $LOG_FILE 2>/dev/null
    
    # Generate report every hour
    if [ "$(date +%M)" = "00" ]; then
        generate_report
    fi
    
    sleep 60  # Check every minute
done