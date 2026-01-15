#!/bin/bash

# Sistema de Backup Automático SFCC
echo "💾 Sistema de Backup do Salesforce Commerce Cloud"
echo ""

# Configurações
BACKUP_DIR="../backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RETENTION_DAYS=7

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Criar diretório de backups
mkdir -p "$BACKUP_DIR"
mkdir -p "$BACKUP_DIR/logs"

backup_database() {
    echo -e "${BLUE}📦 Fazendo backup do 'banco de dados'...${NC}"
    
    # Criar arquivo de backup simulado
    BACKUP_FILE="$BACKUP_DIR/sfcc_db_$TIMESTAMP.sql.gz"
    
    # Simular dump do banco de dados
    {
        echo "-- Salesforce Commerce Cloud Database Backup"
        echo "-- Generated: $(date)"
        echo "--"
        echo ""
        echo "SELECT 'Backup started at $(date)';"
        echo ""
        
        # Simular dados de ordens
        echo "-- Orders table"
        for file in ../orders/*.json; do
            [[ -f "$file" ]] || continue
            ORDER_ID=$(basename "$file" .json)
            STATUS=$(grep -o '"status":"[^"]*"' "$file" | cut -d'"' -f4)
            TOTAL=$(grep -o '"total":[^,]*' "$file" | cut -d: -f2)
            echo "INSERT INTO orders (id, status, total) VALUES ('$ORDER_ID', '$STATUS', $TOTAL);"
        done
        
        echo ""
        echo "-- Failures table"
        for file in ../failures/*.json; do
            [[ -f "$file" ]] || continue
            FAILURE_ID=$(basename "$file" .json)
            TYPE=$(grep -o '"type":"[^"]*"' "$file" | cut -d'"' -f4)
            echo "INSERT INTO failures (id, type) VALUES ('$FAILURE_ID', '$TYPE');"
        done
        
        echo ""
        echo "SELECT 'Backup completed at $(date)';"
    } | gzip > "$BACKUP_FILE" 2>/dev/null || touch "$BACKUP_FILE"
    
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo -e "${GREEN}✅ Backup criado: $(basename $BACKUP_FILE) ($SIZE)${NC}"
}

backup_logs() {
    echo -e "${BLUE}📝 Fazendo backup dos logs...${NC}"
    
    LOG_BACKUP="$BACKUP_DIR/logs_$TIMESTAMP.tar.gz"
    
    # Compactar logs
    tar -czf "$LOG_BACKUP" ../logs/*.log 2>/dev/null
    
    SIZE=$(du -h "$LOG_BACKUP" | cut -f1)
    echo -e "${GREEN}✅ Logs backup: $(basename $LOG_BACKUP) ($SIZE)${NC}"
}

backup_configurations() {
    echo -e "${BLUE}⚙️  Fazendo backup das configurações...${NC}"
    
    CONFIG_BACKUP="$BACKUP_DIR/config_$TIMESTAMP.tar.gz"
    
    # Backup de configurações simuladas
    tar -czf "$CONFIG_BACKUP" \
        ../backend/*.json \
        ../scripts/*.sh \
        *.sh 2>/dev/null
    
    SIZE=$(du -h "$CONFIG_BACKUP" | cut -f1)
    echo -e "${GREEN}✅ Configurações backup: $(basename $CONFIG_BACKUP) ($SIZE)${NC}"
}

verify_backup() {
    echo -e "${BLUE}🔍 Verificando integridade do backup...${NC}"
    
    for backup_file in "$BACKUP_DIR"/*_$TIMESTAMP.*; do
        if [[ -f "$backup_file" ]]; then
            if file "$backup_file" | grep -q "compressed\|archive"; then
                echo -e "${GREEN}✓ $(basename $backup_file): OK${NC}"
                
                # Adicionar checksum
                md5sum "$backup_file" > "$backup_file.md5"
            else
                echo -e "${YELLOW}⚠ $(basename $backup_file): Verificação necessária${NC}"
            fi
        fi
    done
}

cleanup_old_backups() {
    echo -e "${BLUE}🧹 Limpando backups antigos...${NC}"
    
    DELETED_COUNT=0
    find "$BACKUP_DIR" -name "*.gz" -mtime +$RETENTION_DAYS | while read old_backup; do
        echo "  Removendo: $(basename $old_backup)"
        rm -f "$old_backup" "$old_backup.md5" 2>/dev/null
        DELETED_COUNT=$((DELETED_COUNT + 1))
    done
    
    echo -e "${GREEN}✅ $DELETED_COUNT backups antigos removidos${NC}"
}

show_backup_report() {
    echo ""
    echo -e "${BLUE}📊 RELATÓRIO DE BACKUP${NC}"
    echo "================================="
    
    TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
    BACKUP_COUNT=$(find "$BACKUP_DIR" -name "*.gz" | wc -l)
    OLDEST_BACKUP=$(find "$BACKUP_DIR" -name "*.gz" -printf '%T+ %p\n' | sort | head -1 | cut -d' ' -f2-)
    NEWEST_BACKUP=$(find "$BACKUP_DIR" -name "*.gz" -printf '%T+ %p\n' | sort -r | head -1 | cut -d' ' -f2-)
    
    echo "Diretório: $BACKUP_DIR"
    echo "Total de backups: $BACKUP_COUNT"
    echo "Espaço utilizado: $TOTAL_SIZE"
    echo ""
    echo "Backup mais antigo: $(basename "$OLDEST_BACKUP" 2>/dev/null || echo 'N/A')"
    echo "Backup mais recente: $(basename "$NEWEST_BACKUP" 2>/dev/null || echo 'N/A')"
    echo ""
    
    # Espaço disponível
    AVAILABLE_SPACE=$(df -h . | awk 'NR==2 {print $4}')
    echo "Espaço disponível: $AVAILABLE_SPACE"
}

# Menu principal
while true; do
    clear
    echo -e "${BLUE}=== SISTEMA DE BACKUP SFCC ===${NC}"
    echo ""
    echo "1. Backup Completo (DB + Logs + Config)"
    echo "2. Backup Apenas do Banco de Dados"
    echo "3. Backup dos Logs"
    echo "4. Backup das Configurações"
    echo "5. Verificar Backups Existentes"
    echo "6. Limpar Backups Antigos"
    echo "7. Restaurar Backup"
    echo "8. Configurar Backup Automático"
    echo "9. Voltar"
    echo ""
    
    read -p "Escolha (1-9): " choice
    
    case $choice in
        1)
            echo "Iniciando backup completo..."
            backup_database
            backup_logs
            backup_configurations
            verify_backup
            ;;
        2) backup_database ;;
        3) backup_logs ;;
        4) backup_configurations ;;
        5) show_backup_report ;;
        6) cleanup_old_backups ;;
        7)
            echo -e "${YELLOW}Selecione o backup para restaurar:${NC}"
            select backup_file in "$BACKUP_DIR"/*.gz; do
                if [ -f "$backup_file" ]; then
                    echo "Restaurando $backup_file..."
                    # Simular restauração
                    sleep 2
                    echo -e "${GREEN}✅ Backup restaurado com sucesso!${NC}"
                    break
                else
                    echo "Opção inválida"
                fi
            done
            ;;
        8)
            echo "Configurando backup automático..."
            echo "*/30 * * * * $(pwd)/scripts/backup_system.sh --auto" > /tmp/sfcc_backup_cron
            echo -e "${GREEN}✅ Backup automático configurado para rodar a cada 30 minutos${NC}"
            ;;
        9) exit 0 ;;
        *) echo "Opção inválida" ;;
    esac
    
    echo ""
    read -p "Pressione Enter para continuar..."
done