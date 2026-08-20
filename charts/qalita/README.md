# QALITA Platform Helm Chart

<div style="text-align:center;">
<img width="250px" height="auto" src="https://app.platform.qalita.io/logo.svg" style="max-width:250px;"/>
</div>

This chart deploys QALITA Platform on a Kubernetes cluster using the Helm package manager.

# Quick Start

## Upgrading to 3.0.0 — the path to PostgreSQL 18

**This is a major version: the chart's public API changes.** Nothing is removed
yet — the bitnami `postgresql` subchart still runs your database exactly as
before, and a `helm upgrade` with your existing values is a no-op for the
database. What 3.0.0 adds is the machinery for a safe 15 → 18 migration:
**side by side, cutover by one boolean, rollback by the same boolean.**

There is deliberately no scheduled logical-backup machinery in this chart:
database protection is expected at the **volume level** (e.g. nightly Longhorn
backups of the PostgreSQL PVC, with an exercised restore path). Take a volume
snapshot/backup right before each migration step below.

### Step 1 — start the 18 server, side by side

```yaml
postgres18:
  enabled: true        # new StatefulSet qalita-postgres18, own volume/secret
  serveApp: false      # the app still points at bitnami — nothing moved yet
```

The new server starts **empty**, with its own generated password (preserved
across upgrades). It never touches anything the bitnami subchart owns.

### Step 2 — one-shot dump/restore (never `pg_upgrade`)

The dump client must be ≥ the newest server's major, so run `pg_dump` **from
the postgres18 pod** — pg_dump happily dumps the older 15.4 server:

```bash
kubectl exec qalita-postgres18-0 -- sh -c \
  'PGPASSWORD=<bitnami pwd> pg_dump -h <release>-postgresql -U qalita -d qalitadb \
     --no-owner --no-acl | psql -U qalita -d qalitadb'
```

Then compare table counts on both servers before moving on.

### Step 3 — cut over (and how to roll back)

```yaml
postgres18:
  serveApp: true       # backend now targets qalita-postgres18
```

Rollback at any point is the same boolean, set back to `false`: the old server
was never modified. Scale the bitnami StatefulSet to 0 but **keep its volume
intact for several nominal days** before setting `postgresql.enabled: false`.

**Never migrate with `pg_upgrade` and never remount the old volume on the new
server**: PostgreSQL 18 moved its data directory, and a volume mounted at the
pre-18 path makes the server silently write into an anonymous volume — empty
database on next restart.

## Upgrading to 2.19.0 — SeaweedFS 4.41

The bundled SeaweedFS chart moves from 4.0.380 (app 3.80) to 4.41.0 (app 4.41).
Two values change, and **both must land together** — the chart bump alone
renders an image that does not exist, and the values alone cannot reach 4.41
because the old chart hard-codes its tag.

**`seaweedfs.global.repository` is removed.** If you set it, delete it. The key
never had any effect under the old chart, but SeaweedFS 4.41.0 revives it
through a compatibility shim and it then doubles the image path
(`ghcr.io/you/seaweedfs/seaweedfs:4.41`) with no rendering error. A value that
used to be ignored now breaks your pull.

**`seaweedfs.fullnameOverride` now defaults to `seaweedfs`.** SeaweedFS 4.41.0
renames every object it creates to `<release>-seaweedfs-*`. Left to that
default, an existing installation would orphan its `data-filer-*` and
`data1-*` PersistentVolumeClaims — the data survives, but the S3 endpoint
serves an empty store — and the upgrade would fail outright, since a
StatefulSet's `spec.selector` is immutable. The override keeps the names you
already have. **If you deliberately want the new naming**, set it to `""` and
plan a data migration; do not do it in place.

Requires **Helm >= 3.17.0** (the SeaweedFS chart uses `fromToml`). An older
Helm fails with `function "fromToml" not defined`, which reads like a chart
bug but is a tooling floor.

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
- QALITA Doc
- QALITA Postgresql Database
- QALITA Seaweedfs S3 Storage

With `cluster.domain`=**example.com**  Creates the following endpoints:

- <https://example.com>
- <https://api.example.com>
- <https://doc.example.com>

# Upgrading

## To chart 3.0.4 — required to run analysis packs

The worker image default moves to `cli` **2.18.3**. Earlier images cannot run
packs at all:

- `uv`, which every pack's `run.sh` needs to install its dependencies, was
  missing from the image, and the fallback that bootstrapped it is refused
  inside the image's virtualenv. Every job failed with `uv: not found`.
- The image shipped only CPython 3.14, so packs that cap `requires-python`
  below it found no interpreter, and dependencies with no 3.14 wheels could not
  be installed — the runtime carries no compiler. 2.18.3 runs packs on 3.13 and
  also ships 3.11 and 3.12.

Upgrading the chart is enough unless you pin `worker.image` in your own
`values.yaml`, in which case set the tag there too:

```bash
helm repo update
helm upgrade qalita qalita/qalita -f values.yaml
```

Worker pods must be restarted to pick the new image up; the chart's rollout
does that for you.

## To chart 2.18.0 — required if you are on 2.17.0 or older

The worker image moved from the pre-rename package `qalita-cli` to `cli`:

| | Repository | Tag |
|---|---|---|
| Chart `<= 2.17.0` | `qalita-cli` | `2.13.2` |
| Chart `>= 2.18.0` | `cli` | `2.18.0` |

The `qalita-cli` package is no longer served by the client registry
(`registry.qalita.io`), so an install still on chart `2.17.0` or older will fail
to pull its worker the next time the image is not already cached on the node.
Upgrading the chart is enough — the new default points at the current package:

```bash
helm repo update
helm upgrade qalita qalita/qalita -f values.yaml
```

If you pin `worker.image` in your own `values.yaml`, update it there too. Should
you need more time, contact QALITA support: the legacy package still exists
upstream and can be restored to the client registry on request.

# Values

## Common

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| cluster.issuer | string | `letsencrypt-prod` | Cluster Issuer for Cert-Manager, you can get your cluster issuer name by running `kubectl get clusterissuer` |
| cluster.domain | string | `example.com` | DNS Domain or Sub domain for QALITA app and api endpoints |
| cluster.name | string | `local` | Cluster name for QALITA app and api endpoints, it is concatenated with cluster.domain  |
| dockerregistry.enabled | bool | `true` | Enable Private Docker Registry imagePullSecret references |
| dockerregistry.deploySecret | bool | `true` | Create the Docker registry Secret from chart values |
| dockerregistry.dataSecret | string | `{"auths":{"<registry-url>":{"password":"<password>","username":"<username>"}}}` | Docker Registry Secret, you need to configure it to pull the private registry images |

## Frontend

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| frontend.telemetryDisabled | string | `1` | Prevent NextJS framework to send telemetry data to Vercel Servers |
| frontend.webPackPolling | bool | `false` | Prevent webpack to update its compiled content, used only in dev mode |
| frontend.mode | string | `production` | The running mode of the platform, can be <DEV/PROD/DEMO> |
| frontend.image.repository | string | `ghcr.io/qalita/platform-frontend` | QALITA Frontend Image Repository |
| frontend.image.tag | string | `2.18.0` | QALITA Frontend Image Tag |
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
| backend.APItokenExpireMinutes | int | `525600` | Set the user API token expiration time, this api token is used for worker connection and partner synchronisation, it is configured in the JWT exp value. Default to 1 Year |
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
| backend.image.repository | string | `ghcr.io/qalita/platform-backend` | QALITA Backend Image Repository |
| backend.image.tag | string | `2.18.0` | QALITA Backend Image Tag |
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

## Worker

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| worker.enabled | bool | `false` | Enabling worker deployment |
| worker.privileged | bool | `false` | Enabling privilege escalation for cifs mounts |
| worker.name | string | `worker` | Qalita Worker Name |
| worker.initscript | string | `echo hello world` | Qalita Worker init script helps add custom instructions before launching worker, can be used to mount cifs remote path or other actions |
| worker.mode | string | `worker` | Qalita Worker mode <job/worker> |
| worker.token | string | `changeme` | Qalita Worker API Token |
| worker.image.repository | string | `ghcr.io/qalita/cli` | QALITA Worker image (GitHub Container Registry) |
| worker.image.tag | string | `2.18.3` | QALITA Worker Image Tag |
| worker.image.pullPolicy | string | `IfNotPresent` | QALITA Worker Image Pull Policy |
| worker.replicaCount | int | `1` | QALITA Worker Replica Count |
| worker.deployment.extraEnv | list | `[]` | QALITA Worker Deployment Environment Variables, format : `- name: QALITA_ENV value: "PROD"` |
| worker.deployment.resources.requests.memory | string | `50Mi` | QALITA Worker Memory Request |
| worker.deployment.resources.requests.cpu | string | `10m` | QALITA Worker CPU Request |
| worker.pvc.enabled | bool | `false` | Enable persistence for worker data |
| worker.pvc.storageSize | string | `10Gi` | PVC Size for persisting data |

## Documentation

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| doc.enabled | bool | `true` | Enabling doc deployment |
| doc.image.repository | string | `ghcr.io/qalita/documentation` | QALITA Doc Image Repository |
| doc.image.tag | string | `2.18.0` | QALITA Doc Image Tag |
| doc.image.pullPolicy | string | `Always` | QALITA Doc Image Pull Policy |
| doc.replicaCount | int | `1` | QALITA Doc Replica Count |
| doc.service.type | string | `ClusterIP` | QALITA Doc Service Type |
| doc.service.targetPort | int | `80` | QALITA Doc Service Port |
| doc.service.protocol | string | `TCP` | QALITA Doc Service Protocol |
| doc.ingress.enabled | bool | `true` | QALITA Doc Ingress Enabled |
| doc.ingress.tls.enabled | bool | `true` | QALITA Doc Ingress TLS Enabled |
| doc.deployment.resources.requests.cpu | string | `50m` | QALITA Doc Deployment CPU Request |
| doc.deployment.resources.requests.memory | string | `50Mi` | QALITA Doc Deployment Memory Request |

## GitHub Container Registry (GHCR)

Images default to `ghcr.io/qalita/...`. For **private** packages, either pre-create `qalita-platform-dockerregistry` in the target namespace and set `dockerregistry.deploySecret=false`, or set `licenseUrl` to `ghcr.io` and `licenseUser` / `licenseKey` to a GitHub username (or `TOKEN`) and a PAT with `read:packages` so the chart-generated secret can pull. After changing registry hosts, run a normal Helm upgrade so workloads pick up the new `imagePullSecret`. Self-hosted Actions runners that build or pull images must be able to reach `ghcr.io` and use credentials with `read:packages` when pulling private base images.

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

## Helm Sync

For more detailed configuration, please refer to [alpine/helm](https://hub.docker.com/r/alpine/helm)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| helmSync.enabled | bool | false | Enable Helm Sync |
| helmSync.image.repository | string | `alpine/helm` | Helm Sync Image Repository |
| helmSync.kubeconfig | yaml | `` | Kubeconfig yaml formatted, see default values to have a template |
| helmSync.resources.requests.cpu | string | `500m` | QALITA helmsync Deployment CPU Request |
| helmSync.resources.requests.memory | string | `256Mi` | QALITA helmsync Deployment Memory Request |
