# Documentation Index

This directory contains the complete technical documentation for the Option C — RWA Tokenization Platform.

---

## Architecture

Design, storage layout, gas optimization, and deployment reference.

| Document | Description |
|---|---|
| [architecture.md](./architecture/architecture.md) | System overview, component responsibilities, user-flow diagrams, storage layout, trust assumptions, and ADR log |
| [gas-optimization.md](./architecture/gas-optimization.md) | Compiler settings, immutable usage, calldata, custom errors, storage considerations, AMM and vault efficiency |
| [deployment-verification.md](./architecture/deployment-verification.md) | Prerequisites, environment variables, deployment order, post-deploy verification, frontend startup, subgraph deployment, troubleshooting |

→ [Architecture README](./architecture/README.md)

---

## Audit

Security audit report, static analysis results, test coverage, and case studies.

| Document | Description |
|---|---|
| [audit-report.md](./audit/audit-report.md) | Internal security audit: findings table, reentrancy analysis, access control analysis, governance and oracle attack analysis |
| [slither-findings.md](./audit/slither-findings.md) | Static analysis results: 66 contracts analyzed, zero High or Medium findings |
| [testing-coverage.md](./audit/testing-coverage.md) | Test suite structure, fuzz tests, invariants, security case studies, CI integration, coverage metrics |
| [access-control-case-study.md](./audit/access-control-case-study.md) | Vulnerable vs. hardened access control pattern comparison |
| [reentrancy-case-study.md](./audit/reentrancy-case-study.md) | Vulnerable vs. hardened vault comparison, CEI pattern analysis |

→ [Audit README](./audit/README.md)

---

## Project

| Document | Description |
|---|---|
| [contributions.md](./project/contributions.md) | Team contribution breakdown by area: contracts, governance, frontend, deployment, testing, security, documentation, subgraph, CI/CD |

---

## Deliverable Matrix

| Document | Description |
|---|---|
| [DELIVERABLE_MATRIX.md](./DELIVERABLE_MATRIX.md) | Requirements-to-evidence mapping; identifies completed deliverables and items pending external deployment |
