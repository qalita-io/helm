# CLAUDE.md — Qalita Helm

Ce fichier fournit des instructions à Claude Code et Roo Code pour travailler sur ce dépôt.

## Projet

**Qalita Helm** — Charts Helm pour déployer la plateforme Qalita sur Kubernetes.

- **Organisation GitHub** : `qalita-io`
- **Cluster K8s** : `raspberry-pi-cluster`
- **Namespaces** : `qalita-platform-prod`, `qalita-platform-dev`, `qalita-platform-demo`

## Architecture

```
helm/
├── charts/
│   └── qalita/        # Chart principal de la plateforme
│       ├── templates/  # Templates Helm
│       ├── Chart.yaml  # Définition et dépendances
│       └── values.yaml # Valeurs par défaut
├── cr.yaml            # Chart Releaser config
├── ct.yaml            # Chart Testing config
└── .github/workflows/
```

## Commandes

```bash
# Mise à jour des dépendances
cd charts/qalita && helm dependency update

# Deploy dev
helm upgrade --install qalita charts/qalita --namespace qalita-platform-dev -f <values-file>

# Deploy prod
helm upgrade --install qalita charts/qalita --namespace qalita-platform-prod -f <values-file> --atomic --timeout 10m
```

## Conventions

- **Values** : Ne jamais mettre de secrets dans les fichiers values — utiliser des Secrets K8s
- **Tags d'images** : Semver strict `X.Y.Z` (⚠️ PAS de préfixe `v`)
- **Commits** : Messages en anglais, conventionnels (`chore:`, `fix:`)

## Règles de sécurité

- ❌ Ne JAMAIS commiter de secrets, passwords, kubeconfig ou credentials
- ❌ Ne pas modifier les values de production sans demande explicite
- ✅ Toujours tester avec `helm template` avant de déployer
