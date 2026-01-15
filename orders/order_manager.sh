#!/bin/bash

# SFCC Advanced Order Manager
echo "📦 Salesforce Commerce Cloud Order Manager"
echo ""

# Colours
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

view_orders() {
    echo -e "${BLUE}📋 Order List:${NC}"
    echo ""
    
    ls -1 *.json 2>/dev/null | while read file; do
        STATUS=$(grep -o '"status":"[^"]*"' "$file" | cut -d'"' -f4)
        ORDER_ID=$(basename "$file" .json)
        TOTAL=$(grep -o '"total":[^,]*' "$file" | cut -d: -f2)
        CUSTOMER=$(grep -o '"customer_id":"[^"]*"' "$file" | cut -d'"' -f4)
        
        case $STATUS in
            "PENDING") COLOR=$YELLOW ;;
            "PAID") COLOR=$GREEN ;;
            "FAILED") COLOR=$RED ;;
            "EXPORTED") COLOR=$BLUE ;;
            *) COLOR=$NC ;;
        esac
        
        echo -e "  $ORDER_ID - Customer: $CUSTOMER - Total: \$$TOTAL - Status: ${COLOR}$STATUS${NC}"
    done
}

search_order() {
    read -p "🔍 Search (Order ID, Customer or Status): " search_term
    
    echo ""
    echo "Search results for '$search_term':"
    echo ""
    
    FOUND=0
    for file in *.json; do
        if grep -qi "$search_term" "$file"; then
            ORDER_ID=$(basename "$file" .json)
            STATUS=$(grep -o '"status":"[^"]*"' "$file" | cut -d'"' -f4)
            TOTAL=$(grep -o '"total":[^,]*' "$file" | cut -d: -f2)
            
            echo -e "  📦 $ORDER_ID - Status: $STATUS - Total: \$$TOTAL"
            FOUND=1
        fi
    done
    
    if [ $FOUND -eq 0 ]; then
        echo "No orders found."
    fi
}

bulk_operations() {
    echo -e "${BLUE}⚡ Batch Operations:${NC}"
    echo ""
    echo "1. Cancel all pending orders"
    echo "2. Re-process failed orders"
    echo "3. Export paid orders"
    echo "4. Generate CSV report"
    echo ""
    read -p "Choose: " choice
    
    case $choice in
        1)
            COUNT=0
            for file in *.json; do
                if grep -q '"status":"PENDING"' "$file"; then
                    sed -i 's/"status":"PENDING"/"status":"CANCELLED"/' "$file"
                    COUNT=$((COUNT + 1))
                fi
            done
            echo "✅ $COUNT orders cancelled"
            ;;
        2)
            COUNT=0
            for file in *.json; do
                if grep -q '"status":"FAILED"' "$file"; then
                    # 80% chance of success in re-processing
                    if [ $((RANDOM % 10)) -lt 8 ]; then
                        sed -i 's/"status":"FAILED"/"status":"PAID"/' "$file"
                        echo "✅ $(basename $file .json): Re-processed successfully"
                    else
                        echo "❌ $(basename $file .json): Re-processing failed"
                    fi
                    COUNT=$((COUNT + 1))
                fi
            done
            ;;
        3)
            echo "Exporting paid orders..."
            mkdir -p exported_orders
            for file in *.json; do
                if grep -q '"status":"PAID"' "$file"; then
                    cp "$file" "exported_orders/$(basename $file)"
                    sed -i 's/"status":"PAID"/"status":"EXPORTED"/' "$file"
                fi
            done
            echo "✅ Orders exported to 'exported_orders/' folder"
            ;;
        4)
            echo "Generating CSV report..."
            echo "order_id,customer_id,status,total,created_at" > orders_report.csv
            for file in *.json; do
                ORDER_ID=$(basename "$file" .json)
                CUSTOMER_ID=$(grep -o '"customer_id":"[^"]*"' "$file" | cut -d'"' -f4)
                STATUS=$(grep -o '"status":"[^"]*"' "$file" | cut -d'"' -f4)
                TOTAL=$(grep -o '"total":[^,]*' "$file" | cut -d: -f2)
                CREATED_AT=$(grep -o '"created_at":"[^"]*"' "$file" | cut -d'"' -f4)
                
                echo "$ORDER_ID,$CUSTOMER_ID,$STATUS,$TOTAL,$CREATED_AT" >> orders_report.csv
            done
            echo "✅ Report generated: orders_report.csv"
            ;;
    esac
}

# Main menu
while true; do
    clear
    echo -e "${BLUE}=== SFCC Order Manager ===${NC}"
    echo ""
    echo "1. View All Orders"
    echo "2. Search for Specific Order"
    echo "3. View Order Details"
    echo "4. Batch Operations"
    echo "5. Back to Main Menu"
    echo ""
    
    STATS=$(ls -1 *.json 2>/dev/null | wc -l)
    PENDING=$(grep -l '"status":"PENDING"' *.json 2>/dev/null | wc -l)
    FAILED=$(grep -l '"status":"FAILED"' *.json 2>/dev/null | wc -l)
    
    echo -e "${YELLOW}📊 Statistics:${NC}"
    echo "  Total: $STATS orders"
    echo "  Pending: $PENDING"
    echo "  Failed: $FAILED"
    echo ""
    
    read -p "Choose: " choice
    
    case $choice in
        1) view_orders ;;
        2) search_order ;;
        3)
            read -p "Order ID: " order_id
            if [ -f "$order_id.json" ]; then
                cat "$order_id.json" | python3 -m json.tool 2>/dev/null || cat "$order_id.json"
            else
                echo "❌ Order not found"
            fi
            ;;
        4) bulk_operations ;;
        5) exit 0 ;;
        *) echo "Invalid option" ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done
