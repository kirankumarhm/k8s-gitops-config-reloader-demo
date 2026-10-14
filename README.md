# Kubernetes GitOps & Stakater Reloader Polyglot Demo

A complete, production-grade cloud-native reference project demonstrating **zero-code, language-agnostic configuration management** across polyglot microservices (**Spring Boot / Java 21**, **Go 1.23**, **Node.js 22**, and **Python 3.12 FastAPI**) using **Kubernetes ConfigMaps/Secrets**, **Stakater Reloader**, and **ArgoCD GitOps**.

---

## 1. Why this Architecture? (Comparison with Spring Cloud Bus)

| Dimension | Spring Cloud Config + Bus Architecture | Cloud-Native GitOps + Reloader Architecture |
| :--- | :--- | :--- |
| **Non-Java Services (Go, Node, Python)** | **High Code Burden**: Must write custom AMQP clients, exchange bindings, queue listeners, and Jackson/JSON parsers. | **Zero Code**: Standard `os.Getenv`, `process.env`, or local JSON/YAML reading. |
| **Java / Spring Boot** | Requires `spring-cloud-starter-config` and `spring-cloud-starter-bus-amqp`. | Standard `@ConfigurationProperties` or `@Value` injected via Kubernetes. |
| **Infrastructure Overhead** | Dedicated Config Server cluster + RabbitMQ/Kafka broker instances. | Native Kubernetes primitives (ConfigMaps & Secrets) + lightweight Reloader controller. |
| **Dynamic Updates** | Event broadcast over message bus triggers `@RefreshScope` rebinds in memory. | ConfigMap change triggers an automated, zero-downtime Kubernetes `RollingUpdate`. |
| **State Drift & Self-Healing** | Requires custom sync checks. | **ArgoCD** continuously reconciles Git state with the live cluster. |

---

## 2. Architecture Diagram

```mermaid
graph TD
    Git[Git Repository] -->|1. Commit / Push ConfigMap change| Argo[ArgoCD Controller]
    Argo -->|2. Automated Reconciliation| K8sCM[Kubernetes ConfigMap / Secret]
    
    subgraph Kubernetes Cluster
        K8sCM -->|3. Watch change event| Reloader[Stakater Reloader Controller]
        
        Reloader -->|4. Trigger RollingUpdate| DeploySB[Deployment: Spring Boot]
        Reloader -->|4. Trigger RollingUpdate| DeployGo[Deployment: Go Service]
        Reloader -->|4. Trigger RollingUpdate| DeployNode[Deployment: Node.js Service]
        Reloader -->|4. Trigger RollingUpdate| DeployPy[Deployment: Python Service]
        
        DeploySB --> PodSB[Pod: Spring Boot (Java 21)]
        DeployGo --> PodGo[Pod: Go Service (1.23)]
        DeployNode --> PodNode[Pod: Node.js (22)]
        DeployPy --> PodPy[Pod: Python (3.12)]
    end
    
    style Reloader fill:#f9f,stroke:#333,stroke-width:2px
    style K8sCM fill:#bbf,stroke:#333,stroke-width:2px
```

---

## 3. Project Structure

```
k8s-gitops-config-reloader-demo/
├── services/
│   ├── springboot-service/         # Java 21 (0 lines of Config Server / RabbitMQ code)
│   ├── go-service/                 # Go 1.23 (0 lines of AMQP or custom client code)
│   ├── node-service/               # Node.js 22 Express (Pure JSON / env reading)
│   └── python-service/             # Python 3.12 FastAPI (Standard env reading)
├── k8s/
│   ├── base/
│   │   ├── namespace.yaml          # gitops-demo namespace
│   │   ├── configmaps.yaml         # ConfigMaps for all 4 services
│   │   ├── secrets.yaml            # Secret for API tokens
│   │   ├── springboot-service.yaml # Workload with reloader.stakater.com/auto: "true"
│   │   ├── go-service.yaml
│   │   ├── node-service.yaml
│   │   ├── python-service.yaml
│   │   └── kustomization.yaml
│   └── overlays/
│       └── minikube/
│           └── kustomization.yaml
├── gitops/
│   ├── app-project.yaml            # ArgoCD project definition
│   └── application.yaml            # ArgoCD sync pipeline
└── scripts/
    ├── setup-minikube.sh           # Installs Stakater Reloader & ArgoCD into Minikube
    ├── deploy.sh                   # Builds images, loads into Minikube, deploys workloads
    ├── test-gitops-reload.sh       # Automated verification test showing live reload
    └── teardown.sh                 # Cleans up workloads & infrastructure
```

---

## 4. Quickstart Guide (Local Minikube)

### Step 1: Install Reloader & ArgoCD into Minikube
```bash
./scripts/setup-minikube.sh
```

### Step 2: Build & Deploy Polyglot Services
```bash
./scripts/deploy.sh
```

### Step 3: Run the Automated Live Reload Acceptance Test
```bash
./scripts/test-gitops-reload.sh
```
This script:
1. Probes initial config values across all 4 services.
2. Updates the ConfigMaps in the cluster (simulating a Git commit / GitOps sync).
3. Verifies that **Stakater Reloader** triggers a rolling update.
4. Verifies that the new configuration is actively served by all 4 polyglot services with **zero downtime**.

---

## 5. Clean Teardown
```bash
# Tear down demo workloads only:
./scripts/teardown.sh

# Tear down everything including ArgoCD & Reloader:
./scripts/teardown.sh --all
```
