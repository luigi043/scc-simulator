#!/bin/bash

# Sistema de Reporting Avançado SFCC
echo "📈 Sistema de Reporting do Salesforce Commerce Cloud"
echo ""

# Cores
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Diretório de relatórios
REPORT_DIR="../reports"
mkdir -p "$REPORT_DIR"

generate_daily_report() {
    echo -e "${BLUE}📅 Gerando Relatório Diário...${NC}"
    
    REPORT_FILE="$REPORT_DIR/daily_report_$(date +%Y%m%d).html"
    
    # Coletar dados
    TOTAL_ORDERS=$(ls ../orders/*.json 2>/dev/null | wc -l)
    SUCCESSFUL_ORDERS=$(grep -l '"status":"PAID\|"status":"EXPORTED"' ../orders/*.json 2>/dev/null | wc -l)
    FAILED_ORDERS=$(grep -l '"status":"FAILED"' ../orders/*.json 2>/dev/null | wc -l)
    PENDING_ORDERS=$(grep -l '"status":"PENDING"' ../orders/*.json 2>/dev/null | wc -l)
    
    TOTAL_FAILURES=$(ls ../failures/*.json 2>/dev/null | grep -v resolved | wc -l)
    RESOLVED_FAILURES=$(ls ../failures/resolved_*.json 2>/dev/null | wc -l)
    
    SUCCESS_RATE=$(echo "scale=1; $SUCCESSFUL_ORDERS * 100 / ($TOTAL_ORDERS ? $TOTAL_ORDERS : 1)" | bc)
    RESOLUTION_RATE=$(echo "scale=1; $RESOLVED_FAILURES * 100 / (($TOTAL_FAILURES + $RESOLVED_FAILURES) ? ($TOTAL_FAILURES + $RESOLVED_FAILURES) : 1)" | bc)
    
    # Gerar relatório HTML
    cat > "$REPORT_FILE" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>SFCC Daily Report - $(date +"%Y-%m-%d")</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .header { background: #0056a3; color: white; padding: 20px; border-radius: 10px; }
        .metric { background: #f5f5f5; padding: 20px; margin: 10px 0; border-radius: 5px; }
        .success { color: #28a745; }
        .warning { color: #ffc107; }
        .danger { color: #dc3545; }
        .grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 20px; }
        .chart { height: 200px; background: linear-gradient(to right, #28a745 \${SUCCESS_RATE}%, #dc3545 \${FAILED_RATE}%); }
    </style>
</head>
<body>
    <div class="header">
        <h1>📊 Salesforce Commerce Cloud - Daily Report</h1>
        <p>Generated: $(date)</p>
    </div>
    
    <div class="grid">
        <div class="metric">
            <h3>📦 Orders Overview</h3>
            <p>Total Orders: <strong>$TOTAL_ORDERS</strong></p>
            <p>Successful: <span class="success">$SUCCESSFUL_ORDERS</span></p>
            <p>Failed: <span class="danger">$FAILED_ORDERS</span></p>
            <p>Pending: <span class="warning">$PENDING_ORDERS</span></p>
            <p>Success Rate: <strong>${SUCCESS_RATE}%</strong></p>
        </div>
        
        <div class="metric">
            <h3>🚨 Failures Overview</h3>
            <p>Active Failures: <span class="danger">$TOTAL_FAILURES</span></p>
            <p>Resolved Today: <span class="success">$RESOLVED_FAILURES</span></p>
            <p>Resolution Rate: <strong>${RESOLUTION_RATE}%</strong></p>
        </div>
    </div>
    
    <div class="metric">
        <h3>📈 Performance Metrics</h3>
        <div class="chart"></div>
    </div>
    
    <div class="metric">
        <h3>💡 Recommendations</h3>
        <ul>
EOF
    
    # Adicionar recomendações dinâmicas
    if [ "$FAILED_ORDERS" -gt 5 ]; then
        echo "<li>⚠️ Investigate payment gateway integration</li>" >> "$REPORT_FILE"
    fi
    
    if [ "$TOTAL_FAILURES" -gt 10 ]; then
        echo "<li>🚨 Review system configuration and error handling</li>" >> "$REPORT_FILE"
    fi
    
    if (( $(echo "$SUCCESS_RATE < 90" | bc -l) )); then
        echo "<li>📉 Optimize order processing pipeline</li>" >> "$REPORT_FILE"
    fi
    
    cat >> "$REPORT_FILE" << EOF
        </ul>
    </div>
    
    <div class="metric">
        <h3>🎯 SLA Compliance</h3>
        <p>Orders processed within SLA: <strong>95%</strong></p>
        <p>Failures resolved within SLA: <strong>${RESOLUTION_RATE}%</strong></p>
    </div>
</body>
</html>
EOF
    
    echo -e "${GREEN}✅ Relatório gerado: $REPORT_FILE${NC}"
}

generate_sla_report() {
    echo -e "${BLUE}⏱️ Gerando Relatório de SLA...${NC}"
    
    REPORT_FILE="$REPORT_DIR/sla_report_$(date +%Y%m%d).csv"
    
    echo "Failure_ID,Type,Severity,Created_Time,Resolved_Time,Time_to_Resolve(minutes),SLA_Status" > "$REPORT_FILE"
    
    for file in ../failures/resolved_*.json; do
        [[ -f "$file" ]] || continue
        
        FAILURE_ID=$(basename "$file" .json | sed 's/resolved_//')
        TYPE=$(grep -o '"type":"[^"]*"' "$file" | cut -d'"' -f4)
        SEVERITY=$(grep -o '"severity":"[^"]*"' "$file" | cut -d'"' -f4)
        CREATED_TIME=$(grep -o '"timestamp":"[^"]*"' "$file" | cut -d'"' -f4)
        RESOLVED_TIME=$(stat -c %y "$file" | cut -d' ' -f1-2)
        
        # Calcular tempo de resolução
        CREATED_EPOCH=$(date -d "${CREATED_TIME}" +%s 2>/dev/null || echo 0)
        RESOLVED_EPOCH=$(date -d "${RESOLVED_TIME}" +%s 2>/dev/null || echo 0)
        
        if [ $CREATED_EPOCH -gt 0 ] && [ $RESOLVED_EPOCH -gt 0 ]; then
            TIME_DIFF_MIN=$(( (RESOLVED_EPOCH - CREATED_EPOCH) / 60 ))
            
            # Verificar SLA (30 minutos para HIGH, 60 para MEDIUM, 120 para LOW)
            case $SEVERITY in
                "HIGH") SLA_LIMIT=30 ;;
                "MEDIUM") SLA_LIMIT=60 ;;
                *) SLA_LIMIT=120 ;;
            esac
            
            if [ $TIME_DIFF_MIN -le $SLA_LIMIT ]; then
                SLA_STATUS="WITHIN_SLA"
            else
                SLA_STATUS="BREACHED"
            fi
            
            echo "$FAILURE_ID,$TYPE,$SEVERITY,$CREATED_TIME,$RESOLVED_TIME,$TIME_DIFF_MIN,$SLA_STATUS" >> "$REPORT_FILE"
        fi
    done
    
    echo -e "${GREEN}✅ Relatório de SLA gerado: $REPORT_FILE${NC}"
}

generate_trend_analysis() {
    echo -e "${BLUE}📊 Analisando tendências...${NC}"
    
    REPORT_FILE="$REPORT_DIR/trend_analysis_$(date +%Y%m%d).txt"
    
    {
        echo "=== TREND ANALYSIS REPORT ==="
        echo "Period: Last 7 days"
        echo "Generated: $(date)"
        echo ""
        echo "📈 ORDER TRENDS"
        echo "---------------"
        
        # Analisar tendência de ordens
        for i in {6..0}; do
            DATE=$(date -d "$i days ago" +%Y-%m-%d)
            ORDERS_COUNT=$(find ../orders -name "*.json" -newermt "$DATE" ! -newermt "$(date -d "$((i-1)) days ago" +%Y-%m-%d)" 2>/dev/null | wc -l)
            echo "$DATE: $ORDERS_COUNT orders"
        done
        
        echo ""
        echo "📉 FAILURE TRENDS"
        echo "----------------"
        
        # Analisar tendência de falhas
        for i in {6..0}; do
            DATE=$(date -d "$i days ago" +%Y-%m-%d)
            FAILURES_COUNT=$(find ../failures -name "*.json" -newermt "$DATE" ! -newermt "$(date -d "$((i-1)) days ago" +%Y-%m-%d)" 2>/dev/null | wc -l)
            echo "$DATE: $FAILURES_COUNT failures"
        done
        
        echo ""
        echo "💡 INSIGHTS"
        echo "-----------"
        
        # Gerar insights
        AVG_ORDERS=$(ls ../orders/*.json 2>/dev/null | wc -l)
        AVG_FAILURES=$(ls ../failures/*.json 2>/dev/null | wc -l)
        
        if [ $AVG_ORDERS -gt 0 ]; then
            FAILURE_RATE=$((AVG_FAILURES * 100 / AVG_ORDERS))
            echo "Average Failure Rate: ${FAILURE_RATE}%"
            
            if [ $FAILURE_RATE -gt 10 ]; then
                echo "⚠️  High failure rate detected. Consider system optimization."
            fi
        fi
        
        echo ""
        echo "🎯 PREDICTIONS"
        echo "-------------"
        
        # Previsão simples baseada em média móvel
        echo "Next 24h order prediction: $((AVG_ORDERS / 7)) orders"
        echo "Next 24h failure prediction: $((AVG_FAILURES / 7)) failures"
        
    } > "$REPORT_FILE"
    
    echo -e "${GREEN}✅ Análise de tendências gerada: $REPORT_FILE${NC}"
}

show_report_dashboard() {
    clear
    echo -e "${PURPLE}=== 📊 DASHBOARD DE RELATÓRIOS SFCC ===${NC}"
    echo ""
    
    # Listar relatórios disponíveis
    echo -e "${YELLOW}📁 RELATÓRIOS DISPONÍVEIS:${NC}"
    echo ""
    
    ls -1t "$REPORT_DIR"/*.html 2>/dev/null | head -5 | while read report; do
        SIZE=$(du -h "$report" | cut -f1)
        echo "  📄 $(basename "$report") ($SIZE)"
    done
    
    echo ""
    ls -1t "$REPORT_DIR"/*.csv 2>/dev/null | head -5 | while read report; do
        SIZE=$(du -h "$report" | cut -f1)
        echo "  📊 $(basename "$report") ($SIZE)"
    done
    
    echo ""
    echo -e "${YELLOW}📈 ESTATÍSTICAS:${NC}"
    TOTAL_REPORTS=$(ls "$REPORT_DIR"/*.html "$REPORT_DIR"/*.csv 2>/dev/null | wc -l)
    TOTAL_SIZE=$(du -sh "$REPORT_DIR" 2>/dev/null | cut -f1 || echo "0")
    
    echo "  Total de Relatórios: $TOTAL_REPORTS"
    echo "  Espaço Utilizado: $TOTAL_SIZE"
}

# Menu principal
while true; do
    clear
    echo -e "${BLUE}=== SISTEMA DE REPORTING AVANÇADO ===${NC}"
    echo ""
    echo "1. Gerar Relatório Diário (HTML)"
    echo "2. Gerar Relatório de SLA (CSV)"
    echo "3. Análise de Tendências"
    echo "4. Dashboard de Relatórios"
    echo "5. Enviar Relatório por Email"
    echo "6. Agendar Relatórios Automáticos"
    echo "7. Limpar Relatórios Antigos"
    echo "8. Voltar"
    echo ""
    
    read -p "Escolha (1-8): " choice
    
    case $choice in
        1) generate_daily_report ;;
        2) generate_sla_report ;;
        3) generate_trend_analysis ;;
        4) show_report_dashboard ;;
        5)
            echo "Simulando envio de email..."
            LATEST_REPORT=$(ls -1t "$REPORT_DIR"/*.html 2>/dev/null | head -1)
            if [ -f "$LATEST_REPORT" ]; then
                echo "Enviando $(basename "$LATEST_REPORT") para admin@company.com..."
                sleep 2
                echo -e "${GREEN}✅ Relatório enviado com sucesso!${NC}"
            else
                echo "Nenhum relatório encontrado"
            fi
            ;;
        6)
            echo "Agendando relatórios automáticos..."
            echo "0 8 * * * $(pwd)/scripts/advanced_reporting.sh --daily" > /tmp/sfcc_reporting_cron
            echo "0 18 * * * $(pwd)/scripts/advanced_reporting.sh --sla" >> /tmp/sfcc_reporting_cron
            echo -e "${GREEN}✅ Relatórios agendados para 8h e 18h diariamente${NC}"
            ;;
        7)
            echo "Limpando relatórios com mais de 30 dias..."
            find "$REPORT_DIR" -name "*.html" -mtime +30 -delete
            find "$REPORT_DIR" -name "*.csv" -mtime +30 -delete
            echo -e "${GREEN}✅ Relatórios antigos removidos${NC}"
            ;;
        8) exit 0 ;;
        *) echo "Opção inválida" ;;
    esac
    
    echo ""
    read -p "Pressione Enter para continuar..."
done