#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configurações
LOG_DIR="./logs"
ORDERS_DIR="./orders"
FAILURES_DIR="./failures"
BACKEND_DIR="./backend"

# Inicializar diretórios
mkdir -p $LOG_DIR $ORDERS_DIR $FAILURES_DIR $BACKEND_DIR

# Funções principais
show_menu() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  Salesforce Commerce Cloud Simulator${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${GREEN}1.${NC} Simular nova ordem"
    echo -e "${GREEN}2.${NC} Simular pagamento"
    echo -e "${GREEN}3.${NC} Simular falha"
    echo -e "${GREEN}4.${NC} Ver console de suporte"
    echo -e "${GREEN}5.${NC} Monitorar logs"
    echo -e "${GREEN}6.${NC} Retry de jobs falhos"
    echo -e "${GREEN}7.${NC} Investigar logs"
    echo -e "${GREEN}8.${NC} Gerar relatório"
    echo -e "${GREEN}9.${NC} Configurações"
    echo -e "${GREEN}10.${NC} Iniciar API Server Simulator"
    echo -e "${GREEN}11.${NC} Monitoramento Automático"
    echo -e "${GREEN}12.${NC} Processamento em Lote"
    echo -e "${GREEN}13.${NC} Analisador de Logs"
    echo -e "${GREEN}14.${NC} Gerenciador de Ordens"
    echo -e "${GREEN}15.${NC} Dashboard de Falhas"
    echo -e "${GREEN}0.${NC} Sair"
    echo ""
    echo -e "${YELLOW}Escolha uma opção:${NC} "
}

simulate_order() {
    echo -e "${CYAN}Simulando nova ordem...${NC}"
    
    # Gerar ID único
    ORDER_ID="ORD-$(date +%Y%m%d)-$(shuf -i 1000-9999 -n 1)"
    CUSTOMER_ID="CUST-$(shuf -i 10000-99999 -n 1)"
    
    # Gerar valores aleatórios
    TOTAL=$(printf "%.2f" $(echo "scale=2; $(shuf -i 50-500 -n 1) + $(shuf -i 0-99 -n 1)/100" | bc))
    ITEMS=$((RANDOM % 10 + 1))
    
    # Criar arquivo da ordem
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
    
    echo -e "${GREEN}✓ Ordem criada:${NC} $ORDER_ID"
    echo -e "  Total: \$${TOTAL}"
    echo -e "  Itens: ${ITEMS}"
    echo -e "  Status: Pending Payment"
    echo ""
    read -p "Pressione Enter para continuar..."
}

simulate_payment() {
    echo -e "${CYAN}Simulando processamento de pagamento...${NC}"
    
    # Encontrar ordens pendentes
    PENDING_ORDERS=($(grep -l "PENDING" $ORDERS_DIR/*.json 2>/dev/null | head -5))
    
    if [ ${#PENDING_ORDERS[@]} -eq 0 ]; then
        echo -e "${YELLOW}Nenhuma ordem pendente encontrada.${NC}"
        read -p "Pressione Enter para continuar..."
        return
    fi
    
    echo -e "${YELLOW}Ordens pendentes:${NC}"
    for i in "${!PENDING_ORDERS[@]}"; do
        ORDER_FILE="${PENDING_ORDERS[$i]}"
        ORDER_ID=$(basename "$ORDER_FILE" .json)
        TOTAL=$(grep -o '"total":[^,]*' "$ORDER_FILE" | cut -d: -f2)
        echo "[$((i+1))] $ORDER_ID - Total: \$$TOTAL"
    done
    
    echo ""
    read -p "Selecione o número da ordem (ou 0 para todas): " choice
    
    if [ "$choice" = "0" ]; then
        # Processar todas
        for ORDER_FILE in "${PENDING_ORDERS[@]}"; do
            process_payment "$ORDER_FILE"
        done
    elif [[ "$choice" =~ ^[1-9][0-9]*$ ]] && [ "$choice" -le ${#PENDING_ORDERS[@]} ]; then
        process_payment "${PENDING_ORDERS[$((choice-1))]}"
    fi
    
    read -p "Pressione Enter para continuar..."
}

process_payment() {
    local ORDER_FILE="$1"
    local ORDER_ID=$(basename "$ORDER_FILE" .json)
    
    # 20% chance de falha
    if [ $((RANDOM % 5)) -eq 0 ]; then
        # Falha no pagamento
        sed -i 's/"PENDING"/"FAILED"/' "$ORDER_FILE"
        
        # Criar arquivo de falha
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
        
        # Log de falha
        LOG_MSG="[$(date +'%Y-%m-%d %H:%M:%S')] PAYMENT_FAILED: $ORDER_ID - Error: PAYMENT_DECLINED"
        echo "$LOG_MSG" >> "$LOG_DIR/failures.log"
        
        echo -e "${RED}✗ Pagamento falhou para:${NC} $ORDER_ID"
    else
        # Sucesso
        sed -i 's/"PENDING"/"PAID"/' "$ORDER_FILE"
        
        # Log de sucesso
        LOG_MSG="[$(date +'%Y-%m-%d %H:%M:%S')] PAYMENT_SUCCESS: $ORDER_ID"
        echo "$LOG_MSG" >> "$LOG_DIR/payments.log"
        
        echo -e "${GREEN}✓ Pagamento processado:${NC} $ORDER_ID"
    fi
}

simulate_failure() {
    echo -e "${CYAN}Simulando falhas do sistema...${NC}"
    
    # Tipos de falhas
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
    
    # Criar falha do sistema
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
    
    echo -e "${RED}⚠ Falha simulada:${NC} $FAILURE_TYPE"
    echo -e "  Código: $ERROR_CODE"
    echo -e "  ID: $FAILURE_ID"
    echo ""
    read -p "Pressione Enter para continuar..."
}

support_console() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   Console de Suporte SCC${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # Estatísticas
    TOTAL_ORDERS=$(ls -1 $ORDERS_DIR/*.json 2>/dev/null | wc -l)
    FAILED_ORDERS=$(grep -l '"status":"FAILED"' $ORDERS_DIR/*.json 2>/dev/null | wc -l)
    ACTIVE_FAILURES=$(ls -1 $FAILURES_DIR/*.json 2>/dev/null | wc -l)
    
    echo -e "${YELLOW}📊 ESTATÍSTICAS DO SISTEMA:${NC}"
    echo -e "  Total de Ordens: $TOTAL_ORDERS"
    echo -e "  Ordens Falhas: $FAILED_ORDERS"
    echo -e "  Falhas Ativas: $ACTIVE_FAILURES"
    echo ""
    
    # Últimas falhas
    echo -e "${YELLOW}🚨 ÚLTIMAS FALHAS:${NC}"
    ls -1t $FAILURES_DIR/*.json 2>/dev/null | head -5 | while read file; do
        TYPE=$(grep -o '"type":"[^"]*"' "$file" | cut -d'"' -f4)
        ERROR_CODE=$(grep -o '"error_code":"[^"]*"' "$file" | cut -d'"' -f4)
        TIMESTAMP=$(grep -o '"timestamp":"[^"]*"' "$file" | cut -d'"' -f4 | cut -d'T' -f1)
        echo "  • $TYPE ($ERROR_CODE) - $TIMESTAMP"
    done
    
    echo ""
    echo -e "${YELLOW}🛠 AÇÕES DISPONÍVEIS:${NC}"
    echo "  1. Listar todas as falhas"
    echo "  2. Ver detalhes de uma falha"
    echo "  3. Tentar retry automático"
    echo "  4. Aplicar correção manual"
    echo "  5. Voltar ao menu principal"
    echo ""
    read -p "Escolha uma ação: " action
    
    case $action in
        1) list_failures ;;
        2) view_failure_details ;;
        3) auto_retry ;;
        4) manual_fix ;;
        5) return ;;
        *) echo "Opção inválida" ;;
    esac
    
    read -p "Pressione Enter para continuar..."
    support_console
}

list_failures() {
    echo -e "${CYAN}📋 Todas as Falhas:${NC}"
    echo ""
    
    ls -1 $FAILURES_DIR/*.json 2>/dev/null | while read file; do
        FAILURE_ID=$(basename "$file" .json)
        TYPE=$(grep -o '"type":"[^"]*"' "$file" | cut -d'"' -f4)
        ERROR_CODE=$(grep -o '"error_code":"[^"]*"' "$file" | cut -d'"' -f4)
        RETRY_COUNT=$(grep -o '"retry_count":[^,]*' "$file" | cut -d: -f2)
        
        echo -e "  ${RED}${FAILURE_ID}${NC}"
        echo -e "    Tipo: $TYPE"
        echo -e "    Código: $ERROR_CODE"
        echo -e "    Tentativas: $RETRY_COUNT"
        echo ""
    done
}

view_failure_details() {
    read -p "Digite o ID da falha: " failure_id
    
    FILE="$FAILURES_DIR/$failure_id.json"
    if [ -f "$FILE" ]; then
        echo ""
        echo -e "${CYAN}Detalhes da Falha:${NC}"
        echo "========================================"
        cat "$FILE" | python3 -m json.tool 2>/dev/null || cat "$FILE"
        echo ""
        
        # Sugestão de correção
        ERROR_CODE=$(grep -o '"error_code":"[^"]*"' "$FILE" | cut -d'"' -f4)
        suggest_fix "$ERROR_CODE"
    else
        echo -e "${RED}Falha não encontrada${NC}"
    fi
}

suggest_fix() {
    local error_code="$1"
    
    echo -e "${YELLOW}💡 SUGESTÃO DE CORREÇÃO:${NC}"
    
    case $error_code in
        PAY_1*)
            echo "  • Verificar limite do cartão de crédito"
            echo "  • Validar dados do pagamento"
            echo "  • Contactar processador de pagamento"
            ;;
        ERR_500|ERR_501|ERR_502)
            echo "  • Verificar conectividade com API"
            echo "  • Reiniciar serviço OCAPI"
            echo "  • Verificar logs do servidor"
            ;;
        ERR_503|ERR_504)
            echo "  • Verificar timeout de conexão"
            echo "  • Aumentar timeout nas configurações"
            echo "  • Verificar carga do servidor"
            ;;
        *)
            echo "  • Consultar documentação do SFCC"
            echo "  • Verificar logs do sistema"
            echo "  • Contactar suporte Salesforce"
            ;;
    esac
}

auto_retry() {
    echo -e "${CYAN}🔄 Executando retry automático...${NC}"
    
    RETRY_COUNT=0
    for file in $FAILURES_DIR/*.json; do
        [ -f "$file" ] || continue
        
        RETRY_COUNT_CURRENT=$(grep -o '"retry_count":[^,]*' "$file" | cut -d: -f2)
        if [ "$RETRY_COUNT_CURRENT" -lt 3 ]; then
            # Incrementar retry count
            sed -i "s/\"retry_count\":$RETRY_COUNT_CURRENT/\"retry_count\":$((RETRY_COUNT_CURRENT + 1))/" "$file"
            
            # 70% chance de sucesso no retry
            if [ $((RANDOM % 10)) -lt 7 ]; then
                # Marcar como resolvido
                FAILURE_ID=$(basename "$file" .json)
                mv "$file" "$FAILURES_DIR/resolved_$FAILURE_ID.json"
                echo -e "${GREEN}✓ Resolvido:${NC} $(basename $file)"
                RETRY_COUNT=$((RETRY_COUNT + 1))
            fi
        fi
    done
    
    echo -e "${GREEN}Retry completado.${NC} $RETRY_COUNT falhas resolvidas."
}

manual_fix() {
    echo -e "${CYAN}🔧 Aplicar Correção Manual${NC}"
    echo ""
    
    read -p "ID da falha: " failure_id
    read -p "Descrição da correção: " fix_description
    
    FILE="$FAILURES_DIR/$failure_id.json"
    if [ -f "$FILE" ]; then
        # Adicionar informação de correção
        sed -i '$s/}/,    "manual_fix": "'"$fix_description"'",\n    "fixed_by": "'"$USER"'",\n    "fixed_at": "'"$(date -u +"%Y-%m-%dT%H:%M:%SZ")"'"\n}/' "$FILE"
        
        # Mover para resolvidos
        mv "$FILE" "$FAILURES_DIR/resolved_$failure_id.json"
        
        echo -e "${GREEN}✓ Correção aplicada com sucesso!${NC}"
        
        # Log da correção
        LOG_MSG="[$(date +'%Y-%m-%d %H:%M:%S')] MANUAL_FIX_APPLIED: $failure_id - Fix: $fix_description - By: $USER"
        echo "$LOG_MSG" >> "$LOG_DIR/support.log"
    else
        echo -e "${RED}Falha não encontrada${NC}"
    fi
}

monitor_logs() {
    echo -e "${CYAN}📊 Monitoramento de Logs em Tempo Real${NC}"
    echo -e "${YELLOW}Pressione Ctrl+C para parar${NC}"
    echo ""
    
    # Mostrar últimos logs
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
    echo -e "${CYAN}🔍 Investigar Logs${NC}"
    echo ""
    
    echo "1. Buscar por erro específico"
    echo "2. Ver logs por data"
    echo "3. Analisar padrões de falha"
    echo "4. Voltar"
    echo ""
    read -p "Escolha: " choice
    
    case $choice in
        1)
            read -p "Termo de busca: " search_term
            grep -i "$search_term" "$LOG_DIR"/*.log 2>/dev/null | head -20
            ;;
        2)
            read -p "Data (YYYY-MM-DD): " search_date
            grep "$search_date" "$LOG_DIR"/*.log 2>/dev/null
            ;;
        3)
            echo -e "${YELLOW}Padrões de Falha:${NC}"
            echo "===================="
            grep -o "ERROR_CODE:[^ ]*" "$LOG_DIR"/*.log 2>/dev/null | sort | uniq -c | sort -nr
            ;;
    esac
    
    read -p "Pressione Enter para continuar..."
}

generate_report() {
    echo -e "${CYAN}📈 Gerando Relatório...${NC}"
    
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
    
    echo -e "${GREEN}✓ Relatório gerado:${NC} $REPORT_FILE"
    echo ""
    cat "$REPORT_FILE"
    
    read -p "Pressione Enter para continuar..."
}

configure_system() {
    echo -e "${CYAN}⚙️ Configurações do Sistema${NC}"
    echo ""
    
    echo "1. Limpar todos os dados"
    echo "2. Limpar apenas logs"
    echo "3. Gerar dados de teste"
    echo "4. Ver espaço em disco"
    echo "5. Voltar"
    echo ""
    read -p "Escolha: " choice
    
    case $choice in
        1)
            read -p "Tem certeza? (s/n): " confirm
            if [ "$confirm" = "s" ]; then
                rm -rf $ORDERS_DIR/* $FAILURES_DIR/* $LOG_DIR/*
                echo -e "${GREEN}✓ Todos os dados foram limpos${NC}"
            fi
            ;;
        2)
            rm -rf $LOG_DIR/*.log
            echo -e "${GREEN}✓ Logs limpos${NC}"
            ;;
        3)
            echo -e "${CYAN}Gerando dados de teste...${NC}"
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
    
    read -p "Pressione Enter para continuar..."
}

# Menu principal
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
            echo -e "${CYAN}Saindo...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Opção inválida${NC}"
            sleep 1
            ;;
    esac
done