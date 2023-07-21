# QALITA Helm Chart

This chart deploys QALITA on a Kubernetes cluster using the Helm package manager.

# Quick Start

## Pre-requisites

- Kubernetes `1.24+`
- Helm ``3.0+``
- Cert-Manager ``1.0+``

## Dependencies

- [seaweedfs](https://artifacthub.io/packages/helm/seaweedfs/seaweedfs)
- [postgresql](https://artifacthub.io/packages/helm/bitnami/postgresql)

## 1. Adding the chart Repository

```bash
helm repo add qalita https://helm.qalita.io/
helm repo update
```

## 2. Resolve dependencies

```bash
helm dependency update
```

## 3. Install

```bash
helm install qalita qalita/qalita -f values.yaml
```

## 4. Use it

The chart will deploy the following resources:

- QALITA App
- QALITA API
- QALITA Postgresql Database
- QALITA Seaweedfs File Storage

With `cluster.domain`=**example.com**  Creates the following endpoints:

- https://example.com
- https://api.example.com


# Values

## Common

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| cluster.issuer | string | `letsencrypt-prod` | Cluster Issuer for Cert-Manager, you can get your cluster issuer name by running `kubectl get clusterissuer` |
| cluster.domain | string | `example.com` | DNS Domain or Sub domain for QALITA app and api endpoints |
| cluster.name | string | ```''``` | Cluster name for QALITA app and api endpoints, it is concatenated with cluster.domain  |
| dockerregistry.enabled | bool | `true` | Enable Private Docker Registry, qalita's container images are private, you need to setup the registry in order to pull the images |
| dockerregistry.dataSecret | string | `{"auths":{"<registry-url>":{"password":"<password>","username":"<username>"}}}` | Docker Registry Secret, you need to configure it to pull the private registry images |

## Frontend

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| frontend.image.repository | string | `qalita.azurecr.io/qalita/frontend` | QALITA Frontend Image Repository |
| frontend.image.tag | string | `1.0.0` | QALITA Frontend Image Tag |
| frontend.image.pullPolicy | string | `Always` | QALITA Frontend Image Pull Policy |
| frontend.replicaCount | int | `1` | QALITA Frontend Replica Count |
| frontend.service.type | string | `ClusterIP` | QALITA Frontend Service Type |
| frontend.service.targetPort | int | `3000` | QALITA Frontend Service Port |
| frontend.service.protocol | string | `TCP` | QALITA Frontend Service Protocol |
| frontend.ingress.enabled | bool | `true` | QALITA Frontend Ingress Enabled |
| frontend.ingress.tls.enabled | bool | `true` | QALITA Frontend Ingress TLS Enabled |
| frontend.deployment.resources.requests.cpu | string | `500m` | QALITA Frontend Deployment CPU Request |
| frontend.deployment.resources.requests.memory | string | `256Mi` | QALITA Frontend Deployment Memory Request |
| frontend.deployment.env | list | `[]` | QALITA Frontend Deployment Environment Variables, format : `- name: QALITA_ENV value: "PROD"` |

## Backend

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| backend.adminPassword | string | randAlphaNum 25 char long string | Admin Account password |
| backend.secretKey | string | randAlphaNum 512 char long string | Key seed to generate JWT Tokens |
| backend.image.repository | string | `qalita.azurecr.io/qalita/backend` | QALITA Backend Image Repository |
| backend.image.tag | string | `1.0.0` | QALITA Backend Image Tag |
| backend.image.pullPolicy | string | `Always` | QALITA Backend Image Pull Policy |
| backend.replicaCount | int | `1` | QALITA Backend Replica Count |
| backend.service.type | string | `ClusterIP` | QALITA Backend Service Type |
| backend.service.targetPort | int | `3000` | QALITA Backend Service Port |
| backend.service.protocol | string | `TCP` | QALITA Backend Service Protocol |
| backend.ingress.enabled | bool | `true` | QALITA Backend Ingress Enabled |
| backend.ingress.tls.enabled | bool | `true` | QALITA Backend Ingress TLS Enabled |
| backend.deployment.resources.requests.cpu | string | `500m` | QALITA Backend Deployment CPU Request |
| backend.deployment.resources.requests.memory | string | `256Mi` | QALITA Backend Deployment Memory Request |
| backend.deployment.env | list | `[]` | QALITA Backend Deployment Environment Variables, format : `- name: QALITA_ENV value: "PROD"` |

## Database (Postgresql)

For more detailed configuration, please refer to [Bitnami Postgresql Chart](https://artifacthub.io/packages/helm/bitnami/postgresql#parameters)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| postgresql.enabled | bool | true | Enable deploy local postgresql, disable if you use external Postgresql Database |
| postgresql.image.tag | string | `15.3.0` | Postgresql Image Tag |
| postgresql.global.potgresql.auth.database | string | `qalitadb` | Postgresql Database Name |
| postgresql.global.potgresql.auth.username | string | `qalita` | Postgresql Database Username |
| postgresql.global.potgresql.auth.password | string | randAlphaNum 25 char long string | Postgresql Database Password |

## File Storage (Seaweedfs)

For more detailed configuration, please refer to [Seaweedfs Chart](https://artifacthub.io/packages/helm/seaweedfs/seaweedfs)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| seaweedfs.enabled | bool | true | Enable deploy local s3 file storage, disable if you use external S3 storage System |
| seaweedfs.global.imageName | string | `chrislusf/seaweedfs` | Seaweedfs Image Name |
