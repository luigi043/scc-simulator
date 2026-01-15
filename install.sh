#!/bin/bash

echo "Instalando Salesforce Commerce Cloud Simulator..."
echo ""

# Criar diretórios
mkdir -p scc-simulator/{logs,orders,failures,backend}

# Dar permissão de execução
chmod +x scc_simulator.sh

# Verificar dependências
if ! command -v jq &> /dev/null; then
    echo "Instalando jq para processamento JSON..."
    sudo apt-get install -y jq || brew install jq
fi

echo ""
echo "✅ Instalação completa!"
echo ""
echo "Para iniciar o simulador:"
echo "./scc_simulator.sh"
echo ""