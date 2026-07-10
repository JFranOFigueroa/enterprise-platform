# Production Environment

## Purpose
Live traffic.

## Configuration
- 3+ replicas per service
- Aggressive HPA
- Full observability
- TLS enabled

## Access
```bash
kubectl get pods -n apps-prod
```
