---
config:
  layout: elk
---
flowchart RL
 subgraph NFW_Resources["Network Firewall Infrastructure"]
        NFW_VPC["NFW Inspection VPC<br>10.70.0.0/16"]
        NFW["AWS Network Firewall<br>central-egress"]
        NFW_TGW_Attach["NFW TGW Attachment"]
        NFW_NAT["NAT Gateways<br>3 AZs"]
        NFW_Rules["Firewall Rules<br>- Allow Route53<br>- Allow STS<br>- Allow DNS"]
  end
 subgraph INFRA_Resources["ntconcepts-gov-infra Resources"]
        NFW_Resources
  end
 subgraph TGW_Routes["TGW Route Tables"]
        TGW_Inspect["Egress Inspection RT"]
        TGW_Return["Egress Return RT"]
  end
 subgraph AZ1["Availability Zone us-gov-west-1a"]
        Private1["Private Subnet<br>10.10.0.0/24"]
        Public1["Public Subnet<br>10.10.4.0/24"]
  end
 subgraph AZ2["Availability Zone us-gov-west-1b"]
        Private2["Private Subnet<br>10.10.1.0/24"]
        Public2["Public Subnet<br>10.10.5.0/24"]
  end
 subgraph AZ3["Availability Zone us-gov-west-1c"]
        Private3["Private Subnet<br>10.10.2.0/24"]
        Public3["Public Subnet<br>10.10.6.0/24"]
  end
 subgraph VPC_Network["gov-cui-dev-env-vpc Network"]
        TGW["Transit Gateway"]
        TGW_Routes
        AZ1
        AZ2
        AZ3
        VPC_Endpoints["VPC Endpoints<br>- S3<br>- DynamoDB<br>- EKS<br>- EC2<br>- SSM<br>- ECR<br>- Config<br>- ElastiCache"]
  end
 subgraph DIR_Resources["gov-cui-dev-env-directory Resources"]
        AD["AWS Microsoft AD"]
        Workspaces["AWS Workspaces"]
        DIR_VPC["VPC"]
        DIR_Private["Private Subnets"]
  end
 subgraph EKS_Clusters["EKS Clusters"]
        EKS1["Collab Cluster<br>AZ1"]
        EKS2["Collab Cluster<br>AZ2"]
        EKS3["Collab Cluster<br>AZ3"]
  end
 subgraph Applications["Applications"]
        GitLab["Gitlab"]
        Mattermost["ArgoCD"]
        ArgoCD["Mattermost"]
  end
 subgraph COLLAB_Resources["gov-cui-dev-env-collab Resources"]
        EKS_Clusters
        Applications
        COLLAB_VPC["VPC"]
        ALB["AWS Load Balancer"]
        Route53["Route53<br>cui.ntconcepts.dev"]
  end
 subgraph PROJ64_Network["Network Resources"]
        PROJ64_VPC["VPC<br>10.50.0.0/16"]
        PROJ64_TGW_Attach["TGW Attachment"]
        PROJ64_Private["Private Subnets<br>3 AZs"]
        PROJ64_DB["Database Subnets"]
        PROJ64_Cache["ElastiCache Subnets"]
        PROJ64_Endpoints["VPC Endpoints<br>S3, DynamoDB"]
  end
 subgraph Kubeflow_Platform["Kubeflow Platform"]
        Kubeflow["Kubeflow Service"]
        TensorBoard["Tensorbard"]
        MLflow["MLFlow"]
        Notebooks["Jupyter Notebooks"]
  end
 subgraph PROJ64_EKS["EKS p64-studiodx"]
        EKS_CPU["CPU Node Group<br>m5a.xlarge"]
        EKS_GPU_2xl["GPU Node Group<br>g4dn.2xlarge"]
        EKS_GPU_12xl["GPU Node Group<br>g4dn.12xlarge"]
        Kubeflow_Platform
  end
 subgraph PROJ64_Apps["Xpatch Application"]
        Xpatch_Server["Xpatch Server<br>g4dn.xlarge"]
        Xpatch_License["Xpatch License Server<br>t3.medium"]
        Xpatch_S3["S3: xpatch-storage"]
  end
 subgraph PROJ64_Resources["gov-proj64-studio-dx Resources"]
        PROJ64_Network
        PROJ64_EKS
        PROJ64_Apps
        PROJ64_Route53["Route53<br>prod.proj64.cui.ntconcepts.dev"]
        PROJ64_ECR["ECR<br>Cross-Account Pull"]
  end
    User["User/ML Engineer"] -- Connects to --> Workspaces
    Workspaces -- Provides --> Browser["Web Browser"]
    Browser -- Access Environment 1 --> COLLAB_Resources
    Browser -- Access Environment 2 --> PROJ64_Resources
    Browser -. Uses .-> GitLab & Mattermost & Kubeflow
    Kubeflow -- Provides --> TensorBoard & MLflow & Notebooks
    TensorBoard -- Monitors --> EKS_GPU_2xl
    MLflow -- Model Registry --> PROJ64_ECR
    Notebooks -- Compute --> EKS_CPU
    Notebooks -- GPU Compute --> EKS_GPU_2xl
    Notebooks -- Large GPU --> EKS_GPU_12xl
    TGW -. TGW Attachment .-> Private1 & Private2 & Private3 & DIR_VPC & COLLAB_VPC & PROJ64_TGW_Attach & NFW_TGW_Attach
    TGW_Inspect -- "0.0.0.0/0 to NFW" --> NFW_TGW_Attach
    NFW_TGW_Attach -- Inspection --> NFW_VPC
    NFW_VPC -- Traffic Analysis --> NFW
    NFW -- Allowed Traffic --> NFW_NAT
    NFW -- Apply Rules --> NFW_Rules
    TGW_Return -- "Return 10.10.0.0/16" --> DIR_VPC
    TGW_Return -- "Return 10.30.0.0/16" --> COLLAB_VPC
    TGW_Return -- "Return 10.50.0.0/16" --> PROJ64_TGW_Attach
    DIR_VPC -. Associated .-> TGW_Inspect
    COLLAB_VPC -. Associated .-> TGW_Inspect
    PROJ64_TGW_Attach -. Associated .-> TGW_Inspect
    NFW_TGW_Attach -. Associated .-> TGW_Return
    PROJ64_TGW_Attach -. Connected .-> PROJ64_VPC
    PROJ64_VPC -- Contains --> PROJ64_Private & PROJ64_DB & PROJ64_Cache
    PROJ64_Endpoints -. PrivateLink .-> PROJ64_Private
    EKS_CPU -- Nodes --> PROJ64_EKS
    EKS_GPU_2xl -- GPU Nodes --> PROJ64_EKS
    EKS_GPU_12xl -- GPU Nodes --> PROJ64_EKS
    PROJ64_EKS -- Uses --> PROJ64_ECR
    Xpatch_Server -- Uses License --> Xpatch_License
    Xpatch_Server -- Storage --> Xpatch_S3
    VPC_Endpoints -. PrivateLink .-> Private1 & Private2 & Private3
    COLLAB_VPC -. Uses .-> AD
    Workspaces -. Auth .-> AD
    EKS1 -. Pull Images .-> PROJ64_ECR
    EKS2 -. Pull Images .-> PROJ64_ECR
    EKS3 -. Pull Images .-> PROJ64_ECR
    PROJ64_EKS -. Uses .-> AD
    PROJ64_Route53 -. Zone Association .-> Route53
    Route53 -- DNS --> ALB
    ALB -- Routes to --> EKS1 & EKS2 & EKS3
    NFW_NAT -- Egress to Internet --> Internet[" "]
    Internet -- Return Traffic --> NFW_NAT
    NFW_VPC@{ icon: "aws:res-amazon-vpc-virtual-private-cloud-vpc", pos: "b"}
    NFW@{ icon: "aws:res-aws-network-firewall-endpoints", pos: "b"}
    NFW_TGW_Attach@{ icon: "aws:res-aws-transit-gateway-attachment", pos: "b"}
    NFW_NAT@{ icon: "aws:res-amazon-vpc-nat-gateway", pos: "b"}
    NFW_Rules@{ icon: "aws:res-aws-waf-filtering-rule", pos: "b"}
    TGW_Inspect@{ icon: "aws:res-amazon-route-53-route-table", pos: "b"}
    TGW_Return@{ icon: "aws:res-amazon-route-53-route-table", pos: "b"}
    Private1@{ icon: "aws:private-subnet", pos: "b"}
    Public1@{ icon: "aws:public-subnet", pos: "b"}
    Private2@{ icon: "aws:private-subnet", pos: "b"}
    Public2@{ icon: "aws:public-subnet", pos: "b"}
    Private3@{ icon: "aws:private-subnet", pos: "b"}
    Public3@{ icon: "aws:public-subnet", pos: "b"}
    TGW@{ icon: "aws:res-amazon-vpc-customer-gateway", pos: "b"}
    VPC_Endpoints@{ icon: "aws:res-amazon-vpc-endpoints", pos: "b"}
    AD@{ icon: "aws:res-aws-directory-service-aws-managed-microsoft-ad", pos: "b"}
    Workspaces@{ icon: "aws:arch-amazon-workspaces-family", pos: "b"}
    DIR_VPC@{ icon: "aws:arch-amazon-virtual-private-cloud", pos: "b"}
    DIR_Private@{ icon: "aws:private-subnet", pos: "b"}
    EKS1@{ icon: "aws:arch-amazon-elastic-kubernetes-service", pos: "b"}
    EKS2@{ icon: "aws:arch-amazon-elastic-kubernetes-service", pos: "b"}
    EKS3@{ icon: "aws:arch-amazon-elastic-kubernetes-service", pos: "b"}
    GitLab@{ icon: "aws:res-aws-iot-sitewise-data-streams", pos: "b"}
    Mattermost@{ icon: "aws:arch-aws-codedeploy", pos: "b"}
    ArgoCD@{ icon: "azure:windows-notification-services", pos: "b"}
    COLLAB_VPC@{ icon: "aws:arch-amazon-virtual-private-cloud", pos: "b"}
    ALB@{ icon: "aws:res-elastic-load-balancing-application-load-balancer", pos: "b"}
    Route53@{ icon: "aws:arch-amazon-route-53", pos: "b"}
    PROJ64_VPC@{ icon: "aws:arch-amazon-virtual-private-cloud", pos: "b"}
    PROJ64_TGW_Attach@{ icon: "aws:res-aws-transit-gateway-attachment", pos: "b"}
    PROJ64_Private@{ icon: "aws:private-subnet", pos: "b"}
    PROJ64_DB@{ icon: "aws:arch-amazon-rds", pos: "b"}
    PROJ64_Cache@{ icon: "aws:arch-amazon-elasticache", pos: "b"}
    PROJ64_Endpoints@{ icon: "aws:res-amazon-vpc-endpoints", pos: "b"}
    Kubeflow@{ icon: "aws:arch-amazon-sagemaker", pos: "b"}
    TensorBoard@{ icon: "fa:file-code", pos: "b"}
    MLflow@{ icon: "fa:file-code", pos: "b"}
    Notebooks@{ icon: "fa:file-code", pos: "b"}
    EKS_CPU@{ icon: "aws:arch-amazon-ec2", pos: "b"}
    EKS_GPU_2xl@{ icon: "aws:arch-amazon-ec2", pos: "b"}
    EKS_GPU_12xl@{ icon: "aws:arch-amazon-ec2", pos: "b"}
    Xpatch_Server@{ icon: "aws:arch-amazon-ec2", pos: "b"}
    Xpatch_License@{ icon: "aws:arch-amazon-ec2", pos: "b"}
    Xpatch_S3@{ icon: "aws:arch-amazon-simple-storage-service", pos: "b"}
    PROJ64_EKS@{ icon: "aws:arch-amazon-elastic-kubernetes-service", pos: "b"}
    PROJ64_Route53@{ icon: "aws:arch-amazon-route-53", pos: "b"}
    PROJ64_ECR@{ icon: "aws:arch-amazon-elastic-container-registry", pos: "b"}
    User@{ icon: "fa:circle-user", pos: "b"}
    Browser@{ icon: "azure:browser", pos: "b"}
    Internet@{ icon: "aws:res-internet-alt2", pos: "b"}
     NFW_VPC:::firewall
     NFW:::firewall
     NFW_TGW_Attach:::firewall
     NFW_NAT:::firewall
     NFW_Rules:::firewall
     TGW:::network
     VPC_Endpoints:::network
     Kubeflow:::kubeflowClass
     TensorBoard:::kubeflowClass
     MLflow:::kubeflowClass
     Notebooks:::kubeflowClass
     User:::userClass
     Browser:::userClass
     COLLAB_Resources:::collabAccount
     PROJ64_Resources:::proj64Account
    classDef rootAccount fill:#f9f,stroke:#333,stroke-width:4px
    classDef idAccount fill:#9cf,stroke:#333,stroke-width:2px
    classDef infraAccount fill:#fc9,stroke:#333,stroke-width:2px
    classDef vpcAccount fill:#cfc,stroke:#333,stroke-width:2px
    classDef dirAccount fill:#fcf,stroke:#333,stroke-width:2px
    classDef collabAccount fill:#cff,stroke:#333,stroke-width:2px
    classDef proj64Account fill:#ff9,stroke:#333,stroke-width:2px
    classDef network fill:#ff9,stroke:#333,stroke-width:2px
    classDef storage fill:#f99,stroke:#333,stroke-width:2px
    classDef firewall fill:#f66,stroke:#333,stroke-width:3px
    classDef userClass fill:#e6f3ff,stroke:#0073e6,stroke-width:3px
    classDef kubeflowClass fill:#fff0e6,stroke:#ff6600,stroke-width:3px






---
config:
  layout: elk
---
flowchart TD
 subgraph Legend["Legend"]
    direction LR
        NS["Kubernetes Namespace"]
        CP["Cloud Provider Service"]
        EX["External System"]
        K8S["Kubernetes Resource"]
  end
 subgraph KF["Kubeflow"]
        CentralDash["centraldashboard"]
        JupyterWeb["jupyter-web-app"]
        KatibController["katib-controller"]
        NotebookController["notebook-controller"]
        TensorboardController["tensorboard-controller"]
        KServe["kserve-controller"]
        Training["training-operator"]
  end
 subgraph Auth["Auth"]
        Keycloak["Keycloak"]
        OAuth["oauth2-proxy"]
  end
 subgraph IstioSystem["Istio System"]
        Ingress["istio-ingressgateway"]
        IstiodControl["istiod"]
        LocalGateway["cluster-local-gateway"]
  end
 subgraph ArgoCDNS["ArgoCD"]
        ArgoCD["argocd-server"]
        ArgoAppController["application-controller"]
  end
 subgraph CertManager["cert-manager"]
        CertMgrController["cert-manager"]
        CertWebhook["cert-manager-webhook"]
  end
 subgraph ExtDNS["external-dns"]
        ExternalDNS["external-dns"]
  end
 subgraph ExtSecrets["external-secrets"]
        ExternalSecrets["external-secrets"]
        SecretWebhook["external-secrets-webhook"]
  end
 subgraph InfraServices["Infrastructure Services"]
        ArgoCDNS
        CertManager
        ExtDNS
        ExtSecrets
  end
 subgraph K8sCluster["Kubernetes Cluster"]
        KF
        Auth
        IstioSystem
        InfraServices
  end
 subgraph CloudServices["Cloud Provider Services"]
        LoadBalancer["Load Balancer"]
        ObjectStorage["Object Storage"]
        FileStorage["File Storage"]
        DNSService["DNS Service"]
        SecretsMgmt["Secrets Management"]
  end
 subgraph CloudProvider["Cloud Service Provider Environment"]
        K8sCluster
        CloudServices
  end
 subgraph External["External Systems"]
        APIGateway["API Gateway"]
        TrinitySvc["Trinity Service"]
        SAPService["SAP Service"]
        VersionControl["Version Control System"]
  end
    VersionControl -- Git changes trigger deployments --> ArgoAppController
    ArgoAppController -- Deploys ML platform components --> KF
    ArgoAppController -- Deploys auth services --> Auth
    ArgoAppController -- Deploys service mesh --> IstioSystem
    ArgoAppController -- Deploys cert management --> CertManager
    ArgoAppController -- Deploys DNS controller --> ExtDNS
    ArgoAppController -- Deploys secrets management --> ExtSecrets
    Ingress -- Routes external traffic --> LoadBalancer
    LoadBalancer -- Forwards to --> APIGateway
    APIGateway -- Routes to --> TrinitySvc
    TrinitySvc -- Integrates with --> SAPService
    ExtSecrets -- Syncs cloud secrets --> SecretsMgmt
    ExtDNS -- Manages DNS records --> DNSService
    CertMgrController -- Issues SSL certificates --> DNSService
    OAuth -- Authenticates users --> Keycloak
    IstiodControl -- Controls mesh traffic --> Ingress
    KServe -- Manages ML model serving --> ObjectStorage
    NotebookController -- Provisions user workspaces --> FileStorage
    Ingress -- Routes ML platform traffic --> KF
    Ingress -- Routes auth requests --> Auth
     NS:::namespace
     CP:::cloud
     EX:::external
     K8S:::k8s
     CentralDash:::k8s
     JupyterWeb:::k8s
     KatibController:::k8s
     NotebookController:::k8s
     TensorboardController:::k8s
     KServe:::k8s
     Training:::k8s
     Keycloak:::k8s
     OAuth:::k8s
     Ingress:::k8s
     IstiodControl:::k8s
     LocalGateway:::k8s
     ArgoCD:::k8s
     ArgoAppController:::k8s
     CertMgrController:::k8s
     CertWebhook:::k8s
     ExternalDNS:::k8s
     ExternalSecrets:::k8s
     SecretWebhook:::k8s
     CertManager:::namespace
     ExtDNS:::namespace
     ExtSecrets:::namespace
     KF:::namespace
     Auth:::namespace
     IstioSystem:::namespace
     LoadBalancer:::cloud
     ObjectStorage:::cloud
     FileStorage:::cloud
     DNSService:::cloud
     SecretsMgmt:::cloud
     APIGateway:::external
     TrinitySvc:::external
     SAPService:::external
     VersionControl:::external
    classDef namespace fill:#e6f3ff,stroke:#666,stroke-width:2px
    classDef k8s fill:#fff,stroke:#666
    classDef external fill:#f9f9f9,stroke:#333,stroke-width:2px
    classDef cloud fill:#f3f3f3,stroke:#333,stroke-width:2px
    classDef provider fill:#f0f9ff,stroke:#333,stroke-width:3px


---

## Chart 3: Nightwatch RKE2 Platform (Detailed)

> This is the full Nightwatch/StudioDX architecture running on RKE2 with GPU scheduling, ArgoCD GitOps, Keycloak auth, and Kubeflow ML workloads.

```mermaid
flowchart TD
 subgraph subGraph3["Core AWS Services"]
    direction LR
        ECR["ECR Container Registry"]
        S3["S3 Buckets: terraform-state, kubeflow-rke2, pipeline-outputs, model-zoo"]
        SecretsManager["Secrets Manager: Database Passwords, API Keys"]
        IAM["IAM: OIDC Provider, Service Roles IRSA"]
  end
 subgraph subGraph4["Public Subnets"]
        NLB["Network Load Balancer"]
  end
 subgraph subGraph5["Control Plane ASG"]
        CP1["m5a.large rke2-server"]
        CP2["m5a.large rke2-server"]
        CP3["m5a.large rke2-server"]
  end
 subgraph subGraph6["CPU Nodes ASG"]
        CPU_Node1["m5a.2xlarge rke2-agent"]
  end
 subgraph subGraph7["GPU Nodes ASG"]
        GPU_Node1["g4dn.xlarge rke2-agent + NVIDIA Operator"]
  end
 subgraph subGraph9["Cluster Services"]
        ArgoCD["ArgoCD"]
        ClusterAutoscaler["Cluster Autoscaler"]
        Istio["Istio Service Mesh"]
        Keycloak["Keycloak"]
        Oauth2Proxy["oauth2-proxy"]
        KF_Core["Kubeflow Core: Dashboard, Notebooks"]
        KF_Pipelines["KF Pipelines"]
        KServe["KServe"]
        Monitoring["Prometheus, Grafana, Loki"]
        ExtSecrets["External Secrets Operator"]
  end
 subgraph subGraph12["Managed Data Services"]
        RDS["RDS PostgreSQL: ArgoCD, Keycloak, Kubeflow DBs"]
        EFS["EFS: Shared Notebook Storage"]
  end
    Developer["DevSecOps Engineer"] -- git push --> GitRepo["argoflow Git Repository"]
    User["Data Scientist"] -- HTTPS --> NLB
    NLB -- TCP --> Istio
    GitRepo -.-> ArgoCD
    ArgoCD -. syncs manifests .-> Istio & Keycloak & KF_Core & Monitoring
    Istio -- route --> Oauth2Proxy
    Oauth2Proxy -- redirect --> Keycloak
    Keycloak -- verify --> RDS
    Keycloak -- auth token --> Oauth2Proxy
    Oauth2Proxy -- forward --> KF_Core
    KF_Core -- spawns pod --> GPU_Node1
    GPU_Node1 -- mounts --> EFS
    KF_Core -- pending pod --> ClusterAutoscaler
    ClusterAutoscaler -- scale ASG --> IAM
    ExtSecrets -- read --> SecretsManager
    KF_Pipelines -- artifacts --> S3
    KF_Pipelines -- metadata --> RDS
    CPU_Node1 -- pull image --> ECR
    GPU_Node1 -- pull image --> ECR
```