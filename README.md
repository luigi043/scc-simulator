# Salesforce Commerce Cloud Support Simulator

A complete command-line based simulator for Salesforce Commerce Cloud (SFCC) support operations, designed for testing, training, and development purposes.

##  Features

### Core Simulation
- **Order Management**: Simulate e-commerce orders with realistic data
- **Payment Processing**: Simulate payment transactions with random failures
- **Failure Simulation**: Generate system failures mimicking real SFCC environments
- **API Simulation**: Mock REST APIs for OCAPI and Data Warehouse operations

### Support Operations
- **Support Console**: View and manage failed orders
- **Automatic Retry**: Retry failed jobs with configurable success rates
- **Log Investigation**: Advanced log analysis and pattern detection
- **Manual Fixes**: Apply fixes and track resolution times
- **SLA Monitoring**: Track service level agreement compliance

### Advanced Features
- **Alert System**: Real-time monitoring with email/Slack notifications
- **Backup System**: Automated backups with retention policies
- **Reporting Engine**: Generate HTML and CSV reports
- **Webhook Simulator**: Test webhook integrations
- **Deployment Manager**: Simulate CI/CD pipelines
- **Health Monitoring**: System resource monitoring
- **Batch Processing**: Automated order export and inventory sync

##  Prerequisites

- **Bash Shell** (macOS Terminal, Linux Bash, or Windows WSL2)
- **jq** (for JSON processing) - [Installation Guide](https://stedolan.github.io/jq/download/)
- **Python 3** (optional, for advanced features)
- **bc** (for calculations) - usually pre-installed

## 🛠 Installation

### Quick Start (macOS/Linux)

```bash
# 1. Download or clone the project
git clone <repository-url>
cd scc-simulator

# 2. Run the universal installer
chmod +x install_universal.sh
./install_universal.sh

# 3. Grant execution permissions
chmod +x master_control.sh scripts/*.sh backend/*.sh
```

### Manual Installation

```bash
# Create directory structure
mkdir -p scc-simulator/{backend,logs,orders,failures,scripts,backups,reports,webhook_events}
cd scc-simulator

# Install jq (if not installed)
# macOS:
brew install jq

# Linux (Debian/Ubuntu):
sudo apt-get update && sudo apt-get install -y jq

# Linux (RHEL/CentOS):
sudo yum install -y jq
```

##  Usage

### Starting the System

```bash
# Start the master control panel (recommended)
./master_control.sh

# Or start the main simulator directly
./scc_simulator.sh
```

### Main Menu Options

From the master control panel (`./master_control.sh`):

1. **Start All Services** - Launch all background services
2. **Stop All Services** - Stop all running services
3. **Main Console** - Open the primary SFCC simulator
4. **Alert Dashboard** - Real-time monitoring and alerts
5. **Backup System** - Automated backup management
6. **Advanced Reporting** - Generate business intelligence reports
7. **Webhook Simulator** - Test webhook integrations
8. **Deployment Manager** - Simulate CI/CD deployments
9. **System Health Check** - Verify system status and dependencies
10. **Log Viewer** - Unified log monitoring
11. **Install Dependencies** - Install missing packages
12. **Exit** - Shutdown all services and exit

### Basic Workflow

```bash
# 1. Start the system
./master_control.sh

# 2. In the master control, choose option 3 (Main Console)

# 3. From the main console:
#    - Simulate orders (Option 1)
#    - Process payments (Option 2) - some will fail randomly
#    - Access support console (Option 4)
#    - Resolve failures using auto-retry or manual fixes
#    - Monitor logs in real-time (Option 5)
```

## 📁 Project Structure

```
scc-simulator/
├── master_control.sh          # Main control panel
├── scc_simulator.sh           # Primary simulator
├── install_universal.sh       # Installation script
├── .env                       # Configuration file
├── README.md                  # This file
│
├── backend/                   # API and service simulations
│   ├── api_server.sh          # REST API simulator
│   ├── webhook_simulator.sh   # Webhook testing
│   └── api_responses/         # Mock API responses
│
├── scripts/                   # Automation scripts
│   ├── alert_system.sh        # Real-time monitoring
│   ├── auto_monitor.sh        # Automated monitoring
│   ├── backup_system.sh       # Backup management
│   ├── batch_processor.sh     # Batch operations
│   ├── deployment_manager.sh  # CI/CD simulation
│   └── advanced_reporting.sh  # Business reporting
│
├── logs/                      # System logs
│   ├── orders.log            # Order transactions
│   ├── failures.log          # Failure records
│   ├── system.log            # System events
│   ├── alerts.log            # Alert history
│   └── deployments.log       # Deployment history
│
├── orders/                    # Simulated orders (JSON files)
├── failures/                  # System failures (JSON files)
├── backups/                   # Automated backups
├── reports/                   # Generated reports
└── webhook_events/           # Webhook payloads
```

## 🔧 Configuration

Edit `.env` file for system configuration:

```bash
# Salesforce Commerce Cloud Simulator Configuration
ENVIRONMENT=development
LOG_LEVEL=INFO
API_PORT=8080
WEBHOOK_PORT=9090
BACKUP_RETENTION_DAYS=7
FAILURE_RETRY_LIMIT=3
```

##  Key Simulations

### Order Simulation
- Creates realistic order data with customer information
- Simulates different order statuses (PENDING, PAID, FAILED, EXPORTED)
- Generates random order values and item quantities

### Payment Processing
- 20% random failure rate for realistic testing
- Multiple payment methods simulation
- Error code generation for troubleshooting

### System Failures
- Inventory sync failures
- Tax calculation errors
- Shipping rate unavailability
- Order export failures
- Cart pipeline errors

### API Simulation
- OCAPI endpoints simulation
- Data Warehouse API responses
- Random latency and timeout simulation
- Error response generation

##  Alert System

The alert system monitors:
- **Critical failures** (HIGH severity)
- **SLA breaches** (resolution time > 1 hour)
- **System performance** (CPU/Memory usage)
- **Trend analysis** (sudden failure spikes)

Alert notifications are logged and can be configured to simulate:
- Email notifications
- Slack alerts
- SMS notifications (simulated)

## 💾 Backup System

Automatic backup features:
- **Database backup** (simulated SQL dumps)
- **Log rotation** and archiving
- **Configuration backup**
- **Retention policies** (configurable days)
- **Integrity verification**

##  Reporting

Generate various reports:
- **Daily HTML reports** with metrics and charts
- **SLA compliance reports** in CSV format
- **Trend analysis** for business intelligence
- **Performance metrics** and recommendations

##  Webhook Simulation

Test webhook integrations with:
- **Order created/updated/cancelled** events
- **Payment processed/failed** events
- **Inventory updated** events
- **Customer created** events
- **Retry logic** for failed webhooks

##  Deployment Simulation

Simulate CI/CD pipelines:
- **Build process** with testing
- **Staging deployment**
- **Production deployment**
- **Rollback procedures**
- **Environment status** monitoring

##  Troubleshooting

### Common Issues

1. **"command not found: free"** (macOS)
   - The system automatically uses alternative commands
   - No action needed - the scripts are cross-platform

2. **"jq not found"**
   ```bash
   # macOS
   brew install jq
   
   # Linux
   sudo apt-get install jq  # Debian/Ubuntu
   sudo yum install jq      # RHEL/CentOS
   ```

3. **Permission denied**
   ```bash
   chmod +x *.sh scripts/*.sh backend/*.sh
   ```

4. **Scripts not working from wrong directory**
   - Always run from the `scc-simulator` root directory
   - Use `./master_control.sh` to navigate between services

### System Health Check

Run the built-in health check:
```bash
./master_control.sh
# Choose option 9: System Health Check
```

##  Learning Resources

This simulator demonstrates:
- **Enterprise support workflows**
- **Incident management procedures**
- **SLA tracking and reporting**
- **System monitoring best practices**
- **Automated recovery processes**

## Use Cases

### For Developers
- Test SFCC integration code
- Simulate edge cases and failures
- Develop monitoring scripts
- Practice troubleshooting scenarios

### For Support Teams
- Train on SFCC support procedures
- Practice incident response
- Learn log analysis techniques
- Understand SLA management

### For DevOps
- Test monitoring configurations
- Practice deployment procedures
- Develop backup strategies
- Implement alerting systems

## 🔄 Development Workflow

```bash
# Typical development session
./master_control.sh          # Start control panel
# → Start all services
# → Open main console
# → Simulate orders and failures
# → Practice troubleshooting
# → Generate reports
# → Check system health
```

##  License

This project is for educational and demonstration purposes. Salesforce Commerce Cloud is a trademark of Salesforce.com, Inc.

##  Contributing

This is a demonstration project. For educational purposes only.

## Support

This is a simulator project for learning purposes. For actual Salesforce Commerce Cloud support, contact [Salesforce Support](https://help.salesforce.com/).

---

