#!/bin/bash

# Sistema de Controle Master SFCC
echo "🎮 Sistema de Controle Master do Salesforce Commerce Cloud"
echo ""

# Cores
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

show_master_dashboard() {
    clear
    echo -e "${PURPLE}=== 🎮 MASTER CONTROL SFCC ===${NC}"
    echo ""
    
    # Status de todos os serviços
    echo -e "${CYAN}🔄 STATUS DOS SERVIÇOS:${NC}"
    echo ""
    
    check_service() {
        local name=$1
        local script=$2
        local dir=$3
        
        if ps aux | grep -q "[${script:0:1}]${script:1}"; then
            echo -e "  ${GREEN}●${NC} $name: RUNNING"
        else
            echo -e "  ${RED}●${NC} $name: STOPPED"
        fi
    }
    
    check_service "API Simulator" "api_server.sh" "backend"
    check_service "Alert System" "alert_system.sh" "scripts"
    check_service "Auto Monitor" "auto_monitor.sh" "scripts"
    check_service "Batch Processor" "batch_processor.sh" "scripts"
    check_service "Backup System" "backup_system.sh" "scripts"
    
    echo ""
    
    # Estatísticas do sistema
    echo -e "${CYAN}📊 ESTATÍSTICAS DO SISTEMA:${NC}"
    echo ""
    
    TOTAL_ORDERS=$(ls orders/*.json 2>/dev/null | wc -l)
    ACTIVE_FAILURES=$(ls failures/*.json 2>/dev/null | grep -v resolved | wc -l)
    TOTAL_LOGS=$(find logs -name "*.log" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}')
    BACKUP_SIZE=$(du -sh backups 2>/dev/null | cut -f1 || echo "0")
    
    echo "  📦 Ordens: $TOTAL_ORDERS"
    echo "  🚨 Falhas Ativas: $ACTIVE_FAILURES"
    echo "  📝 Linhas de Log: $TOTAL_LOGS"
    echo "  💾 Backup Total: $BACKUP_SIZE"
    
    echo ""
    
    # Saúde do sistema
    echo -e "${CYAN}❤️  SAÚDE DO SISTEMA:${NC}"
    echo ""
    
    MEMORY_USAGE=$(free -m | awk '/Mem:/ {printf "%.0f", $3/$2*100}')
    if [ "$MEMORY_USAGE" -lt 70 ]; then
        echo -e "  ${GREEN}●${NC} Memória: ${MEMORY_USAGE}% (OK)"
    elif [ "$MEMORY_USAGE" -lt 85 ]; then
        echo -e "  ${YELLOW}●${NC} Memória: ${MEMORY_USAGE}% (WARNING)"
    else
        echo -e "  ${RED}●${NC} Memória: ${MEMORY_USAGE}% (CRITICAL)"
    fi
    
    DISK_USAGE=$(df -h . | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$DISK_USAGE" -lt 80 ]; then
        echo -e "  ${GREEN}●${NC} Disco: ${DISK_USAGE}% (OK)"
    elif [ "$DISK_USAGE" -lt 90 ]; then
        echo -e "  ${YELLOW}●${NC} Disco: ${DISK_USAGE}% (WARNING)"
    else
        echo -e "  ${RED}●${NC} Disco: ${DISK_USAGE}% (CRITICAL)"
    fi
    
    echo ""
    echo -e "${CYAN}🚀 AÇÕES RÁPIDAS:${NC}"
}

start_all_services() {
    echo -e "${BLUE}🚀 Iniciando todos os serviços...${NC}"
    
    # Iniciar serviços em background
    cd backend && nohup ./api_server.sh > /dev/null 2>&1 &
    cd ../scripts
    nohup ./alert_system.sh > /dev/null 2>&1 &
    nohup ./auto_monitor.sh > /dev/null 2>&1 &
    nohup ./batch_processor.sh > /dev/null 2>&1 &
    cd ..
    
    echo -e "${GREEN}✅ Todos os serviços iniciados!${NC}"
    sleep 2
}

stop_all_services() {
    echo -e "${YELLOW}🛑 Parando todos os serviços...${NC}"
    
    pkill -f "api_server.sh"
    pkill -f "alert_system.sh"
    pkill -f "auto_monitor.sh"
    pkill -f "batch_processor.sh"
    
    echo -e "${GREEN}✅ Todos os serviços parados!${NC}"
    sleep 2
}

system_health_check() {
    echo -e "${BLUE}🔍 Executando verificação de saúde do sistema...${NC}"
    echo ""
    
    # Verificar diretórios
    DIRS=("orders" "failures" "logs" "backups" "reports" "scripts" "backend")
    for dir in "${DIRS[@]}"; do
        if [ -d "$dir" ]; then
            echo -e "  ${GREEN}✓${NC} Diretório $dir: OK"
        else
            echo -e "  ${RED}✗${NC} Diretório $dir: FALTANDO"
        fi
    done
    
    echo ""
    
    # Verificar scripts executáveis
    SCRIPTS=("scc_simulator.sh" "scripts/alert_system.sh" "backend/api_server.sh")
    for script in "${SCRIPTS[@]}"; do
        if [ -x "$script" ]; then
            echo -e "  ${GREEN}✓${NC} Script $script: EXECUTÁVEL"
        else
            echo -e "  ${YELLOW}⚠${NC} Script $script: SEM PERMISSÃO"
        fi
    done
    
    echo ""
    
    # Verificar espaço em disco
    echo -e "${YELLOW}💾 USO DE DISCO:${NC}"
    df -h .
}

show_log_viewer() {
    echo -e "${BLUE}📋 Visualizador de Logs Unificado${NC}"
    echo ""
    
    echo "1. Logs de Ordens"
    echo "2. Logs de Falhas"
    echo "3. Logs do Sistema"
    echo "4. Logs de Deploy"
    echo "5. Todos os Logs"
    echo "6. Monitorar em Tempo Real"
    echo ""
    
    read -p "Escolha: " log_choice
    
    case $log_choice in
        1) tail -f logs/orders.log ;;
        2) tail -f logs/failures.log ;;
        3) tail -f logs/system.log ;;
        4) tail -f logs/deployments.log ;;
        5) tail -f logs/*.log ;;
        6) 
            echo "Monitorando todos os logs em tempo real..."
            multitail logs/*.log
            ;;
        *) echo "Opção inválida" ;;
    esac
}

# Menu principal
while true; do
    show_master_dashboard
    
    echo ""
    echo "1. Iniciar Todos os Serviços"
    echo "2. Parar Todos os Serviços"
    echo "3. Console Principal"
    echo "4. Dashboard de Alertas"
    echo "5. Sistema de Backup"
    echo "6. Reporting Avançado"
    echo "7. Webhook Simulator"
    echo "8. Deployment Manager"
    echo "9. Verificação de Saúde"
    echo "10. Visualizador de Logs"
    echo "11. Sair"
    echo ""
    
    read -p "Escolha (1-11): " choice
    
    case $choice in
        1) start_all_services ;;
        2) stop_all_services ;;
        3) ./scc_simulator.sh ;;
        4) cd scripts && ./alert_system.sh && cd .. ;;
        5) cd scripts && ./backup_system.sh && cd .. ;;
        6) cd scripts && ./advanced_reporting.sh && cd .. ;;
        7) cd backend && ./webhook_simulator.sh && cd .. ;;
        8) cd scripts && ./deployment_manager.sh && cd .. ;;
        9) system_health_check ;;
        10) show_log_viewer ;;
        11) 
            stop_all_services
            echo -e "${GREEN}👋 Saindo do Master Control...${NC}"
            exit 0
            ;;
        *) echo "Opção inválida" ;;
    esac
    
    echo ""
    read -p "Pressione Enter para continuar..."
done