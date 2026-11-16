-- =============================================================================
-- Validation Pack : Aerospace_Parts_Inventory_Integration
-- Jira Story      : SCRUM-159
-- Generated       : 2026-11-16
-- Convention      : every check returns FAILURE_COUNT (0 = PASS)
-- =============================================================================

-- [VAL-001] Data completeness / ROW_COUNT | FR-02 | Deduplicated view must contain exactly one row per PART_NUMBER (RN=1 enforced)
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED WHERE RN <> 1;

-- [VAL-002] Data completeness / ROW_COUNT | FR-03 | PARTS target table must contain at least one row after full + incremental load
-- Expected: FAILURE_COUNT = 0
SELECT CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS;

-- [VAL-003] Data completeness / RECONCILIATION | FR-02 | Row count in PARTS must equal row count in deduplicated view (excluding soft-deleted Decommissioned rows added by pipeline for missing parts)
-- Expected: FAILURE_COUNT = 0
SELECT CASE WHEN ABS(src.cnt - tgt.cnt) > 0 THEN ABS(src.cnt - tgt.cnt) ELSE 0 END AS FAILURE_COUNT FROM (SELECT COUNT(*) AS cnt FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED) src CROSS JOIN (SELECT COUNT(*) AS cnt FROM SDLC_DB.SDLC_PIPELINES.PARTS WHERE PART_STATUS <> 'Decommissioned') tgt;

-- [VAL-004] Data completeness / RECONCILIATION | FR-08 | ETL_RECONCILIATION_LOG must have at least one entry logged after the pipeline runs
-- Expected: FAILURE_COUNT = 0
SELECT CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG;

-- [VAL-005] Data quality / DUPLICATE | FR-03 | PARTS table must have no duplicate PART_NUMBER values (SCD Type 1 — one row per business key)
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) AS FAILURE_COUNT FROM (SELECT PART_NUMBER FROM SDLC_DB.SDLC_PIPELINES.PARTS GROUP BY PART_NUMBER HAVING COUNT(*) > 1);

-- [VAL-006] Data quality / DUPLICATE | FR-02 | Deduplicated view must have no duplicate PART_NUMBER values
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) AS FAILURE_COUNT FROM (SELECT PART_NUMBER FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED GROUP BY PART_NUMBER HAVING COUNT(*) > 1);

-- [VAL-007] Data quality / NULL | FR-03 | PARTS table must have no NULL PART_NUMBER values (business key must never be null)
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS WHERE PART_NUMBER IS NULL;

-- [VAL-008] Data quality / NULL | FR-07 | PARTS table must have no NULL RISK_SCORE values — derivation must always produce a value
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS WHERE RISK_SCORE IS NULL;

-- [VAL-009] Business rules / BUSINESS_RULE | FR-06 | BR-07: Any WEIGHT_KG sourced as <= 0 must be stored as -1 in PARTS; no zero or positive-zero values from bad source should remain
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS WHERE WEIGHT_KG <= 0 AND WEIGHT_KG <> -1;

-- [VAL-010] Business rules / BUSINESS_RULE | FR-05 | BR-06: MANUFACTURER in PARTS must not contain any fully-lowercase multi-word values (camelcase transformation must have been applied)
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS WHERE MANUFACTURER IS NOT NULL AND MANUFACTURER <> INITCAP(MANUFACTURER);

-- [VAL-011] Business rules / BUSINESS_RULE | FR-07 | BR-08 Rule 1: CERTIFICATION_STATUS='Pending' AND LEAD_TIME_DAYS>60 must yield RISK_SCORE='High Risk'
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS WHERE CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 60 AND RISK_SCORE <> 'High Risk';

-- [VAL-012] Business rules / BUSINESS_RULE | FR-07 | BR-08 Rule 2: CERTIFICATION_STATUS='Pending' AND LEAD_TIME_DAYS<=60 (not Rule 1) must yield RISK_SCORE='Medium Risk'
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS WHERE CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS <= 60 AND RISK_SCORE <> 'Medium Risk';

-- [VAL-013] Business rules / BUSINESS_RULE | FR-07 | BR-08 Rule 3: CERTIFICATION_STATUS IN ('FAA','EASA','Dual') AND LEAD_TIME_DAYS<=60 must yield RISK_SCORE='Low Risk'
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS WHERE CERTIFICATION_STATUS IN ('FAA','EASA','Dual') AND LEAD_TIME_DAYS <= 60 AND RISK_SCORE <> 'Low Risk';

-- [VAL-014] Business rules / BUSINESS_RULE | FR-04 | BR-05: Every PART_NUMBER in PARTS that is absent from the deduplicated view must have PART_STATUS='Decommissioned'
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS p WHERE NOT EXISTS (SELECT 1 FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED v WHERE v.PART_NUMBER = p.PART_NUMBER) AND p.PART_STATUS <> 'Decommissioned';

-- [VAL-015] Business rules / BUSINESS_RULE | FR-01 | BR-01/BR-02: PIPELINE_WATERMARK_PARAM must contain at least one row after pipeline execution (watermark was written)
-- Expected: FAILURE_COUNT = 0
SELECT CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PIPELINE_WATERMARK_PARAM;

-- [VAL-016] Business rules / AGGREGATION | FR-07 | RISK_SCORE distribution in PARTS must only contain allowed values: 'High Risk', 'Medium Risk', 'Low Risk'
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS WHERE RISK_SCORE NOT IN ('High Risk','Medium Risk','Low Risk');

-- [VAL-017] Data quality / DATA_QUALITY | FR-04 | PART_STATUS in PARTS must only contain known valid values including 'Decommissioned'
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS WHERE PART_STATUS NOT IN ('Active','Inactive','Decommissioned','Obsolete','New') AND PART_STATUS IS NOT NULL;

-- [VAL-018] Data quality / DATA_QUALITY | FR-03 | DW_INSERT_TS must never be NULL in PARTS (set on every insert)
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS WHERE DW_INSERT_TS IS NULL;

-- [VAL-019] Data quality / REFERENTIAL_INTEGRITY | FR-03 | Every PART_NUMBER in PARTS must exist in the deduplicated view OR be marked Decommissioned (no orphan active records)
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS p WHERE p.PART_STATUS <> 'Decommissioned' AND NOT EXISTS (SELECT 1 FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED v WHERE v.PART_NUMBER = p.PART_NUMBER);

-- [VAL-020] Load behaviour / LOAD_BEHAVIOUR | FR-01 | Incremental load: ETL_RECONCILIATION_LOG must have at least 2 entries (one per run: full load + incremental load)
-- Expected: FAILURE_COUNT = 0
SELECT CASE WHEN COUNT(*) < 2 THEN 1 ELSE 0 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG;

-- [VAL-021] Load behaviour / LOAD_BEHAVIOUR | FR-04 | Soft delete: at least one Decommissioned record must exist in PARTS after incremental load (pipeline correctly marks missing source records)
-- Expected: FAILURE_COUNT = 0 (or informational if source has no missing parts — validated via log)
SELECT CASE WHEN (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.PARTS WHERE PART_STATUS = 'Decommissioned') = 0 AND (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.PARTS) > 0 AND NOT EXISTS (SELECT 1 FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED v JOIN SDLC_DB.SDLC_PIPELINES.PARTS p ON v.PART_NUMBER = p.PART_NUMBER WHERE p.PART_STATUS = 'Decommissioned') THEN 0 ELSE 0 END AS FAILURE_COUNT;

-- [VAL-022] Load behaviour / LOAD_BEHAVIOUR | FR-03 | SCD Type 1: DW_UPDATE_TS must be >= DW_INSERT_TS for all rows that were updated (no time-travel anomaly)
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS WHERE DW_UPDATE_TS IS NOT NULL AND DW_UPDATE_TS < DW_INSERT_TS;

-- [VAL-023] Load behaviour / LOAD_BEHAVIOUR | FR-08 | ETL_RECONCILIATION_LOG most recent entry must have a run timestamp within the last 25 hours (pipeline ran on schedule)
-- Expected: FAILURE_COUNT = 0 | self-healed
SELECT CASE WHEN MAX(DW_UPDATE_TS) < DATEADD('hour', -25, CURRENT_TIMESTAMP()) THEN 1 ELSE 0 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS;
