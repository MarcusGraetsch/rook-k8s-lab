# RBAC Design — IDP Platform

## Überblick

Role-Based Access Control (RBAC) bestimmt wer im Kubernetes Cluster was darf. Hier wird das Design für die IDP Platform beschrieben.

## Hierarchie

```
Kubernetes RBAC Hierarchie
│
├── Cluster Ebene
│   ├── ClusterRole (statisch, von Platform Admin verwaltet)
│   └── ClusterRoleBinding (bindet ClusterRole an User/Group)
│
└── Namespace Ebene
    ├── Role (statisch)
    └── RoleBinding (bindet Role an User/Group)
```

## Rollen-Definitionen

### 1. PlatformAdmin (ClusterRole)

Vollzugriff auf Plattform-Management. Nur für internes Platform Team.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: platform-admin
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
  - nonResourceURLs: ["*"]
    verbs: ["*"]
```

### 2. AppDeveloper (Role)

Für Entwicklerteams die in einem Namespace deployen dürfen.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-developer
  namespace: <team-namespace>
rules:
  # Deployments, Services, ConfigMaps
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["services", "configmaps", "secrets"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  # Logs lesen
  - apiGroups: [""]
    resources: ["pods/log"]
    verbs: ["get", "list"]
  # Status lesen
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
```

### 3. Customer (Role)

Für externe Kunden — minimaler Zugriff.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: customer-app-operator
  namespace: <customer-namespace>
rules:
  # Nur eigene Deployments
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  # Services für eigene Apps
  - apiGroups: [""]
    resources: ["services"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  # Logs lesen (für eigene Pods)
  - apiGroups: [""]
    resources: ["pods/log"]
    verbs: ["get", "list"]
  # Status lesen
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
  # KEIN exec, KEIN secret lesen, KEIN Zugriff auf andere NS
```

## Fiktive Team-Zuordnungen

### Berlinwasser GmbH

| Person | Rolle | ClusterRoleBinding / RoleBinding |
|--------|-------|----------------------------------|
| maria.platform@berlinwasser.de | PlatformAdmin | ClusterRoleBinding → platform-admin |
| dev.wasserbilanz@berlinwasser.de | AppDeveloper | RoleBinding in namespace: wasserbilanz → app-developer |
| dev.abwasser@berlinwasser.de | AppDeveloper | RoleBinding in namespace: abwasser → app-developer |

### AgrarPower (externer Kunde)

| Person | Rolle | ClusterRoleBinding / RoleBinding |
|--------|-------|----------------------------------|
| kunde.agripower@agripower.de | Customer | RoleBinding in namespace: agripower → customer-app-operator |

### Stadtwerke Hamburg (externer Kunde)

| Person | Rolle | ClusterRoleBinding / RoleBinding |
|--------|-------|----------------------------------|
| kunde.stadtwerke@stadtwerke-hh.de | Customer | RoleBinding in namespace: stadtwerke-hh → customer-app-operator |

## Verbote (durch OPA Gatekeeper ergänzend)

Was explizit NICHT erlaubt ist:

```yaml
# Diese Aktionen sind verboten und werden von OPA blockiert

# 1. KEIN exec in Container (RCE verhindern)
# Catch: RoleBinding mit pods/exec explizit verbieten

# 2. KEIN secret lesen (Credentials schützen)
# Catch: Role verbietet "secrets" resource

# 3. KEIN kubectl proxy
# Catch: OPA Policy verbietet port-forward

# 4. KEINE privileged Container
# Catch: OPA Policy prüft securityContext

# 5. KEINE Root-Container
# Catch: OPA Policy prüft runAsNonRoot
```

## Flux Integration

Flux kann GitHub Teams direkt auf RBAC mappen:

```yaml
# flux-team-sync.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: flux-team-sync
  namespace: flux-system
data:
  # Team "platform-admins" in GitHub org → ClusterRoleBinding
  platform-admins: |
    group: github:Berlinwasser/platform-admins
    role: ClusterRole/platform-admin

  # Team "dev-wasserbilanz" → RoleBinding in NS wasserbilanz
  dev-wasserbilanz: |
    group: github:Berlinwasser/dev-wasserbilanz
    role: Role/app-developer
    namespace: wasserbilanz
```

## RBAC in Practice — Was sieht wer?

### PlatformAdmin (maria)
```
kubectl get all -A           ✅ (alle Namespaces)
kubectl create ns test       ✅
kubectl auth can-i create ns ✅
kubectl exec -it pod/xxx     ✅
```

### AppDeveloper (dev.wasserbilanz)
```
kubectl get all -n wasserbilanz    ✅
kubectl get all -n abwasser       ❌ (Permission denied)
kubectl exec -it pod/xxx -n wasserbilanz  ❌ (nicht in Role)
kubectl get secrets -n wasserbilanz       ❌ (nicht in Role)
```

### Customer (kunde.agripower)
```
kubectl get all -n agripower         ✅ (nur eigene NS)
kubectl exec -it pod/xxx -n agripower ❌
kubectl get all -n wasserbilanz      ❌
kubectl get secrets                  ❌
```

## GitOps RBAC Workflow

```
GitHub Team definiert
    │
    ▼
Flux erkennt Team-Mitglieder (via GitHub API)
    │
    ▼
Flux erstellt/updated RoleBinding im Cluster
    │
    ▼
User bekommt Zugriff via Keycloak OIDC Token
    │
    ▼
Token enthält Gruppen → kubectl nutzt OIDC Auth
```

## Nächste Schritte

1. [ ] Namespaces für Teams erstellen (wasserbilanz, abwasser, agripower, stadtwerke-hh)
2. [ ] RoleDefinitions als YAML in Git speichern
3. [ ] RoleBindings via Flux managed
4. [ ] OPA Gatekeeper Policies für zusätzliche Restriktionen
5. [ ] Keycloak OIDC konfigurieren (GitHub OAuth als IdP)
6. [ ] Test: Developer kann nur eigene NS sehen

---

*Erstellt: 2026-04-21*
