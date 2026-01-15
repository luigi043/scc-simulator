#!/bin/bash

# Monitor automático para SFCC
LOG_FILE="../logs/auto_monitor.log"
ALERT_FILE="../logs/alerts.log"

echo "🔍 Iniciando Monitor Automático SFCC"
echo "Log: $LOG_FILE"
echo ""

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

monitor_failures() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] Verificando falhas...${NC}"
    
    # Verificar novas falhas
    NEW_FAILURES=$(find ../failures -name "*.json" -mmin -5 2>/dev/null | wc -l)
    if [ "$NEW_FAILURES" -gt 0 ]; then
        echo -e "${RED}⚠️  $NEW_FAILURES novas falhas detectadas!${NC}" | tee -a $ALERT_FILE
        
        # Detalhar falhas
        find ../failures -name "*.json" -mmin -5 | while read file; do
            TYPE=$(grep -o '"type":"[^"]*"' "$file" | cut -d'"' -f4)
            echo "  - $TYPE: $(basename $file)" | tee -a $ALERT_FILE
        done
    fi
}

monitor_orders() {
    # Verificar ordens pendentes por muito tempo
    STUCK_ORDERS=$(grep -l '"status":"PENDING"' ../orders/*.json 2>/dev/null | while read file; do
        FILE_AGE=$(($(date +%s) - $(stat -c %Y "$file")))
        if [ $FILE_AGE -gt 300 ]; then  # Mais de 5 minutos
            echo "$(basename $file)"
        fi
    done | wc -l)
    
    if [ "$STUCK_ORDERS" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  $STUCK_ORDENS ordens pendentes por muito tempo${NC}" | tee -a $ALERT_FILE
    fi
}

monitor_system() {
    # Verificar uso de recursos
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
    MEM_USAGE=$(free -m | awk '/Mem:/ {printf "%.1f", $3/$2*100}')
    
    if (( $(echo "$CPU_USAGE > 80" | bc -l) )); then
        echo -e "${RED}🚨 Alta CPU: ${CPU_USAGE}%${NC}" | tee -a $ALERT_FILE
    fi
    
    if (( $(echo "$MEM_USAGE > 85" | bc -l) )); then
        echo -e "${RED}🚨 Alta Memória: ${MEM_USAGE}%${NC}" | tee -a $ALERT_FILE
    fi
}

generate_report() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] Gerando relatório...${NC}"
    
    REPORT="../logs/daily_report_$(date +%Y%m%d).txt"
    
    {
        echo "=== Relatório Diário SFCC ==="
        echo "Gerado: $(date)"
        echo ""
        echo "📊 ORDENS"
        echo "Total: $(ls ../orders/*.json 2>/dev/null | wc -l)"
        echo "Pendentes: $(grep -l '"status":"PENDING"' ../orders/*.json 2>/dev/null | wc -l)"
        echo "Falhas: $(grep -l '"status":"FAILED"' ../orders/*.json 2>/dev/null | wc -l)"
        echo ""
        echo "🚨 FALHAS"
        echo "Ativas: $(ls ../failures/*.json 2>/dev/null | grep -v resolved | wc -l)"
        echo "Resolvidas: $(ls ../failures/resolved_*.json 2>/dev/null | wc -l)"
        echo ""
        echo "🔄 TAXAS"
        echo "Sucesso: $(echo "scale=1; ($(ls ../orders/*.json 2>/dev/null | wc -l) - $(grep -l '"status":"FAILED"' ../orders/*.json 2>/dev/null | wc -l)) * 100 / $(ls ../orders/*.json 2>/dev/null | wc -l)" | bc)%"
        echo ""
        echo "📈 RECOMENDAÇÕES"
        
        FAILURE_COUNT=$(ls ../failures/*.json 2>/dev/null | grep -v resolved | wc -l)
        if [ "$FAILURE_COUNT" -gt 5 ]; then
            echo "⚠️  Muitas falhas ativas. Considere escalar para time de desenvolvimento."
        fi
        
        STUCK_ORDERS_COUNT=$(find ../orders -name "*.json" -mmin +10 | xargs grep -l '"status":"PENDING"' 2>/dev/null | wc -l)
        if [ "$STUCK_ORDERS_COUNT" -gt 0 ]; then
            echo "🔄 Ordens pendentes antigas. Execute retry manual."
        fi
    } > $REPORT
    
    echo "Relatório salvo em: $REPORT"
}

# Loop principal de monitoramento
echo "🔄 Monitoramento iniciado. Pressione Ctrl+C para parar."
echo ""

while true; do
    {
        echo ""
        echo "=== Ciclo de Monitoramento $(date +'%H:%M:%S') ==="
        monitor_failures
        monitor_orders
        monitor_system
        echo ""
    } | tee -a $LOG_FILE
    
    # Gerar relatório a cada hora
    if [ "$(date +%M)" = "00" ]; then
        generate_report
    fi
    
    sleep 60  # Verificar a cada minuto
done