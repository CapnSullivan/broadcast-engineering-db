-- Schema extracted from engineering2.sqlite. No original records included.
-- The aliases FK was corrected from a stale devices_old reference to devices.
PRAGMA foreign_keys = ON;
BEGIN;
CREATE TABLE aliases (
  asb       TEXT NOT NULL,
  layer     TEXT NOT NULL,
  target_id TEXT NOT NULL,      -- device_id
  alias     TEXT NOT NULL,
  PRIMARY KEY (asb, layer, target_id, alias),
  FOREIGN KEY (asb, layer, target_id) REFERENCES "devices"(asb, layer, device_id)
);

CREATE TABLE cables (
  asb TEXT NOT NULL,
  layer TEXT NOT NULL,
  cable_label TEXT NOT NULL,
  a_device TEXT,
  a_port TEXT,
  b_device TEXT,
  b_port TEXT,
  net_name TEXT,
  domain_raw TEXT,
  source TEXT,
  PRIMARY KEY (asb, layer, cable_label)
);

CREATE TABLE devices (
  asb          TEXT NOT NULL,
  layer        TEXT NOT NULL,
  device_id    TEXT NOT NULL,
  model_id     TEXT,
  model_name   TEXT,
  location_raw TEXT,
  location_zone TEXT,
  rack_id      TEXT,
  frame_type   TEXT,
  frame_id     TEXT,
  frame_slot_id TEXT,
  u_level      TEXT,
  location_note TEXT,
  transcription_short TEXT,
  transcription_full  TEXT,
  note         TEXT,
  PRIMARY KEY (asb, layer, device_id),
  FOREIGN KEY (model_id) REFERENCES models(model_id)
);

CREATE TABLE model_ports (
  model_id     TEXT NOT NULL,
  name         TEXT NOT NULL,   -- имя порта (EXT1, HDSDI1, ...)
  io           TEXT,            -- in / out / bi
  signal       TEXT,            -- техтип (VIDEO_SDI / AUDIO / analog_SD / ...)
  interface    TEXT,            -- HDSDI / CVBS / REF_BB / ...
  connector    TEXT,            -- BNC / XLR / RJ45 / ...
  label        TEXT,            -- человекочит. ярлык
  port_group   TEXT,            -- группа портов
  domain       TEXT, doc_name TEXT, port_role TEXT,            -- канон: DGV/VID/AUD/SYN/IT (лучше так)
  PRIMARY KEY (model_id, name),
  FOREIGN KEY (model_id) REFERENCES models(model_id)
);

CREATE TABLE models (
  model_id  TEXT PRIMARY KEY,
  note      TEXT
);

CREATE TABLE vjp_active_program (
  slot_id     INTEGER PRIMARY KEY CHECK (slot_id = 1),
  program_id  TEXT,
  activated_at TEXT,
  note        TEXT,
  FOREIGN KEY (program_id) REFERENCES vjp_program_sets(program_id)
);

CREATE TABLE vjp_live_patches (
  asb          TEXT NOT NULL,
  layer        TEXT NOT NULL DEFAULT 'LIVE',
  base_layer   TEXT NOT NULL DEFAULT 'DESIGN',
  device_id    TEXT NOT NULL,
  port_name    TEXT NOT NULL,
  peer_device  TEXT,
  peer_port    TEXT,
  patch_role   TEXT NOT NULL DEFAULT 'PATCH',
  active       INTEGER NOT NULL DEFAULT 1,
  note         TEXT,
  PRIMARY KEY (asb, layer, device_id, port_name)
);

CREATE TABLE vjp_normals (
  model_id    TEXT NOT NULL,
  a_port      TEXT NOT NULL,
  b_port      TEXT NOT NULL,
  normal_dir  TEXT NOT NULL DEFAULT 'A_TO_B',
  break_on_a  INTEGER NOT NULL DEFAULT 1,
  break_on_b  INTEGER NOT NULL DEFAULT 1,
  note        TEXT,
  PRIMARY KEY (model_id, a_port, b_port),
  FOREIGN KEY (model_id) REFERENCES models(model_id)
);

CREATE TABLE vjp_patch_sets (
  patch_set_id TEXT PRIMARY KEY,
  name         TEXT NOT NULL,
  kind         TEXT NOT NULL DEFAULT 'PROGRAM',
  starts_at    TEXT,
  ends_at      TEXT,
  note         TEXT
);

CREATE TABLE vjp_program_patches (
  program_id    TEXT NOT NULL,
  asb           TEXT NOT NULL,
  layer         TEXT NOT NULL,
  base_layer    TEXT NOT NULL DEFAULT 'DESIGN',
  device_id     TEXT NOT NULL,
  port_name     TEXT NOT NULL,
  peer_device   TEXT,
  peer_port     TEXT,
  patch_role    TEXT NOT NULL DEFAULT 'PATCH',
  active        INTEGER NOT NULL DEFAULT 1,
  note          TEXT,
  PRIMARY KEY (program_id, asb, layer, device_id, port_name),
  FOREIGN KEY (program_id) REFERENCES vjp_program_sets(program_id)
);

CREATE TABLE vjp_program_sets (
  program_id  TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  starts_at   TEXT,
  ends_at     TEXT,
  note        TEXT
);

CREATE TABLE vjp_set_patches (
  patch_set_id TEXT NOT NULL,
  asb          TEXT NOT NULL,
  layer        TEXT NOT NULL,
  device_id    TEXT NOT NULL,
  port_name    TEXT NOT NULL,
  peer_device  TEXT,
  peer_port    TEXT,
  patch_role   TEXT NOT NULL DEFAULT 'PATCH',
  active       INTEGER NOT NULL DEFAULT 1,
  note         TEXT,
  PRIMARY KEY (patch_set_id, asb, layer, device_id, port_name),
  FOREIGN KEY (patch_set_id) REFERENCES vjp_patch_sets(patch_set_id)
);

CREATE INDEX ix_cables_a ON cables(asb, layer, a_device, a_port);

CREATE INDEX ix_cables_b ON cables(asb, layer, b_device, b_port);

CREATE VIEW broken_cables_v AS
SELECT cable_label, asb, layer, a_device, a_port, b_device, b_port
FROM cables
WHERE (a_device IS NOT NULL AND a_port IS NULL)
   OR (a_device IS NULL AND a_port IS NOT NULL)
   OR (b_device IS NOT NULL AND b_port IS NULL)
   OR (b_device IS NULL AND b_port IS NOT NULL);

CREATE VIEW edges_flow_v AS
WITH p AS (
  SELECT
    c.asb, c.layer, c.cable_label,
    c.a_device, c.a_port, c.b_device, c.b_port,
    c.net_name, c.domain_raw,

    da.model_id AS a_model,
    db.model_id AS b_model,

    CASE
      WHEN da.model_id='VJP.model' AND c.a_port LIKE 'A%' THEN 'in'
      WHEN da.model_id='VJP.model' AND c.a_port LIKE 'B%' THEN 'out'
      ELSE mpa.io
    END AS a_io,
    mpa.domain AS a_domain,
    mpa.signal AS a_signal,

    CASE
      WHEN db.model_id='VJP.model' AND c.b_port LIKE 'A%' THEN 'in'
      WHEN db.model_id='VJP.model' AND c.b_port LIKE 'B%' THEN 'out'
      ELSE mpb.io
    END AS b_io,
    mpb.domain AS b_domain,
    mpb.signal AS b_signal

  FROM cables c
  LEFT JOIN devices da
    ON da.asb=c.asb AND da.layer=c.layer AND da.device_id=c.a_device
  LEFT JOIN devices db
    ON db.asb=c.asb AND db.layer=c.layer AND db.device_id=c.b_device
  LEFT JOIN model_ports mpa
    ON mpa.model_id=da.model_id AND mpa.name=c.a_port
  LEFT JOIN model_ports mpb
    ON mpb.model_id=db.model_id AND mpb.name=c.b_port
  WHERE c.a_device IS NOT NULL AND c.a_port IS NOT NULL
    AND c.b_device IS NOT NULL AND c.b_port IS NOT NULL
),
dir AS (
  SELECT
    asb, layer, cable_label, net_name, domain_raw,
    CASE
      WHEN lower(a_io)='out' AND lower(b_io)='in'  THEN 'OK'
      WHEN lower(a_io)='in'  AND lower(b_io)='out' THEN 'OK'
      ELSE 'UNKNOWN'
    END AS direction_status,
    CASE
      WHEN lower(a_io)='out' AND lower(b_io)='in'  THEN a_device
      WHEN lower(a_io)='in'  AND lower(b_io)='out' THEN b_device
      ELSE a_device
    END AS from_device,
    CASE
      WHEN lower(a_io)='out' AND lower(b_io)='in'  THEN a_port
      WHEN lower(a_io)='in'  AND lower(b_io)='out' THEN b_port
      ELSE a_port
    END AS from_port,
    CASE
      WHEN lower(a_io)='out' AND lower(b_io)='in'  THEN b_device
      WHEN lower(a_io)='in'  AND lower(b_io)='out' THEN a_device
      ELSE b_device
    END AS to_device,
    CASE
      WHEN lower(a_io)='out' AND lower(b_io)='in'  THEN b_port
      WHEN lower(a_io)='in'  AND lower(b_io)='out' THEN a_port
      ELSE b_port
    END AS to_port,
    COALESCE(UPPER(domain_raw), UPPER(a_domain), UPPER(b_domain)) AS domain,
    COALESCE(a_signal, b_signal) AS signal
  FROM p
)
SELECT
  asb, layer, cable_label,
  from_device, from_port, to_device, to_port,
  (from_device || ' ' || from_port) AS from_ref,
  (to_device || ' ' || to_port)     AS to_ref,
  domain, signal, net_name,
  direction_status
FROM dir;

CREATE VIEW edges_v AS
WITH enriched AS (
  SELECT
    c.asb, c.layer, c.cable_label,
    c.a_device, c.a_port, c.b_device, c.b_port,
    c.net_name, c.domain_raw,

    da.model_id AS a_model_id,
    db.model_id AS b_model_id,

    mpa.domain    AS a_domain,
    mpa.signal    AS a_signal,
    mpa.interface AS a_interface,
    mpa.connector AS a_connector,
    mpa.io        AS a_io,

    mpb.domain    AS b_domain,
    mpb.signal    AS b_signal,
    mpb.interface AS b_interface,
    mpb.connector AS b_connector,
    mpb.io        AS b_io

  FROM cables c
  LEFT JOIN devices da
    ON da.asb=c.asb AND da.layer=c.layer AND da.device_id=c.a_device
  LEFT JOIN devices db
    ON db.asb=c.asb AND db.layer=c.layer AND db.device_id=c.b_device
  LEFT JOIN model_ports mpa
    ON mpa.model_id=da.model_id AND mpa.name=c.a_port
  LEFT JOIN model_ports mpb
    ON mpb.model_id=db.model_id AND mpb.name=c.b_port
  WHERE c.a_device IS NOT NULL AND c.a_port IS NOT NULL
    AND c.b_device IS NOT NULL AND c.b_port IS NOT NULL
)
SELECT
  asb,
  layer,
  cable_label,
  a_device AS from_device,
  a_port   AS from_port,
  b_device AS to_device,
  b_port   AS to_port,
  (a_device || ' ' || a_port) AS from_ref,
  (b_device || ' ' || b_port) AS to_ref,
  COALESCE(UPPER(domain_raw), UPPER(a_domain), UPPER(b_domain)) AS domain,
  COALESCE(a_signal, b_signal) AS signal,
  COALESCE(a_interface, b_interface) AS interface,
  COALESCE(a_connector, b_connector) AS connector,
  net_name
FROM enriched

UNION ALL

SELECT
  asb,
  layer,
  cable_label,
  b_device AS from_device,
  b_port   AS from_port,
  a_device AS to_device,
  a_port   AS to_port,
  (b_device || ' ' || b_port) AS from_ref,
  (a_device || ' ' || a_port) AS to_ref,
  COALESCE(UPPER(domain_raw), UPPER(b_domain), UPPER(a_domain)) AS domain,
  COALESCE(b_signal, a_signal) AS signal,
  COALESCE(b_interface, a_interface) AS interface,
  COALESCE(b_connector, a_connector) AS connector,
  net_name
FROM enriched;

CREATE VIEW journal_design_v AS
WITH p AS (
  SELECT
    c.asb, c.layer AS cable_layer, c.cable_label,
    c.a_device, c.a_port, c.b_device, c.b_port,
    c.net_name, c.domain_raw,
    da.model_id AS a_model,
    db.model_id AS b_model,
    CASE
      WHEN da.model_id='VJP.model' AND c.a_port LIKE 'A%' THEN 'in'
      WHEN da.model_id='VJP.model' AND c.a_port LIKE 'B%' THEN 'out'
      ELSE mpa.io
    END AS a_io,
    mpa.domain AS a_domain,
    mpa.signal AS a_signal,
    CASE
      WHEN db.model_id='VJP.model' AND c.b_port LIKE 'A%' THEN 'in'
      WHEN db.model_id='VJP.model' AND c.b_port LIKE 'B%' THEN 'out'
      ELSE mpb.io
    END AS b_io,
    mpb.domain AS b_domain,
    mpb.signal AS b_signal
  FROM cables c
  LEFT JOIN devices da
    ON da.asb=c.asb AND da.layer=c.layer AND da.device_id=c.a_device
  LEFT JOIN devices db
    ON db.asb=c.asb AND db.layer=c.layer AND db.device_id=c.b_device
  LEFT JOIN model_ports mpa
    ON mpa.model_id=da.model_id AND mpa.name=c.a_port
  LEFT JOIN model_ports mpb
    ON mpb.model_id=db.model_id AND mpb.name=c.b_port
  WHERE c.a_device IS NOT NULL AND c.a_port IS NOT NULL
    AND c.b_device IS NOT NULL AND c.b_port IS NOT NULL
    AND c.layer='DESIGN'
),
dir AS (
  SELECT
    asb, cable_layer, cable_label, net_name, domain_raw,
    CASE
      WHEN lower(a_io)='out' AND lower(b_io)='in'  THEN 'OK'
      WHEN lower(a_io)='in'  AND lower(b_io)='out' THEN 'OK'
      ELSE 'UNKNOWN'
    END AS dir_status,
    CASE
      WHEN lower(a_io)='out' AND lower(b_io)='in'  THEN a_device
      WHEN lower(a_io)='in'  AND lower(b_io)='out' THEN b_device
      ELSE a_device
    END AS src_device,
    CASE
      WHEN lower(a_io)='out' AND lower(b_io)='in'  THEN a_port
      WHEN lower(a_io)='in'  AND lower(b_io)='out' THEN b_port
      ELSE a_port
    END AS src_port,
    CASE
      WHEN lower(a_io)='out' AND lower(b_io)='in'  THEN b_device
      WHEN lower(a_io)='in'  AND lower(b_io)='out' THEN a_device
      ELSE b_device
    END AS dst_device,
    CASE
      WHEN lower(a_io)='out' AND lower(b_io)='in'  THEN b_port
      WHEN lower(a_io)='in'  AND lower(b_io)='out' THEN a_port
      ELSE b_port
    END AS dst_port,
    COALESCE(UPPER(domain_raw), UPPER(a_domain), UPPER(b_domain)) AS domain,
    COALESCE(a_signal, b_signal) AS signal
  FROM p
)
SELECT
  asb,
  cable_layer,
  cable_label,
  dir_status,
  src_device,
  src_port,
  dst_device,
  dst_port,
  '[' || asb || '] ' || cable_label || ': ' ||
  src_device || ' ' || src_port || ' -> ' ||
  dst_device || ' ' || dst_port ||
  ' (' || COALESCE(domain,'') || ')' ||
  CASE
    WHEN net_name IS NOT NULL AND TRIM(net_name)<>'' THEN ' ' || net_name
    WHEN signal   IS NOT NULL AND TRIM(signal)<>''   THEN ' ' || signal
    ELSE ''
  END || CASE WHEN dir_status='UNKNOWN' THEN ' (!)' ELSE '' END AS line
FROM dir;

CREATE VIEW journal_live_v AS
WITH base_non_vjp AS (
  SELECT
    jd.asb,
    jd.cable_layer,
    'DESIGN' AS status_source,
    jd.cable_label,
    jd.dir_status,
    jd.src_device,
    jd.src_port,
    jd.dst_device,
    jd.dst_port,
    jd.line
  FROM journal_design_v jd
  WHERE jd.src_device NOT LIKE 'VJP.%' AND jd.dst_device NOT LIKE 'VJP.%'
),
vjp_rows AS (
  SELECT
    asb,
    'DESIGN' AS cable_layer,
    status_source,
    'VJP:' || vjp_device || ':' || a_port || ':' || b_port AS cable_label,
    current_state AS dir_status,
    from_device_name_to_VJP_port_A AS src_device,
    from_device_port_to_VJP_port_A AS src_port,
    to_device_name_from_VJP_port_B AS dst_device,
    to_device_port_from_VJP_port_B AS dst_port,
    line
  FROM vjp_current_status_v
)
SELECT * FROM base_non_vjp
UNION ALL
SELECT * FROM vjp_rows;

CREATE VIEW open_ends_v AS
SELECT
  asb, layer, cable_label,
  CASE
    WHEN a_device IS NOT NULL AND a_port IS NOT NULL AND (b_device IS NULL OR b_port IS NULL)
      THEN a_device || ' ' || a_port
    WHEN b_device IS NOT NULL AND b_port IS NOT NULL AND (a_device IS NULL OR a_port IS NULL)
      THEN b_device || ' ' || b_port
    ELSE '(invalid)'
  END AS known_end,
  net_name, domain_raw, source
FROM cables
WHERE
  (a_device IS NOT NULL AND a_port IS NOT NULL AND (b_device IS NULL OR b_port IS NULL))
  OR
  (b_device IS NOT NULL AND b_port IS NOT NULL AND (a_device IS NULL OR a_port IS NULL));

CREATE VIEW ports_in_use_v AS
WITH ends AS (
  SELECT asb, layer, cable_label, a_device AS device_id, a_port AS port_name, 'A' AS side
  FROM cables
  WHERE a_device IS NOT NULL AND a_port IS NOT NULL
  UNION ALL
  SELECT asb, layer, cable_label, b_device AS device_id, b_port AS port_name, 'B' AS side
  FROM cables
  WHERE b_device IS NOT NULL AND b_port IS NOT NULL
)
SELECT
  e.asb,
  e.layer,
  e.device_id,
  d.model_id,
  mp.label,
  mp.doc_name,
  mp.io,
  mp.domain,
  mp.signal,
  mp.interface,
  mp.connector,
  e.cable_label,
  e.side
FROM ends e
LEFT JOIN devices d
  ON d.asb=e.asb AND d.layer=e.layer AND d.device_id=e.device_id
LEFT JOIN model_ports mp
  ON mp.model_id=d.model_id AND mp.name=e.port_name;

CREATE VIEW ports_unused_v AS
WITH used_ports AS (
  SELECT asb, layer, a_device AS device_id, a_port AS port_name
  FROM cables
  WHERE a_device IS NOT NULL AND a_port IS NOT NULL
  UNION
  SELECT asb, layer, b_device AS device_id, b_port AS port_name
  FROM cables
  WHERE b_device IS NOT NULL AND b_port IS NOT NULL
)
SELECT
  d.asb,
  d.layer,
  d.device_id,
  d.model_id,
  mp.label,
  mp.doc_name,
  mp.io,
  mp.domain,
  mp.signal,
  mp.interface,
  mp.connector
FROM devices d
JOIN model_ports mp
  ON mp.model_id = d.model_id
LEFT JOIN used_ports u
  ON u.asb=d.asb AND u.layer=d.layer AND u.device_id=d.device_id AND u.port_name=mp.name
WHERE u.port_name IS NULL;

CREATE VIEW vjp_current_status_v AS
WITH design AS (
  SELECT * FROM vjp_design_v
), live AS (
  SELECT * FROM vjp_live_v
), program AS (
  SELECT * FROM vjp_program_v
)
SELECT
  d.asb,
  CASE
    WHEN p.program_id IS NOT NULL AND (p.patch_a_peer_device IS NOT NULL OR p.patch_b_peer_device IS NOT NULL) THEN p.layer
    WHEN (l.patch_a_peer_device IS NOT NULL OR l.patch_b_peer_device IS NOT NULL) THEN l.layer
    ELSE d.layer
  END AS layer,
  d.vjp_device,
  d.a_port,
  d.b_port,
  COALESCE(p.from_device_name_to_VJP_port_A, l.from_device_name_to_VJP_port_A, d.from_device_name_to_VJP_port_A) AS from_device_name_to_VJP_port_A,
  COALESCE(p.from_device_port_to_VJP_port_A, l.from_device_port_to_VJP_port_A, d.from_device_port_to_VJP_port_A) AS from_device_port_to_VJP_port_A,
  COALESCE(
    CASE WHEN p.program_state LIKE 'BROKEN_AT_B%' OR p.program_state = 'BROKEN_A_AND_B' THEN p.patch_b_peer_device END,
    CASE WHEN l.live_state LIKE 'BROKEN_AT_B%' OR l.live_state = 'BROKEN_A_AND_B' THEN l.patch_b_peer_device END,
    p.to_device_name_from_VJP_port_B,
    l.to_device_name_from_VJP_port_B,
    d.to_device_name_from_VJP_port_B
  ) AS to_device_name_from_VJP_port_B,
  COALESCE(
    CASE WHEN p.program_state LIKE 'BROKEN_AT_B%' OR p.program_state = 'BROKEN_A_AND_B' THEN p.patch_b_peer_port END,
    CASE WHEN l.live_state LIKE 'BROKEN_AT_B%' OR l.live_state = 'BROKEN_A_AND_B' THEN l.patch_b_peer_port END,
    p.to_device_port_from_VJP_port_B,
    l.to_device_port_from_VJP_port_B,
    d.to_device_port_from_VJP_port_B
  ) AS to_device_port_from_VJP_port_B,
  COALESCE(p.domain, l.domain, d.domain) AS domain,
  COALESCE(p.net_name, l.net_name, d.net_name) AS net_name,
  CASE
    WHEN p.program_id IS NOT NULL AND (p.patch_a_peer_device IS NOT NULL OR p.patch_b_peer_device IS NOT NULL) THEN 1
    WHEN (l.patch_a_peer_device IS NOT NULL OR l.patch_b_peer_device IS NOT NULL) THEN 1
    ELSE 0
  END AS has_active_patch,
  CASE
    WHEN p.program_id IS NOT NULL AND (p.patch_a_peer_device IS NOT NULL OR p.patch_b_peer_device IS NOT NULL) THEN
      'PROGRAM:' || p.program_id || ':' || d.vjp_device || ':' || CASE
        WHEN p.patch_b_peer_device IS NOT NULL THEN d.b_port
        WHEN p.patch_a_peer_device IS NOT NULL THEN d.a_port
        ELSE d.b_port
      END
    WHEN (l.patch_a_peer_device IS NOT NULL OR l.patch_b_peer_device IS NOT NULL) THEN
      'LIVE:' || d.vjp_device || ':' || CASE
        WHEN l.patch_b_peer_device IS NOT NULL THEN d.b_port
        WHEN l.patch_a_peer_device IS NOT NULL THEN d.a_port
        ELSE d.b_port
      END
    ELSE NULL
  END AS active_patch_ref,
  CASE
    WHEN p.program_id IS NOT NULL AND (p.patch_a_peer_device IS NOT NULL OR p.patch_b_peer_device IS NOT NULL) THEN p.program_id
    WHEN (l.patch_a_peer_device IS NOT NULL OR l.patch_b_peer_device IS NOT NULL) THEN 'LIVE'
    ELSE 'DESIGN'
  END AS status_source,
  CASE
    WHEN p.program_id IS NOT NULL AND (p.patch_a_peer_device IS NOT NULL OR p.patch_b_peer_device IS NOT NULL) THEN p.program_state
    WHEN (l.patch_a_peer_device IS NOT NULL OR l.patch_b_peer_device IS NOT NULL) THEN l.live_state
    ELSE d.link_state
  END AS current_state,
  CASE
    WHEN p.program_id IS NOT NULL AND (p.patch_a_peer_device IS NOT NULL OR p.patch_b_peer_device IS NOT NULL) THEN
      COALESCE(p.from_device_name_to_VJP_port_A || ' ' || p.from_device_port_to_VJP_port_A, '?') || ' -> ' || p.vjp_device || ' ' || p.a_port ||
      ' => ' || p.vjp_device || ' ' || p.b_port ||
      CASE
        WHEN p.program_state = 'BROKEN_AT_B' THEN ' [program break@B] -> ' || COALESCE(p.patch_b_peer_device || ' ' || p.patch_b_peer_port, '?')
        WHEN p.program_state = 'BROKEN_AT_A' THEN ' [program break@A] -> ' || COALESCE(p.patch_a_peer_device || ' ' || p.patch_a_peer_port, '?')
        ELSE ' -> ' || COALESCE(p.to_device_name_from_VJP_port_B || ' ' || p.to_device_port_from_VJP_port_B, '?')
      END
    WHEN (l.patch_a_peer_device IS NOT NULL OR l.patch_b_peer_device IS NOT NULL) THEN l.line
    ELSE d.line
  END AS line
FROM design d
LEFT JOIN live l
  ON l.asb = d.asb AND l.base_layer = d.layer AND l.vjp_device = d.vjp_device AND l.a_port = d.a_port AND l.b_port = d.b_port
LEFT JOIN program p
  ON p.asb = d.asb AND p.base_layer = d.layer AND p.vjp_device = d.vjp_device AND p.a_port = d.a_port AND p.b_port = d.b_port;

CREATE VIEW vjp_design_v AS
WITH cable_ends AS (
  SELECT
    asb,
    layer,
    cable_label,
    a_device AS device_id,
    a_port   AS port_name,
    b_device AS peer_device,
    b_port   AS peer_port,
    net_name,
    domain_raw,
    'A' AS side
  FROM cables
  WHERE a_device IS NOT NULL AND a_port IS NOT NULL

  UNION ALL

  SELECT
    asb,
    layer,
    cable_label,
    b_device AS device_id,
    b_port   AS port_name,
    a_device AS peer_device,
    a_port   AS peer_port,
    net_name,
    domain_raw,
    'B' AS side
  FROM cables
  WHERE b_device IS NOT NULL AND b_port IS NOT NULL
)
SELECT
  d.asb,
  d.layer,
  d.device_id AS vjp_device,
  d.model_id,
  n.a_port,
  n.b_port,
  n.normal_dir,
  n.break_on_a,
  n.break_on_b,
  ca.cable_label AS a_cable_label,
  ca.peer_device AS from_device_name_to_VJP_port_A,
  ca.peer_port   AS from_device_port_to_VJP_port_A,
  cb.cable_label AS b_cable_label,
  cb.peer_device AS to_device_name_from_VJP_port_B,
  cb.peer_port   AS to_device_port_from_VJP_port_B,
  COALESCE(UPPER(ca.domain_raw), UPPER(cb.domain_raw)) AS domain,
  COALESCE(ca.net_name, cb.net_name) AS net_name,
  CASE
    WHEN ca.cable_label IS NOT NULL AND cb.cable_label IS NOT NULL THEN 'THROUGH'
    WHEN ca.cable_label IS NOT NULL THEN 'A_ONLY'
    WHEN cb.cable_label IS NOT NULL THEN 'B_ONLY'
    ELSE 'OPEN'
  END AS link_state,
  CASE
    WHEN ca.cable_label IS NOT NULL AND cb.cable_label IS NOT NULL THEN
      ca.peer_device || ' ' || ca.peer_port || ' -> ' || d.device_id || ' ' || n.a_port || ' => ' || d.device_id || ' ' || n.b_port || ' -> ' || cb.peer_device || ' ' || cb.peer_port
    WHEN ca.cable_label IS NOT NULL THEN
      ca.peer_device || ' ' || ca.peer_port || ' -> ' || d.device_id || ' ' || n.a_port || ' => ' || d.device_id || ' ' || n.b_port || ' -> ?'
    WHEN cb.cable_label IS NOT NULL THEN
      '? -> ' || d.device_id || ' ' || n.a_port || ' => ' || d.device_id || ' ' || n.b_port || ' -> ' || cb.peer_device || ' ' || cb.peer_port
    ELSE
      d.device_id || ' ' || n.a_port || ' => ' || d.device_id || ' ' || n.b_port
  END AS line
FROM devices d
JOIN vjp_normals n
  ON n.model_id = d.model_id
LEFT JOIN cable_ends ca
  ON ca.asb = d.asb AND ca.layer = d.layer AND ca.device_id = d.device_id AND ca.port_name = n.a_port
LEFT JOIN cable_ends cb
  ON cb.asb = d.asb AND cb.layer = d.layer AND cb.device_id = d.device_id AND cb.port_name = n.b_port;

CREATE VIEW vjp_live_v AS
WITH cable_ends AS (
  SELECT asb, layer, cable_label,
         a_device AS device_id, a_port AS port_name,
         b_device AS peer_device, b_port AS peer_port,
         net_name, domain_raw
  FROM cables
  WHERE a_device IS NOT NULL AND a_port IS NOT NULL
  UNION ALL
  SELECT asb, layer, cable_label,
         b_device AS device_id, b_port AS port_name,
         a_device AS peer_device, a_port AS peer_port,
         net_name, domain_raw
  FROM cables
  WHERE b_device IS NOT NULL AND b_port IS NOT NULL
), base AS (
  SELECT
    d.asb,
    lp.layer AS layer,
    lp.base_layer,
    d.device_id AS vjp_device,
    n.a_port,
    n.b_port,
    ca.peer_device AS from_device_name_to_VJP_port_A,
    ca.peer_port   AS from_device_port_to_VJP_port_A,
    cb.peer_device AS to_device_name_from_VJP_port_B,
    cb.peer_port   AS to_device_port_from_VJP_port_B,
    COALESCE(UPPER(ca.domain_raw), UPPER(cb.domain_raw)) AS domain,
    COALESCE(ca.net_name, cb.net_name) AS net_name,
    lpa.peer_device AS patch_a_peer_device,
    lpa.peer_port   AS patch_a_peer_port,
    lpa.patch_role  AS patch_a_role,
    lpa.active      AS patch_a_active,
    lpb.peer_device AS patch_b_peer_device,
    lpb.peer_port   AS patch_b_peer_port,
    lpb.patch_role  AS patch_b_role,
    lpb.active      AS patch_b_active
  FROM devices d
  JOIN vjp_normals n ON n.model_id = d.model_id
  JOIN (SELECT DISTINCT asb, layer, base_layer, device_id FROM vjp_live_patches WHERE active = 1) lp
    ON lp.asb = d.asb AND lp.base_layer = d.layer AND lp.device_id = d.device_id
  LEFT JOIN cable_ends ca ON ca.asb = d.asb AND ca.layer = d.layer AND ca.device_id = d.device_id AND ca.port_name = n.a_port
  LEFT JOIN cable_ends cb ON cb.asb = d.asb AND cb.layer = d.layer AND cb.device_id = d.device_id AND cb.port_name = n.b_port
  LEFT JOIN vjp_live_patches lpa ON lpa.asb = d.asb AND lpa.base_layer = d.layer AND lpa.device_id = d.device_id AND lpa.port_name = n.a_port AND lpa.active = 1
  LEFT JOIN vjp_live_patches lpb ON lpb.asb = d.asb AND lpb.base_layer = d.layer AND lpb.device_id = d.device_id AND lpb.port_name = n.b_port AND lpb.active = 1
)
SELECT
  asb, layer, base_layer, vjp_device, a_port, b_port,
  from_device_name_to_VJP_port_A, from_device_port_to_VJP_port_A,
  to_device_name_from_VJP_port_B, to_device_port_from_VJP_port_B,
  patch_a_peer_device, patch_a_peer_port, patch_a_role,
  patch_b_peer_device, patch_b_peer_port, patch_b_role,
  domain, net_name,
  CASE
    WHEN patch_a_active = 1 AND patch_b_active = 1 THEN 'BROKEN_A_AND_B'
    WHEN patch_a_active = 1 THEN 'BROKEN_AT_A'
    WHEN patch_b_active = 1 THEN 'BROKEN_AT_B'
    WHEN from_device_name_to_VJP_port_A IS NOT NULL AND to_device_name_from_VJP_port_B IS NOT NULL THEN 'THROUGH'
    WHEN from_device_name_to_VJP_port_A IS NOT NULL THEN 'A_ONLY'
    WHEN to_device_name_from_VJP_port_B IS NOT NULL THEN 'B_ONLY'
    ELSE 'OPEN'
  END AS live_state,
  CASE
    WHEN patch_b_active = 1 THEN
      COALESCE(from_device_name_to_VJP_port_A || ' ' || from_device_port_to_VJP_port_A, '?') || ' -> ' ||
      vjp_device || ' ' || a_port || ' => ' || vjp_device || ' ' || b_port ||
      ' [break@B] -> ' || COALESCE(patch_b_peer_device || ' ' || patch_b_peer_port, '?') ||
      ' ; rear-B disconnected: ' || COALESCE(to_device_name_from_VJP_port_B || ' ' || to_device_port_from_VJP_port_B, '?')
    WHEN patch_a_active = 1 THEN
      COALESCE(from_device_name_to_VJP_port_A || ' ' || from_device_port_to_VJP_port_A, '?') || ' -> ' ||
      vjp_device || ' ' || a_port || ' [break@A] -> ' || COALESCE(patch_a_peer_device || ' ' || patch_a_peer_port, '?') ||
      ' ; rear-B disconnected: ' || COALESCE(to_device_name_from_VJP_port_B || ' ' || to_device_port_from_VJP_port_B, '?')
    WHEN from_device_name_to_VJP_port_A IS NOT NULL AND to_device_name_from_VJP_port_B IS NOT NULL THEN
      from_device_name_to_VJP_port_A || ' ' || from_device_port_to_VJP_port_A || ' -> ' || vjp_device || ' ' || a_port ||
      ' => ' || vjp_device || ' ' || b_port || ' -> ' || to_device_name_from_VJP_port_B || ' ' || to_device_port_from_VJP_port_B
    WHEN from_device_name_to_VJP_port_A IS NOT NULL THEN
      from_device_name_to_VJP_port_A || ' ' || from_device_port_to_VJP_port_A || ' -> ' || vjp_device || ' ' || a_port ||
      ' => ' || vjp_device || ' ' || b_port || ' -> ?'
    WHEN to_device_name_from_VJP_port_B IS NOT NULL THEN
      '? -> ' || vjp_device || ' ' || a_port || ' => ' || vjp_device || ' ' || b_port ||
      ' -> ' || to_device_name_from_VJP_port_B || ' ' || to_device_port_from_VJP_port_B
    ELSE
      vjp_device || ' ' || a_port || ' => ' || vjp_device || ' ' || b_port
  END AS line
FROM base;

CREATE VIEW vjp_program_v AS
WITH active_program AS (
  SELECT program_id FROM vjp_active_program WHERE slot_id = 1
), cable_ends AS (
  SELECT asb, layer, cable_label,
         a_device AS device_id, a_port AS port_name,
         b_device AS peer_device, b_port AS peer_port,
         net_name, domain_raw
  FROM cables
  WHERE a_device IS NOT NULL AND a_port IS NOT NULL
  UNION ALL
  SELECT asb, layer, cable_label,
         b_device AS device_id, b_port AS port_name,
         a_device AS peer_device, a_port AS peer_port,
         net_name, domain_raw
  FROM cables
  WHERE b_device IS NOT NULL AND b_port IS NOT NULL
), base AS (
  SELECT
    d.asb,
    pp.layer AS layer,
    pp.base_layer,
    ap.program_id,
    d.device_id AS vjp_device,
    n.a_port,
    n.b_port,
    ca.peer_device AS from_device_name_to_VJP_port_A,
    ca.peer_port   AS from_device_port_to_VJP_port_A,
    cb.peer_device AS to_device_name_from_VJP_port_B,
    cb.peer_port   AS to_device_port_from_VJP_port_B,
    COALESCE(UPPER(ca.domain_raw), UPPER(cb.domain_raw)) AS domain,
    COALESCE(ca.net_name, cb.net_name) AS net_name,
    ppa.peer_device AS patch_a_peer_device,
    ppa.peer_port   AS patch_a_peer_port,
    ppa.patch_role  AS patch_a_role,
    ppa.active      AS patch_a_active,
    ppb.peer_device AS patch_b_peer_device,
    ppb.peer_port   AS patch_b_peer_port,
    ppb.patch_role  AS patch_b_role,
    ppb.active      AS patch_b_active
  FROM devices d
  JOIN vjp_normals n ON n.model_id = d.model_id
  JOIN active_program ap
  JOIN (SELECT DISTINCT program_id, asb, layer, base_layer, device_id FROM vjp_program_patches WHERE active = 1) pp
    ON pp.program_id = ap.program_id AND pp.asb = d.asb AND pp.base_layer = d.layer AND pp.device_id = d.device_id
  LEFT JOIN cable_ends ca ON ca.asb = d.asb AND ca.layer = d.layer AND ca.device_id = d.device_id AND ca.port_name = n.a_port
  LEFT JOIN cable_ends cb ON cb.asb = d.asb AND cb.layer = d.layer AND cb.device_id = d.device_id AND cb.port_name = n.b_port
  LEFT JOIN vjp_program_patches ppa ON ppa.program_id = ap.program_id AND ppa.asb = d.asb AND ppa.base_layer = d.layer AND ppa.device_id = d.device_id AND ppa.port_name = n.a_port AND ppa.active = 1
  LEFT JOIN vjp_program_patches ppb ON ppb.program_id = ap.program_id AND ppb.asb = d.asb AND ppb.base_layer = d.layer AND ppb.device_id = d.device_id AND ppb.port_name = n.b_port AND ppb.active = 1
)
SELECT
  asb, layer, base_layer, program_id, vjp_device, a_port, b_port,
  from_device_name_to_VJP_port_A, from_device_port_to_VJP_port_A,
  to_device_name_from_VJP_port_B, to_device_port_from_VJP_port_B,
  patch_a_peer_device, patch_a_peer_port, patch_a_role,
  patch_b_peer_device, patch_b_peer_port, patch_b_role,
  domain, net_name,
  CASE
    WHEN patch_a_active = 1 AND patch_b_active = 1 THEN 'BROKEN_A_AND_B'
    WHEN patch_a_active = 1 THEN 'BROKEN_AT_A'
    WHEN patch_b_active = 1 THEN 'BROKEN_AT_B'
    WHEN from_device_name_to_VJP_port_A IS NOT NULL AND to_device_name_from_VJP_port_B IS NOT NULL THEN 'THROUGH'
    WHEN from_device_name_to_VJP_port_A IS NOT NULL THEN 'A_ONLY'
    WHEN to_device_name_from_VJP_port_B IS NOT NULL THEN 'B_ONLY'
    ELSE 'OPEN'
  END AS program_state
FROM base;

COMMIT;
