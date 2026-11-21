"""Schema-level tests for agent migrations (constraints, triggers, indexes).

SQLCipher only adds page encryption, so plain SQLite behaves identically for these checks.
Go store tests (deliverable 4) cover behaviour. These tests guard the DDL itself.
Run: python3 -m unittest discover -s tools/db
"""
import pathlib
import sqlite3
import time
import unittest

MIGRATIONS = pathlib.Path(__file__).resolve().parents[2] / "agent/internal/store/migrations"
NOW = int(time.time() * 1000)
DAY = 86_400_000
H32 = b"\x00" * 32


class AgentSchemaTest(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(":memory:")
        self.db.execute("PRAGMA foreign_keys = ON")
        for f in sorted(MIGRATIONS.glob("*.sql")):
            self.db.executescript(f.read_text(encoding="utf-8"))
        self.db.execute("INSERT INTO household(id, uid, agent_uid, created_ms) VALUES (1, 'h', 'a', ?)", (NOW,))
        self.db.execute("INSERT INTO device(uid, auto_name, first_seen_ms, last_seen_ms, rev) VALUES ('d1','x',?,?,1)",
                        (NOW, NOW))

    def assertRejected(self, sql, params=()):
        with self.assertRaises(sqlite3.DatabaseError):
            self.db.execute(sql, params)

    def test_single_household_row_and_retention_values(self):
        self.assertRejected("INSERT INTO household(id, uid, agent_uid, created_ms) VALUES (2,'x','y',0)")
        self.assertRejected("UPDATE household SET retention_days = 45")
        self.db.execute("UPDATE household SET retention_days = 90")

    def test_one_active_owner(self):
        self.db.execute("INSERT INTO member(uid, display_name, role, created_ms, rev) VALUES ('m1','A','owner',0,1)")
        self.assertRejected("INSERT INTO member(uid, display_name, role, created_ms, rev) VALUES ('m2','B','owner',0,2)")
        self.db.execute("UPDATE member SET removed_ms = 1 WHERE uid = 'm1'")
        self.db.execute("INSERT INTO member(uid, display_name, role, created_ms, rev) VALUES ('m2','B','owner',0,2)")

    def test_pairing_token_ttl_and_attempts(self):
        self.assertRejected("INSERT INTO pairing_token(id, secret_hash, role, created_ms, expires_ms) "
                            "VALUES ('t', ?, 'owner', 0, 300001)", (H32,))
        self.db.execute("INSERT INTO pairing_token(id, secret_hash, role, created_ms, expires_ms) "
                        "VALUES ('t', ?, 'owner', 0, 300000)", (H32,))
        self.assertRejected("UPDATE pairing_token SET attempts = 6 WHERE id = 't'")

    def test_one_open_session_per_device(self):
        self.db.execute("INSERT INTO device_session(device_id, connected_ms, rev) VALUES (1, ?, 1)", (NOW,))
        self.assertRejected("INSERT INTO device_session(device_id, connected_ms, rev) VALUES (1, ?, 2)", (NOW,))
        self.db.execute("UPDATE device_session SET disconnected_ms = ? WHERE device_id = 1", (NOW + 1,))
        self.db.execute("INSERT INTO device_session(device_id, connected_ms, rev) VALUES (1, ?, 2)", (NOW + 2,))
        self.assertRejected("UPDATE device_session SET disconnected_ms = 0 WHERE id = 2")

    def test_identifier_belongs_to_one_device(self):
        self.db.execute("INSERT INTO device(uid, auto_name, first_seen_ms, last_seen_ms, rev) VALUES ('d2','y',0,0,2)")
        self.db.execute("INSERT INTO device_identifier(device_id, kind, value, first_seen_ms, last_seen_ms) "
                        "VALUES (1,'mac','aa:bb:cc:dd:ee:ff',0,0)")
        self.assertRejected("INSERT INTO device_identifier(device_id, kind, value, first_seen_ms, last_seen_ms) "
                            "VALUES (2,'mac','aa:bb:cc:dd:ee:ff',0,0)")

    def test_categories_seeded_and_enforced(self):
        codes = {r[0] for r in self.db.execute("SELECT code FROM category")}
        self.assertEqual(codes, {"social", "video", "gaming", "adult", "shopping", "education", "news",
                                 "malicious", "infrastructure", "unknown"})
        self.assertRejected("INSERT INTO site(etld1, category) VALUES ('x.com', 'gambling')")

    def test_daily_aggregate_primary_key(self):
        self.db.execute("INSERT INTO site(etld1) VALUES ('youtube.com')")
        row = (20261121, 1, 1, 5, NOW, NOW)
        self.db.execute("INSERT INTO domain_daily_agg VALUES (?,?,?,?,?,?)", row)
        self.assertRejected("INSERT INTO domain_daily_agg VALUES (?,?,?,?,?,?)", row)

    def test_minor_consent_requires_profile(self):
        sql = ("INSERT INTO consent_record(uid, purpose, notice_version, language, granted, method, created_ms, "
               "evidence_sha256, profile_id) VALUES (?, 'minor_parental_consent', 'v1', 'hi', 1, "
               "'parental_attestation', 0, ?, ?)")
        self.assertRejected(sql, ("c1", H32, None))
        self.db.execute("INSERT INTO profile(uid, name, is_minor, created_ms, rev) VALUES ('p1','Kid',1,0,1)")
        self.db.execute(sql, ("c1", H32, 1))
        self.assertRejected("INSERT INTO consent_record(uid, purpose, notice_version, language, granted, method, "
                            "created_ms, evidence_sha256) VALUES ('c2','network_monitoring','v1','fr',1,"
                            "'in_app_ack',0,?)", (H32,))

    def test_audit_log_append_only_with_retention_window(self):
        ins = "INSERT INTO audit_log(ts_ms, actor, action, prev_hash, hash) VALUES (?, 'system', 'x', ?, ?)"
        self.db.execute(ins, (NOW, H32, H32))
        self.db.execute(ins, (NOW - 400 * DAY, H32, H32))
        self.assertRejected("UPDATE audit_log SET action = 'y'")
        self.assertRejected("DELETE FROM audit_log WHERE ts_ms = ?", (NOW,))
        self.db.execute("DELETE FROM audit_log WHERE ts_ms < ?", (NOW - 365 * DAY,))
        self.assertEqual(self.db.execute("SELECT count(*) FROM audit_log").fetchone()[0], 1)

    def test_hot_path_queries_use_indexes(self):
        plans = {
            "SELECT * FROM dns_query WHERE device_id = 1 ORDER BY ts_ms DESC LIMIT 50": "ix_dnsq_device_time",
            "DELETE FROM dns_query WHERE ts_ms < 5": "ix_dnsq_time",
            "SELECT * FROM device_session WHERE device_id = 1 AND disconnected_ms IS NULL": "ux_session_one_open",
            "SELECT site_id, sum(query_count) FROM domain_daily_agg WHERE day = 20261121 GROUP BY site_id":
                "domain_daily_agg",
            "SELECT * FROM alert WHERE read_ms IS NULL ORDER BY created_ms DESC": "ix_alert_unread",
        }
        for sql, idx in plans.items():
            plan = " ".join(r[3] for r in self.db.execute("EXPLAIN QUERY PLAN " + sql))
            self.assertIn(idx, plan, f"{sql} -> {plan}")


if __name__ == "__main__":
    unittest.main()
