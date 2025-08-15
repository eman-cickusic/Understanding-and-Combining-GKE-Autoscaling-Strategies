#!/bin/bash

# GKE Autoscaling Lab - Cluster Setup Script
# This script creates and configures a GKE cluster with autoscaling capabilities

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="scaling-demo"
DEFAULT_ZONE="us-central1-a"
NUM_NODES=3

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

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if gcloud is installed
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed. Please install it first."
        exit 1
    fi
    
    # Check if user is authenticated
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "."; then
        log_error "Not authenticated with gcloud. Please run 'gcloud auth login'"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

set_configuration() {
    # Get current project
    CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)
    
    if [[ -z "$CURRENT_PROJECT" ]]; then
        log_error "No project set. Please run 'gcloud config set project YOUR_PROJECT_ID'"
        exit 1
    fi
    
    # Use environment variable or default zone
    ZONE=${ZONE:-$DEFAULT_ZONE}
    
    log_info "Using project: $CURRENT_PROJECT"
    log_info "Using zone: $ZONE"
    
    # Set default zone
    gcloud config set compute/zone $ZONE
}

create_cluster() {
    log_info "Creating GKE cluster: $CLUSTER_NAME"
    
    # Check if cluster already exists
    if gcloud container clusters describe $CLUSTER_NAME --zone=$ZONE &>/dev/null; then
        log_warning "Cluster $CLUSTER_NAME already exists in zone $ZONE"
        read -p "Do you want to continue with the existing cluster? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Exiting..."
            exit 0
        fi
    else
        # Create the cluster
        log_info "Creating cluster with $NUM_NODES nodes and VPA enabled..."
        gcloud container clusters create $CLUSTER_NAME \
            --num-nodes=$NUM_NODES \
            --enable-vertical-pod-autoscaling \
            --zone=$ZONE \
            --machine-type=e2-medium \
            --disk-size=20GB \
            --enable-autorepair \
            --enable-autoupgrade
        
        log_success "Cluster created successfully"
    fi
}

configure_kubectl() {
    log_info "Configuring kubectl..."
    gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE
    log_success "kubectl configured"
}

verify_cluster() {
    log_info "Verifying cluster status..."
    
    # Wait for cluster to be ready
    log_info "Waiting for cluster to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    # Display cluster info
    echo
    log_info "Cluster Information:"
    kubectl get nodes
    echo
    kubectl get deployments --all-namespaces
    
    log_success "Cluster verification completed"
}

main() {
    echo
    log_info "Starting GKE Autoscaling Lab Cluster Setup"
    echo "==========================================="
    
    check_prerequisites
    set_configuration
    create_cluster
    configure_kubectl
    verify_cluster
    
    echo
    log_success "Cluster setup completed successfully!"
    echo
    log_info "Next steps:"
    echo "1. Deploy applications: kubectl apply -f manifests/"
    echo "2. Configure autoscaling: ./scripts/configure-autoscaling.sh"
    echo "3. Run load tests: ./scripts/load-test.sh"
    echo
}

# Run main function
main "$@"
