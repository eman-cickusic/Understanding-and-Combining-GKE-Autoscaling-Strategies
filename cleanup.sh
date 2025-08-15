#!/bin/bash

# GKE Autoscaling Lab - Cleanup Script
# This script cleans up all resources created during the lab

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

confirm_cleanup() {
    echo
    log_warning "This will DELETE the following resources:"
    echo "• GKE Cluster: $CLUSTER_NAME"
    echo "• All pods, deployments, and services"
    echo "• Autoscaling configurations (HPA, VPA, etc.)"
    echo "• Any automatically created node pools"
    echo
    log_error "THIS ACTION CANNOT BE UNDONE!"
    echo
    
    read -p "Are you sure you want to continue? Type 'DELETE' to confirm: " confirmation
    
    if [[ "$confirmation" != "DELETE" ]]; then
        log_info "Cleanup cancelled"
        exit 0
    fi
}

show_current_resources() {
    log_info "Current resources that will be deleted:"
    echo "========================================"
    
    # Get current zone
    ZONE=${ZONE:-$DEFAULT_ZONE}
    
    # Check if cluster exists
    if gcloud container clusters describe $CLUSTER_NAME --zone=$ZONE &>/dev/null; then
        echo
        log_info "Cluster: $CLUSTER_NAME (zone: $ZONE)"
        
        # Show node pools
        echo
        log_info "Node Pools:"
        gcloud container node-pools list --cluster=$CLUSTER_NAME --zone=$ZONE 2>/dev/null || echo "Unable to list node pools"
        
        # Show nodes
        echo
        log_info "Nodes:"
        kubectl get nodes 2>/dev/null || echo "Unable to connect to cluster"
        
        # Show deployments
        echo
        log_info "Deployments:"
        kubectl get deployments --all-namespaces 2>/dev/null | grep -v kube-system || echo "Unable to list deployments"
        
        # Show HPAs
        echo
        log_info "Horizontal Pod Autoscalers:"
        kubectl get hpa 2>/dev/null || echo "No HPA resources found"
        
        # Show VPAs
        echo
        log_info "Vertical Pod Autoscalers:"
        kubectl get vpa 2>/dev/null || echo "No VPA resources found"
        
    else
        log_warning "Cluster $CLUSTER_NAME not found in zone $ZONE"
        return 1
    fi
}

cleanup_kubernetes_resources() {
    log_info "Cleaning up Kubernetes resources..."
    
    if ! kubectl cluster-info &>/dev/null; then
        log_warning "Cannot connect to cluster. Skipping Kubernetes resource cleanup."
        return 0
    fi
    
    # Delete load generator if running
    log_info "Stopping any running load generators..."
    kubectl delete pod load-generator --ignore-not-found=true
    
    # Delete HPA
    log_info "Deleting Horizontal Pod Autoscalers..."
    kubectl delete hpa --all --ignore-not-found=true
    
    # Delete VPA
    log_info "Deleting Vertical Pod Autoscalers..."
    kubectl delete vpa --all --ignore-not-found=true
    
    # Delete pause pods
    log_info "Deleting pause pods..."
    kubectl delete deployment overprovisioning -n kube-system --ignore-not-found=true
    kubectl delete priorityclass overprovisioning --ignore-not-found=true
    
    # Delete Pod Disruption Budgets
    log_info "Deleting Pod Disruption Budgets..."
    kubectl delete pdb --all -n kube-system --ignore-not-found=true
    
    # Delete application deployments
    log_info "Deleting application deployments..."
    kubectl delete deployment php-apache --ignore-not-found=true
    kubectl delete deployment hello-server --ignore-not-found=true
    kubectl delete service php-apache --ignore-not-found=true
    
    log_success "Kubernetes resources cleaned up"
}

cleanup_cluster() {
    log_info "Deleting GKE cluster: $CLUSTER_NAME"
    
    # Get current zone
    ZONE=${ZONE:-$DEFAULT_ZONE}
    
    # Check if cluster exists
    if ! gcloud container clusters describe $CLUSTER_NAME --zone=$ZONE &>/dev/null; then
        log_warning "Cluster $CLUSTER_NAME not found in zone $ZONE"
        return 0
    fi
    
    # Delete the cluster
    log_info "This may take several minutes..."
    gcloud container clusters delete $CLUSTER_NAME --zone=$ZONE --quiet
    
    log_success "Cluster deleted successfully"
}

cleanup_local_files() {
    log_info "Cleaning up local temporary files..."
    
    # Remove any temporary files that might have been created
    rm -f /tmp/gke-autoscaling-* 2>/dev/null || true
    
    # Clear kubectl context if it was set to the deleted cluster
    kubectl config get-contexts | grep $CLUSTER_NAME &>/dev/null && {
        log_info "Removing kubectl context for deleted cluster..."
        kubectl config delete-context gke_$(gcloud config get-value project)_${ZONE}_${CLUSTER_NAME} 2>/dev/null || true
    }
    
    log_success "Local cleanup completed"
}

show_cleanup_summary() {
    echo
    log_success "Cleanup Summary"
    echo "==============="
    echo "✅ Kubernetes resources deleted"
    echo "✅ GKE cluster deleted"
    echo "✅ Local files cleaned up"
    echo
    log_info "Resources that were removed:"
    echo "• Cluster: $CLUSTER_NAME"
    echo "• All node pools (including auto-provisioned ones)"
    echo "• All VMs and persistent disks"
    echo "• Load balancers and networking resources"
    echo "• Horizontal and Vertical Pod Autoscalers"
    echo "• Pod Disruption Budgets"
    echo "• Application deployments and services"
    echo
    log_success "Lab environment completely cleaned up!"
}

partial_cleanup_menu() {
    echo
    log_info "Partial Cleanup Options"
    echo "======================="
    echo "1. Delete applications only (keep cluster)"
    echo "2. Delete autoscaling configs only"
    echo "3. Delete everything (full cleanup)"
    echo "4. Cancel"
    echo
    read -p "Choose option (1-4): " option
    
    case $option in
        1)
            cleanup_kubernetes_resources
            log_success "Applications deleted. Cluster preserved."
            ;;
        2)
            kubectl delete hpa --all --ignore-not-found=true
            kubectl delete vpa --all --ignore-not-found=true
            kubectl delete pdb --all -n kube-system --ignore-not-found=true
            log_success "Autoscaling configurations deleted."
            ;;
        3)
            return 0  # Continue with full cleanup
            ;;
        4)
            log_info "Cleanup cancelled"
            exit 0
            ;;
        *)
            log_error "Invalid option"
            exit 1
            ;;
    esac
    
    exit 0
}

main() {
    echo
    log_info "Starting GKE Autoscaling Lab Cleanup"
    echo "===================================="
    
    # Check if gcloud is available
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI is not installed"
        exit 1
    fi
    
    # Show what will be deleted
    if show_current_resources; then
        echo
        read -p "Do you want partial cleanup instead of full deletion? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            partial_cleanup_menu
        fi
        
        # Confirm full cleanup
        confirm_cleanup
        
        # Perform cleanup
        cleanup_kubernetes_resources
        cleanup_cluster
        cleanup_local_files
        show_cleanup_summary
    else
        log_info "No resources found to clean up"
    fi
}

# Handle script interruption
trap 'echo; log_warning "Cleanup interrupted. Some resources may still exist."; exit 1' INT TERM

# Run main function
main "$@"
