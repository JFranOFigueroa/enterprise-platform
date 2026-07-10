# Staging Environment

## Purpose
Pre-production validation.

## Configuration
- 2 replicas per service
- Conservative HPA
- Production-like logging

## Access
```bash
kubectl get pods -n apps-staging
```
