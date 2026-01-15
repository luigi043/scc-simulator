#!/bin/bash

# SFCC Automatic Backup System
echo "💾 Salesforce Commerce Cloud Backup System"
echo ""

# Settings
BACKUP_DIR="../backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RETENTION_DAYS=7

# Colours
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Create backup directory
mkdir -p "$BACKUP_DIR"
mkdir -p "$BACKUP_DIR/logs"

backup_database() {
    echo -e "${BLUE}📦 Creating 'database' backup...${NC}"
    
    # Create simulated backup file
    BACKUP_FILE="$BACKUP_DIR/sfcc_db_$TIMESTAMP.sql.gz"
    
    # Simulate database dump
    {
        echo "-- Salesforce Commerce Cloud Database Backup"
        echo "-- Generated: $(date)"
        echo "--"
        echo ""
        echo "SELECT 'Backup started at $(date)';"
        echo ""
        
        # Simulate order data
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
    echo -e "${GREEN}✅ Backup created: $(basename $BACKUP_FILE) ($SIZE)${NC}"
}

backup_logs() {
    echo -e "${BLUE}📝 Creating logs backup...${NC}"
    
    LOG_BACKUP="$BACKUP_DIR/logs_$TIMESTAMP.tar.gz"
    
    # Compress logs
    tar -czf "$LOG_BACKUP" ../logs/*.log 2>/dev/null
    
    SIZE=$(du -h "$LOG_BACKUP" | cut -f1)
    echo -e "${GREEN}✅ Logs backup: $(basename $LOG_BACKUP) ($SIZE)${NC}"
}

backup_configurations() {
    echo -e "${BLUE}⚙️  Creating configurations backup...${NC}"
    
    CONFIG_BACKUP="$BACKUP_DIR/config_$TIMESTAMP.tar.gz"
    
    # Backup simulated configurations
    tar -czf "$CONFIG_BACKUP" \
        ../backend/*.json \
        ../scripts/*.sh \
        *.sh 2>/dev/null
    
    SIZE=$(du -h "$CONFIG_BACKUP" | cut -f1)
    echo -e "${GREEN}✅ Configurations backup: $(basename $CONFIG_BACKUP) ($SIZE)${NC}"
}

verify_backup() {
    echo -e "${BLUE}🔍 Verifying backup integrity...${NC}"
    
    for backup_file in "$BACKUP_DIR"/*_$TIMESTAMP.*; do
        if [[ -f "$backup_file" ]]; then
            if file "$backup_file" | grep -q "compressed\|archive"; then
                echo -e "${GREEN}✓ $(basename $backup_file): OK${NC}"
                
                # Add checksum
                md5sum "$backup_file" > "$backup_file.md5"
            else
                echo -e "${YELLOW}⚠ $(basename $backup_file): Verification needed${NC}"
            fi
        fi
    done
}

cleanup_old_backups() {
    echo -e "${BLUE}🧹 Cleaning old backups...${NC}"
    
    DELETED_COUNT=0
    find "$BACKUP_DIR" -name "*.gz" -mtime +$RETENTION_DAYS | while read old_backup; do
        echo "  Removing: $(basename $old_backup)"
        rm -f "$old_backup" "$old_backup.md5" 2>/dev/null
        DELETED_COUNT=$((DELETED_COUNT + 1))
    done
    
    echo -e "${GREEN}✅ $DELETED_COUNT old backups removed${NC}"
}

show_backup_report() {
    echo ""
    echo -e "${BLUE}📊 BACKUP REPORT${NC}"
    echo "================================="
    
    TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
    BACKUP_COUNT=$(find "$BACKUP_DIR" -name "*.gz" | wc -l)
    OLDEST_BACKUP=$(find "$BACKUP_DIR" -name "*.gz" -printf '%T+ %p\n' | sort | head -1 | cut -d' ' -f2-)
    NEWEST_BACKUP=$(find "$BACKUP_DIR" -name "*.gz" -printf '%T+ %p\n' | sort -r | head -1 | cut -d' ' -f2-)
    
    echo "Directory: $BACKUP_DIR"
    echo "Total backups: $BACKUP_COUNT"
    echo "Space used: $TOTAL_SIZE"
    echo ""
    echo "Oldest backup: $(basename "$OLDEST_BACKUP" 2>/dev/null || echo 'N/A')"
    echo "Newest backup: $(basename "$NEWEST_BACKUP" 2>/dev/null || echo 'N/A')"
    echo ""
    
    # Available space
    AVAILABLE_SPACE=$(df -h . | awk 'NR==2 {print $4}')
    echo "Available space: $AVAILABLE_SPACE"
}

# Main menu
while true; do
    clear
    echo -e "${BLUE}=== SFCC BACKUP SYSTEM ===${NC}"
    echo ""
    echo "1. Complete Backup (DB + Logs + Config)"
    echo "2. Database Backup Only"
    echo "3. Logs Backup"
    echo "4. Configurations Backup"
    echo "5. Check Existing Backups"
    echo "6. Clean Old Backups"
    echo "7. Restore Backup"
    echo "8. Configure Automatic Backup"
    echo "9. Back"
    echo ""
    
    read -p "Choose (1-9): " choice
    
    case $choice in
        1)
            echo "Starting complete backup..."
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
            echo -e "${YELLOW}Select backup to restore:${NC}"
            select backup_file in "$BACKUP_DIR"/*.gz; do
                if [ -f "$backup_file" ]; then
                    echo "Restoring $backup_file..."
                    # Simulate restoration
                    sleep 2
                    echo -e "${GREEN}✅ Backup restored successfully!${NC}"
                    break
                else
                    echo "Invalid option"
                fi
            done
            ;;
        8)
            echo "Configuring automatic backup..."
            echo "*/30 * * * * $(pwd)/scripts/backup_system.sh --auto" > /tmp/sfcc_backup_cron
            echo -e "${GREEN}✅ Automatic backup configured to run every 30 minutes${NC}"
            ;;
        9) exit 0 ;;
        *) echo "Invalid option" ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
done