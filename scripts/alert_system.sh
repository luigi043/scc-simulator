#!/bin/bash

# SFCC Real-Time Alert System
echo "🚨 Salesforce Commerce Cloud Alert System"
echo ""

# Colours
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Settings
ALERT_LOG="../logs/alerts.log"
NOTIFICATIONS_LOG="../logs/notifications.log"
CRITICAL_THRESHOLD=5
WARNING_THRESHOLD=3

# Function to send notifications
send_notification() {
    local level=$1
    local message=$2
    local details=$3
    
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    
    case $level in
        "CRITICAL")
            COLOR=$RED
            PREFIX="🔴 CRITICAL"
            # Simulate email/Slack sending
            echo "[$TIMESTAMP] EMAIL_ALERT: $message" >> $NOTIFICATIONS_LOG
            ;;
        "WARNING")
            COLOR=$YELLOW
            PREFIX="🟡 WARNING"
            echo "[$TIMESTAMP] SLACK_ALERT: $message" >> $NOTIFICATIONS_LOG
            ;;
        "INFO")
            COLOR=$GREEN
            PREFIX="🟢 INFO"
            ;;
    esac
    
    # Log to file
    echo "[$TIMESTAMP] [$level] $message - $details" >> $ALERT_LOG
    
    # Show on console
    echo -e "${COLOR}$PREFIX${NC} [$TIMESTAMP]"
    echo -e "   $message"
    echo -e "   📝 $details"
    echo ""
}

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
            }'
    elif command -v top &> /dev/null; then
        # Using top as fallback
        top -l 1 | awk '/PhysMem:/ {printf "%.0f", $8/$2*100}' 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Function to get CPU usage (cross-platform)
get_cpu_usage() {
    if command -v top &> /dev/null; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            top -l 2 | awk '/CPU usage:/ && NR>2 {print $3}' | tr -d '%'
        else
            # Linux
            top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1
        fi
    else
        echo "0"
    fi
}

# Monitor critical failures
monitor_critical_failures() {
    echo -e "${BLUE}🔍 Monitoring critical failures...${NC}"
    
    CRITICAL_COUNT=$(grep -r '"severity":"HIGH"' ../failures/*.json 2>/dev/null | grep -v resolved | wc -l)
    
    if [ "$CRITICAL_COUNT" -ge "$CRITICAL_THRESHOLD" ]; then
        send_notification "CRITICAL" "Multiple critical failures detected" "Total: $CRITICAL_COUNT HIGH failures"
    elif [ "$CRITICAL_COUNT" -ge "$WARNING_THRESHOLD" ]; then
        send_notification "WARNING" "Critical failures increasing" "Total: $CRITICAL_COUNT HIGH failures"
    fi
}

# Monitor SLA
monitor_sla() {
    echo -e "${BLUE}⏱️  Checking SLA...${NC}"
    
    # Calculate failures not resolved for more than 1 hour
    OLD_FAILURES=0
    for file in ../failures/*.json; do
        [[ -f "$file" ]] || continue
        [[ "$file" == *"resolved"* ]] && continue
        
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            FILE_AGE=$(( $(date +%s) - $(stat -f %m "$file") ))
        else
            # Linux
            FILE_AGE=$(( $(date +%s) - $(stat -c %Y "$file") ))
        fi
        
        if [ $FILE_AGE -gt 3600 ]; then  # More than 1 hour
            OLD_FAILURES=$((OLD_FAILURES + 1))
            FAILURE_ID=$(basename "$file" .json)
            
            if [ $FILE_AGE -gt 7200 ]; then  # More than 2 hours
                send_notification "CRITICAL" "Old failure not resolved" "ID: $FAILURE_ID - Age: $((FILE_AGE/3600))h"
            fi
        fi
    done
    
    if [ "$OLD_FAILURES" -gt 0 ]; then
        send_notification "WARNING" "Old failures pending" "Total: $OLD_FAILURES failures older than 1h"
    fi
}

# Monitor performance
monitor_performance() {
    echo -e "${BLUE}📈 Monitoring performance...${NC}"
    
    # Check simulated API response times
    if [ -f "../backend/api_traffic.log" ]; then
        SLOW_REQUESTS=$(awk -F',' '$(NF) > 1.0 {count++} END {print count}' "../backend/api_traffic.log" 2>/dev/null)
        
        if [ "$SLOW_REQUESTS" -gt 10 ]; then
            send_notification "WARNING" "Slow APIs detected" "$SLOW_REQUESTS requests above 1s"
        fi
    fi
    
    # Check resource usage
    MEMORY_USAGE=$(get_memory_usage)
    if [ "$MEMORY_USAGE" -gt 85 ] 2>/dev/null; then
        send_notification "WARNING" "High memory usage" "Current usage: ${MEMORY_USAGE}%"
    fi
    
    CPU_USAGE=$(get_cpu_usage)
    if [ "$CPU_USAGE" -gt 80 ] 2>/dev/null; then
        send_notification "WARNING" "High CPU usage" "Current usage: ${CPU_USAGE}%"
    fi
}

# Monitor trends
monitor_trends() {
    echo -e "${BLUE}📊 Analysing trends...${NC}"
    
    # Check for sudden increase in failures
    CURRENT_HOUR_FAILURES=$(grep "$(date +'%Y-%m-%d %H:')" ../logs/failures.log 2>/dev/null | wc -l)
    PREVIOUS_HOUR_FAILURES=$(grep "$(date -d '1 hour ago' +'%Y-%m-%d %H:')" ../logs/failures.log 2>/dev/null | wc -l)
    
    # Check if we have enough data
    if [ "$PREVIOUS_HOUR_FAILURES" -eq 0 ]; then
        PREVIOUS_HOUR_FAILURES=1  # Avoid division by zero
    fi
    
    if [ "$CURRENT_HOUR_FAILURES" -gt 0 ]; then
        INCREASE_PERCENTAGE=$(( (CURRENT_HOUR_FAILURES - PREVIOUS_HOUR_FAILURES) * 100 / PREVIOUS_HOUR_FAILURES ))
        
        if [ "$INCREASE_PERCENTAGE" -gt 100 ]; then
            send_notification "CRITICAL" "Drastic failure increase" "Increase: ${INCREASE_PERCENTAGE}% in the last hour"
        elif [ "$INCREASE_PERCENTAGE" -gt 50 ]; then
            send_notification "WARNING" "Significant failure increase" "Increase: ${INCREASE_PERCENTAGE}% in the last hour"
        fi
    fi
}

# Alerts dashboard
show_alert_dashboard() {
    clear
    echo -e "${PURPLE}=== 🚨 SFCC ALERTS DASHBOARD ===${NC}"
    echo ""
    
    # Alert statistics from last 24h
    CRITICAL_24H=$(grep -c "CRITICAL" $ALERT_LOG 2>/dev/null || echo "0")
    WARNING_24H=$(grep -c "WARNING" $ALERT_LOG 2>/dev/null || echo "0")
    
    echo -e "${YELLOW}📊 ALERT SUMMARY (24h):${NC}"
    echo -e "  🔴 Critical: $CRITICAL_24H"
    echo -e "  🟡 Warnings: $WARNING_24H"
    echo ""
    
    # Latest alerts
    echo -e "${YELLOW}📋 LATEST ALERTS:${NC}"
    if [ -f "$ALERT_LOG" ]; then
        tail -5 $ALERT_LOG 2>/dev/null | while read line; do
            if echo "$line" | grep -q "CRITICAL"; then
                echo -e "  ${RED}●${NC} $line"
            elif echo "$line" | grep -q "WARNING"; then
                echo -e "  ${YELLOW}●${NC} $line"
            else
                echo -e "  ${GREEN}●${NC} $line"
            fi
        done
    else
        echo "  No recent alerts"
    fi
    
    echo ""
    echo -e "${YELLOW}🔔 NOTIFICATIONS SENT:${NC}"
    if [ -f "$NOTIFICATIONS_LOG" ]; then
        tail -3 $NOTIFICATIONS_LOG 2>/dev/null || echo "  No recent notifications"
    else
        echo "  No recent notifications"
    fi
}

# Check if we're in the correct directory
if [ ! -d "../logs" ]; then
    echo -e "${RED}Error: logs directory not found!${NC}"
    echo "Execute this script from the scripts/ directory"
    exit 1
fi

# Main loop
echo "🔄 Alert system started. Checking every 30 seconds..."
echo "Press Ctrl+C to stop"
echo ""

COUNTER=0
while true; do
    COUNTER=$((COUNTER + 1))
    
    echo ""
    echo -e "${BLUE}=== Cycle $COUNTER - $(date +'%H:%M:%S') ===${NC}"
    
    # Execute all checks
    monitor_critical_failures
    monitor_sla
    monitor_performance
    monitor_trends
    
    # Show dashboard every 10 cycles
    if [ $((COUNTER % 10)) -eq 0 ]; then
        show_alert_dashboard
    fi
    
    sleep 30  # Check every 30 seconds
done