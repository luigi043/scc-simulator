#!/bin/bash

# Processador em Lote para SFCC
echo "⚡ Iniciando Processamento em Lote"
echo ""

# Cores
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

process_order_export() {
    echo -e "${BLUE}📤 Exportando ordens para ERP...${NC}"
    
    # Encontrar ordens pagas não exportadas
    ORDERS_TO_EXPORT=$(grep -l '"status":"PAID"' ../orders/*.json 2>/dev/null | head -10)
    
    COUNT=0
    for ORDER_FILE in $ORDERS_TO_EXPORT; do
        ORDER_ID=$(basename "$ORDER_FILE" .json)
        
        # Simular exportação
        echo -n "  Exportando $ORDER_ID..."
        sleep 0.5
        
        # 90% chance de sucesso
        if [ $((RANDOM % 10)) -lt 9 ]; then
            # Marcar como exportado
            sed -i 's/"status":"PAID"/"status":"EXPORTED"/' "$ORDER_FILE"
            echo -e " ${GREEN}✓${NC}"
            
            # Log
            echo "$(date +'%Y-%m-%d %H:%M:%S'),EXPORT_SUCCESS,$ORDER_ID" >> ../logs/batch.log
            COUNT=$((COUNT + 1))
        else
            # Falha na exportação
            echo -e " ${RED}✗${NC}"
            echo "$(date +'%Y-%m-%d %H:%M:%S'),EXPORT_FAILED,$ORDER_ID" >> ../logs/batch.log
        fi
    done
    
    echo -e "${GREEN}✅ $COUNT ordens exportadas${NC}"
}

process_inventory_sync() {
    echo -e "${BLUE}🔄 Sincronizando inventário...${NC}"
    
    # Simular sincronização
    for i in {1..5}; do
        PRODUCT_ID="PROD-$(printf "%03d" $i)"
        STOCK_LEVEL=$((RANDOM % 100 + 1))
        
        echo -n "  $PRODUCT_ID: $STOCK_LEVEL unidades..."
        sleep 0.3
        
        # Criar registro de inventário
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
    echo -e "${BLUE}🧹 Limpando dados antigos...${NC}"
    
    # Limpar logs com mais de 7 dias
    find ../logs -name "*.log" -mtime +7 -delete 2>/dev/null
    
    # Limpar ordens completadas com mais de 30 dias
    find ../orders -name "*.json" -mtime +30 | xargs grep -l '"status":"EXPORTED"' 2>/dev/null | while read file; do
        echo "  Arquivando: $(basename $file)"
        mv "$file" "../orders/archived/$(basename $file)" 2>/dev/null
    done
    
    echo "$(date +'%Y-%m-%d %H:%M:%S'),CLEANUP_COMPLETED" >> ../logs/batch.log
    echo -e "${GREEN}✅ Limpeza completada${NC}"
}

# Menu de processamento
while true; do
    clear
    echo -e "${BLUE}=== Processador em Lote SFCC ===${NC}"
    echo ""
    echo "1. Exportar Ordens para ERP"
    echo "2. Sincronizar Inventário"
    echo "3. Limpar Dados Antigos"
    echo "4. Executar Todos"
    echo "5. Voltar"
    echo ""
    read -p "Escolha: " choice
    
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
        *) echo "Opção inválida" ;;
    esac
    
    echo ""
    read -p "Pressione Enter para continuar..."
done