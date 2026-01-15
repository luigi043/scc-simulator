#!/bin/bash

# Salesforce Commerce Cloud Simulator Configuration

# API URLs (simulated)
export SFCC_API_URL="https://api.sandbox.salesforce.com"
export SFCC_OCAPI_URL="https://sandbox.salesforce.com/s/Shopify/dw/shop/v21_3"

# Retry settings
export MAX_RETRY_COUNT=3
export RETRY_DELAY=5

# Log settings
export LOG_LEVEL="INFO" # DEBUG, INFO, WARN, ERROR
export LOG_ROTATION_DAYS=7

# Simulation settings
export FAILURE_RATE=20 # percentage
export AUTO_RETRY_SUCCESS_RATE=70 # percentage

# Paths
export BASE_DIR="./scc-simulator"
export ORDERS_DIR="$BASE_DIR/orders"
export FAILURES_DIR="$BASE_DIR/failures"
export LOGS_DIR="$BASE_DIR/logs"