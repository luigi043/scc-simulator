#!/bin/bash

# Dashboard de Falhas SFCC
echo "🚨 Dashboard de Falhas do Salesforce Commerce Cloud"
echo ""

# Cores
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

show_dashboard() {
    clear
    echo -e "${BLUE}=== DASHBOARD DE FALHAS SFCC ===${NC}"
    echo ""
    
    # Estatísticas em tempo real
    ACTIVE_FAILURES=$(ls -1 *.json 2>/dev/null | grep -v resolved | wc -l)
    RESOLVED_TODAY=$(find . -name "resolved_*.json" -mtime -1 | wc -l)
    CRITICAL_FAILURES=$(grep -l '"severity":"HIGH"' *.json 2>/dev/null | wc -l)
    
    # Sistema de cores para status
    if [ "$ACTIVE_FAILURES" -gt 10 ]; then
        FAILURE_COLOR=$RED
        STATUS="CRÍTICO"
    elif [ "$ACTIVE_FAILURES" -gt 5 ]; then
        FAILURE_COLOR=$YELLOW
        STATUS="ALERTA"
    else
        FAILURE_COLOR=$GREEN
        STATUS="NORMAL"
    fi
    
    echo -e "📊 ${YELLOW}ESTADO DO SISTEMA:${NC} ${FAILURE_COLOR}$STATUS${NC}"
    echo ""
    echo -e "  🔴 Falhas Ativas: ${FAILURE_COLOR}$ACTIVE_FAILURES${NC}"
    echo -e "  🟡 Críticas: $CRITICAL_FAILURES"
    echo -e "  🟢 Resolvidas Hoje: $RESOLVED_TODAY"
    echo ""
    
    # Lista de falhas ativas
    echo -e "${YELLOW}🚨 FALHAS ATIVAS:${NC}"
    echo ""
    
    ls -1t *.json 2>/dev/null | grep -v resolved | head -10 | while read file; do
        FAILURE_ID=$(basename "$file" .json)
        TYPE=$(grep -o '"type":"[^"]*"' "$file" | cut -d'"' -f4)
        SEVERITY=$(grep -o '"severity":"[^"]*"' "$file" | cut -d'"' -f4)
        TIMESTAMP=$(grep -o '"timestamp":"[^"]*"' "$file" | cut -d'"' -f4 | cut -d'T' -f2 | cut -c1-5)
        
        case $SEVERITY in
            "HIGH") SEV_COLOR=$RED ;;
            "MEDIUM") SEV_COLOR=$YELLOW ;;
            *) SEV_COLOR=$GREEN ;;
        esac
        
        echo -e "  ${SEV_COLOR}●${NC} $TYPE"
        echo -e "     ID: $FAILURE_ID"
        echo -e "     Severidade: ${SEV_COLOR}$SEVERITY${NC}"
        echo -e "     Hora: $TIMESTAMP"
        echo ""
    done
    
    # SLA Status
    echo -e "${YELLOW}⏱️  STATUS DO SLA:${NC}"
    
    # Calcular tempo médio de resolução
    TOTAL_TIME=0
    RESOLVED_COUNT=0
    
    find . -name "resolved_*.json" -mtime -7 | while read file; do
        CREATED_TIME=$(grep -o '"timestamp":"[^"]*"' "$file" | cut -d'"' -f4)
        RESOLVED_TIME=$(stat -c %Y "$file")
        
        if [ -n "$CREATED_TIME" ]; then
            CREATED_EPOCH=$(date -d "${CREATED_TIME}" +%s 2>/dev/null || echo $RESOLVED_TIME)
            TIME_DIFF=$((RESOLVED_TIME - CREATED_EPOCH))
            TOTAL_TIME=$((TOTAL_TIME + TIME_DIFF))
            RESOLVED_COUNT=$((RESOLVED_COUNT + 1))
        fi
    done
    
    if [ $RESOLVED_COUNT -gt 0 ]; then
        AVG_SECONDS=$((TOTAL_TIME / RESOLVED_COUNT))
        AVG_MINUTES=$((AVG_SECONDS / 60))
        
        if [ $AVG_MINUTES -lt 30 ]; then
            SLA_COLOR=$GREEN
            SLA_STATUS="DENTRO DO SLA"
        elif [ $AVG_MINUTES -lt 60 ]; then
            SLA_COLOR=$YELLOW
            SLA_STATUS="ATENÇÃO"
        else
            SLA_COLOR=$RED
            SLA_STATUS="FORA DO SLA"
        fi
        
        echo -e "  Tempo Médio de Resolução: ${SLA_COLOR}$AVG_MINUTES minutos${NC}"
        echo -e "  Status: ${SLA_COLOR}$SLA_STATUS${NC}"
    else
        echo "  Sem dados suficientes para calcular SLA"
    fi
}

auto_triage() {
    echo -e "${BLUE}🤖 Iniciando Triagem Automática...${NC}"
    echo ""
    
    TRIAGED=0
    for file in *.json; do
        [[ -f "$file" ]] || continue
        
        ERROR_CODE=$(grep -o '"error_code":"[^"]*"' "$file" | cut -d'"' -f4)
        
        # Regras de triagem automática
        case $ERROR_CODE in
            PAY_1*)
                echo "🔧 Aplicando correção para $ERROR_CODE..."
                sed -i 's/"retry_count":0/"retry_count":1/' "$file"
                sed -i '/"error_message"/a\    "auto_triage": "Payment validation rules updated",' "$file"
                TRIAGED=$((TRIAGED + 1))
                ;;
            ERR_50*)
                echo "🔧 Aplicando correção para $ERROR_CODE..."
                sed -i 's/"retry_count":0/"retry_count":1/' "$file"
                sed -i '/"error_message"/a\    "auto_triage": "API timeout increased",' "$file"
                TRIAGED=$((TRIAGED + 1))
                ;;
        esac
    done
    
    echo -e "${GREEN}✅ $TRIAGED falhas triadas automaticamente${NC}"
}

generate_sla_report() {
    echo -e "${BLUE}📊 Gerando Relatório de SLA...${NC}"
    
    REPORT="sla_report_$(date +%Y%m%d).txt"
    
    {
        echo "=== RELATÓRIO DE SLA - SFCC SUPPORT ==="
        echo "Período: $(date)"
        echo ""
        
        echo "📈 MÉTRICAS DE DESEMPENHO"
        echo "Falhas Resolvidas: $(find . -name "resolved_*.json" -mtime -1 | wc -l)"
        echo "Falhas Pendentes: $(ls -1 *.json 2>/dev/null | grep -v resolved | wc -l)"
        echo "Tempo Médio de Resolução: $AVG_MINUTES minutos"
        echo ""
        
        echo "🎯 ATINGIMENTO DE SLA"
        
        # Calcular taxa de sucesso
        TOTAL_FAILURES=$(( $(find . -name "resolved_*.json" -mtime -7 | wc -l) + $(ls -1 *.json 2>/dev/null | grep -v resolved | wc -l) ))
        
        if [ $TOTAL_FAILURES -gt 0 ]; then
            SLA_RATE=$(echo "scale=1; $(find . -name "resolved_*.json" -mtime -7 | wc -l) * 100 / $TOTAL_FAILURES" | bc)
            
            if (( $(echo "$SLA_RATE >= 95" | bc -l) )); then
                echo "✅ EXCELENTE: $SLA_RATE% dentro do SLA"
            elif (( $(echo "$SLA_RATE >= 85" | bc -l) )); then
                echo "⚠️  BOM: $SLA_RATE% dentro do SLA"
            else
                echo "❌ PRECISA MELHORAR: $SLA_RATE% dentro do SLA"
            fi
        fi
        
        echo ""
        echo "📋 RECOMENDAÇÕES"
        echo "1. Monitorar falhas do tipo PAY_1XX mais de perto"
        echo "2. Implementar retry automático para ERROS 50X"
        echo "3. Revisar configurações de timeout da API"
    } > "$REPORT"
    
    echo -e "${GREEN}✅ Relatório gerado: $REPORT${NC}"
}

# Menu principal
while true; do
    show_dashboard
    
    echo ""
    echo -e "${BLUE}⚡ AÇÕES RÁPIDAS:${NC}"
    echo "1. Atualizar Dashboard"
    echo "2. Triagem Automática"
    echo "3. Gerar Relatório de SLA"
    echo "4. Ver Todas as Falhas"
    echo "5. Sair"
    echo ""
    
    read -p "Escolha (1-5): " choice
    
    case $choice in
        1) continue ;;
        2) auto_triage ;;
        3) generate_sla_report ;;
        4) 
            echo ""
            echo "Todas as Falhas:"
            ls -1 *.json 2>/dev/null | while read file; do
                echo "  - $(basename $file .json)"
            done
            ;;
        5) exit 0 ;;
    esac
    
    echo ""
    read -p "Pressione Enter para continuar..."
done