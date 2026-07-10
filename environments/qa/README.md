# QA Environment

## Purpose
Validation and quality assurance.

## Configuration
- 1-2 replicas per service
- HPA disabled
- Standard logging

## Access
```bash
kubectl get pods -n apps-qa
```
