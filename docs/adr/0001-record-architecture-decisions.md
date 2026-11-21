# ADR-0001: Record architecture decisions
**Status:** Accepted · **Date:** 2026-11-21

## Context
The product spans four codebases and has security and regulatory constraints. The reasons behind decisions have to be easy to find later, by auditors as well as engineers.

## Decision
We use lightweight ADRs in `docs/adr/`, numbered sequentially, and we never edit them after acceptance. A changed decision gets a new ADR that supersedes the old one. Any PR that changes a trust boundary, data flow or retention rule must reference an ADR.

## Consequences
There is a small overhead per decision. In return we get an audit trail useful for DPDP accountability and security reviews.
