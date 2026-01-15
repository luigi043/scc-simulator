#!/bin/bash

# Inicializar todos os serviços SFCC

echo "🚀 Inicializando Salesforce Commerce Cloud Environment"
echo ""

# Cores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Verificar se está no diretório correto
if [ ! -d "backend" ] || [ ! -d "scripts" ]; then
    echo -e "${YELLOW}⚠️  Execute este script do diretório raiz do projeto${NC}"
    exit 1
fi

# Iniciar serviços em background
start_service() {
    local name=$1
    local script=$2
    local dir=$3
    
    echo -e "${BLUE}▶️  Iniciando $name...${NC}"
    cd $dir
    nohup ./$script > /dev/null 2>&1 &
    cd ..
    sleep 1
    echo -e "${GREEN}✅ $name iniciado${NC}"
}

# Menu de inicialização
while true; do
    clear
    echo -e "${BLUE}=== SFCC Environment Launcher ===${NC}"
    echo ""
    echo "1. Iniciar API Server Simulator"
    echo "2. Iniciar Monitoramento Automático"
    echo "3. Iniciar Processamento em Lote"
    echo "4. Iniciar Todos os Serviços"
    echo "5. Ver Status dos Serviços"
    echo "6. Parar Todos os Serviços"
    echo "7. Iniciar Console Principal"
    echo "8. Sair"
    echo ""
    
    read -p "Escolha: " choice
    
    case $choice in
        1) start_service "API Server" "api_server.sh" "backend" ;;
        2) start_service "Auto Monitor" "auto_monitor.sh" "scripts" ;;
        3) start_service "Batch Processor" "batch_processor.sh" "scripts" ;;
        4)
            start_service "API Server" "api_server.sh" "backend"
            start_service "Auto Monitor" "auto_monitor.sh" "scripts"
            start_service "Batch Processor" "batch_processor.sh" "scripts"
            echo ""
            echo -e "${GREEN}✅ Todos os serviços iniciados!${NC}"
            ;;
        5)
            echo -e "${YELLOW}📊 Status dos Serviços:${NC}"
            echo ""
            ps aux | grep -E "api_server|auto_monitor|batch_processor" | grep -v grep || echo "Nenhum serviço em execução"
            ;;
        6)
            echo "Parando serviços..."
            pkill -f "api_server.sh"
            pkill -f "auto_monitor.sh"
            pkill -f "batch_processor.sh"
            echo -e "${GREEN}✅ Serviços parados${NC}"
            ;;
        7) ./scc_simulator.sh ;;
        8) exit 0 ;;
        *) echo "Opção inválida" ;;
    esac
    
    echo ""
    read -p "Pressione Enter para continuar..."
done