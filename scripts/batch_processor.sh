#!/bin/bash

# Batch Processor for SFCC
echo "⚡ Starting Batch Processing"
echo ""

# Colours
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

process_order_export() {
    echo -e "${BLUE}📤 Exporting orders to ERP...${NC}"
    
    # Find paid orders not exported
    ORDERS_TO_EXPORT=$(grep -l '"status":"PAID"' ../orders/*.json 2>/dev/null | head -10)
    
    COUNT=0
    for ORDER_FILE in $ORDERS_TO_EXPORT; do
        ORDER_ID=$(basename "$ORDER_FILE" .json)
        
        # Simulate export
        echo -n "  Exporting $ORDER_ID..."
        sleep 0.5
        
        # 90% chance of success
        if [ $((RANDOM % 10)) -lt 9 ]; then
            # Mark as exported
            sed -i 's/"status":"PAID"/"status":"EXPORTED"/' "$ORDER_FILE"
            echo -e " ${GREEN}✓${NC}"
            
            # Log
            echo "$(date +'%Y-%m-%d %H:%M:%S'),EXPORT_SUCCESS,$ORDER_ID" >> ../logs/batch.log
            COUNT=$((COUNT + 1))
        else
            # Export failure
            echo -e " ${RED}✗${NC}"
            echo "$(date +'%Y-%m-%d %H:%M:%S'),EXPORT_FAILED,$ORDER_ID" >> ../logs/batch.log
        fi
    done
    
    echo -e "${GREEN}✅ $COUNT orders exported${NC}"
}

process_inventory_sync() {
    echo -e "${BLUE}🔄 Synchronising inventory...${NC}"
    
    # Simulate synchronisation
    for i in {1..5}; do
        PRODUCT_ID="PROD-$(printf "%03d" $i)"
        STOCK_LEVEL=$((RANDOM % 100 + 1))
        
        echo -n "  $PRODUCT_ID: $STOCK_LEVEL units..."
        sleep 0.3
        
        # Create inventory record
        cat > "../backend/inventory_$PRODUCT_ID.json" << EOF
{
    "product_id": "$PRODUCT_ID",
    "stock_level": $STOCK_LEVEL,
    "last_sync": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "status": "synced"
}
EOF
        
        echo -e " ${GREEN}✓${NC}"
    done
    
    echo "$(date +'%Y-%m-%d %H:%M:%S'),INVENTORY_SYNC,5_products" >> ../logs/batch.log
}

cleanup_old_data() {
    echo -e "${BLUE}🧹 Cleaning old data...${NC}"
    
    # Clean logs older than 7 days
    find ../logs -name "*.log" -mtime +7 -delete 2>/dev/null
    
    # Clean completed orders older than 30 days
    find ../orders -name "*.json" -mtime +30 | xargs grep -l '"status":"EXPORTED"' 2>/dev/null | while read file; do
        echo "  Archiving: $(basename $file)"
        mv "$file" "../orders/archived/$(basename $file)" 2>/dev/null
    done
    
    echo "$(date +'%Y-%m-%d %H:%M:%S'),CLEANUP_COMPLETED" >> ../logs/batch.log
    echo -e "${GREEN}✅ Cleanup completed${NC}"
}

# Processing menu
while true; do
    clear
    echo -e "${BLUE}=== SFCC Batch Processor ===${NC}"
    echo ""
    echo "1. Export Orders to ERP"
    echo "2. Synchronise Inventory"
    echo "3. Clean Old Data"
    echo "4. Execute All"
    echo "5. Back"
    echo ""
    read -p "Choose: " choice
    
    case $choice in
        1) process_order_export ;;
        2) process_inventory_sync ;;
        3) cleanup_old_data ;;
        4)
            process_order_export
            process_inventory_sync
            cleanup_old_data
            ;;
        5) exit 0 ;;
        *) echo "Invalid option" ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done