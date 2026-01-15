#!/bin/bash

# Simulador de Webhooks SFCC
echo "🔗 Simulador de Webhooks do Salesforce Commerce Cloud"
echo ""

# Configurações
PORT=9090
WEBHOOK_LOG="../logs/webhooks.log"
EVENTS_DIR="../webhook_events"

# Cores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

mkdir -p "$EVENTS_DIR"

# Lista de webhooks suportados
WEBHOOK_ENDPOINTS=(
    "/webhooks/order/created"
    "/webhooks/order/updated"
    "/webhooks/order/cancelled"
    "/webhooks/payment/processed"
    "/webhooks/payment/failed"
    "/webhooks/inventory/updated"
    "/webhooks/customer/created"
)

# Gerar payloads de exemplo
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

# Simular recebimento de webhook
simulate_webhook_reception() {
    local endpoint=$1
    local payload_file=$2
    
    echo -e "${BLUE}🔄 Simulando webhook: $endpoint${NC}"
    
    # Simular processamento
    sleep 0.5
    
    # 20% chance de falha no webhook
    if [ $((RANDOM % 5)) -eq 0 ]; then
        echo -e "${RED}❌ Webhook falhou (simulação)${NC}"
        STATUS="failed"
        RESPONSE_CODE=500
    else
        echo -e "${GREEN}✅ Webhook processado com sucesso${NC}"
        STATUS="processed"
        RESPONSE_CODE=200
    fi
    
    # Registrar no log
    EVENT_TYPE=$(basename "$payload_file" | cut -d'_' -f2- | sed 's/.json//')
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] WEBHOOK: $EVENT_TYPE - Status: $STATUS - Endpoint: $endpoint" >> "$WEBHOOK_LOG"
    
    # Simular retry se falhou
    if [ "$STATUS" = "failed" ]; then
        echo -e "${YELLOW}🔄 Tentando retry em 2 segundos...${NC}"
        sleep 2
        simulate_webhook_reception "$endpoint" "$payload_file"
    fi
}

# Dashboard de webhooks
show_webhook_dashboard() {
    clear
    echo -e "${BLUE}=== 🔗 DASHBOARD DE WEBHOOKS SFCC ===${NC}"
    echo ""
    
    # Estatísticas
    TOTAL_EVENTS=$(ls "$EVENTS_DIR"/*.json 2>/dev/null | wc -l)
    SUCCESSFUL_EVENTS=$(grep -c "Status: processed" "$WEBHOOK_LOG" 2>/dev/null)
    FAILED_EVENTS=$(grep -c "Status: failed" "$WEBHOOK_LOG" 2>/dev/null)
    
    echo -e "${YELLOW}📊 ESTATÍSTICAS:${NC}"
    echo "  Total de Eventos: $TOTAL_EVENTS"
    echo "  Processados: $SUCCESSFUL_EVENTS"
    echo "  Falhas: $FAILED_EVENTS"
    echo ""
    
    # Últimos eventos
    echo -e "${YELLOW}📋 ÚLTIMOS WEBHOOKS:${NC}"
    tail -10 "$WEBHOOK_LOG" 2>/dev/null | while read line; do
        if echo "$line" | grep -q "failed"; then
            echo -e "  ${RED}●${NC} $line"
        else
            echo -e "  ${GREEN}●${NC} $line"
        fi
    done
}

# Menu principal
while true; do
    clear
    echo -e "${BLUE}=== SIMULADOR DE WEBHOOKS SFCC ===${NC}"
    echo ""
    echo "1. Simular 'Order Created' Webhook"
    echo "2. Simular 'Payment Processed' Webhook"
    echo "3. Simular 'Payment Failed' Webhook"
    echo "4. Simular 'Inventory Updated' Webhook"
    echo "5. Dashboard de Webhooks"
    echo "6. Testar Todos os Webhooks"
    echo "7. Configurar Endpoints"
    echo "8. Voltar"
    echo ""
    
    read -p "Escolha (1-8): " choice
    
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
            echo -e "${YELLOW}Simulando falha de pagamento...${NC}"
            sleep 1
            echo -e "${RED}❌ Webhook de falha de pagamento enviado${NC}"
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] WEBHOOK: payment.failed - Status: processed" >> "$WEBHOOK_LOG"
            ;;
        4)
            echo -e "${YELLOW}Simulando atualização de inventário...${NC}"
            sleep 1
            echo -e "${GREEN}✅ Webhook de inventário enviado${NC}"
            echo "[$(date +'%Y-%m-%d %H:%M:%S')] WEBHOOK: inventory.updated - Status: processed" >> "$WEBHOOK_LOG"
            ;;
        5) show_webhook_dashboard ;;
        6)
            echo "Testando todos os webhooks..."
            for endpoint in "${WEBHOOK_ENDPOINTS[@]}"; do
                PAYLOAD_FILE=$(generate_order_created_payload)
                simulate_webhook_reception "$endpoint" "$PAYLOAD_FILE"
                sleep 1
            done
            ;;
        7)
            echo -e "${YELLOW}Endpoints de Webhook Configurados:${NC}"
            for endpoint in "${WEBHOOK_ENDPOINTS[@]}"; do
                echo "  POST http://localhost:$PORT$endpoint"
            done
            ;;
        8) exit 0 ;;
        *) echo "Opção inválida" ;;
    esac
    
    echo ""
    read -p "Pressione Enter para continuar..."
done