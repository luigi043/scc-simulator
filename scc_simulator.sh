#!/bin/bash

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Colour

# Configurations
LOG_DIR="./logs"
ORDERS_DIR="./orders"
FAILURES_DIR="./failures"
BACKEND_DIR="./backend"

# Initialise directories
mkdir -p $LOG_DIR $ORDERS_DIR $FAILURES_DIR $BACKEND_DIR

# Main functions
show_menu() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  Salesforce Commerce Cloud Simulator${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${GREEN}1.${NC} Simulate new order"
    echo -e "${GREEN}2.${NC} Simulate payment"
    echo -e "${GREEN}3.${NC} Simulate failure"
    echo -e "${GREEN}4.${NC} View support console"
    echo -e "${GREEN}5.${NC} Monitor logs"
    echo -e "${GREEN}6.${NC} Retry failed jobs"
    echo -e "${GREEN}7.${NC} Investigate logs"
    echo -e "${GREEN}8.${NC} Generate report"
    echo -e "${GREEN}9.${NC} Settings"
    echo -e "${GREEN}10.${NC} Start API Server Simulator"
    echo -e "${GREEN}11.${NC} Automatic Monitoring"
    echo -e "${GREEN}12.${NC} Batch Processing"
    echo -e "${GREEN}13.${NC} Log Analyser"
    echo -e "${GREEN}14.${NC} Order Manager"
    echo -e "${GREEN}15.${NC} Failure Dashboard"
    echo -e "${GREEN}0.${NC} Exit"
    echo ""
    echo -e "${YELLOW}Choose an option:${NC} "
}

simulate_order() {
    echo -e "${CYAN}Simulating new order...${NC}"
    
    # Generate unique ID
    ORDER_ID="ORD-$(date +%Y%m%d)-$(shuf -i 1000-9999 -n 1)"
    CUSTOMER_ID="CUST-$(shuf -i 10000-99999 -n 1)"
    
    # Generate random values
    TOTAL=$(printf "%.2f" $(echo "scale=2; $(shuf -i 50-500 -n 1) + $(shuf -i 0-99 -n 1)/100" | bc))
    ITEMS=$((RANDOM % 10 + 1))
    
    # Create order file
    cat > "$ORDERS_DIR/$ORDER_ID.json" << EOF
{
    "order_id": "$ORDER_ID",
    "customer_id": "$CUSTOMER_ID",
    "status": "PENDING",
    "total": $TOTAL,
    "items": $ITEMS,
    "currency": "USD",
    "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "payment_method": "credit_card",
    "shipping_address": {
        "street": "123 Main St",
        "city": "San Francisco",
        "state": "CA",
        "zip": "94105"
    }
}
EOF
    
    # Log
    LOG_MSG="[$(date +'%Y-%m-%d %H:%M:%S')] ORDER_CREATED: $ORDER_ID - Total: \$$TOTAL - Items: $ITEMS"
    echo "$LOG_MSG" >> "$LOG_DIR/orders.log"
    
    echo -e "${GREEN}✓ Order created:${NC} $ORDER_ID"
    echo -e "  Total: \$${TOTAL}"
    echo -e "  Items: ${ITEMS}"
    echo -e "  Status: Pending Payment"
    echo ""
    read -p "Press Enter to continue..."
}

simulate_payment() {
    echo -e "${CYAN}Simulating payment processing...${NC}"
    
    # Find pending orders
    PENDING_ORDERS=($(grep -l "PENDING" $ORDERS_DIR/*.json 2>/dev/null | head -5))
    
    if [ ${#PENDING_ORDERS[@]} -eq 0 ]; then
        echo -e "${YELLOW}No pending orders found.${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo -e "${YELLOW}Pending orders:${NC}"
    for i in "${!PENDING_ORDERS[@]}"; do
        ORDER_FILE="${PENDING_ORDERS[$i]}"
        ORDER_ID=$(basename "$ORDER_FILE" .json)
        TOTAL=$(grep -o '"total":[^,]*' "$ORDER_FILE" | cut -d: -f2)
        echo "[$((i+1))] $ORDER_ID - Total: \$$TOTAL"
    done
    
    echo ""
    read -p "Select order number (or 0 for all): " choice
    
    if [ "$choice" = "0" ]; then
        # Process all
        for ORDER_FILE in "${PENDING_ORDERS[@]}"; do
            process_payment "$ORDER_FILE"
        done
    elif [[ "$choice" =~ ^[1-9][0-9]*$ ]] && [ "$choice" -le ${#PENDING_ORDERS[@]} ]; then
        process_payment "${PENDING_ORDERS[$((choice-1))]}"
    fi
    
    read -p "Press Enter to continue..."
}

process_payment() {
    local ORDER_FILE="$1"
    local ORDER_ID=$(basename "$ORDER_FILE" .json)
    
    # 20% chance of failure
    if [ $((RANDOM % 5)) -eq 0 ]; then
        # Payment failure
        sed -i 's/"PENDING"/"FAILED"/' "$ORDER_FILE"
        
        # Create failure file
        FAILURE_ID="FAIL-$(date +%Y%m%d%H%M%S)-$(shuf -i 1000-9999 -n 1)"
        
        cat > "$FAILURES_DIR/$FAILURE_ID.json" << EOF
{
    "failure_id": "$FAILURE_ID",
    "order_id": "$ORDER_ID",
    "type": "PAYMENT_FAILED",
    "error_code": "PAY_$(shuf -i 100-199 -n 1)",
    "error_message": "Payment processor declined transaction",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "retry_count": 0
}
EOF
        
        # Failure log
        LOG_MSG="[$(date +'%Y-%m-%d %H:%M:%S')] PAYMENT_FAILED: $ORDER_ID - Error: PAYMENT_DECLINED"
        echo "$LOG_MSG" >> "$LOG_DIR/failures.log"
        
        echo -e "${RED}✗ Payment failed for:${NC} $ORDER_ID"
    else
        # Success
        sed -i 's/"PENDING"/"PAID"/' "$ORDER_FILE"
        
        # Success log
        LOG_MSG="[$(date +'%Y-%m-%d %H:%M:%S')] PAYMENT_SUCCESS: $ORDER_ID"
        echo "$LOG_MSG" >> "$LOG_DIR/payments.log"
        
        echo -e "${GREEN}✓ Payment processed:${NC} $ORDER_ID"
    fi
}

simulate_failure() {
    echo -e "${CYAN}Simulating system failures...${NC}"
    
    # Failure types
    FAILURE_TYPES=(
        "INVENTORY_SYNC_FAILED"
        "TAX_CALCULATION_ERROR" 
        "SHIPPING_RATE_UNAVAILABLE"
        "ORDER_EXPORT_FAILED"
        "CART_PIPELINE_ERROR"
    )
    
    FAILURE_TYPE=${FAILURE_TYPES[$((RANDOM % ${#FAILURE_TYPES[@]}))]}
    FAILURE_ID="SYS-FAIL-$(date +%Y%m%d%H%M%S)"
    ERROR_CODE="ERR_$(shuf -i 500-599 -n 1)"
    
    # Create system failure
    cat > "$FAILURES_DIR/$FAILURE_ID.json" << EOF
{
    "failure_id": "$FAILURE_ID",
    "type": "$FAILURE_TYPE",
    "error_code": "$ERROR_CODE",
    "error_message": "System failure in $FAILURE_TYPE",
    "severity": "$([ $((RANDOM % 2)) -eq 0 ] && echo "HIGH" || echo "MEDIUM")",
    "component": "sfcc-$([ $((RANDOM % 3)) -eq 0 ] && echo "ocapi" || echo "dw")",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "retry_count": 0
}
EOF
    
    # Log
    LOG_MSG="[$(date +'%Y-%m-%d %H:%M:%S')] SYSTEM_FAILURE: $FAILURE_TYPE - Code: $ERROR_CODE"
    echo "$LOG_MSG" >> "$LOG_DIR/system.log"
    
    echo -e "${RED}⚠ Simulated failure:${NC} $FAILURE_TYPE"
    echo -e "  Code: $ERROR_CODE"
    echo -e "  ID: $FAILURE_ID"
    echo ""
    read -p "Press Enter to continue..."
}

support_console() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   SCC Support Console${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # Statistics
    TOTAL_ORDERS=$(ls -1 $ORDERS_DIR/*.json 2>/dev/null | wc -l)
    FAILED_ORDERS=$(grep -l '"status":"FAILED"' $ORDERS_DIR/*.json 2>/dev/null | wc -l)
    ACTIVE_FAILURES=$(ls -1 $FAILURES_DIR/*.json 2>/dev/null | wc -l)
    
    echo -e "${YELLOW}📊 SYSTEM STATISTICS:${NC}"
    echo -e "  Total Orders: $TOTAL_ORDERS"
    echo -e "  Failed Orders: $FAILED_ORDERS"
    echo -e "  Active Failures: $ACTIVE_FAILURES"
    echo ""
    
    # Latest failures
    echo -e "${YELLOW}🚨 LATEST FAILURES:${NC}"
    ls -1t $FAILURES_DIR/*.json 2>/dev/null | head -5 | while read file; do
        TYPE=$(grep -o '"type":"[^"]*"' "$file" | cut -d'"' -f4)
        ERROR_CODE=$(grep -o '"error_code":"[^"]*"' "$file" | cut -d'"' -f4)
        TIMESTAMP=$(grep -o '"timestamp":"[^"]*"' "$file" | cut -d'"' -f4 | cut -d'T' -f1)
        echo "  • $TYPE ($ERROR_CODE) - $TIMESTAMP"
    done
    
    echo ""
    echo -e "${YELLOW}🛠 AVAILABLE ACTIONS:${NC}"
    echo "  1. List all failures"
    echo "  2. View failure details"
    echo "  3. Try automatic retry"
    echo "  4. Apply manual fix"
    echo "  5. Return to main menu"
    echo ""
    read -p "Choose an action: " action
    
    case $action in
        1) list_failures ;;
        2) view_failure_details ;;
        3) auto_retry ;;
        4) manual_fix ;;
        5) return ;;
        *) echo "Invalid option" ;;
    esac
    
    read -p "Press Enter to continue..."
    support_console
}

list_failures() {
    echo -e "${CYAN}📋 All Failures:${NC}"
    echo ""
    
    ls -1 $FAILURES_DIR/*.json 2>/dev/null | while read file; do
        FAILURE_ID=$(basename "$file" .json)
        TYPE=$(grep -o '"type":"[^"]*"' "$file" | cut -d'"' -f4)
        ERROR_CODE=$(grep -o '"error_code":"[^"]*"' "$file" | cut -d'"' -f4)
        RETRY_COUNT=$(grep -o '"retry_count":[^,]*' "$file" | cut -d: -f2)
        
        echo -e "  ${RED}${FAILURE_ID}${NC}"
        echo -e "    Type: $TYPE"
        echo -e "    Code: $ERROR_CODE"
        echo -e "    Attempts: $RETRY_COUNT"
        echo ""
    done
}

view_failure_details() {
    read -p "Enter failure ID: " failure_id
    
    FILE="$FAILURES_DIR/$failure_id.json"
    if [ -f "$FILE" ]; then
        echo ""
        echo -e "${CYAN}Failure Details:${NC}"
        echo "========================================"
        cat "$FILE" | python3 -m json.tool 2>/dev/null || cat "$FILE"
        echo ""
        
        # Fix suggestion
        ERROR_CODE=$(grep -o '"error_code":"[^"]*"' "$FILE" | cut -d'"' -f4)
        suggest_fix "$ERROR_CODE"
    else
        echo -e "${RED}Failure not found${NC}"
    fi
}

suggest_fix() {
    local error_code="$1"
    
    echo -e "${YELLOW}💡 FIX SUGGESTION:${NC}"
    
    case $error_code in
        PAY_1*)
            echo "  • Verify credit card limit"
            echo "  • Validate payment data"
            echo "  • Contact payment processor"
            ;;
        ERR_500|ERR_501|ERR_502)
            echo "  • Check API connectivity"
            echo "  • Restart OCAPI service"
            echo "  • Check server logs"
            ;;
        ERR_503|ERR_504)
            echo "  • Check connection timeout"
            echo "  • Increase timeout in settings"
            echo "  • Check server load"
            ;;
        *)
            echo "  • Consult SFCC documentation"
            echo "  • Check system logs"
            echo "  • Contact Salesforce support"
            ;;
    esac
}

auto_retry() {
    echo -e "${CYAN}🔄 Executing automatic retry...${NC}"
    
    RETRY_COUNT=0
    for file in $FAILURES_DIR/*.json; do
        [ -f "$file" ] || continue
        
        RETRY_COUNT_CURRENT=$(grep -o '"retry_count":[^,]*' "$file" | cut -d: -f2)
        if [ "$RETRY_COUNT_CURRENT" -lt 3 ]; then
            # Increment retry count
            sed -i "s/\"retry_count\":$RETRY_COUNT_CURRENT/\"retry_count\":$((RETRY_COUNT_CURRENT + 1))/" "$file"
            
            # 70% chance of success on retry
            if [ $((RANDOM % 10)) -lt 7 ]; then
                # Mark as resolved
                FAILURE_ID=$(basename "$file" .json)
                mv "$file" "$FAILURES_DIR/resolved_$FAILURE_ID.json"
                echo -e "${GREEN}✓ Resolved:${NC} $(basename $file)"
                RETRY_COUNT=$((RETRY_COUNT + 1))
            fi
        fi
    done
    
    echo -e "${GREEN}Retry completed.${NC} $RETRY_COUNT failures resolved."
}

manual_fix() {
    echo -e "${CYAN}🔧 Apply Manual Fix${NC}"
    echo ""
    
    read -p "Failure ID: " failure_id
    read -p "Fix description: " fix_description
    
    FILE="$FAILURES_DIR/$failure_id.json"
    if [ -f "$FILE" ]; then
        # Add fix information
        sed -i '$s/}/,    "manual_fix": "'"$fix_description"'",\n    "fixed_by": "'"$USER"'",\n    "fixed_at": "'"$(date -u +"%Y-%m-%dT%H:%M:%SZ")"'"\n}/' "$FILE"
        
        # Move to resolved
        mv "$FILE" "$FAILURES_DIR/resolved_$failure_id.json"
        
        echo -e "${GREEN}✓ Fix applied successfully!${NC}"
        
        # Fix log
        LOG_MSG="[$(date +'%Y-%m-%d %H:%M:%S')] MANUAL_FIX_APPLIED: $failure_id - Fix: $fix_description - By: $USER"
        echo "$LOG_MSG" >> "$LOG_DIR/support.log"
    else
        echo -e "${RED}Failure not found${NC}"
    fi
}

monitor_logs() {
    echo -e "${CYAN}📊 Real-Time Log Monitoring${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    echo ""
    
    # Show latest logs
    tail -f "$LOG_DIR"/*.log 2>/dev/null | while read line; do
        if echo "$line" | grep -q "FAILED\|ERROR"; then
            echo -e "${RED}$line${NC}"
        elif echo "$line" | grep -q "SUCCESS\|PAID"; then
            echo -e "${GREEN}$line${NC}"
        else
            echo -e "${CYAN}$line${NC}"
        fi
    done
}

investigate_logs() {
    echo -e "${CYAN}🔍 Investigate Logs${NC}"
    echo ""
    
    echo "1. Search for specific error"
    echo "2. View logs by date"
    echo "3. Analyse failure patterns"
    echo "4. Back"
    echo ""
    read -p "Choose: " choice
    
    case $choice in
        1)
            read -p "Search term: " search_term
            grep -i "$search_term" "$LOG_DIR"/*.log 2>/dev/null | head -20
            ;;
        2)
            read -p "Date (YYYY-MM-DD): " search_date
            grep "$search_date" "$LOG_DIR"/*.log 2>/dev/null
            ;;
        3)
            echo -e "${YELLOW}Failure Patterns:${NC}"
            echo "===================="
            grep -o "ERROR_CODE:[^ ]*" "$LOG_DIR"/*.log 2>/dev/null | sort | uniq -c | sort -nr
            ;;
    esac
    
    read -p "Press Enter to continue..."
}

generate_report() {
    echo -e "${CYAN}📈 Generating Report...${NC}"
    
    REPORT_FILE="report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "Salesforce Commerce Cloud Support Report"
        echo "Generated: $(date)"
        echo "========================================"
        echo ""
        echo "📊 STATISTICS"
        echo "Total Orders: $(ls -1 $ORDERS_DIR/*.json 2>/dev/null | wc -l)"
        echo "Failed Orders: $(grep -l '"status":"FAILED"' $ORDERS_DIR/*.json 2>/dev/null | wc -l)"
        echo "Active Failures: $(ls -1 $FAILURES_DIR/*.json 2>/dev/null | grep -v resolved | wc -l)"
        echo "Resolved Failures: $(ls -1 $FAILURES_DIR/resolved_*.json 2>/dev/null | wc -l)"
        echo ""
        echo "🚨 TOP FAILURE TYPES"
        grep -h '"type":"' $FAILURES_DIR/*.json 2>/dev/null | cut -d'"' -f4 | sort | uniq -c | sort -nr
        echo ""
        echo "🔄 RETRY STATISTICS"
        echo "Average retry count: $(grep -h '"retry_count":' $FAILURES_DIR/*.json 2>/dev/null | cut -d: -f2 | awk '{sum+=$1; count++} END {print count ? sum/count : 0}')"
        echo ""
        echo "👤 SUPPORT ACTIVITY"
        tail -20 "$LOG_DIR/support.log" 2>/dev/null || echo "No support activity logged"
    } > "$REPORT_FILE"
    
    echo -e "${GREEN}✓ Report generated:${NC} $REPORT_FILE"
    echo ""
    cat "$REPORT_FILE"
    
    read -p "Press Enter to continue..."
}

configure_system() {
    echo -e "${CYAN}⚙️ System Settings${NC}"
    echo ""
    
    echo "1. Clear all data"
    echo "2. Clear only logs"
    echo "3. Generate test data"
    echo "4. View disk space"
    echo "5. Back"
    echo ""
    read -p "Choose: " choice
    
    case $choice in
        1)
            read -p "Are you sure? (y/n): " confirm
            if [ "$confirm" = "y" ]; then
                rm -rf $ORDERS_DIR/* $FAILURES_DIR/* $LOG_DIR/*
                echo -e "${GREEN}✓ All data cleared${NC}"
            fi
            ;;
        2)
            rm -rf $LOG_DIR/*.log
            echo -e "${GREEN}✓ Logs cleared${NC}"
            ;;
        3)
            echo -e "${CYAN}Generating test data...${NC}"
            for i in {1..10}; do
                simulate_order
                sleep 0.1
            done
            for i in {1..3}; do
                simulate_failure
                sleep 0.1
            done
            ;;
        4)
            df -h .
            ;;
    esac
    
    read -p "Press Enter to continue..."
}

# Main menu
while true; do
    show_menu
    read choice
    
    case $choice in
        1) simulate_order ;;
        2) simulate_payment ;;
        3) simulate_failure ;;
        4) support_console ;;
        5) monitor_logs ;;
        6) auto_retry ;;
        7) investigate_logs ;;
        8) generate_report ;;
        9) configure_system ;;
        0) 
            echo -e "${CYAN}Exiting...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            sleep 1
            ;;
    esac
done