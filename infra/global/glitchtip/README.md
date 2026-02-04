# GlitchTip - Self-hosted Error Tracking

Open-source Sentry alternative deployed in `infrastructure` namespace.

**URL**: https://glitchtip.infra.makekod.ru

## Prerequisites

Ensure you're using the correct kubeconfig:
```bash
export KUBECONFIG=~/.kube/nirssyan-infra.kubeconfig
```

## Deployment

### 1. Create secrets

```bash
# Generate passwords
POSTGRES_PASSWORD=$(openssl rand -base64 32)
SECRET_KEY=$(openssl rand -base64 50)

# Create PostgreSQL secret
kubectl create secret generic glitchtip-postgres -n infrastructure \
  --from-literal=password="$POSTGRES_PASSWORD"

# Create GlitchTip secrets
kubectl create secret generic glitchtip-secrets -n infrastructure \
  --from-literal=secret-key="$SECRET_KEY" \
  --from-literal=database-url="postgres://glitchtip:${POSTGRES_PASSWORD}@glitchtip-postgres:5432/glitchtip"

# Verify
kubectl get secrets -n infrastructure | grep glitchtip
```

### 2. Apply manifests

```bash
cd /path/to/infra-startup/global/glitchtip

# Apply in order
kubectl apply -f 01-postgres-pvc.yml
kubectl apply -f 02-postgres.yml
kubectl apply -f 03-redis.yml
kubectl apply -f 04-glitchtip-pvc.yml
kubectl apply -f 05-web.yml
kubectl apply -f 06-worker.yml
kubectl apply -f 07-ingress.yml
```

Or apply all at once:
```bash
kubectl apply -f .
```

### 3. Wait for pods

```bash
kubectl get pods -n infrastructure -l app=glitchtip-postgres -w
kubectl get pods -n infrastructure -l app=glitchtip-web -w
```

### 4. Create superuser

```bash
kubectl exec -it -n infrastructure deployment/glitchtip-web -- ./manage.py createsuperuser
```

## Connecting Services

### Get DSN

1. Open https://glitchtip.infra.makekod.ru
2. Login with superuser
3. Create Organization → Create Project
4. Copy DSN from project settings

DSN format: `https://<key>@glitchtip.infra.makekod.ru/<project_id>`

### Update makefeed-api to use GlitchTip

1. Get the new DSN from GlitchTip UI

2. Create sealed secret value:
```bash
cd /path/to/infra-startup

printf 'https://your-key@glitchtip.infra.makekod.ru/1' > /tmp/dsn.txt
kubeseal --raw --from-file=/tmp/dsn.txt \
  --namespace infatium-dev \
  --name service-secrets \
  --cert projects/infatium/sealed-secrets-pub.pem
rm /tmp/dsn.txt
```

3. Update `projects/infatium/overlays/dev/service-secrets-sealed.yml`:
   - Replace `SENTRY_DSN` value with new sealed value

4. Apply and restart:
```bash
kubectl apply -f projects/infatium/overlays/dev/service-secrets-sealed.yml
kubectl rollout restart deployment/makefeed-api -n infatium-dev
```

## Python SDK Configuration

GlitchTip is 100% compatible with Sentry SDK. No code changes needed.

```python
import sentry_sdk

sentry_sdk.init(
    dsn="https://key@glitchtip.infra.makekod.ru/1",
    environment="production",
    traces_sample_rate=0.1,  # For performance monitoring
)
```

## Maintenance

### View logs
```bash
kubectl logs -n infrastructure deployment/glitchtip-web --tail=100
kubectl logs -n infrastructure deployment/glitchtip-worker --tail=100
```

### Database migrations
Migrations run automatically on pod startup.

### Cleanup old events
Celery beat runs cleanup tasks automatically based on `GLITCHTIP_MAX_EVENT_LIFE_DAYS` (default: 90).

## Resources

- Web UI: https://glitchtip.infra.makekod.ru
- Docs: https://glitchtip.com/documentation
- GitHub: https://gitlab.com/glitchtip/glitchtip
