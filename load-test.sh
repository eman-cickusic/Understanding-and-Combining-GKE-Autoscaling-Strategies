#!/bin/bash

# GKE Autoscaling Lab - Load Test Script
# This script runs load tests to demonstrate autoscaling behavior

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
LOAD_TEST_DURATION=300  # 5 minutes
MONITORING_INTERVAL=10  # 10 seconds

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_initial_status() {
    log_info "Initial Cluster Status (Before Load Test)"
    echo "=========================================="
    
    echo
    log_info "Nodes:"
    kubectl get nodes
    
    echo
    log_info "Deployments:"
    kubectl get deployments
    
    echo
    log_info "HPA Status:"
    kubectl get hpa
    
    echo
    log_info "Pod Distribution:"
    kubectl get pods -o wide | grep -E "(php-apache|hello-server)"
}

run_load_test() {
    log_info "Starting load test against php-apache service..."
    log_warning "This will run for approximately $LOAD_TEST_DURATION seconds"
    
    # Start load test in background
    log_info "Launching load generator..."
    kubectl run load-generator \
        --image=busybox \
        --restart=Never \
        --rm \
        --stdin \
        --tty=false \
        --command -- \
        /bin/sh -c "while sleep 0.01; do wget -q -O- http://php-apache; done" &
    
    LOAD_PID=$!
    log_info "Load generator started with PID: $LOAD_PID"
    
    # Monitor scaling for specified duration
    log_info "Monitoring autoscaling behavior..."
    
    START_TIME=$(date +%s)
    COUNTER=0
    
    while [ $COUNTER -lt $LOAD_TEST_DURATION ]; do
        CURRENT_TIME=$(date +%s)
        ELAPSED=$((CURRENT_TIME - START_TIME))
        
        echo
        echo "========================================="
        log_info "Load Test Progress: ${ELAPSED}s / ${LOAD_TEST_DURATION}s"
        echo "========================================="
        
        # Show HPA status
        echo
        log_info "HPA Status:"
        kubectl get hpa
        
        # Show deployment replicas
        echo
        log_info "PHP Apache Deployment:"
        kubectl get deployment php-apache
        
        # Show nodes
        echo
        log_info "Cluster Nodes:"
        kubectl get nodes
        
        # Show pods distribution
        echo
        log_info "Pod Distribution:"
        kubectl get pods -o wide | grep php-apache | head -10
        
        sleep $MONITORING_INTERVAL
        COUNTER=$((COUNTER + MONITORING_INTERVAL))
    done
    
    # Stop load test
    log_info "Stopping load test..."
    kill $LOAD_PID 2>/dev/null || true
    
    # Clean up load generator pod
    kubectl delete pod load-generator 2>/dev/null || true
    
    log_success "Load test completed"
}

monitor_scale_down() {
    log_info "Monitoring scale-down behavior..."
    log_info "Waiting for cluster to scale down after load test..."
    
    SCALE_DOWN_MONITORING=180  # 3 minutes
    COUNTER=0
    
    while [ $COUNTER -lt $SCALE_DOWN_MONITORING ]; do
        echo
        echo "================================"
        log_info "Scale-down Monitoring: ${COUNTER}s / ${SCALE_DOWN_MONITORING}s"
        echo "================================"
        
        # Show HPA status
        echo
        log_info "HPA Status:"
        kubectl get hpa
        
        # Show deployment status
        echo
        log_info "Deployment Status:"
        kubectl get deployment php-apache
        
        # Show node count
        echo
        log_info "Node Count:"
        kubectl get nodes --no-headers | wc -l | xargs echo "Total nodes:"
        
        sleep $MONITORING_INTERVAL
        COUNTER=$((COUNTER + MONITORING_INTERVAL))
    done
}

show_final_status() {
    log_info "Final Cluster Status (After Load Test)"
    echo "======================================"
    
    echo
    log_info "Nodes:"
    kubectl get nodes
    
    echo
    log_info "Deployments:"
    kubectl get deployments
    
    echo
    log_info "HPA Status:"
    kubectl get hpa
    
    echo
    log_info "VPA Status:"
    kubectl get vpa
    
    echo
    log_info "System Pods (kube-system):"
    kubectl get pods -n kube-system -l run=overprovisioning
    
    echo
    log_info "Node Pools (if any created by NAP):"
    kubectl get nodes -o custom-columns="NAME:.metadata.name,INSTANCE-TYPE:.metadata.labels.node\.kubernetes\.io/instance-type,ZONE:.metadata.labels.topology\.kubernetes\.io/zone"
}

run_interactive_monitoring() {
    log_info "Starting interactive monitoring mode..."
    echo "Press 'q' to quit, 'r' to refresh, or any other key to continue..."
    
    while true; do
        clear
        echo "========================================="
        log_info "GKE Autoscaling Lab - Live Monitoring"
        echo "========================================="
        echo "Time: $(date)"
        echo
        
        # Show key metrics
        log_info "HPA Status:"
        kubectl get hpa
        
        echo
        log_info "Deployments:"
        kubectl get deployments
        
        echo
        log_info "Nodes:"
        kubectl get nodes
        
        echo
        log_info "Recent Pod Events:"
        kubectl get events --sort-by='.lastTimestamp' | grep -E "(php-apache|Scaled|Created|Started)" | tail -5
        
        echo
        echo "Commands: [q]uit | [r]efresh | [any key] continue"
        read -t 10 -n 1 key 2>/dev/null || key=""
        
        case $key in
            q|Q)
                log_info "Exiting monitoring mode..."
                break
                ;;
            r|R)
                continue
                ;;
            *)
                continue
                ;;
        esac
    done
}

run_custom_load_test() {
    echo
    log_info "Custom Load Test Options"
    echo "========================"
    echo "1. Light load (30 seconds)"
    echo "2. Medium load (2 minutes)" 
    echo "3. Heavy load (5 minutes)"
    echo "4. Interactive monitoring only"
    echo
    read -p "Choose option (1-4): " option
    
    case $option in
        1)
            LOAD_TEST_DURATION=30
            run_load_test
            ;;
        2)
            LOAD_TEST_DURATION=120
            run_load_test
            ;;
        3)
            LOAD_TEST_DURATION=300
            run_load_test
            ;;
        4)
            run_interactive_monitoring
            return
            ;;
        *)
            log_error "Invalid option. Using default 5-minute test."
            LOAD_TEST_DURATION=300
            run_load_test
            ;;
    esac
}

validate_prerequisites() {
    log_info "Validating prerequisites..."
    
    # Check if cluster exists and kubectl is configured
    if ! kubectl cluster-info &>/dev/null; then
        log_error "Unable to connect to Kubernetes cluster. Please ensure cluster is created and kubectl is configured."
        exit 1
    fi
    
    # Check if required deployments exist
    if ! kubectl get deployment php-apache &>/dev/null; then
        log_error "php-apache deployment not found. Please run ./scripts/configure-autoscaling.sh first."
        exit 1
    fi
    
    # Check if HPA exists
    if ! kubectl get hpa php-apache &>/dev/null; then
        log_error "HPA for php-apache not found. Please run ./scripts/configure-autoscaling.sh first."
        exit 1
    fi
    
    log_success "Prerequisites validated"
}

main() {
    echo
    log_info "Starting GKE Autoscaling Load Test"
    echo "=================================="
    
    validate_prerequisites
    show_initial_status
    
    echo
    read -p "Do you want to run a custom load test? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        run_custom_load_test
    else
        run_load_test
    fi
    
    monitor_scale_down
    show_final_status
    
    echo
    log_success "Load test completed successfully!"
    echo
    log_info "Key observations:"
    echo "• HPA scaled replicas based on CPU utilization"
    echo "• Cluster Autoscaler added/removed nodes as needed"
    echo "• VPA adjusted resource requests automatically"
    echo "• Node Auto Provisioning may have created optimized node pools"
    echo
    log_info "Continue monitoring with: ./scripts/monitor.sh"
    echo
}

# Handle script interruption
trap 'log_warning "Load test interrupted. Cleaning up..."; kill $LOAD_PID 2>/dev/null || true; kubectl delete pod load-generator 2>/dev/null || true; exit 1' INT TERM

# Run main function
main "$@"
