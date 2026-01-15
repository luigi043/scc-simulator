#!/bin/bash

# SFCC Log Analyser
echo "📊 Salesforce Commerce Cloud Log Analyser"
echo ""

# Colours
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

analyze_error_patterns() {
    echo -e "${BLUE}🔍 Analysing Error Patterns...${NC}"
    echo ""
    
    # Analysis by error type
    echo "📈 Distribution by Type:"
    grep -h "ERROR\|FAILED" *.log 2>/dev/null | grep -o "PAYMENT_FAILED\|INVENTORY_SYNC\|ORDER_EXPORT" | sort | uniq -c | sort -nr
    
    echo ""
    echo "🕒 Temporal Pattern:"
    echo "Morning (00-11): $(grep -c " 0[0-9]:\|1[0-1]:" *.log 2>/dev/null) errors"
    echo "Afternoon (12-17): $(grep -c "1[2-7]:" *.log 2>/dev/null) errors"
    echo "Evening (18-23): $(grep -c "1[8-9]:\|2[0-3]:" *.log 2>/dev/null) errors"
    
    echo ""
    echo "📉 Daily Trend:"
    tail -100 *.log 2>/dev/null | grep -c "FAILED" | awk '{print "Last 100 entries: "$1" failures"}'
}

find_critical_errors() {
    echo -e "${RED}🚨 Searching for Critical Errors...${NC}"
    echo ""
    
    # Search for critical errors
    CRITICAL_PATTERNS=(
        "timeout"
        "out of memory"
        "database"
        "connection refused"
        "disk full"
    )
    
    for pattern in "${CRITICAL_PATTERNS[@]}"; do
        COUNT=$(grep -i "$pattern" *.log 2>/dev/null | wc -l)
        if [ "$COUNT" -gt 0 ]; then
            echo -e "${RED}⚠️  $COUNT '$pattern' errors found${NC}"
            grep -i "$pattern" *.log 2>/dev/null | head -3 | sed 's/^/    /'
        fi
    done
}

generate_log_report() {
    echo -e "${GREEN}📄 Generating Log Report...${NC}"
    
    REPORT="log_analysis_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== SFCC Log Analysis ==="
        echo "Period: Last 24 hours"
        echo "Generated: $(date)"
        echo ""
        
        echo "📊 GENERAL STATISTICS"
        echo "Total Logs: $(wc -l *.log 2>/dev/null | tail -1 | awk '{print $1}')"
        echo "Errors: $(grep -c "ERROR\|FAILED" *.log 2>/dev/null)"
        echo "Warnings: $(grep -c "WARN\|ALERT" *.log 2>/dev/null)"
        echo ""
        
        echo "🚨 TOP 5 ERRORS"
        grep -h "ERROR\|FAILED" *.log 2>/dev/null | grep -o "PAY_[0-9]*\|ERR_[0-9]*" | sort | uniq -c | sort -nr | head -5
        echo ""
        
        echo "📈 RECOMMENDATIONS"
        
        # Analysis recommendations
        PAYMENT_ERRORS=$(grep -c "PAYMENT_FAILED" *.log 2>/dev/null)
        if [ "$PAYMENT_ERRORS" -gt 10 ]; then
            echo "1. ⚠️  Too many payment errors. Check gateway integration."
        fi
        
        TIMEOUT_COUNT=$(grep -c "timeout" *.log 2>/dev/null)
        if [ "$TIMEOUT_COUNT" -gt 5 ]; then
            echo "2. ⏱️  Frequent timeouts. Increase API timeouts."
        fi
    } > "$REPORT"
    
    echo -e "${GREEN}✅ Report generated: $REPORT${NC}"
}

# Main menu
while true; do
    clear
    echo -e "${BLUE}=== SFCC Log Analyser ===${NC}"
    echo ""
    echo "1. Analyse Error Patterns"
    echo "2. Search for Critical Errors"
    echo "3. Generate Complete Report"
    echo "4. Monitor Logs in Real Time"
    echo "5. Clean Old Logs"
    echo "6. Back"
    echo ""
    read -p "Choose: " choice
    
    case $choice in
        1) analyze_error_patterns ;;
        2) find_critical_errors ;;
        3) generate_log_report ;;
        4) tail -f *.log 2>/dev/null ;;
        5)
            echo "Cleaning logs older than 7 days..."
            find . -name "*.log" -mtime +7 -delete
            echo "✅ Complete"
            ;;
        6) exit 0 ;;
        *) echo "Invalid option" ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done