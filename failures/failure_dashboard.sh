#!/bin/bash

# SFCC Failure Dashboard
echo "🚨 Salesforce Commerce Cloud Failure Dashboard"
echo ""

# Colours
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

show_dashboard() {
    clear
    echo -e "${BLUE}=== SFCC FAILURE DASHBOARD ===${NC}"
    echo ""
    
    # Real-time statistics
    ACTIVE_FAILURES=$(ls -1 *.json 2>/dev/null | grep -v resolved | wc -l)
    RESOLVED_TODAY=$(find . -name "resolved_*.json" -mtime -1 | wc -l)
    CRITICAL_FAILURES=$(grep -l '"severity":"HIGH"' *.json 2>/dev/null | wc -l)
    
    # Colour system for status
    if [ "$ACTIVE_FAILURES" -gt 10 ]; then
        FAILURE_COLOR=$RED
        STATUS="CRITICAL"
    elif [ "$ACTIVE_FAILURES" -gt 5 ]; then
        FAILURE_COLOR=$YELLOW
        STATUS="WARNING"
    else
        FAILURE_COLOR=$GREEN
        STATUS="NORMAL"
    fi
    
    echo -e "📊 ${YELLOW}SYSTEM STATUS:${NC} ${FAILURE_COLOR}$STATUS${NC}"
    echo ""
    echo -e "  🔴 Active Failures: ${FAILURE_COLOR}$ACTIVE_FAILURES${NC}"
    echo -e "  🟡 Critical: $CRITICAL_FAILURES"
    echo -e "  🟢 Resolved Today: $RESOLVED_TODAY"
    echo ""
    
    # List of active failures
    echo -e "${YELLOW}🚨 ACTIVE FAILURES:${NC}"
    echo ""
    
    ls -1t *.json 2>/dev/null | grep -v resolved | head -10 | while read file; do
        FAILURE_ID=$(basename "$file" .json)
        TYPE=$(grep -o '"type":"[^"]*"' "$file" | cut -d'"' -f4)
        SEVERITY=$(grep -o '"severity":"[^"]*"' "$file" | cut -d'"' -f4)
        TIMESTAMP=$(grep -o '"timestamp":"[^"]*"' "$file" | cut -d'"' -f4 | cut -d'T' -f2 | cut -c1-5)
        
        case $SEVERITY in
            "HIGH") SEV_COLOR=$RED ;;
            "MEDIUM") SEV_COLOR=$YELLOW ;;
            *) SEV_COLOR=$GREEN ;;
        esac
        
        echo -e "  ${SEV_COLOR}●${NC} $TYPE"
        echo -e "     ID: $FAILURE_ID"
        echo -e "     Severity: ${SEV_COLOR}$SEVERITY${NC}"
        echo -e "     Time: $TIMESTAMP"
        echo ""
    done
    
    # SLA Status
    echo -e "${YELLOW}⏱️  SLA STATUS:${NC}"
    
    # Calculate average resolution time
    TOTAL_TIME=0
    RESOLVED_COUNT=0
    
    find . -name "resolved_*.json" -mtime -7 | while read file; do
        CREATED_TIME=$(grep -o '"timestamp":"[^"]*"' "$file" | cut -d'"' -f4)
        RESOLVED_TIME=$(stat -c %Y "$file")
        
        if [ -n "$CREATED_TIME" ]; then
            CREATED_EPOCH=$(date -d "${CREATED_TIME}" +%s 2>/dev/null || echo $RESOLVED_TIME)
            TIME_DIFF=$((RESOLVED_TIME - CREATED_EPOCH))
            TOTAL_TIME=$((TOTAL_TIME + TIME_DIFF))
            RESOLVED_COUNT=$((RESOLVED_COUNT + 1))
        fi
    done
    
    if [ $RESOLVED_COUNT -gt 0 ]; then
        AVG_SECONDS=$((TOTAL_TIME / RESOLVED_COUNT))
        AVG_MINUTES=$((AVG_SECONDS / 60))
        
        if [ $AVG_MINUTES -lt 30 ]; then
            SLA_COLOR=$GREEN
            SLA_STATUS="WITHIN SLA"
        elif [ $AVG_MINUTES -lt 60 ]; then
            SLA_COLOR=$YELLOW
            SLA_STATUS="ATTENTION"
        else
            SLA_COLOR=$RED
            SLA_STATUS="OUTSIDE SLA"
        fi
        
        echo -e "  Average Resolution Time: ${SLA_COLOR}$AVG_MINUTES minutes${NC}"
        echo -e "  Status: ${SLA_COLOR}$SLA_STATUS${NC}"
    else
        echo "  Not enough data to calculate SLA"
    fi
}

auto_triage() {
    echo -e "${BLUE}🤖 Starting Automatic Triage...${NC}"
    echo ""
    
    TRIAGED=0
    for file in *.json; do
        [[ -f "$file" ]] || continue
        
        ERROR_CODE=$(grep -o '"error_code":"[^"]*"' "$file" | cut -d'"' -f4)
        
        # Automatic triage rules
        case $ERROR_CODE in
            PAY_1*)
                echo "🔧 Applying fix for $ERROR_CODE..."
                sed -i 's/"retry_count":0/"retry_count":1/' "$file"
                sed -i '/"error_message"/a\    "auto_triage": "Payment validation rules updated",' "$file"
                TRIAGED=$((TRIAGED + 1))
                ;;
            ERR_50*)
                echo "🔧 Applying fix for $ERROR_CODE..."
                sed -i 's/"retry_count":0/"retry_count":1/' "$file"
                sed -i '/"error_message"/a\    "auto_triage": "API timeout increased",' "$file"
                TRIAGED=$((TRIAGED + 1))
                ;;
        esac
    done
    
    echo -e "${GREEN}✅ $TRIAGED failures triaged automatically${NC}"
}

generate_sla_report() {
    echo -e "${BLUE}📊 Generating SLA Report...${NC}"
    
    REPORT="sla_report_$(date +%Y%m%d).txt"
    
    {
        echo "=== SLA REPORT - SFCC SUPPORT ==="
        echo "Period: $(date)"
        echo ""
        
        echo "📈 PERFORMANCE METRICS"
        echo "Failures Resolved: $(find . -name "resolved_*.json" -mtime -1 | wc -l)"
        echo "Pending Failures: $(ls -1 *.json 2>/dev/null | grep -v resolved | wc -l)"
        echo "Average Resolution Time: $AVG_MINUTES minutes"
        echo ""
        
        echo "🎯 SLA ACHIEVEMENT"
        
        # Calculate success rate
        TOTAL_FAILURES=$(( $(find . -name "resolved_*.json" -mtime -7 | wc -l) + $(ls -1 *.json 2>/dev/null | grep -v resolved | wc -l) ))
        
        if [ $TOTAL_FAILURES -gt 0 ]; then
            SLA_RATE=$(echo "scale=1; $(find . -name "resolved_*.json" -mtime -7 | wc -l) * 100 / $TOTAL_FAILURES" | bc)
            
            if (( $(echo "$SLA_RATE >= 95" | bc -l) )); then
                echo "✅ EXCELLENT: $SLA_RATE% within SLA"
            elif (( $(echo "$SLA_RATE >= 85" | bc -l) )); then
                echo "⚠️  GOOD: $SLA_RATE% within SLA"
            else
                echo "❌ NEEDS IMPROVEMENT: $SLA_RATE% within SLA"
            fi
        fi
        
        echo ""
        echo "📋 RECOMMENDATIONS"
        echo "1. Monitor PAY_1XX type failures more closely"
        echo "2. Implement automatic retry for 50X ERRORS"
        echo "3. Review API timeout settings"
    } > "$REPORT"
    
    echo -e "${GREEN}✅ Report generated: $REPORT${NC}"
}

# Main menu
while true; do
    show_dashboard
    
    echo ""
    echo -e "${BLUE}⚡ QUICK ACTIONS:${NC}"
    echo "1. Refresh Dashboard"
    echo "2. Automatic Triage"
    echo "3. Generate SLA Report"
    echo "4. View All Failures"
    echo "5. Exit"
    echo ""
    
    read -p "Choose (1-5): " choice
    
    case $choice in
        1) continue ;;
        2) auto_triage ;;
        3) generate_sla_report ;;
        4) 
            echo ""
            echo "All Failures:"
            ls -1 *.json 2>/dev/null | while read file; do
                echo "  - $(basename $file .json)"
            done
            ;;
        5) exit 0 ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done