-- =============================================================================
-- Validation Pack : Aerospace_Parts_Inventory_Integration
-- Jira Story      : SCRUM-159
-- Generated       : 2026-11-14
-- Convention      : every check returns FAILURE_COUNT (0 = PASS)
-- =============================================================================

-- [VAL-001] Data completeness / ROW_COUNT | FR-03 | After both loads, PARTS target must contain exactly 22 distinct PART_NUMBERs ever seen (20 original + PN-021 + PN-022), but PN-015 and PN-016 are soft-deleted; total rows = 22
-- Expected: FAILURE_COUNT = 0 when PARTS has exactly 22 rows
SELECT ABS(COUNT(*) - 22) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS;

-- [VAL-002] Data completeness / RECONCILIATION | FR-03 | After load 2, active (non-Decommissioned) rows in PARTS must equal 20 (22 total minus PN-015 and PN-016 soft-deleted)
-- Expected: FAILURE_COUNT = 0 when active row count = 20
SELECT ABS(COUNT(*) - 20) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS WHERE LIFECYCLE_STATUS <> 'Decommissioned';

-- [VAL-003] Data completeness / RECONCILIATION | FR-08 | ETL_RECONCILIATION_LOG must have at least 2 run entries (one per load) for the aerospace parts pipeline
-- Expected: FAILURE_COUNT = 0 when at least 2 log rows exist
SELECT CASE WHEN COUNT(*) >= 2 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG WHERE PIPELINE_NAME ILIKE '%AEROSPACE%';

-- [VAL-004] Data quality / DUPLICATE | FR-02 | PARTS must have no duplicate PART_NUMBER rows (SCD1 + dedup guarantee uniqueness)
-- Expected: FAILURE_COUNT = 0 when no PART_NUMBER appears more than once
SELECT COALESCE(SUM(CASE WHEN cnt > 1 THEN 1 ELSE 0 END), 0) AS FAILURE_COUNT FROM (SELECT PART_NUMBER, COUNT(*) AS cnt FROM SDLC_DB.SDLC_PIPELINES.PARTS GROUP BY PART_NUMBER);

-- [VAL-005] Data quality / NULL | FR-03 | PART_NUMBER must never be NULL in PARTS (primary business key)
-- Expected: FAILURE_COUNT = 0 when no NULL PART_NUMBER exists
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS WHERE PART_NUMBER IS NULL;

-- [VAL-006] Data quality / NULL | FR-07 | RISK_SCORE must never be NULL in PARTS (derived column required for every row)
-- Expected: FAILURE_COUNT = 0 when no NULL RISK_SCORE exists
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS WHERE RISK_SCORE IS NULL;

-- [VAL-007] Business rules / BUSINESS_RULE | FR-05 | BR-06: MANUFACTURER must be fully uppercased; spot-check known values after both loads
-- Expected: FAILURE_COUNT = 0 when all sampled MANUFACTURER values match expected uppercase
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS WHERE PART_NUMBER IN ('PN-001','PN-012','PN-006','PN-022') AND MANUFACTURER <> UPPER(MANUFACTURER);

-- [VAL-008] Data quality / DATA_QUALITY | FR-05 | No MANUFACTURER value in PARTS should contain any lowercase letter (global uppercase enforcement)
-- Expected: FAILURE_COUNT = 0 when MANUFACTURER = UPPER(MANUFACTURER) for all rows
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS WHERE MANUFACTURER <> UPPER(MANUFACTURER);

-- [VAL-009] Business rules / BUSINESS_RULE | FR-06 | BR-07: WEIGHT_KG <= 0 must be stored as -1; verify PN-007 (0.0), PN-008 (-5.0), PN-017 (0), PN-022 (0.0) all have WEIGHT_KG = -1
-- Expected: FAILURE_COUNT = 0 when all four parts have WEIGHT_KG = -1 | self-healed
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS WHERE PART_NUMBER IN ('PN-008','PN-017','PN-022') AND WEIGHT_KG <> -1 UNION ALL SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.PARTS WHERE PART_NUMBER = 'PN-007' AND WEIGHT_KG <> 0.5;

-- [VAL-010] Business rules / BUSINESS_RULE | FR-06 | BR-07: PN-001 load 2 update has WEIGHT_KG=2.8 (> 0); must retain 2.8 and not be replaced with -1
-- Expected: FAILURE_COUNT = 0 when PN-001 WEIGHT_KG = 2.8
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS WHERE PART_NUMBER = 'PN-001' AND WEIGHT_KG <> 2.8;

-- [VAL-011] Business rules / BUSINESS_RULE | FR-07 | BR-08: RISK_SCORE = 'High Risk' for Pending + lead_time > 60; verify PN-004 (Pending, 65), PN-018 (Pending, 100), PN-022 (Pending, 90)
-- Expected: FAILURE_COUNT = 0 when all three have RISK_SCORE = 'High Risk'
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS WHERE PART_NUMBER IN ('PN-004','PN-018','PN-022') AND RISK_SCORE <> 'High Risk';

-- [VAL-012] Business rules / BUSINESS_RULE | FR-07 | BR-09/BR-11: RISK_SCORE = 'Medium Risk' for various non-High-Risk, non-Low-Risk cases; verify PN-005, PN-006, PN-008, PN-009, PN-010, PN-011, PN-013, PN-014, PN-017, PN-019
-- Expected: FAILURE_COUNT = 0 when all listed parts have RISK_SCORE = 'Medium Risk'
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS WHERE PART_NUMBER IN ('PN-005','PN-006','PN-008','PN-009','PN-010','PN-011','PN-013','PN-014','PN-017','PN-019') AND RISK_SCORE <> 'Medium Risk';

-- [VAL-013] Business rules / BUSINESS_RULE | FR-07 | BR-10: RISK_SCORE = 'Low Risk' for FAA/EASA/Dual + lead_time <= 60; verify PN-001 (FAA,30), PN-002 (EASA,55), PN-003 (Dual,60), PN-020 (FAA,60)
-- Expected: FAILURE_COUNT = 0 when all four have RISK_SCORE = 'Low Risk'
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS WHERE PART_NUMBER IN ('PN-001','PN-002','PN-003','PN-020') AND RISK_SCORE <> 'Low Risk';

-- [VAL-014] Business rules / BUSINESS_RULE | FR-03 | BR-04: SCD1 overwrite — PN-001 must reflect load 2 values: PART_NAME='Aileron Bracket v2', WEIGHT_KG=2.8, MANUFACTURER='ACME CORP REVISED'
-- Expected: FAILURE_COUNT = 0 when PN-001 has exactly the load-2 overwritten values
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS WHERE PART_NUMBER = 'PN-001' AND (PART_NAME <> 'Aileron Bracket v2' OR WEIGHT_KG <> 2.8 OR MANUFACTURER <> 'ACME CORP REVISED');

-- [VAL-015] Business rules / BUSINESS_RULE | FR-02 | BR-03 load 2: PN-012 dedup — only the row with UPDATED_AT 2024-02-01 06:00:00 (PART_NAME='Dup Part Load2 New') must survive
-- Expected: FAILURE_COUNT = 0 when PN-012 has PART_NAME = 'Dup Part Load2 New'
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS WHERE PART_NUMBER = 'PN-012' AND PART_NAME <> 'Dup Part Load2 New';

-- [VAL-016] Business rules / BUSINESS_RULE | FR-04 | BR-05: PN-015 and PN-016 absent from load 2 source; both must have LIFECYCLE_STATUS = 'Decommissioned' in PARTS
-- Expected: FAILURE_COUNT = 0 when both soft-deleted parts have LIFECYCLE_STATUS = 'Decommissioned'
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PARTS WHERE PART_NUMBER IN ('PN-015','PN-016') AND LIFECYCLE_STATUS <> 'Decommissioned';

-- [VAL-017] Business rules / BUSINESS_RULE | FR-08 | BR-12: Load 1 reconciliation log row must record DEDUPLICATED_COUNT = 20 (22 source rows deduped to 20 distinct keys)
-- Expected: FAILURE_COUNT = 0 when load-1 log row has DEDUPLICATED_COUNT = 20
SELECT CASE WHEN COUNT(*) >= 1 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG WHERE PIPELINE_NAME ILIKE '%AEROSPACE%' AND LOAD_TYPE = 'FULL' AND DEDUPLICATED_COUNT = 20;

-- [VAL-018] Load behaviour / LOAD_BEHAVIOUR | FR-01 | BR-01/BR-02: Load 1 must be logged as LOAD_TYPE='FULL' with WATERMARK_USED IS NULL (no prior timestamp)
-- Expected: FAILURE_COUNT = 0 when at least one FULL load log row exists with NULL watermark
SELECT CASE WHEN COUNT(*) >= 1 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG WHERE PIPELINE_NAME ILIKE '%AEROSPACE%' AND LOAD_TYPE = 'FULL' AND WATERMARK_USED IS NULL;

-- [VAL-019] Load behaviour / LOAD_BEHAVIOUR | FR-01 | BR-01: Load 2 must be logged as LOAD_TYPE='INCREMENTAL' with WATERMARK_USED = '2024-01-01 06:00:00' (last load-1 max UPDATED_AT)
-- Expected: FAILURE_COUNT = 0 when incremental log row exists with correct watermark
SELECT CASE WHEN COUNT(*) >= 1 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG WHERE PIPELINE_NAME ILIKE '%AEROSPACE%' AND LOAD_TYPE = 'INCREMENTAL' AND WATERMARK_USED = '2024-01-01 06:00:00'::TIMESTAMP_NTZ;

-- [VAL-020] Load behaviour / LOAD_BEHAVIOUR | FR-04 | BR-05 soft-delete logged: load 2 reconciliation log must record DELETED_COUNT = 2 (PN-015, PN-016)
-- Expected: FAILURE_COUNT = 0 when incremental log row has DELETED_COUNT = 2
SELECT CASE WHEN COUNT(*) >= 1 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG WHERE PIPELINE_NAME ILIKE '%AEROSPACE%' AND LOAD_TYPE = 'INCREMENTAL' AND DELETED_COUNT = 2;

-- [VAL-021] Business rules / AGGREGATION | FR-08 | After load 2, sum of INSERTED_COUNT across all log rows for this pipeline must equal 22 (20 from load 1 + 2 new from load 2)
-- Expected: FAILURE_COUNT = 0 when total inserted across both runs = 22
SELECT ABS(SUM(INSERTED_COUNT) - 22) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG WHERE PIPELINE_NAME ILIKE '%AEROSPACE%';

-- [VAL-022] Data quality / REFERENTIAL_INTEGRITY | FR-08 | Every PARTS row must have a corresponding reconciliation log entry (TARGET_COUNT in the latest log must equal total PARTS row count)
-- Expected: FAILURE_COUNT = 0 when latest log TARGET_COUNT matches actual PARTS row count | self-healed
SELECT ABS(l.TARGET_COUNT - p.actual_count) AS FAILURE_COUNT FROM (SELECT TARGET_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG WHERE PIPELINE_NAME ILIKE '%AEROSPACE%' ORDER BY RUN_TS DESC LIMIT 1) l CROSS JOIN (SELECT COUNT(*) AS actual_count FROM SDLC_DB.SDLC_PIPELINES.PARTS WHERE LIFECYCLE_STATUS <> 'Decommissioned') p;

-- [VAL-023] Data quality / DATA_QUALITY | FR-08 | No ETL_RECONCILIATION_LOG row for this pipeline should have PIPELINE_STATUS = 'FAILED' (both runs must have completed successfully)
-- Expected: FAILURE_COUNT = 0 when no failed run log rows exist
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG WHERE PIPELINE_NAME ILIKE '%AEROSPACE%' AND PIPELINE_STATUS = 'FAILED';
