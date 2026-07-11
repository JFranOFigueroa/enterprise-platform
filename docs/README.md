# Enterprise Platform - Documentation

> All project knowledge lives here. If the team disappears, the platform must be maintainable by reading this documentation.

## Structure

```
docs/
├── context.md                          # Project context and current status
├── code-reference.md                   # Technical reference for all code
├── environments-architecture.md        # Environment management rules
├── architecture/                       # Design documents (Phase 1)
│   ├── platform-architecture.md        # Vision and 7 principles
│   ├── capability-model.md             # 5 layers, 13 capabilities
│   ├── platform-topology.md            # Cluster and namespace design
│   ├── platform-constitution.md        # 15 governing principles
│   ├── repo-structure.md               # Repository organization rationale
│   ├── sprint1-foundation.md           # Sprint 1 scope and deliverables
│   ├── ep-002-k8s-distribution.md      # RKE2 selection criteria
│   ├── debian-vs-ubuntu.md             # OS comparison
│   ├── feedback.md                     # Project feedback
│   ├── final-blueprint.md              # 10 architectural views
│   └── bonus.md                        # Additional insights
├── runbooks/                           # Operational guides
│   ├── day2-operations.md              # Common operations
│   ├── troubleshooting.md              # Problem diagnosis
│   ├── backup-restore.md               # Backup procedures
│   ├── scaling.md                      # Horizontal/vertical scaling
│   └── monitoring.md                   # Monitoring and alerts
└── archive/                            # Historical documents
    └── OLD_Architecture/               # Legacy Docker Compose setup
```

## Key Documents

### For New Team Members
1. Start with [Context](context.md) to understand the project
2. Read [Platform Constitution](architecture/platform-constitution.md) for governing principles
3. Review [Platform Architecture](architecture/platform-architecture.md) for the vision

### For Platform Engineers
1. [Code Reference](code-reference.md) - Complete technical reference
2. [Runbooks](runbooks/) - Step-by-step operational procedures
3. [Architecture](architecture/) - Design decisions and rationale

### For Application Developers
1. [Environments Architecture](environments-architecture.md) - How to create new environments
2. [Golden Path](../tools/templates/golden-path-app.md) - How to deploy applications

## Architecture Decision Records

See [ADR/](../ADR/) for all architectural decisions.

## Conventions

- Documentation is versioned with the code
- All decisions must be documented before implementation
- Runbooks follow the format: Purpose → Prerequisites → Steps → Verification → Rollback
