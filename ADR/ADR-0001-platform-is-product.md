# ADR-0001: The Platform is the Product

## Status

Accepted

## Context

Enterprise Platform is not a project with an end date. It is a product with its own life, versions, and backlog. IUMBIT is the first consumer, not the purpose.

Every component must be reusable. The platform exists to enable development teams to build, deploy, and operate enterprise applications with confidence, consistency, and speed.

## Decision

The platform is the product. It will evolve through versions, backlog, documentation, ADRs, and continuous improvement processes. Applications are internal clients of the platform and will receive stable, well-documented capabilities.

## Consequences

- The platform has its own release cycle (v0.1 → v1.0)
- Every component must be designed for reuse across multiple applications
- The platform team maintains the platform as a product team
- IUMBIT is a consumer, not the owner of platform decisions
- Technology choices are implementation details, not architectural decisions
