# Image du sidecar de sauvegarde PostgreSQL (modèle jobchef/helm, lui-même
# issu de previly/helm — le script durci vit dans
# charts/qalita/templates/postgres-backup-configmap.yaml).
#
# Base postgres:18-alpine et PAS l'image aws-cli : pg_dump refuse de sauvegarder
# un serveur d'une majeure SUPÉRIEURE à la sienne, jamais l'inverse. Un client
# 18 dumpe donc aussi bien le serveur 15.4 actuel (période transitoire, phase
# 11a) que le serveur 18 cible (phase 11c) — c'est ce qui permet de livrer la
# sauvegarde AVANT la migration, comme la spec l'exige. Un client 15 aurait
# fait l'inverse : fonctionner aujourd'hui, produire des archives vides de
# 20 octets le jour de la bascule (mesuré sur previly, spec « Instruit le
# 2026-08-16 »).
#
# LE TAG :18 EST OBLIGATOIRE, PAS PRÉFÉRABLE. Avec IfNotPresent et une image
# déjà en cache sur un nœud, un rebuild du même tag :15 ne serait jamais
# repris, même en supprimant le pod — mesuré sur previly (pi1).
#
# curl est cuit dans l'image pour le ping healthchecks.io du script — le
# modèle jobchef ne l'avait pas, et son ping (garde `command -v curl`) était
# donc silencieusement inopérant.
#
# mirror.gcr.io : miroir Docker Hub de Google, anonyme, sans rate limit.
FROM mirror.gcr.io/library/postgres:18-alpine

RUN apk add --no-cache aws-cli gzip curl && \
    adduser -D -u 1000 -h /tmp -s /sbin/nologin backup

# HOME doit être inscriptible pour le cache de l'AWS CLI.
ENV HOME=/tmp

USER backup
ENTRYPOINT []
