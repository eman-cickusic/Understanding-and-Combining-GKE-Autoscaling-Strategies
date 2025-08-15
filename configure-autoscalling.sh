#!/bin/bash

# GKE Autoscaling Lab - Configure Autoscaling Script
# This script configures HPA, VPA, Cluster Autoscaler, and Node Auto Provisioning

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="scaling-demo"
DEFAULT_ZONE="us-central1-a"

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

deploy_applications() {
    log_info "Deploying applications..."
    
    # Deploy PHP Apache application
    log_info "Deploying php-apache application..."
    kubectl apply -f manifests/php-apache.yaml
    
    # Deploy hello-server for VPA demo
    log_info "Deploying hello-server application..."
    kubectl create deployment hello-server --image=gcr.io/google-samples/hello-app:1.0
    kubectl set resources deployment hello-server --requests=cpu=450m
    
    # Wait for deployments to be ready
    log_info "Waiting for deployments to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/php-apache
    kubectl wait --for=condition=available --timeout=300s deployment/hello-server
    
    log_success "Applications deployed successfully"
}

configure_hpa() {
    log_info "Configuring Horizontal Pod Autoscaler..."
    
    # Configure HPA for php-apache
    kubectl autoscale deployment php-apache --cpu-percent=50 --min=1 --max=10
    
    # Wait a moment for HPA to initialize
    sleep 10
    
    # Show HPA status
    log_info "HPA Status:"
    kubectl get hpa
    
    log_success "HPA configured successfully"
}

configure_vpa() {
    log_info "Configuring Vertical Pod Autoscaler..."
    
    # Apply VPA configuration
    kubectl apply -f manifests/hello-vpa.yaml
    
    # Scale hello-server to 2 replicas for VPA demo
    kubectl scale deployment hello-server --replicas=2
    
    log_info "Waiting for VPA to generate recommendations..."
    sleep 30
    
    # Show VPA status
    log_info "VPA Status:"
    kubectl describe vpa hello-server-vpa
    
    log_success "VPA configured successfully"
}

configure_cluster_autoscaler() {
    log_info "Configuring Cluster Autoscaler..."
    
    # Get current zone
    ZONE=${ZONE:-$DEFAULT_ZONE}
    
    # Enable cluster autoscaler
    log_info "Enabling cluster autoscaler..."
    gcloud container clusters update $CLUSTER_NAME \
        --enable-autoscaling \
        --min-nodes 1 \
        --max-nodes 5 \
        --zone=$ZONE
    
    # Set optimize-utilization profile
    log_info "Setting autoscaling profile to optimize-utilization..."
    gcloud container clusters update $CLUSTER_NAME \
        --autoscaling-profile optimize-utilization \
        --zone=$ZONE
    
    log_success "Cluster Autoscaler configured successfully"
}

configure_pod_disruption_budgets() {
    log_info "Configuring Pod Disruption Budgets..."
    
    # Apply PDB configurations
    kubectl apply -f manifests/pod-disruption-budgets.yaml
    
    # Verify PDBs
    log_info "Pod Disruption Budgets created:"
    kubectl get pdb -n kube-system
    
    log_success "Pod Disruption Budgets configured successfully"
}

configure_node_auto_provisioning() {
    log_info "Configuring Node Auto Provisioning..."
    
    # Get current zone
    ZONE=${ZONE:-$DEFAULT_ZONE}
    
    # Enable Node Auto Provisioning
    gcloud container clusters update $CLUSTER_NAME \
        --enable-autoprovisioning \
        --min-cpu 1 \
        --min-memory 2 \
        --max-cpu 45 \
        --max-memory 160 \
        --zone=$ZONE
    
    log_success "Node Auto Provisioning configured successfully"
}

deploy_pause_pods() {
    log_info "Deploying Pause Pods for overprovisioning..."
    
    # Apply pause pod configuration
    kubectl apply -f manifests/pause-pod.yaml
    
    log_info "Waiting for pause pod to be scheduled..."
    sleep 30
    
    # Show pause pod status
    kubectl get pods -n kube-system -l run=overprovisioning
    
    log_success "Pause Pods deployed successfully"
}

show_status() {
    log_info "Current Cluster Status:"
    echo "======================="
    
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
    log_info "Pods by Node:"
    kubectl get pods -o wide
}

main() {
    echo
    log_info "Starting GKE Autoscaling Configuration"
    echo "======================================"
    
    deploy_applications
    sleep 10
    
    configure_hpa
    sleep 5
    
    configure_vpa
    sleep 5
    
    configure_cluster_autoscaler
    sleep 10
    
    configure_pod_disruption_budgets
    sleep 5
    
    configure_node_auto_provisioning
    sleep 10
    
    deploy_pause_pods
    sleep 5
    
    show_status
    
    echo
    log_success "Autoscaling configuration completed successfully!"
    echo
    log_info "Monitor your cluster with:"
    echo "  kubectl get hpa"
    echo "  kubectl get vpa"
    echo "  kubectl get nodes"
    echo "  kubectl get pods -o wide"
    echo
    log_info "Run load test with: ./scripts/load-test.sh"
    echo
}

# Run main function
main "$@"
