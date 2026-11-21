# ADR-0004: DNS capture strategy
**Status:** Proposed · **Date:** 2026-11-21

## Context
To attribute domains to devices, the agent must receive each device's DNS queries with the client's real source IP. Indian ISP routers vary:
- Many retail routers (TP-Link, D-Link, Tenda) and some ISP units (ACT, Hathway, BSNL) let the user change the DHCP-advertised DNS server.
- JioFiber and Airtel Xstream ISP firmware frequently **locks** the LAN DNS setting, while still letting the user disable the DHCP server.
- If the router itself forwards DNS (the router as resolver, upstream set to the agent), every query appears to come from the router's IP, which destroys per-device attribution.
- IPv6 (widespread on Jio) adds RA/RDNSS-advertised ISP DNS.

## Decision
1. **Mode A, Router DNS (preferred):** the router's DHCP hands out the agent IP as primary DNS.
2. **Mode B, Agent DHCP (opt-in, new scope):** for locked routers, the user disables router DHCP and the agent serves DHCPv4 (with lease persistence, conflict detection through ARP probe, and an "abort and restore router DHCP" guide). This needs `CAP_NET_ADMIN`/`NET_RAW`.
3. **Mode C, OpenWrt native:** dnsmasq keeps DHCP and forwards DNS to the agent with `--add-mac`/EDNS client subnet so the client is preserved, or the agent reads `/tmp/dhcp.leases` and binds :53 directly.
4. **Upstream:** DoH (HTTP/2) or DoT, **TLS 1.3 only**, to a user-selected resolver (Cloudflare, Google, Quad9, AdGuard, NextDNS custom URL). Plain "ISP DNS" is not offered for upstream.
5. **Bypass mitigation (opt-in):** NXDOMAIN for known DoH hostnames (signed list), `use-application-dns.net` canary (disables Firefox auto-DoH), and optionally `mask.icloud.com`/`mask-h2.icloud.com` (disables iCloud Private Relay network-wide). Off by default, because blocking is outside MVP scope. The canary responses are framed as "mitigation", with clear UI copy.
6. **Bypass indicator (always on):** a device is flagged when it shows network presence (ARP/NDP refresh, router byte counters) for over 30 min with zero agent queries, when it queries DoH bootstrap domains, or when it has IPv6 traffic but no AAAA/A queries through the agent.
7. The agent also listens on IPv6 (link-local + ULA). The setup guide shows how to point router IPv6 DNS at the agent or disable RDNSS where possible.

## Alternatives
- *Transparent DNS interception (iptables DNAT of :53):* only possible on the router (OpenWrt). Added as an option in mode C later.
- *Port mirroring/SPAN:* consumer routers lack it. Rejected.

## Consequences
+ Works on the majority of Indian home setups, including locked ISP routers.
− Mode B makes the agent critical for IP addressing as well as DNS. Mitigated with lease persistence, a watchdog and documented rollback. The setup guide recommends Mode A whenever possible.
