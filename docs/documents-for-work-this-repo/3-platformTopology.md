# Enterprise Platform - Topology

## Cluster Design

### Development Cluster
- apps-dev
- apps-qa
- apps-staging

### Production Cluster
- apps-prod

### Platform System Namespaces
- ingress-system
- monitoring
- logging
- gitops
- cert-manager
- storage
- security

## Separation Principle

Platform services NEVER mix with business applications.
