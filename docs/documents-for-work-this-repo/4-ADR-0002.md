# ADR-0002: Cloud Native Platform

## Decision

Adopt a Cloud Native platform approach: Git → CI → Registry → GitOps → K8s → Observability → Applications.

## Context

Kubernetes is NOT the product, it is a component. The platform has 13 defined capabilities.

## Consequences

- All components must be container-native
- GitOps is the operational model
- Observability from day 1
