{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "qalita.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "qalita.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "qalita.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "qalita.labels" -}}
app.kubernetes.io/name: {{ include "qalita.name" . }}
helm.sh/chart: {{ include "qalita.chart" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Valeur d'un champ de Secret, EN PRÉSERVANT CE QUI EXISTE DÉJÀ EN CLUSTER.

Retourne la valeur EN CLAIR. L'appelant l'écrit dans `stringData` ; il ne doit
pas la ré-encoder.

POURQUOI CE HELPER EXISTE. Le 2026-08-17, un `helm upgrade` de
qalita-platform-demo lancé avec le seul fichier de values a détruit deux
Secrets d'un coup :
  - seaweedfs-s3-secret : les quatre identifiants réécrits à VIDE, parce que
    platform/demo-values.yaml déclare `backend.s3.*: ""` — ce sont des
    emplacements que le pipeline remplit au déploiement, et le template les
    recopiait tels quels. Le backend est tombé en boucle sur
    « InvalidAccessKeyId », la passerelle S3 ne relisant sa configuration qu'au
    démarrage ;
  - qalita-qalita-secret : `secretKey` (signature JWT) et `adminPassword`
    regénérés aléatoirement, parce qu'ils étaient rendus avec
    `default (randAlphaNum N) .Values…` — un défaut qui rotait donc ces valeurs
    à CHAQUE upgrade où elles n'étaient pas fournies, invalidant toutes les
    sessions en cours.
Le champ `licenseKey` du même Secret, lui, avait déjà le bon motif (`lookup`
puis réutilisation) et a traversé l'incident intact. Ce helper généralise ce
motif au lieu de le laisser à un seul champ.

ORDRE DE RÉSOLUTION, du plus explicite au plus prudent :
  1. la valeur fournie dans les values, si elle est non vide — c'est la
     déclaration, elle prime toujours ;
  2. sinon la valeur DÉJÀ PRÉSENTE dans le Secret en cluster — un déploiement
     qui ne fournit pas un secret ne doit jamais en détruire un ;
  3. sinon `default`, s'il est renseigné — pour les champs qui ont une valeur
     de repli qui a un sens métier, comme `licenseKey` qui vaut « unlicenced »
     tant qu'aucune licence n'est posée ;
  4. sinon, si `generate` est vrai, une valeur aléatoire de `length`
     caractères — uniquement au tout premier déploiement, quand il n'y a rien
     à préserver ;
  5. sinon `fail`, avec le nom du champ. Un déploiement qui ne peut pas
     produire une valeur valide doit s'arrêter bruyamment, pas écrire du vide.

ATTENTION AU MODE `helm template`. `lookup` y renvoie toujours vide : l'étape 2
est donc inopérante, et un rendu hors cluster avec des values vides tombera en
3 ou en 4. C'est voulu — `helm template` sert à inspecter, pas à déployer — mais
cela veut dire qu'un test de non-régression sur la préservation doit passer par
`helm upgrade --dry-run`, seul mode où `lookup` interroge réellement l'API.

Arguments (dict) :
  ctx       le contexte racine ($)
  secret    nom du Secret en cluster
  key       clé dans ce Secret
  value     valeur issue des values (peut être vide ou nulle)
  default   valeur de repli explicite (facultatif)
  generate  booléen : générer une valeur aléatoire en dernier recours
  length    longueur de la valeur générée
*/}}
{{- define "qalita.preservedSecret" -}}
{{- $ctx := .ctx -}}
{{- /* `default ""` avant `toString` : sur une valeur nulle, `toString` seul
       rendrait la chaîne "<nil>", qui passerait pour une valeur fournie. */ -}}
{{- $supplied := .value | default "" | toString -}}
{{- if $supplied -}}
{{- $supplied -}}
{{- else -}}
{{- $existing := lookup "v1" "Secret" $ctx.Release.Namespace .secret -}}
{{- $prev := "" -}}
{{- if and $existing $existing.data (hasKey $existing.data .key) -}}
{{- $prev = index $existing.data .key | b64dec -}}
{{- end -}}
{{- $fallback := .default | default "" | toString -}}
{{- if $prev -}}
{{- $prev -}}
{{- else if $fallback -}}
{{- $fallback -}}
{{- else if .generate -}}
{{- randAlphaNum (.length | int) -}}
{{- else -}}
{{- fail (printf "Secret %s : le champ %s est vide et aucune valeur existante n'a ete trouvee dans le namespace %s. Fournissez-le (pipeline, Infisical, --set) plutot que de deployer avec un emplacement vide : ecrire une valeur vide ici casserait l'authentification." .secret .key $ctx.Release.Namespace) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Variables d'environnement S3 + planification du script de sauvegarde
PostgreSQL. Partagées mot pour mot entre le Deployment transitoire (qui
sauvegarde le serveur bitnami 15.4 via le Service) et le sidecar du
StatefulSet postgres18 (qui parle à localhost) : seule la connexion à la base
diffère entre les deux, et elle reste donc chez l'appelant.
*/}}
{{- define "qalita.postgresBackup.commonEnv" -}}
- name: BACKUP_SCHEDULE
  value: {{ .Values.postgresBackup.schedule | quote }}
- name: RETENTION_DAYS
  value: {{ .Values.postgresBackup.retentionDays | quote }}
- name: MIN_BACKUP_BYTES
  value: {{ .Values.postgresBackup.minBytes | quote }}
{{- /*
  Ni S3_BACKUP_PREFIX ni BACKUP_PING_URL ici : chaque consommateur pose les
  siens. Les préfixes séparent les archives des deux serveurs (cf. plus bas) ;
  les URL de ping séparent leurs ALARMES — pendant la fenêtre 18-vide, les
  /fail attendus du sidecar ne doivent pas sonner sur le check de la
  sauvegarde de production.
*/}}
- name: S3_BACKUP_ENDPOINT
  value: {{ .Values.postgresBackup.s3.endpoint | quote }}
- name: S3_BACKUP_BUCKET
  value: {{ .Values.postgresBackup.s3.bucket | quote }}
{{- /*
  PAS de S3_BACKUP_PREFIX ici, et c'est structurel : pendant la phase 11c les
  DEUX consommateurs de ce helper tournent en même temps — le Deployment
  transitoire dumpe le serveur 15, le sidecar dumpe le serveur 18 — et la base
  porte le même nom des deux côtés. Un préfixe commun aurait mélangé leurs
  archives backup_qalitadb_*.sql.gz dans le même dossier : « la dernière
  archive » pouvait être la copie 18 périmée d'avant l'incident du 15, et la
  purge de l'un rongeait la rétention de l'autre. Chaque consommateur pose son
  S3_BACKUP_PREFIX (…/pg15, …/pg18) ; la purge du script est scoper par
  préfixe, donc chacun ne purge que les siennes.
*/}}
- name: S3_BACKUP_REGION
  value: {{ .Values.postgresBackup.s3.region | quote }}
- name: S3_BACKUP_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef:
      name: qalita-postgres-backup-s3
      key: access_key_id
- name: S3_BACKUP_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: qalita-postgres-backup-s3
      key: secret_access_key
{{- end -}}

{{/*
Port PostgreSQL, robuste à la disparition du sous-chart bitnami.

`.Values.postgresql.primary.service.ports.postgresql` n'existe PAS dans les
values de ce chart : il arrive par la fusion des defaults du sous-chart. Or une
dépendance sous `condition: postgresql.enabled` disparaît TOUT ENTIÈRE quand la
condition tombe — templates ET defaults. Mesuré : à l'étape 5 de la séquence de
migration 11c (postgresql.enabled: false), le chemin fait un nil pointer et le
chart devient inrendable au moment précis où l'on retire l'ancien serveur.
La navigation parenthésée rend chaque étage optionnel ; 5432 est la valeur que
ce parc n'a jamais surchargée nulle part.
*/}}
{{- define "qalita.postgresPort" -}}
{{- ((((.Values.postgresql).primary).service).ports).postgresql | default 5432 -}}
{{- end -}}
