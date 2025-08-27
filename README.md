# Understanding and Combining GKE Autoscaling Strategies

This repository contains the implementation and configuration files for demonstrating various Google Kubernetes Engine (GKE) autoscaling strategies including Horizontal Pod Autoscaling (HPA), Vertical Pod Autoscaling (VPA), Cluster Autoscaler, and Node Auto Provisioning.

## 🎯 Lab Objectives

- ✅ Decrease number of replicas with Horizontal Pod Autoscaler
- ✅ Decrease CPU request with Vertical Pod Autoscaler  
- ✅ Decrease number of nodes with Cluster Autoscaler
- ✅ Automatically create optimized node pools with Node Auto Provisioning
- ✅ Test autoscaling behavior under load spikes
- ✅ Optimize cluster with Pause Pods for overprovisioning

## 📋 Prerequisites 

- Google Cloud Platform account with billing enabled
- `gcloud` CLI installed and configured
- `kubectl` installed
- Basic knowledge of Kubernetes concepts

## 🚀 Quick Start

### 1. Clone and Setup

```bash
git clone <your-repo-url>
cd gke-autoscaling-strategies
chmod +x scripts/*.sh
```

### 2. Deploy Infrastructure

```bash
# Set your project and zone
export PROJECT_ID="your-project-id"
export ZONE="us-central1-a"

# Run the setup script
./scripts/setup-cluster.sh
```

### 3. Deploy Applications

```bash
# Deploy the PHP Apache application
kubectl apply -f manifests/php-apache.yaml

# Deploy hello-server for VPA demonstration
kubectl apply -f manifests/hello-server.yaml
kubectl apply -f manifests/hello-vpa.yaml
```

### 4. Configure Autoscaling

```bash
# Setup autoscaling policies
./scripts/configure-autoscaling.sh
```

### 5. Test Load Scenarios

```bash
# Run load test
./scripts/load-test.sh
```

## 📁 Repository Structure

```
├── README.md
├── manifests/
│   ├── php-apache.yaml
│   ├── hello-vpa.yaml
│   ├── pause-pod.yaml
│   └── pod-disruption-budgets.yaml
├── scripts/
│   ├── setup-cluster.sh
│   ├── configure-autoscaling.sh
│   ├── load-test.sh
│   ├── cleanup.sh
│   └── monitor.sh
├── docs/
│   ├── autoscaling-strategies.md
│   └── cost-optimization.md
└── examples/
    └── monitoring-commands.md
```

## 🔧 Configuration Files

### Application Deployments
- `manifests/php-apache.yaml` - PHP Apache deployment with resource limits
- `manifests/hello-vpa.yaml` - Vertical Pod Autoscaler configuration
- `manifests/pause-pod.yaml` - Pause pods for cluster overprovisioning

### Autoscaling Policies
- Horizontal Pod Autoscaler: 1-10 replicas, 50% CPU target
- Vertical Pod Autoscaler: Auto mode with CPU/memory recommendations
- Cluster Autoscaler: 1-5 nodes with optimize-utilization profile
- Node Auto Provisioning: 1-45 CPU, 2-160GB memory limits

## 📊 Monitoring and Observability

### Key Commands

```bash
# Monitor HPA status
kubectl get hpa

# Check VPA recommendations
kubectl describe vpa hello-server-vpa

# View node utilization
kubectl get nodes
kubectl describe nodes

# Monitor deployments
kubectl get deployments
watch kubectl get pods
```

### Cloud Console Monitoring
- Navigate to GKE → Clusters → scaling-demo → Nodes tab
- Monitor CPU/Memory utilization in real-time
- Observe autoscaling events in the cluster events

## 💡 Autoscaling Strategies Explained

### 1. Horizontal Pod Autoscaler (HPA)
- **Purpose**: Scale pod replicas based on CPU/memory metrics
- **Best for**: Stateless applications with variable load
- **Configuration**: Target 50% CPU utilization, 1-10 replica range

### 2. Vertical Pod Autoscaler (VPA)
- **Purpose**: Right-size individual pods' resource requests
- **Best for**: Applications with predictable resource patterns
- **Modes**: Off (recommendations), Initial (startup only), Auto (continuous)

### 3. Cluster Autoscaler
- **Purpose**: Add/remove nodes based on pod scheduling needs
- **Profile**: Optimize-utilization for aggressive cost savings
- **Range**: 1-5 nodes with Pod Disruption Budgets

### 4. Node Auto Provisioning (NAP)
- **Purpose**: Create optimized node pools for specific workloads
- **Benefits**: Right-sized infrastructure for diverse workload requirements
- **Limits**: 1-45 CPU cores, 2-160GB memory per cluster

## 🏗️ Infrastructure Optimization

### Cost Optimization Formula
```
Safety Buffer = (1 - buffer_percentage) / (1 + traffic_growth_percentage)
```

**Example**: 15% buffer + 30% traffic growth = 65% safety buffer

### Pause Pod Strategy
- Deploy low-priority pods to reserve buffer capacity
- High-priority workloads preempt pause pods for faster scaling
- Recommended: 1 pause pod per node for optimal resource utilization

## 🧪 Load Testing Results

### Scenario 1: Low Demand
- HPA scaled php-apache from 3 → 1 replicas
- VPA reduced hello-server CPU request from 450m → 25m
- Cluster Autoscaler scaled nodes from 3 → 2

### Scenario 2: High Demand (Load Test)
- HPA scaled php-apache to 7+ replicas
- Cluster Autoscaler provisioned additional nodes
- NAP created optimized high-CPU node pool
- Response time: ~3-5 minutes for full scaling

### Scenario 3: Overprovisioned Cluster
- Pause pods provided immediate scheduling capacity
- Reduced scaling time from 3-5 minutes to <1 minute
- Improved application availability during traffic spikes

## 🔍 Troubleshooting

### Common Issues

1. **HPA shows `<unknown>/50%`**
   - Wait 1-2 minutes for metrics collection
   - Verify metrics-server is running

2. **VPA not updating pods**
   - Ensure updatePolicy is set to "Auto"
   - Scale deployment to ≥2 replicas
   - Check VPA controller logs

3. **Cluster Autoscaler not scaling down**
   - Verify Pod Disruption Budgets are applied
   - Check for pods without PDBs blocking node drain

4. **Node Auto Provisioning not triggered**
   - Ensure resource requests exceed current capacity
   - Verify NAP limits are configured correctly

### Debug Commands

```bash
# Check autoscaler events
kubectl get events --sort-by='.lastTimestamp'

# Verify system pod PDBs
kubectl get pdb -n kube-system

# Check node capacity and allocation
kubectl describe nodes | grep -A5 "Allocated resources"

# Monitor cluster autoscaler logs
kubectl logs -n kube-system -l app=cluster-autoscaler
```

## 🧹 Cleanup

```bash
# Run cleanup script
./scripts/cleanup.sh

# Or manually delete cluster
gcloud container clusters delete scaling-demo --zone=$ZONE
```

## 📚 Additional Resources

- [GKE Autoscaling Documentation](https://cloud.google.com/kubernetes-engine/docs/concepts/horizontalpodautoscaler)
- [Vertical Pod Autoscaling](https://cloud.google.com/kubernetes-engine/docs/concepts/verticalpodautoscaler)
- [Cluster Autoscaler](https://cloud.google.com/kubernetes-engine/docs/concepts/cluster-autoscaler)
- [Node Auto Provisioning](https://cloud.google.com/kubernetes-engine/docs/how-to/node-auto-provisioning)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
