#!/bin/bash

# GKE Autoscaling Lab - Monitoring Script
# This script provides real-time monitoring of the autoscaling cluster

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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

log_header() {
    echo -e "${CYAN}$1${NC}"
}

show_cluster_overview() {
    log_header "=== CLUSTER OVERVIEW ==="
    
    # Basic cluster info
    echo
    log_info "Cluster Nodes:"
    kubectl get nodes -o custom-columns="NAME:.metadata.name,STATUS:.status.conditions[?(@.type=='Ready')].status,ROLES:.metadata.labels.kubernetes\.io/arch,INSTANCE-TYPE:.metadata.labels.node\.kubernetes\.io/instance-type,ZONE:.metadata.labels.topology\.kubernetes\.io/zone"
    
    echo
    log_info "Node Resource Usage:"
    kubectl top nodes 2>/dev/null || echo "Metrics not available yet"
}

show_autoscaling_status() {
    log_header "=== AUTOSCALING STATUS ==="
    
    # HPA Status
    echo
    log_info "Horizontal Pod Autoscaler (HPA):"
    kubectl get hpa -o custom-columns="NAME:.metadata.name,REFERENCE:.spec.scaleTargetRef.name,TARGETS:.status.currentCPUUtilizationPercentage,MINPODS:.spec.minReplicas,MAXPODS:.spec.maxReplicas,REPLICAS:.status.currentReplicas"
    
    # VPA Status
    echo
    log_info "Vertical Pod Autoscaler (VPA):"
    kubectl get vpa 2>/dev/null || echo "No VPA resources found"
    
    # Show VPA recommendations if available
    if kubectl get vpa hello-server-vpa &>/dev/null; then
        echo
        log_info "VPA Recommendations:"
        kubectl describe vpa hello-server-vpa | sed -n '/Container Recommendations:/,/Events:/p' | head -20
    fi
}

show_workload_status() {
    log_header "=== WORKLOAD STATUS ==="
    
    echo
    log_info "Application Deployments:"
    kubectl get deployments -o custom-columns="NAME:.metadata.name,READY:.status.readyReplicas,UP-TO-DATE:.status.updatedReplicas,AVAILABLE:.status.availableReplicas,AGE:.metadata.creationTimestamp"
    
    echo
    log_info "Pod Distribution by Node:"
    kubectl get pods -o custom-columns="POD:.metadata.name,NODE:.spec.nodeName,STATUS:.status.phase" | grep -E "(php-apache|hello-server)" | sort -k2
    
    echo
    log_info "Resource Usage by Pod:"
    kubectl top pods 2>/dev/null | grep -E "(php-apache|hello-server)" || echo "Pod metrics not available yet"
}

show_system_pods() {
    log_header "=== SYSTEM COMPONENTS ==="
    
    echo
    log_info "Pause Pods (Overprovisioning):"
    kubectl get pods -n kube-system -l run=overprovisioning -o wide 2>/dev/null || echo "No pause pods found"
    
    echo
    log_info "Pod Disruption Budgets:"
    kubectl get pdb -n kube-system -o custom-columns="NAME:.metadata.name,MIN-AVAILABLE:.spec.minAvailable,MAX-UNAVAILABLE:.spec.maxUnavailable,ALLOWED-DISRUPTIONS:.status.disruptionsAllowed"
}

show_events() {
    log_header "=== RECENT EVENTS ==="
    
    echo
    log_info "Autoscaling Events (Last 10):"
    kubectl get events --sort-by='.lastTimestamp' | grep -E "(Scaled|HorizontalPodAutoscaler|VerticalPodAutoscaler|cluster-autoscaler)" | tail -10 || echo "No recent autoscaling events"
    
    echo
    log_info "Pod Events (Last 5):"
    kubectl get events --sort-by='.lastTimestamp' | grep -E "(php-apache|hello-server)" | tail -5 || echo "No recent pod events"
}

show_cost_optimization_metrics() {
    log_header "=== COST OPTIMIZATION METRICS ==="
    
    echo
    log_info "Current Resource Requests vs Limits:"
    
    # Calculate total resources
    echo
    echo "PHP-Apache Deployment:"
    kubectl get deployment php-apache -o jsonpath='{.spec.replicas}' | xargs echo "Replicas:"
    kubectl get deployment php-apache -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' | xargs echo "CPU Request per pod:"
    kubectl get deployment php-apache -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}' | xargs echo "CPU Limit per pod:"
    
    echo
    echo "Hello-Server Deployment:"
    kubectl get deployment hello-server -o jsonpath='{.spec.replicas}' | xargs echo "Replicas:"
    kubectl get deployment hello-server -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' | xargs echo "CPU Request per pod:"
    
    echo
    log_info "Node Utilization:"
    kubectl describe nodes | grep -A 4 "Allocated resources:" | grep -E "(cpu|memory)"
}

interactive_mode() {
    log_header "=== INTERACTIVE MONITORING MODE ==="
    echo "Press 'q' to quit, 'r' to refresh, number keys for specific views"
    echo
    
    while true; do
        clear
        echo "========================================================"
        log_header "GKE AUTOSCALING LAB - LIVE MONITORING"
        echo "========================================================"
        echo "Time: $(date)"
        echo "Refresh: Auto (10s) | Manual: 'r' | Quit: 'q'"
        echo "Views: [1] Overview [2] Autoscaling [3] Workloads [4] Events [5] Costs"
        echo "========================================================"
        
        # Quick status summary
        echo
        log_info "Quick Status:"
        printf "Nodes: "
        kubectl get nodes --no-headers | wc -l
        printf "HPA Target: "
        kubectl get hpa php-apache -o jsonpath='{.status.currentCPUUtilizationPercentage}' 2>/dev/null | xargs echo -n
        echo "/50%"
        printf "PHP Replicas: "
        kubectl get deployment php-apache -o jsonpath='{.status.replicas}' 2>/dev/null
        echo
        
        # Show most recent events
        echo
        log_info "Latest Events:"
        kubectl get events --sort-by='.lastTimestamp' | tail -3
        
        echo
        echo "Auto-refresh in 10 seconds... (press key for manual control)"
        
        read -t 10 -n 1 key 2>/dev/null || key=""
        
        case $key in
            q|Q)
                log_info "Exiting monitoring mode..."
                break
                ;;
            r|R)
                continue
                ;;
            1)
                clear
                show_cluster_overview
                read -p "Press any key to continue..." -n 1
                ;;
            2)
                clear
                show_autoscaling_status
                read -p "Press any key to continue..." -n 1
                ;;
            3)
                clear
                show_workload_status
                read -p "Press any key to continue..." -n 1
                ;;
            4)
                clear
                show_events
                read -p "Press any key to continue..." -n 1
                ;;
            5)
                clear
                show_cost_optimization_metrics
                read -p "Press any key to continue..." -n 1
                ;;
            *)
                continue
                ;;
        esac
    done
}

snapshot_mode() {
    log_header "=== CLUSTER SNAPSHOT MODE ==="
    
    show_cluster_overview
    echo
    show_autoscaling_status  
    echo
    show_workload_status
    echo
    show_system_pods
    echo
    show_events
    echo
    show_cost_optimization_metrics
}

main() {
    echo
    log_info "Starting GKE Autoscaling Monitoring"
    echo "==================================="
    
    # Check if cluster is accessible
    if ! kubectl cluster-info &>/dev/null; then
        log_error "Unable to connect to Kubernetes cluster"
        exit 1
    fi
    
    echo
    echo "Monitoring Options:"
    echo "1. Interactive mode (live updates)"
    echo "2. Snapshot mode (one-time view)"
    echo "3. Continuous snapshot (every 30s)"
    echo
    read -p "Choose option (1-3) [default: 1]: " option
    
    case ${option:-1} in
        1)
            interactive_mode
            ;;
        2)
            snapshot_mode
            ;;
        3)
            log_info "Starting continuous monitoring (Ctrl+C to stop)..."
            while true; do
                clear
                snapshot_mode
                echo
                log_info "Next update in 30 seconds..."
                sleep 30
            done
            ;;
        *)
            log_error "Invalid option"
            exit 1
            ;;
    esac
    
    echo
    log_success "Monitoring session completed"
}

# Handle script interruption
trap 'echo; log_info "Monitoring stopped"; exit 0' INT TERM

# Run main function
main "$@"
