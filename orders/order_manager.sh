#!/bin/bash

# Gerenciador Avançado de Ordens SFCC
echo "📦 Gerenciador de Ordens do Salesforce Commerce Cloud"
echo ""

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

view_orders() {
    echo -e "${BLUE}📋 Lista de Ordens:${NC}"
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
        
        echo -e "  $ORDER_ID - Cliente: $CUSTOMER - Total: \$$TOTAL - Status: ${COLOR}$STATUS${NC}"
    done
}

search_order() {
    read -p "🔍 Buscar (ID do Pedido, Cliente ou Status): " search_term
    
    echo ""
    echo "Resultados da busca por '$search_term':"
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
        echo "Nenhum pedido encontrado."
    fi
}

bulk_operations() {
    echo -e "${BLUE}⚡ Operações em Lote:${NC}"
    echo ""
    echo "1. Cancelar todas as ordens pendentes"
    echo "2. Reprocessar ordens falhas"
    echo "3. Exportar ordens pagas"
    echo "4. Gerar relatório CSV"
    echo ""
    read -p "Escolha: " choice
    
    case $choice in
        1)
            COUNT=0
            for file in *.json; do
                if grep -q '"status":"PENDING"' "$file"; then
                    sed -i 's/"status":"PENDING"/"status":"CANCELLED"/' "$file"
                    COUNT=$((COUNT + 1))
                fi
            done
            echo "✅ $COUNT ordens canceladas"
            ;;
        2)
            COUNT=0
            for file in *.json; do
                if grep -q '"status":"FAILED"' "$file"; then
                    # 80% chance de sucesso no reprocessamento
                    if [ $((RANDOM % 10)) -lt 8 ]; then
                        sed -i 's/"status":"FAILED"/"status":"PAID"/' "$file"
                        echo "✅ $(basename $file .json): Reprovado com sucesso"
                    else
                        echo "❌ $(basename $file .json): Falha no reprocessamento"
                    fi
                    COUNT=$((COUNT + 1))
                fi
            done
            ;;
        3)
            echo "Exportando ordens pagas..."
            mkdir -p exported_orders
            for file in *.json; do
                if grep -q '"status":"PAID"' "$file"; then
                    cp "$file" "exported_orders/$(basename $file)"
                    sed -i 's/"status":"PAID"/"status":"EXPORTED"/' "$file"
                fi
            done
            echo "✅ Ordens exportadas para pasta 'exported_orders/'"
            ;;
        4)
            echo "Gerando relatório CSV..."
            echo "order_id,customer_id,status,total,created_at" > orders_report.csv
            for file in *.json; do
                ORDER_ID=$(basename "$file" .json)
                CUSTOMER_ID=$(grep -o '"customer_id":"[^"]*"' "$file" | cut -d'"' -f4)
                STATUS=$(grep -o '"status":"[^"]*"' "$file" | cut -d'"' -f4)
                TOTAL=$(grep -o '"total":[^,]*' "$file" | cut -d: -f2)
                CREATED_AT=$(grep -o '"created_at":"[^"]*"' "$file" | cut -d'"' -f4)
                
                echo "$ORDER_ID,$CUSTOMER_ID,$STATUS,$TOTAL,$CREATED_AT" >> orders_report.csv
            done
            echo "✅ Relatório gerado: orders_report.csv"
            ;;
    esac
}

# Menu principal
while true; do
    clear
    echo -e "${BLUE}=== Gerenciador de Ordens SFCC ===${NC}"
    echo ""
    echo "1. Visualizar Todas as Ordens"
    echo "2. Buscar Ordem Específica"
    echo "3. Ver Detalhes da Ordem"
    echo "4. Operações em Lote"
    echo "5. Voltar ao Menu Principal"
    echo ""
    
    STATS=$(ls -1 *.json 2>/dev/null | wc -l)
    PENDING=$(grep -l '"status":"PENDING"' *.json 2>/dev/null | wc -l)
    FAILED=$(grep -l '"status":"FAILED"' *.json 2>/dev/null | wc -l)
    
    echo -e "${YELLOW}📊 Estatísticas:${NC}"
    echo "  Total: $STATS ordens"
    echo "  Pendentes: $PENDING"
    echo "  Falhas: $FAILED"
    echo ""
    
    read -p "Escolha: " choice
    
    case $choice in
        1) view_orders ;;
        2) search_order ;;
        3)
            read -p "ID da Ordem: " order_id
            if [ -f "$order_id.json" ]; then
                cat "$order_id.json" | python3 -m json.tool 2>/dev/null || cat "$order_id.json"
            else
                echo "❌ Ordem não encontrada"
            fi
            ;;
        4) bulk_operations ;;
        5) exit 0 ;;
        *) echo "Opção inválida" ;;
    esac
    
    echo ""
    read -p "Pressione Enter para continuar..."
done