# ADR-0009: Backend on ASP.NET Core / .NET 10 LTS
**Status:** Accepted · **Date:** 2026-11-21

## Context
The brief specifies ASP.NET Core 9. .NET 9 is an STS release whose support **ended in May 2026**. Running unsupported runtimes violates ASVS V14 and our own patch policy. .NET 10 is LTS (supported until November 2028).

## Decision
Use **ASP.NET Core on .NET 10 LTS**, with Minimal APIs + endpoint filters, EF Core 10 + Npgsql (PostgreSQL), OpenIddict 6/7, `Microsoft.AspNetCore.RateLimiting`, built-in OpenAPI document generation validated against the hand-written 3.1 contract, and OpenTelemetry.

## Consequences
+ Supported runtime, no migration in the near term. API surface is identical to what was requested.
− A deviation from the brief, which is why it is flagged for approval.
