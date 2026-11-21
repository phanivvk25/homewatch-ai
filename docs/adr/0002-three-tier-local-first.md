# ADR-0002: Three-tier, local-first architecture
**Status:** Proposed · **Date:** 2026-11-21

## Context
Mobile OS sandboxes prevent a phone from observing other devices' traffic. Observation needs a component on the LAN that devices send DNS to. DNS history is highly sensitive (DPDP), so the less of it leaves the home, the smaller the regulatory and breach surface.

## Decision
- **Home Agent** (data plane) on the LAN does all observation and storage.
- **Flutter App** (control plane) talks to the agent directly on the LAN.
- **Cloud backend** is *optional*. It provides accounts, a blind relay and push. It **never** stores or decrypts DNS or device data.
- Default mode is **LOCAL-ONLY**. Remote mode is an explicit opt-in by the owner and can be turned off at any time, which wipes cloud routing state.

## Alternatives considered
- *Cloud-first (agent uploads logs):* simpler sync, but it makes us a fiduciary of sensitive browsing data, adds cross-border and breach risk, and raises costs. Rejected.
- *Router-only (OpenWrt) product:* small addressable market in India, where most homes use ISP-provided routers. Kept as one distribution channel, not the only one.

## Consequences
+ Minimal personal data in the cloud. Strong privacy story.
− Local-only users get no instant push. Sync logic lives in the app. Agent availability matters.
