# ADR-0004: Cloud Agnostic

## Decision

The platform must run locally, on-premise, or in the cloud. Applications never know where they are running.

## Context

Development local = Production (same architecture, different size).

## Consequences

- Terraform for infrastructure provisioning
- Ansible for configuration
- Same Kubernetes distribution everywhere
