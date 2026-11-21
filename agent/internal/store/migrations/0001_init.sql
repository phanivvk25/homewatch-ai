-- Home Network Tracker agent schema, migration 0001.
-- Engine: SQLite 3.39+ via SQLCipher 4 (whole-file AES-256). See docs/architecture/data-model.md.
-- Conventions:
--   * Timestamps are INTEGER Unix epoch milliseconds, UTC.
--   * Internal joins use INTEGER rowids. Public identifiers (exposed through the API) are `uid` TEXT (UUIDv7).
--   * `rev` is a monotonically increasing change sequence assigned by the store for delta sync.
--   * Hot tables avoid foreign-key cascades on the DNS write path. Cascades are used on cold tables only.

PRAGMA foreign_keys = ON;

-- ---------------------------------------------------------------------------
-- Household (exactly one row) and settings
-- ---------------------------------------------------------------------------
CREATE TABLE household (
  id              INTEGER PRIMARY KEY CHECK (id = 1),
  uid             TEXT    NOT NULL UNIQUE,
  agent_uid       TEXT    NOT NULL UNIQUE,            -- agent identity (matches backend agents.id)
  created_ms      INTEGER NOT NULL,
  timezone        TEXT    NOT NULL DEFAULT 'Asia/Kolkata',
  retention_days  INTEGER NOT NULL DEFAULT 30 CHECK (retention_days IN (7, 30, 90)),
  max_db_mb       INTEGER NOT NULL DEFAULT 1024 CHECK (max_db_mb >= 64),
  remote_enabled  INTEGER NOT NULL DEFAULT 0 CHECK (remote_enabled IN (0, 1)),
  relay_url       TEXT,
  monitoring_ack_ms INTEGER                            -- owner acknowledged the disclosure duty
) STRICT;

-- Typed key/value settings (upstream DNS, capture mode, feature flags, DHCP config).
-- Values are JSON validated by the Go layer against the API schema.
CREATE TABLE setting (
  key         TEXT    PRIMARY KEY,
  value_json  TEXT    NOT NULL CHECK (json_valid(value_json)),
  updated_ms  INTEGER NOT NULL,
  rev         INTEGER NOT NULL
) STRICT;

-- ---------------------------------------------------------------------------
-- Users on the agent side: members and their paired app installations
-- ---------------------------------------------------------------------------
CREATE TABLE member (
  id             INTEGER PRIMARY KEY,
  uid            TEXT    NOT NULL UNIQUE,
  display_name   TEXT    NOT NULL CHECK (length(display_name) BETWEEN 1 AND 64),
  role           TEXT    NOT NULL CHECK (role IN ('owner', 'member', 'viewer')),
  cloud_user_id  TEXT,                                 -- set when remote mode links an account
  created_ms     INTEGER NOT NULL,
  removed_ms     INTEGER,
  rev            INTEGER NOT NULL
) STRICT;
-- At most one active owner.
CREATE UNIQUE INDEX ux_member_single_owner ON member(role) WHERE role = 'owner' AND removed_ms IS NULL;

CREATE TABLE paired_client (
  id              INTEGER PRIMARY KEY,
  uid             TEXT    NOT NULL UNIQUE,             -- = client cert CN
  member_id       INTEGER NOT NULL REFERENCES member(id) ON DELETE CASCADE,
  platform        TEXT    NOT NULL CHECK (platform IN ('android', 'ios')),
  device_label    TEXT    NOT NULL,                    -- e.g. "Pixel 7" (user-visible, editable)
  cert_serial     TEXT    NOT NULL UNIQUE,
  cert_not_after  INTEGER NOT NULL,
  spki_sha256     BLOB    NOT NULL CHECK (length(spki_sha256) = 32),
  noise_pub       BLOB    NOT NULL CHECK (length(noise_pub) = 32),
  paired_ms       INTEGER NOT NULL,
  last_seen_ms    INTEGER,
  revoked_ms      INTEGER,
  rev             INTEGER NOT NULL
) STRICT;
CREATE INDEX ix_paired_client_member ON paired_client(member_id);

-- Revoked serials are checked on every TLS handshake (kept in memory, persisted here).
CREATE TABLE revoked_cert (
  cert_serial  TEXT    PRIMARY KEY,
  revoked_ms   INTEGER NOT NULL,
  not_after    INTEGER NOT NULL                         -- row can be dropped after expiry
) STRICT;

CREATE TABLE pairing_token (
  id            TEXT    PRIMARY KEY,                    -- token_id (public, in QR)
  secret_hash   BLOB    NOT NULL CHECK (length(secret_hash) = 32),  -- SHA-256(token_secret)
  role          TEXT    NOT NULL CHECK (role IN ('owner', 'member', 'viewer')),
  created_by    INTEGER REFERENCES member(id) ON DELETE SET NULL,   -- NULL = console-issued
  created_ms    INTEGER NOT NULL,
  expires_ms    INTEGER NOT NULL,
  used_ms       INTEGER,
  attempts      INTEGER NOT NULL DEFAULT 0 CHECK (attempts <= 5),
  CHECK (expires_ms - created_ms <= 300000)             -- 5 minutes maximum
) STRICT;
CREATE INDEX ix_pairing_token_expiry ON pairing_token(expires_ms);

-- ---------------------------------------------------------------------------
-- Family profiles (devices are assigned to these). Includes hooks for future schedules and rules.
-- ---------------------------------------------------------------------------
CREATE TABLE profile (
  id             INTEGER PRIMARY KEY,
  uid            TEXT    NOT NULL UNIQUE,
  name           TEXT    NOT NULL CHECK (length(name) BETWEEN 1 AND 40),
  avatar         TEXT    NOT NULL DEFAULT 'person',
  is_minor       INTEGER NOT NULL DEFAULT 0 CHECK (is_minor IN (0, 1)),
  schedule_json  TEXT    CHECK (schedule_json IS NULL OR json_valid(schedule_json)), -- allowed hours
  created_ms     INTEGER NOT NULL,
  rev            INTEGER NOT NULL
) STRICT;

-- ---------------------------------------------------------------------------
-- Devices and identifiers
-- ---------------------------------------------------------------------------
CREATE TABLE device (
  id                   INTEGER PRIMARY KEY,
  uid                  TEXT    NOT NULL UNIQUE,
  display_name         TEXT    CHECK (display_name IS NULL OR length(display_name) BETWEEN 1 AND 64),
  auto_name            TEXT    NOT NULL,               -- best guess (hostname / mDNS / vendor+type)
  vendor               TEXT,
  device_type          TEXT    NOT NULL DEFAULT 'unknown' CHECK (device_type IN (
                         'phone','tablet','computer','tv','streaming','speaker','console',
                         'camera','printer','iot','router','wearable','unknown')),
  type_source          TEXT    NOT NULL DEFAULT 'heuristic' CHECK (type_source IN ('heuristic','user')),
  profile_id           INTEGER REFERENCES profile(id) ON DELETE SET NULL,
  trusted              INTEGER NOT NULL DEFAULT 0 CHECK (trusted IN (0, 1)),
  possibly_randomized  INTEGER NOT NULL DEFAULT 0 CHECK (possibly_randomized IN (0, 1)),
  bypass_suspected_ms  INTEGER,                         -- last time the bypass detector flagged it
  current_ipv4         TEXT,
  first_seen_ms        INTEGER NOT NULL,
  last_seen_ms         INTEGER NOT NULL,
  merged_into          INTEGER REFERENCES device(id),   -- non-NULL = hidden, kept for undo window
  rev                  INTEGER NOT NULL
) STRICT;
CREATE INDEX ix_device_last_seen   ON device(last_seen_ms DESC) WHERE merged_into IS NULL;
CREATE INDEX ix_device_first_seen  ON device(first_seen_ms DESC) WHERE merged_into IS NULL;
CREATE INDEX ix_device_profile     ON device(profile_id) WHERE profile_id IS NOT NULL;
CREATE INDEX ix_device_rev         ON device(rev);

CREATE TABLE device_identifier (
  id            INTEGER PRIMARY KEY,
  device_id     INTEGER NOT NULL REFERENCES device(id) ON DELETE CASCADE,
  kind          TEXT    NOT NULL CHECK (kind IN ('mac','dhcp_client_id','hostname','dhcp_fp','mdns_name','ipv6_iid')),
  value         TEXT    NOT NULL,
  first_seen_ms INTEGER NOT NULL,
  last_seen_ms  INTEGER NOT NULL,
  UNIQUE (kind, value)
) STRICT;
CREATE INDEX ix_device_identifier_device ON device_identifier(device_id);

CREATE TABLE merge_log (
  id                INTEGER PRIMARY KEY,
  uid               TEXT    NOT NULL UNIQUE,
  survivor_id       INTEGER NOT NULL REFERENCES device(id) ON DELETE CASCADE,
  merged_id         INTEGER NOT NULL REFERENCES device(id) ON DELETE CASCADE,
  moved_ids_json    TEXT    NOT NULL CHECK (json_valid(moved_ids_json)), -- identifier ids moved
  created_ms        INTEGER NOT NULL,
  expires_ms        INTEGER NOT NULL,                    -- created + 7 days
  undone_ms         INTEGER,
  actor_client_id   INTEGER REFERENCES paired_client(id) ON DELETE SET NULL
) STRICT;

-- Optional DHCP server mode (ADR-0004 mode B)
CREATE TABLE dhcp_lease (
  mac          TEXT    PRIMARY KEY,
  ipv4         TEXT    NOT NULL UNIQUE,
  hostname     TEXT,
  client_id    TEXT,
  expires_ms   INTEGER NOT NULL,
  static       INTEGER NOT NULL DEFAULT 0 CHECK (static IN (0, 1))
) STRICT;

-- ---------------------------------------------------------------------------
-- Connection sessions
-- ---------------------------------------------------------------------------
CREATE TABLE device_session (
  id               INTEGER PRIMARY KEY,
  device_id        INTEGER NOT NULL REFERENCES device(id) ON DELETE CASCADE,
  connected_ms     INTEGER NOT NULL,
  disconnected_ms  INTEGER,                              -- NULL = currently online
  ipv4             TEXT,
  close_reason     TEXT    CHECK (close_reason IN ('timeout','probe_failed','agent_shutdown','merged')),
  rev              INTEGER NOT NULL,
  CHECK (disconnected_ms IS NULL OR disconnected_ms >= connected_ms)
) STRICT;
CREATE INDEX ix_session_device_time ON device_session(device_id, connected_ms DESC);
CREATE INDEX ix_session_open        ON device_session(device_id) WHERE disconnected_ms IS NULL;
CREATE INDEX ix_session_time        ON device_session(connected_ms);
CREATE INDEX ix_session_rev         ON device_session(rev);
-- Only one open session per device.
CREATE UNIQUE INDEX ux_session_one_open ON device_session(device_id) WHERE disconnected_ms IS NULL;

-- ---------------------------------------------------------------------------
-- Domain categories and dictionaries
-- ---------------------------------------------------------------------------
CREATE TABLE category (
  code        TEXT    PRIMARY KEY,
  sensitive   INTEGER NOT NULL CHECK (sensitive IN (0, 1)),   -- adult, malicious
  alertable   INTEGER NOT NULL CHECK (alertable IN (0, 1)),
  hidden_by_default INTEGER NOT NULL DEFAULT 0 CHECK (hidden_by_default IN (0, 1)),
  sort_order  INTEGER NOT NULL
) STRICT;

INSERT INTO category (code, sensitive, alertable, hidden_by_default, sort_order) VALUES
  ('social',         0, 0, 0, 10),
  ('video',          0, 0, 0, 20),
  ('gaming',         0, 0, 0, 30),
  ('adult',          1, 1, 0, 40),
  ('shopping',       0, 0, 0, 50),
  ('education',      0, 0, 0, 60),
  ('news',           0, 0, 0, 70),
  ('malicious',      1, 1, 0, 80),
  ('infrastructure', 0, 0, 1, 90),
  ('unknown',        0, 0, 0, 100);

-- Registrable domain (eTLD+1). This is the "DomainCategory" entity: category + provenance.
CREATE TABLE site (
  id               INTEGER PRIMARY KEY,
  etld1            TEXT    NOT NULL UNIQUE COLLATE NOCASE,
  category         TEXT    NOT NULL DEFAULT 'unknown' REFERENCES category(code),
  category_source  TEXT    NOT NULL DEFAULT 'bundle' CHECK (category_source IN ('bundle','user')),
  bundle_version   INTEGER,                               -- version that categorised it
  brand            TEXT                                   -- e.g. "YouTube" for googlevideo.com
) STRICT;
CREATE INDEX ix_site_category ON site(category);

-- Fully-qualified names seen (dictionary-encoded to keep dns_query rows small).
CREATE TABLE domain (
  id      INTEGER PRIMARY KEY,
  name    TEXT    NOT NULL UNIQUE COLLATE NOCASE,
  site_id INTEGER NOT NULL REFERENCES site(id)
) STRICT;
CREATE INDEX ix_domain_site ON domain(site_id);

-- ---------------------------------------------------------------------------
-- DNS queries (hot table). Repeats of (device, domain, qtype) within 60 s are coalesced.
-- ---------------------------------------------------------------------------
CREATE TABLE dns_query (
  id            INTEGER PRIMARY KEY,
  ts_ms         INTEGER NOT NULL,                        -- first query in the coalescing window
  last_ts_ms    INTEGER NOT NULL,
  device_id     INTEGER NOT NULL,                        -- device.id (no FK: hot path; janitor cleans orphans)
  domain_id     INTEGER NOT NULL,                        -- domain.id
  qtype         INTEGER NOT NULL,                        -- RFC 1035 numeric type
  rcode         INTEGER NOT NULL,
  flags         INTEGER NOT NULL DEFAULT 0,              -- bit0 cached, bit1 blocked(future), bit2 doh_canary, bit3 via_ipv6, bit4 via_dot
  repeat_count  INTEGER NOT NULL DEFAULT 1 CHECK (repeat_count >= 1),
  upstream_ms   INTEGER,                                 -- NULL when served from cache
  answer        TEXT                                     -- up to 2 addresses / CNAME target, comma-separated
) STRICT;
CREATE INDEX ix_dnsq_device_time ON dns_query(device_id, ts_ms DESC);
CREATE INDEX ix_dnsq_domain_time ON dns_query(domain_id, ts_ms DESC);
CREATE INDEX ix_dnsq_time        ON dns_query(ts_ms);

-- Daily roll-up powering dashboards and site lists. `day` = local date (household tz) as YYYYMMDD.
CREATE TABLE domain_daily_agg (
  day          INTEGER NOT NULL,
  device_id    INTEGER NOT NULL,
  site_id      INTEGER NOT NULL,
  query_count  INTEGER NOT NULL,
  first_ts_ms  INTEGER NOT NULL,
  last_ts_ms   INTEGER NOT NULL,
  PRIMARY KEY (day, device_id, site_id)
) STRICT, WITHOUT ROWID;
CREATE INDEX ix_agg_site_day   ON domain_daily_agg(site_id, day);
CREATE INDEX ix_agg_device_day ON domain_daily_agg(device_id, day);

-- ---------------------------------------------------------------------------
-- Alerts
-- ---------------------------------------------------------------------------
CREATE TABLE alert_rule (
  id           INTEGER PRIMARY KEY,
  uid          TEXT    NOT NULL UNIQUE,
  kind         TEXT    NOT NULL CHECK (kind IN ('new_device','outside_hours','category_access','dns_bypass')),
  enabled      INTEGER NOT NULL DEFAULT 1 CHECK (enabled IN (0, 1)),
  profile_id   INTEGER REFERENCES profile(id) ON DELETE CASCADE,  -- NULL = household-wide
  params_json  TEXT    NOT NULL DEFAULT '{}' CHECK (json_valid(params_json)),
  updated_ms   INTEGER NOT NULL,
  rev          INTEGER NOT NULL
) STRICT;

CREATE TABLE alert (
  id            INTEGER PRIMARY KEY,
  uid           TEXT    NOT NULL UNIQUE,                 -- opaque 128-bit ref, also used in push payloads
  rule_id       INTEGER REFERENCES alert_rule(id) ON DELETE SET NULL,
  kind          TEXT    NOT NULL CHECK (kind IN ('new_device','outside_hours','category_access','dns_bypass','agent_update')),
  severity      TEXT    NOT NULL CHECK (severity IN ('info','warning','critical')),
  device_id     INTEGER REFERENCES device(id) ON DELETE CASCADE,
  site_id       INTEGER REFERENCES site(id),
  created_ms    INTEGER NOT NULL,
  details_json  TEXT    NOT NULL DEFAULT '{}' CHECK (json_valid(details_json)),
  dedupe_key    TEXT    NOT NULL,
  read_ms       INTEGER,
  pushed_ms     INTEGER,
  rev           INTEGER NOT NULL
) STRICT;
CREATE INDEX ix_alert_created ON alert(created_ms DESC);
CREATE INDEX ix_alert_unread  ON alert(created_ms DESC) WHERE read_ms IS NULL;
CREATE INDEX ix_alert_dedupe  ON alert(dedupe_key, created_ms DESC);
CREATE INDEX ix_alert_rev     ON alert(rev);

-- ---------------------------------------------------------------------------
-- Consent records (DPDP). Subject is the owner/member, or a minor profile (parental attestation).
-- ---------------------------------------------------------------------------
CREATE TABLE consent_record (
  id               INTEGER PRIMARY KEY,
  uid              TEXT    NOT NULL UNIQUE,
  member_id        INTEGER REFERENCES member(id) ON DELETE SET NULL,  -- who gave it
  profile_id       INTEGER REFERENCES profile(id) ON DELETE SET NULL, -- subject if minor profile
  purpose          TEXT    NOT NULL CHECK (purpose IN (
                     'network_monitoring','monitoring_disclosure_ack','minor_parental_consent',
                     'remote_access','push_notifications','crash_reports','analytics')),
  notice_version   TEXT    NOT NULL,
  language         TEXT    NOT NULL CHECK (language IN ('en','hi','te','ta')),
  granted          INTEGER NOT NULL CHECK (granted IN (0, 1)),
  method           TEXT    NOT NULL CHECK (method IN ('in_app_ack','parental_attestation')),
  created_ms       INTEGER NOT NULL,
  withdrawn_ms     INTEGER,
  evidence_sha256  BLOB    NOT NULL CHECK (length(evidence_sha256) = 32),  -- hash of notice text shown
  CHECK (purpose <> 'minor_parental_consent' OR profile_id IS NOT NULL)
) STRICT;
CREATE INDEX ix_consent_purpose ON consent_record(purpose, created_ms DESC);

-- ---------------------------------------------------------------------------
-- Audit log (hash-chained, append-only: enforced by triggers)
-- ---------------------------------------------------------------------------
CREATE TABLE audit_log (
  id            INTEGER PRIMARY KEY,
  ts_ms         INTEGER NOT NULL,
  actor         TEXT    NOT NULL,                        -- paired_client uid | 'console' | 'system' | 'relay'
  action        TEXT    NOT NULL,                        -- e.g. 'pairing.completed', 'settings.retention_changed'
  target_type   TEXT,
  target_uid    TEXT,
  details_json  TEXT    NOT NULL DEFAULT '{}' CHECK (json_valid(details_json)), -- never domains/MACs
  prev_hash     BLOB    NOT NULL CHECK (length(prev_hash) = 32),
  hash          BLOB    NOT NULL CHECK (length(hash) = 32)
) STRICT;
CREATE INDEX ix_audit_time ON audit_log(ts_ms);

CREATE TRIGGER audit_log_no_update BEFORE UPDATE ON audit_log
BEGIN SELECT RAISE(ABORT, 'audit_log is append-only'); END;
-- Deletes are allowed only for the oldest rows (retention janitor). Rows newer than 365 days are protected.
CREATE TRIGGER audit_log_retention_only BEFORE DELETE ON audit_log
WHEN OLD.ts_ms > (CAST(strftime('%s','now') AS INTEGER) * 1000 - 365 * 86400000)
BEGIN SELECT RAISE(ABORT, 'audit_log rows younger than 365 days cannot be deleted'); END;

-- ---------------------------------------------------------------------------
-- Delta sync tombstones
-- ---------------------------------------------------------------------------
CREATE TABLE tombstone (
  rev         INTEGER PRIMARY KEY,
  entity      TEXT    NOT NULL CHECK (entity IN ('device','session','alert','profile','member','client','alert_rule')),
  uid         TEXT    NOT NULL,
  deleted_ms  INTEGER NOT NULL
) STRICT;
CREATE INDEX ix_tombstone_deleted ON tombstone(deleted_ms);

CREATE TABLE schema_migrations (
  version     INTEGER PRIMARY KEY,
  applied_ms  INTEGER NOT NULL
) STRICT;
INSERT INTO schema_migrations (version, applied_ms) VALUES (1, CAST(strftime('%s','now') AS INTEGER) * 1000);
