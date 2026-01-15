#!/bin/bash

# Sistema de Alertas SFCC em Tempo Real
echo "🚨 Sistema de Alertas do Salesforce Commerce Cloud"
echo ""

# Cores
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configurações
ALERT_LOG="../logs/alerts.log"
NOTIFICATIONS_LOG="../logs/notifications.log"
CRITICAL_THRESHOLD=5
WARNING_THRESHOLD=3

# Função para enviar notificações
send_notification() {
    local level=$1
    local message=$2
    local details=$3
    
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    
    case $level in
        "CRITICAL")
            COLOR=$RED
            PREFIX="🔴 CRÍTICO"
            # Simular envio de email/Slack
            echo "[$TIMESTAMP] EMAIL_ALERT: $message" >> $NOTIFICATIONS_LOG
            ;;
        "WARNING")
            COLOR=$YELLOW
            PREFIX="🟡 ALERTA"
            echo "[$TIMESTAMP] SLACK_ALERT: $message" >> $NOTIFICATIONS_LOG
            ;;
        "INFO")
            COLOR=$GREEN
            PREFIX="🟢 INFO"
            ;;
    esac
    
    # Registrar no log
    echo "[$TIMESTAMP] [$level] $message - $details" >> $ALERT_LOG
    
    # Mostrar no console
    echo -e "${COLOR}$PREFIX${NC} [$TIMESTAMP]"
    echo -e "   $message"
    echo -e "   📝 $details"
    echo ""
}

# Monitorar falhas críticas
monitor_critical_failures() {
    echo -e "${BLUE}🔍 Monitorando falhas críticas...${NC}"
    
    CRITICAL_COUNT=$(grep -r '"severity":"HIGH"' ../failures/*.json 2>/dev/null | grep -v resolved | wc -l)
    
    if [ "$CRITICAL_COUNT" -ge "$CRITICAL_THRESHOLD" ]; then
        send_notification "CRITICAL" "Múltiplas falhas críticas detectadas" "Total: $CRITICAL_COUNT falhas HIGH"
    elif [ "$CRITICAL_COUNT" -ge "$WARNING_THRESHOLD" ]; then
        send_notification "WARNING" "Falhas críticas aumentando" "Total: $CRITICAL_COUNT falhas HIGH"
    fi
}

# Monitorar SLA
monitor_sla() {
    echo -e "${BLUE}⏱️  Verificando SLA...${NC}"
    
    # Calcular falhas não resolvidas por mais de 1 hora
    OLD_FAILURES=0
    for file in ../failures/*.json; do
        [[ -f "$file" ]] || continue
        [[ "$file" == *"resolved"* ]] && continue
        
        FILE_AGE=$(( $(date +%s) - $(stat -c %Y "$file") ))
        if [ $FILE_AGE -gt 3600 ]; then  # Mais de 1 hora
            OLD_FAILURES=$((OLD_FAILURES + 1))
            FAILURE_ID=$(basename "$file" .json)
            
            if [ $FILE_AGE -gt 7200 ]; then  # Mais de 2 horas
                send_notification "CRITICAL" "Falha antiga não resolvida" "ID: $FAILURE_ID - Idade: $((FILE_AGE/3600))h"
            fi
        fi
    done
    
    if [ "$OLD_FAILURES" -gt 0 ]; then
        send_notification "WARNING" "Falhas antigas pendentes" "Total: $OLD_FAILURES falhas com mais de 1h"
    fi
}

# Monitorar performance
monitor_performance() {
    echo -e "${BLUE}📈 Monitorando performance...${NC}"
    
    # Verificar tempo de resposta das APIs simuladas
    if [ -f "../backend/api_traffic.log" ]; then
        SLOW_REQUESTS=$(awk -F',' '$(NF) > 1.0 {count++} END {print count}' "../backend/api_traffic.log" 2>/dev/null)
        
        if [ "$SLOW_REQUESTS" -gt 10 ]; then
            send_notification "WARNING" "APIs lentas detectadas" "$SLOW_REQUESTS requisições acima de 1s"
        fi
    fi
    
    # Verificar uso de recursos
    MEMORY_USAGE=$(free -m | awk '/Mem:/ {printf "%.0f", $3/$2*100}')
    if [ "$MEMORY_USAGE" -gt 85 ]; then
        send_notification "WARNING" "Alto uso de memória" "Uso atual: ${MEMORY_USAGE}%"
    fi
}

# Monitorar tendências
monitor_trends() {
    echo -e "${BLUE}📊 Analisando tendências...${NC}"
    
    # Verificar aumento súbito de falhas
    CURRENT_HOUR_FAILURES=$(grep "$(date +'%Y-%m-%d %H:')" ../logs/failures.log 2>/dev/null | wc -l)
    PREVIOUS_HOUR_FAILURES=$(grep "$(date -d '1 hour ago' +'%Y-%m-%d %H:')" ../logs/failures.log 2>/dev/null | wc -l)
    
    if [ "$PREVIOUS_HOUR_FAILURES" -gt 0 ]; then
        INCREASE_PERCENTAGE=$(( (CURRENT_HOUR_FAILURES - PREVIOUS_HOUR_FAILURES) * 100 / PREVIOUS_HOUR_FAILURES ))
        
        if [ "$INCREASE_PERCENTAGE" -gt 100 ]; then
            send_notification "CRITICAL" "Aumento drástico de falhas" "Aumento: ${INCREASE_PERCENTAGE}% na última hora"
        elif [ "$INCREASE_PERCENTAGE" -gt 50 ]; then
            send_notification "WARNING" "Aumento significativo de falhas" "Aumento: ${INCREASE_PERCENTAGE}% na última hora"
        fi
    fi
}

# Dashboard de alertas
show_alert_dashboard() {
    clear
    echo -e "${PURPLE}=== 🚨 DASHBOARD DE ALERTAS SFCC ===${NC}"
    echo ""
    
    # Estatísticas de alertas das últimas 24h
    CRITICAL_24H=$(grep -c "CRITICAL" $ALERT_LOG 2>/dev/null)
    WARNING_24H=$(grep -c "WARNING" $ALERT_LOG 2>/dev/null)
    
    echo -e "${YELLOW}📊 RESUMO DE ALERTAS (24h):${NC}"
    echo -e "  🔴 Críticos: $CRITICAL_24H"
    echo -e "  🟡 Avisos: $WARNING_24H"
    echo ""
    
    # Últimos alertas
    echo -e "${YELLOW}📋 ÚLTIMOS ALERTAS:${NC}"
    tail -5 $ALERT_LOG 2>/dev/null | while read line; do
        if echo "$line" | grep -q "CRITICAL"; then
            echo -e "  ${RED}●${NC} $line"
        elif echo "$line" | grep -q "WARNING"; then
            echo -e "  ${YELLOW}●${NC} $line"
        else
            echo -e "  ${GREEN}●${NC} $line"
        fi
    done
    
    echo ""
    echo -e "${YELLOW}🔔 NOTIFICAÇÕES ENVIADAS:${NC}"
    tail -3 $NOTIFICATIONS_LOG 2>/dev/null || echo "  Nenhuma notificação recente"
}

# Loop principal
echo "🔄 Sistema de alertas iniciado. Verificando a cada 30 segundos..."
echo "Pressione Ctrl+C para parar"
echo ""

COUNTER=0
while true; do
    COUNTER=$((COUNTER + 1))
    
    echo ""
    echo -e "${BLUE}=== Ciclo $COUNTER - $(date +'%H:%M:%S') ===${NC}"
    
    # Executar todas as verificações
    monitor_critical_failures
    monitor_sla
    monitor_performance
    monitor_trends
    
    # Mostrar dashboard a cada 10 ciclos
    if [ $((COUNTER % 10)) -eq 0 ]; then
        show_alert_dashboard
    fi
    
    sleep 30  # Verificar a cada 30 segundos
done