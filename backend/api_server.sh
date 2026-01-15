#!/bin/bash

# API Server Simulator para SFCC
PORT=8080
API_DIR="./api_responses"
mkdir -p $API_DIR

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Iniciando Salesforce Commerce Cloud API Simulator...${NC}"
echo -e "${BLUE}📡 Porta: $PORT${NC}"
echo ""

# Criar respostas de API pré-definidas
cat > "$API_DIR/ocapi_orders.json" << 'EOF'
{
    "_v": "21.3",
    "_type": "order",
    "order_no": "00000001",
    "order_total": 129.99,
    "currency": "USD",
    "status": "created",
    "payment_status": "paid",
    "shipping_status": "not_shipped",
    "billing_address": {
        "address1": "123 Main St",
        "city": "San Francisco",
        "country_code": "US",
        "first_name": "John",
        "last_name": "Doe",
        "phone": "555-1234"
    },
    "product_items": [
        {
            "product_id": "prod-001",
            "product_name": "SFCC Hoodie",
            "quantity": 2,
            "price": 64.99
        }
    ]
}
EOF

cat > "$API_DIR/dw_inventory.json" << 'EOF'
{
    "inventory": {
        "product_id": "prod-001",
        "stock_level": 45,
        "availability": "in_stock",
        "reserved": 3,
        "threshold": 10
    }
}
EOF

# Função para simular respostas da API
simulate_api_response() {
    local endpoint=$1
    local method=$2
    
    sleep 0.5  # Simular latência
    
    # 30% chance de erro
    if [ $((RANDOM % 10)) -lt 3 ]; then
        cat > /tmp/api_error.json << EOF
{
    "fault": {
        "type": "SystemFault",
        "message": "Internal server error",
        "detail": "OCAPI service unavailable",
        "error_code": "ERR-$(shuf -i 500-599 -n 1)",
        "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    }
}
EOF
        echo "HTTP/1.1 500 Internal Server Error"
        echo "Content-Type: application/json"
        echo "Content-Length: $(wc -c < /tmp/api_error.json)"
        echo ""
        cat /tmp/api_error.json
    else
        case $endpoint in
            "/s/-/dw/data/v21_3/orders/*")
                cat "$API_DIR/ocapi_orders.json"
                ;;
            "/inventory/*")
                cat "$API_DIR/dw_inventory.json"
                ;;
            *)
                echo '{"status":"ok","message":"Request processed"}'
                ;;
        esac
    fi
}

# Servidor HTTP simples
echo -e "${GREEN}✅ APIs Disponíveis:${NC}"
echo "  GET  /s/-/dw/data/v21_3/orders/{id}  - OCAPI Order Details"
echo "  GET  /inventory/{product_id}         - Inventory Check"
echo "  POST /jobs/order-export              - Trigger Order Export"
echo "  GET  /system/health                  - System Health Check"
echo ""

echo "Simulando APIs... Pressione Ctrl+C para parar"
echo ""

while true; do
    # Simular tráfego de API
    for i in {1..10}; do
        ENDPOINTS=(
            "/s/-/dw/data/v21_3/orders/ORD-$(shuf -i 1000-9999 -n 1)"
            "/inventory/prod-$(shuf -i 100-999 -n 1)"
            "/system/health"
            "/jobs/order-export"
        )
        
        ENDPOINT=${ENDPOINTS[$((RANDOM % ${#ENDPOINTS[@]}))]}
        METHODS=("GET" "POST")
        METHOD=${METHODS[$((RANDOM % ${#METHODS[@]}))]}
        
        echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $METHOD $ENDPOINT"
        
        # Simular tempo de resposta
        RESPONSE_TIME=$(echo "scale=2; $(shuf -i 50-2000 -n 1)/1000" | bc)
        sleep $RESPONSE_TIME
        
        # Registrar no log
        echo "$(date +'%Y-%m-%d %H:%M:%S'),$METHOD,$ENDPOINT,$RESPONSE_TIME" >> "$API_DIR/api_traffic.log"
        
        # 10% chance de falha crítica
        if [ $((RANDOM % 100)) -lt 10 ]; then
            echo -e "${RED}⚠️  Simulando falha de API...${NC}"
            sleep 2
            echo -e "${RED}❌ API Timeout após ${RESPONSE_TIME}s${NC}"
        fi
    done
    
    sleep 5
done