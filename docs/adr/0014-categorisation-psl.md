# ADR-0014: Domain grouping (PSL) and offline signed category bundles
**Status:** Accepted · **Date:** 2026-11-21

## Decision
- eTLD+1 grouping uses the **Public Suffix List** (`golang.org/x/net/publicsuffix`, plus a bundled newer PSL snapshot). For example, `rr3---sn-x.googlevideo.com` groups under `googlevideo.com`. A curated "brand alias" map (`googlevideo.com`, `ytimg.com` → YouTube) aids readability.
- Categories: `social, video, gaming, adult, shopping, education, news, malicious, unknown`. Sources (licence-vetted, A11): UT1 blacklists (CC BY-SA 4.0, attribution in About), URLhaus (CC0) for malicious, and a curated India-specific list (for example Hotstar/JioCinema, Flipkart/Meesho, Byju's/PhysicsWallah, Dream11) maintained in-repo.
- Packaging: a compact sorted binary trie in a **signed** bundle (minisign Ed25519). The agent checks for updates daily (remote mode, or a direct HTTPS fetch from the release CDN with no identifiers). Lookups happen **locally**, so no domain ever leaves the home for categorisation.
- Noise domains (OS telemetry, CDNs, connectivity checks) are tagged `infrastructure` and hidden by default in "Sites" views (toggle to show).

## Consequences
+ Private, fast and offline.
− Coverage gaps ("unknown") are expected and stated in the known limitations.
