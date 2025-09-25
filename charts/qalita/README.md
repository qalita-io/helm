# QALITA Platform Helm Chart

<div style="text-align:center;">
<img width="250px" height="auto" src="https://cloud.platform.qalita.io/logo.svg" style="max-width:250px;"/>
</div>

This chart deploys QALITA Platform on a Kubernetes cluster using the Helm package manager.

# Quick Start

## Pre-requisites

- Kubernetes `1.24+`
- Helm ``3.0+``
- Cert-Manager ``1.0+``

## Dependencies

- [seaweedfs](https://artifacthub.io/packages/helm/seaweedfs/seaweedfs)
- [postgresql](https://artifacthub.io/packages/helm/bitnami/postgresql)
- [redis](https://artifacthub.io/packages/helm/bitnami/redis)

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
- QALITA Doc
- QALITA Postgresql Database
- QALITA Redis Cache Database
- QALITA Seaweedfs S3 Storage

With `cluster.domain`=**example.com**  Creates the following endpoints:

- <https://example.com>
- <https://api.example.com>
- <https://doc.example.com>

# Values

## Common

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| cluster.issuer | string | `letsencrypt-prod` | Cluster Issuer for Cert-Manager, you can get your cluster issuer name by running `kubectl get clusterissuer` |
| cluster.domain | string | `example.com` | DNS Domain or Sub domain for QALITA app and api endpoints |
| cluster.name | string | `local` | Cluster name for QALITA app and api endpoints, it is concatenated with cluster.domain  |
| dockerregistry.enabled | bool | `true` | Enable Private Docker Registry, qalita's container images are private, you need to setup the registry in order to pull the images |
| dockerregistry.dataSecret | string | `{"auths":{"<registry-url>":{"password":"<password>","username":"<username>"}}}` | Docker Registry Secret, you need to configure it to pull the private registry images |

## Frontend

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| frontend.telemetryDisabled | string | `1` | Prevent NextJS framework to send telemetry data to Vercel Servers |
| frontend.webPackPolling | bool | `false` | Prevent webpack to update its compiled content, used only in dev mode |
| frontend.mode | string | `production` | The running mode of the platform, can be <DEV/PROD/DEMO> |
| frontend.image.repository | string | `qalita.azurecr.io/qalita/frontend` | QALITA Frontend Image Repository |
| frontend.image.tag | string | `2.3.2` | QALITA Frontend Image Tag |
| frontend.image.pullPolicy | string | `Always` | QALITA Frontend Image Pull Policy |
| frontend.replicaCount | int | `1` | QALITA Frontend Replica Count |
| frontend.service.type | string | `ClusterIP` | QALITA Frontend Service Type |
| frontend.service.targetPort | int | `3000` | QALITA Frontend Service Port |
| frontend.service.protocol | string | `TCP` | QALITA Frontend Service Protocol |
| frontend.ingress.enabled | bool | `true` | QALITA Frontend Ingress Enabled |
| frontend.ingress.tls.enabled | bool | `true` | QALITA Frontend Ingress TLS Enabled |
| frontend.deployment.resources.requests.cpu | string | `500m` | QALITA Frontend Deployment CPU Request |
| frontend.deployment.resources.requests.memory | string | `256Mi` | QALITA Frontend Deployment Memory Request |
| frontend.deployment.extraEnv | list | `[]` | QALITA Frontend Deployment Environment Variables, format : `- name: QALITA_ENV value: "PROD"` |

## Backend

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| backend.organization.name | string | `local` | Set the organization Name |
| backend.RetentionLogsHours | int | `720` | Set the log retention in hours |
| backend.AUTHTokenExpireMinutes | int | `240` | Set the user session timeout, it is configured in the JWT exp value, default to 4 hours |
| backend.APItokenExpireMinutes | int | `525600` | Set the user API token expiration time, this api token is used for agent connection and partner synchronisation, it is configured in the JWT exp value. Default to 1 Year |
| backend.mode | string | `PROD` | The running mode of the platform, can be <DEV/PROD/DEMO> |
| backend.iniSleep | int | `3` | The amount of seconds the backend waits to connect to the backend database (postgresql) before retrying |
| backend.authMode | string | `table` | Authentication mode: `table/ldap/saml` |
| backend.adminUsername | string | `admin` | The admin user name |
| backend.adminPassword | string | randAlphaNum 25 char long string | Admin Account password |
| backend.secretKey | string | randAlphaNum 512 char long string | Key seed to generate JWT Tokens |
| backend.secretKeyAlgorithm | string | `HS256` | Algorithm Type used to issue JWT |
| backend.api.port | int | `3080` | Backend API exposed Port |
| backend.api.host | string | `0.0.0.0` | Ip address Backend is exposed to |
| backend.api.worker | int | `4` | Number of process bootstrapped  |
| backend.image.repository | string | `qalita.azurecr.io/qalita/backend` | QALITA Backend Image Repository |
| backend.image.tag | string | `2.3.2` | QALITA Backend Image Tag |
| backend.image.pullPolicy | string | `Always` | QALITA Backend Image Pull Policy |
| backend.replicaCount | int | `1` | QALITA Backend Replica Count |
| backend.service.type | string | `ClusterIP` | QALITA Backend Service Type |
| backend.service.targetPort | int | `3000` | QALITA Backend Service Port |
| backend.service.protocol | string | `TCP` | QALITA Backend Service Protocol |
| backend.ingress.enabled | bool | `true` | QALITA Backend Ingress Enabled |
| backend.ingress.tls.enabled | bool | `true` | QALITA Backend Ingress TLS Enabled |
| backend.deployment.resources.requests.cpu | string | `500m` | QALITA Backend Deployment CPU Request |
| backend.deployment.resources.requests.memory | string | `256Mi` | QALITA Backend Deployment Memory Request |
| backend.deployment.extraEnv | list | `[]` | QALITA Backend Deployment Environment Variables, format : `- name: QALITA_ENV value: "PROD"` |
| backend.s3.url | string | `http://seaweedfs-s3:8333` | S3 Store Url Endpoint |
| backend.s3.secretName | string | `seaweedfs-s3-secret` | Secret containing read / write credentials for the s3 store |
| backend.s3.admin_access_key_id | string | `` | S3 Write user access key |
| backend.s3.admin_secret_access_key | string | `` | S3 Write user secret key |
| backend.s3.read_access_key_id | string | `` | S3 read user access key |
| backend.s3.read_secret_access_key | string | `` | S3 read user secret key |
| backend.mail.enabled | bool | `false` | Enable Mail Features |
| backend.mail.username | string | `` | SMTP Mail Account Username |
| backend.mail.password | string | `` | SMTP Mail Account Password |
| backend.mail.from | string | `no-reply@example.com` | Mail Address |
| backend.mail.from_name | string | `QALITA Platform` | Mail Name |
| backend.mail.port | int | `1025` | SMTP Mail Server Port |
| backend.mail.server | string | `` | SMTP Mail Server Host |
| backend.mail.starttls | bool | `false` | SMTP Mail Server STARTTLS |
| backend.mail.ssl_tls | bool | `false` | SMTP Mail Server SSL_TLS Protocol |

## Agent

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| agent.enabled | bool | `false` | Enabling agent deployment |
| agent.privileged | bool | `false` | Enabling privilege escalation for cifs mounts |
| agent.name | string | `local-agent` | Qalita Agent Name |
| agent.initscript | string | `echo hello world` | Qalita Agent init script helps add custom instructions before launching agent, can be used to mount cifs remote path or other actions |
| agent.mode | string | `worker` | Qalita Agent mode <job/worker> |
| agent.token | string | `changeme` | Qalita Agent API Token |
| agent.image.repository | string | `qalita/agent` | [QALITA Agent Image Repository](https://hub.docker.com/r/qalita/agent) |
| agent.image.tag | string | `2.3.2` | QALITA Agent Image Tag |
| agent.image.pullPolicy | string | `Always` | QALITA Agent Image Pull Policy |
| agent.replicaCount | int | `1` | QALITA Agent Replica Count |
| agent.deployment.extraEnv | list | `[]` | QALITA Agent Deployment Environment Variables, format : `- name: QALITA_ENV value: "PROD"` |
| agent.deployment.resources.requests.memory | string | `256Mi` | QALITA Agent Memory Request |
| agent.deployment.resources.requests.cpu | string | `200m` | QALITA Agent CPU Request |
| agent.pvc.enabled | bool | `false` | Enable persistence for agent data |
| agent.pvc.storageSize | string | `10Gi` | PVC Size for persisting data |

## Documentation

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| doc.enabled | bool | `true` | Enabling doc deployment |
| doc.image.repository | string | `qalita.azurecr.io/qalita/doc` | QALITA Doc Image Repository |
| doc.image.tag | string | `2.3.2` | QALITA Doc Image Tag |
| doc.image.pullPolicy | string | `Always` | QALITA Doc Image Pull Policy |
| doc.replicaCount | int | `1` | QALITA Doc Replica Count |
| doc.service.type | string | `ClusterIP` | QALITA Doc Service Type |
| doc.service.targetPort | int | `80` | QALITA Doc Service Port |
| doc.service.protocol | string | `TCP` | QALITA Doc Service Protocol |
| doc.ingress.enabled | bool | `true` | QALITA Doc Ingress Enabled |
| doc.ingress.tls.enabled | bool | `true` | QALITA Doc Ingress TLS Enabled |
| doc.deployment.resources.requests.cpu | string | `50m` | QALITA Doc Deployment CPU Request |
| doc.deployment.resources.requests.memory | string | `50Mi` | QALITA Doc Deployment Memory Request |

## Database (Postgresql)

For more detailed configuration, please refer to [Bitnami Postgresql Chart](https://artifacthub.io/packages/helm/bitnami/postgresql#parameters)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| postgresql.enabled | bool | true | Enable deploy local postgresql, disable if you use external Postgresql Database |
| postgresql.image.tag | string | `15.4.0` | Postgresql Image Tag |
| postgresql.global.potgresql.auth.database | string | `qalitadb` | Postgresql Database Name |
| postgresql.global.potgresql.auth.username | string | `qalita` | Postgresql Database Username |
| postgresql.global.potgresql.auth.password | string | randAlphaNum 25 char long string | Postgresql Database Password |
| postgresql.primary.persistence.size | string | `8Gi` | PVC Size for persisting data |

## S3 Object Storage (Seaweedfs)

For more detailed configuration, please refer to [Seaweedfs Chart](https://artifacthub.io/packages/helm/seaweedfs/seaweedfs)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| seaweedfs.enabled | bool | true | Enable deploy local s3 file storage, disable if you use external S3 storage System |
| seaweedfs.global.imageName | string | `chrislusf/seaweedfs` | Seaweedfs Image Name |
| seaweedfs.global.createClusterRole | bool | `true` | Creates Service Accounts and Role and Role Binding  for seaweedfs |

## Cache (Redis)

For more detailed configuration, please refer to [Bitnami Redis Chart](https://artifacthub.io/packages/helm/bitnami/redis)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| redis.enabled | bool | true | Enable deploy local redis, disable if you use external Redis Database |
| redis.auth.password | string | randAlphaNum 25 char long string | Redis Database Password |

## Helm Sync

For more detailed configuration, please refer to [alpine/helm](https://hub.docker.com/r/alpine/helm)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| helmSync.enabled | bool | false | Enable Helm Sync |
| helmSync.image.repository | string | `alpine/helm` | Helm Sync Image Repository |
| helmSync.kubeconfig | yaml | `` | Kubeconfig yaml formatted, see default values to have a template |
| helmSync.resources.requests.cpu | string | `500m` | QALITA helmsync Deployment CPU Request |
| helmSync.resources.requests.memory | string | `256Mi` | QALITA helmsync Deployment Memory Request |
