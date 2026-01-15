#!/bin/bash

# SFCC Webhook Simulator
echo "🔗 Salesforce Commerce Cloud Webhook Simulator"
echo ""

# Settings
PORT=9090
WEBHOOK_LOG="../logs/webhooks.log"
EVENTS_DIR="../webhook_events"

# Colours
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

mkdir -p "$EVENTS_DIR"

# List of supported webhooks
WEBHOOK_ENDPOINTS=(
    "/webhooks/order/created"
    "/webhooks/order/updated"
    "/webhooks/order/cancelled"
    "/webhooks/payment/processed"
    "/webhooks/payment/failed"
    "/webhooks/inventory/updated"
    "/webhooks/customer/created"
)

# Generate example payloads
generate_order_created_payload() {
    ORDER_ID="WEBHOOK-ORD-$(date +%s)$(shuf -i 1000-9999 -n 1)"
    
    cat > "$EVENTS_DIR/${ORDER_ID}_created.json" << EOF
{
    "event": "order.created",
    "event_id": "evt_$(shuf -i 100000000000000-999999999999999 -n 1)",
    "created": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "data": {
        "order_id": "$ORDER_ID",
        "order_no": "$(printf "%08d" $(shuf -i 1-99999999 -n 1))",
        "status": "created",
        "currency": "USD",
        "amount_total": $(printf "%.2f" $(echo "scale=2; $(shuf -i 50-500 -n 1) + $(shuf -i 0-99 -n 1)/100" | bc)),
        "billing_address": {
            "city": "San Francisco",
            "country": "US",
            "line1": "123 Market St"
        },
        "customer": {
            "email": "customer$(shuf -i 1000-9999 -n 1)@example.com",
            "first_name": "John",
            "last_name": "Doe"
        },
        "line_items": [
            {
                "product_id": "prod_$(shuf -i 1000-9999 -n 1)",
                "sku": "SKU-$(shuf -i 10000-99999 -n 1)",
                "name": "SFCC Premium Product",
                "quantity": $(shuf -i 1-5 -n 1),
                "price": $(printf "%.2f" $(echo "scale=2; $(shuf -i 20-100 -n 1) + $(shuf -i 0-99 -n 1)/100" | bc))
            }
        ]
    }
}
EOF
    echo "$EVENTS_DIR/${ORDER_ID}_created.json"
}

generate_payment_processed_payload() {
    ORDER_ID="WEBHOOK-ORD-$(shuf -i 100000-999999 -n 1)"
    
    cat > "$EVENTS_DIR/${ORDER_ID}_payment.json" << EOF
{
    "event": "payment.processed",
    "event_id": "pay_$(shuf -i 100000000000000-999999999999999 -n 1)",
    "created": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "data": {
        "order_id": "$ORDER_ID",
        "payment_id": "pay_$(shuf -i 100000000000000-999999999999999 -n 1)",
        "amount": $(printf "%.2f" $(echo "scale=2; $(shuf -i 50-500 -n 1) + $(shuf -i 0-99 -n 1)/100" | bc)),
        "currency": "USD",
        "status": "succeeded",
        "payment_method": "card",
        "card_last4": "$(printf "%04d" $(shuf -i 1-9999 -n 1))"
    }
}
EOF
    echo "$EVENTS_DIR/${ORDER_ID}_payment.json"
}

# Simulate webhook reception
simulate_webhook_reception() {
    local endpoint=$1
    local payload_file=$2
    
    echo -e "${BLUE}🔄 Simulating webhook: $endpoint${NC}"
    
    # Simulate processing
    sleep 0.5
    
    # 20% chance of webhook failure
    if [ $((RANDOM % 5)) -eq 0 ]; then
        echo -e "${RED}❌ Webhook failed (simulation)${NC}"
        STATUS="failed"
        RESPONSE_CODE=500
    else
        echo -e "${GREEN}✅ Webhook processed successfully${NC}"
        STATUS="processed"
        RESPONSE_CODE=200
    fi
    
    # Log to file
    EVENT_TYPE=$(basename "$payload_file" | cut -d'_' -f2- | sed 's/.json//')
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] WEBHOOK: $EVENT_TYPE - Status: $STATUS - Endpoint: $endpoint" >> "$WEBHOOK_LOG"
    
    # Simulate retry if failed
    if [ "$STATUS" = "failed" ]; then
        echo -e "${YELLOW}🔄 Trying retry in 2 seconds...${NC}"
        sleep 2
        simulate_webhook_reception "$endpoint" "$payload_file"
    fi
}

# Webhooks dashboard
show_webhook_dashboard() {
    clear
    echo -e "${BLUE}=== 🔗 SFCC WEBHOOKS DASHBOARD ===${NC}"
    echo ""
    
    # Statistics
    TOTAL_EVENTS=$(ls "$EVENTS_DIR"/*.json 2>/dev/null | wc -l)
    SUCCESSFUL_EVENTS=$(grep -c "Status: processed" "$WEBHOOK_LOG" 2>/dev/null)
    FAILED_EVENTS=$(grep -c "Status: failed" "$WEBHOOK_LOG" 2>/dev/null)
    
    echo -e "${YELLOW}📊 STATISTICS:${NC}"
    echo "  Total Events: $TOTAL_EVENTS"
    echo "  Processed: $SUCCESSFUL_EVENTS"
    echo "  Failed: $FAILED_EVENTS"
    echo ""
    
    # Latest events
    echo -e "${YELLOW}📋 LATEST WEBHOOKS:${NC}"
    tail -10 "$WEBHOOK_LOG" 2>/dev/null | while read line; do
        if echo "$line" | grep -q "failed"; then
            echo -e "  ${RED}●${NC} $line"
        else
            echo -e "  ${GREEN}●${NC} $line"
        fi
    done
}

# Main menu
while true; do
    clear
    echo -e "${BLUE}=== SFCC WEBHOOK SIMULATOR ===${NC}"
    echo ""
    echo "1. Simulate 'Order Created' Webhook"
    echo "2. Simulate 'Payment Processed' Webhook"
    echo "3. Simulate 'Payment Failed' Webhook"
    echo "4. Simulate 'Inventory Updated' Webhook"
    echo "5. Webhooks Dashboard"
    echo "6. Test All Webhooks"
    echo "7. Configure Endpoints"
    echo "8. Back"
    echo ""
    
    read -p "Choose (1-8): " choice
    
    case $choice in
        1)
            PAYLOAD_FILE=$(generate_order_created_payload)
            simulate_webhook_reception "/webhooks/order/created" "$PAYLOAD_FILE"
            ;;
        2)
            PAYLOAD_FILE=$(generate_payment_processed_payload)
            simulate_webhook_reception "/webhooks/payment/processed" "$PAYLOAD_FILE"
            ;;
        3)
            echo -e "${YELLOW}Simulating payment failure...${NC}"
            sleep 1
            echo -e "${RED}❌ Payment failure webhook sent${NC}"
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] WEBHOOK: payment.failed - Status: processed" >> "$WEBHOOK_LOG"
            ;;
        4)
            echo -e "${YELLOW}Simulating inventory update...${NC}"
            sleep 1
            echo -e "${GREEN}✅ Inventory webhook sent${NC}"
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] WEBHOOK: inventory.updated - Status: processed" >> "$WEBHOOK_LOG"
            ;;
        5) show_webhook_dashboard ;;
        6)
            echo "Testing all webhooks..."
            for endpoint in "${WEBHOOK_ENDPOINTS[@]}"; do
                PAYLOAD_FILE=$(generate_order_created_payload)
                simulate_webhook_reception "$endpoint" "$PAYLOAD_FILE"
                sleep 1
            done
            ;;
        7)
            echo -e "${YELLOW}Configured Webhook Endpoints:${NC}"
            for endpoint in "${WEBHOOK_ENDPOINTS[@]}"; do
                echo "  POST http://localhost:$PORT$endpoint"
            done
            ;;
        8) exit 0 ;;
        *) echo "Invalid option" ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done