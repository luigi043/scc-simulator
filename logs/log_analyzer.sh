#!/bin/bash

# Analisador de Logs SFCC
echo "📊 Analisador de Logs do Salesforce Commerce Cloud"
echo ""

# Cores
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

analyze_error_patterns() {
    echo -e "${BLUE}🔍 Analisando Padrões de Erro...${NC}"
    echo ""
    
    # Análise por tipo de erro
    echo "📈 Distribuição por Tipo:"
    grep -h "ERROR\|FAILED" *.log 2>/dev/null | grep -o "PAYMENT_FAILED\|INVENTORY_SYNC\|ORDER_EXPORT" | sort | uniq -c | sort -nr
    
    echo ""
    echo "🕒 Padrão Temporal:"
    echo "Manhã (00-11): $(grep -c " 0[0-9]:\|1[0-1]:" *.log 2>/dev/null) erros"
    echo "Tarde (12-17): $(grep -c "1[2-7]:" *.log 2>/dev/null) erros"
    echo "Noite (18-23): $(grep -c "1[8-9]:\|2[0-3]:" *.log 2>/dev/null) erros"
    
    echo ""
    echo "📉 Tendência Diária:"
    tail -100 *.log 2>/dev/null | grep -c "FAILED" | awk '{print "Últimas 100 entradas: "$1" falhas"}'
}

find_critical_errors() {
    echo -e "${RED}🚨 Buscando Erros Críticos...${NC}"
    echo ""
    
    # Procurar erros críticos
    CRITICAL_PATTERNS=(
        "timeout"
        "out of memory"
        "database"
        "connection refused"
        "disk full"
    )
    
    for pattern in "${CRITICAL_PATTERNS[@]}"; do
        COUNT=$(grep -i "$pattern" *.log 2>/dev/null | wc -l)
        if [ "$COUNT" -gt 0 ]; then
            echo -e "${RED}⚠️  $COUNT erros de '$pattern' encontrados${NC}"
            grep -i "$pattern" *.log 2>/dev/null | head -3 | sed 's/^/    /'
        fi
    done
}

generate_log_report() {
    echo -e "${GREEN}📄 Gerando Relatório de Logs...${NC}"
    
    REPORT="log_analysis_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== Análise de Logs SFCC ==="
        echo "Período: Últimas 24 horas"
        echo "Gerado: $(date)"
        echo ""
        
        echo "📊 ESTATÍSTICAS GERAIS"
        echo "Total de Logs: $(wc -l *.log 2>/dev/null | tail -1 | awk '{print $1}')"
        echo "Erros: $(grep -c "ERROR\|FAILED" *.log 2>/dev/null)"
        echo "Alertas: $(grep -c "WARN\|ALERT" *.log 2>/dev/null)"
        echo ""
        
        echo "🚨 TOP 5 ERROS"
        grep -h "ERROR\|FAILED" *.log 2>/dev/null | grep -o "PAY_[0-9]*\|ERR_[0-9]*" | sort | uniq -c | sort -nr | head -5
        echo ""
        
        echo "📈 RECOMENDAÇÕES"
        
        # Análise de recomendações
        PAYMENT_ERRORS=$(grep -c "PAYMENT_FAILED" *.log 2>/dev/null)
        if [ "$PAYMENT_ERRORS" -gt 10 ]; then
            echo "1. ⚠️  Muitos erros de pagamento. Verificar integração com gateway."
        fi
        
        TIMEOUT_COUNT=$(grep -c "timeout" *.log 2>/dev/null)
        if [ "$TIMEOUT_COUNT" -gt 5 ]; then
            echo "2. ⏱️  Timeouts frequentes. Aumentar timeout das APIs."
        fi
    } > "$REPORT"
    
    echo -e "${GREEN}✅ Relatório gerado: $REPORT${NC}"
}

# Menu principal
while true; do
    clear
    echo -e "${BLUE}=== Analisador de Logs SFCC ===${NC}"
    echo ""
    echo "1. Analisar Padrões de Erro"
    echo "2. Buscar Erros Críticos"
    echo "3. Gerar Relatório Completo"
    echo "4. Monitorar Logs em Tempo Real"
    echo "5. Limpar Logs Antigos"
    echo "6. Voltar"
    echo ""
    read -p "Escolha: " choice
    
    case $choice in
        1) analyze_error_patterns ;;
        2) find_critical_errors ;;
        3) generate_log_report ;;
        4) tail -f *.log 2>/dev/null ;;
        5)
            echo "Limpando logs com mais de 7 dias..."
            find . -name "*.log" -mtime +7 -delete
            echo "✅ Concluído"
            ;;
        6) exit 0 ;;
        *) echo "Opção inválida" ;;
    esac
    
    echo ""
    read -p "Pressione Enter para continuar..."
done