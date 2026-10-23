-- =============================================================================
-- Validation Pack : Aerospace_Parts_Inventory_Integration
-- Jira Story      : SCRUM-158
-- Generated       : 2026-10-23
-- Convention      : every check returns FAILURE_COUNT (0 = PASS)
-- =============================================================================

-- [VAL-001] Data completeness / ROW_COUNT | FR-01 | Target AEROSPACE_PARTS must contain exactly 20 distinct PART_NUMBERs ever loaded (18 active + 2 decommissioned = 20 total rows after both loads)
-- Expected: FAILURE_COUNT = 0 when total distinct PART_NUMBER rows = 20
SELECT CASE WHEN COUNT(*) = 20 THEN 0 ELSE COUNT(*) END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS;

-- [VAL-002] Data completeness / RECONCILIATION | FR-01 | Active (non-Decommissioned) rows in target must match distinct PART_NUMBERs currently in source (18 after load 2)
-- Expected: FAILURE_COUNT = 0 when active target rows = 18
SELECT CASE WHEN (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS WHERE STATUS <> 'Decommissioned') = (SELECT COUNT(DISTINCT PART_NUMBER) FROM IDEA_2_DB.PUBLIC.AEROSPACE_PARTS_SOURCE) THEN 0 ELSE 1 END AS FAILURE_COUNT;

-- [VAL-003] Data quality / DUPLICATE | FR-02 | Target AEROSPACE_PARTS must have no duplicate PART_NUMBER rows (each key appears exactly once after deduplication and SCD-1 merge)
-- Expected: FAILURE_COUNT = 0 when no PART_NUMBER appears more than once
SELECT COUNT(*) AS FAILURE_COUNT FROM (SELECT PART_NUMBER FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS GROUP BY PART_NUMBER HAVING COUNT(*) > 1);

-- [VAL-004] Data quality / NULL | FR-03 | Mandatory columns PART_NUMBER, PART_NAME, MANUFACTURER, STATUS must have no NULLs in target
-- Expected: FAILURE_COUNT = 0 when no NULLs in key columns
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS WHERE PART_NUMBER IS NULL OR PART_NAME IS NULL OR MANUFACTURER IS NULL OR STATUS IS NULL;

-- [VAL-005] Data quality / DATA_QUALITY | FR-05 | MANUFACTURER must be fully uppercase for all rows (BR-06 transformation applied)
-- Expected: FAILURE_COUNT = 0 when MANUFACTURER = UPPER(MANUFACTURER) for all rows
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS WHERE MANUFACTURER <> UPPER(MANUFACTURER);

-- [VAL-006] Data quality / DATA_QUALITY | FR-06 | WEIGHT_KG must never be 0 or any negative value other than -1 (BR-07: values <= 0 replaced with -1)
-- Expected: FAILURE_COUNT = 0 when no WEIGHT_KG is <= 0 except exactly -1
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS WHERE WEIGHT_KG <= 0 AND WEIGHT_KG <> -1;

-- [VAL-007] Business rules / BUSINESS_RULE | FR-07 | BR-08: High Risk rows — PN-004, PN-005, PN-011, PN-019 must all have RISK_SCORE='High Risk' (Pending + LEAD_TIME_DAYS > 60)
-- Expected: FAILURE_COUNT = 0 when all 4 specified parts have RISK_SCORE='High Risk'
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS WHERE PART_NUMBER IN ('PN-004','PN-005','PN-011','PN-019') AND RISK_SCORE <> 'High Risk';

-- [VAL-008] Business rules / BUSINESS_RULE | FR-07 | BR-09/BR-11: Medium Risk rows — PN-009, PN-015, PN-008, PN-006, PN-013, PN-010, PN-012, PN-016 must have RISK_SCORE='Medium Risk'
-- Expected: FAILURE_COUNT = 0 when all 8 specified parts have RISK_SCORE='Medium Risk'
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS WHERE PART_NUMBER IN ('PN-009','PN-015','PN-008','PN-006','PN-013','PN-010','PN-012','PN-016') AND RISK_SCORE <> 'Medium Risk';

-- [VAL-009] Business rules / BUSINESS_RULE | FR-07 | BR-10: Low Risk rows — PN-001, PN-002, PN-003, PN-007, PN-014, PN-018, PN-020 must have RISK_SCORE='Low Risk'
-- Expected: FAILURE_COUNT = 0 when all 7 specified parts have RISK_SCORE='Low Risk'
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS WHERE PART_NUMBER IN ('PN-001','PN-002','PN-003','PN-007','PN-014','PN-018','PN-020') AND RISK_SCORE <> 'Low Risk';

-- [VAL-010] Business rules / BUSINESS_RULE | FR-04 | BR-05: PN-015 and PN-017 absent from load-2 source extract must have STATUS='Decommissioned' in target
-- Expected: FAILURE_COUNT = 0 when both decommissioned parts have correct status
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS WHERE PART_NUMBER IN ('PN-015','PN-017') AND STATUS <> 'Decommissioned';

-- [VAL-011] Business rules / BUSINESS_RULE | FR-03 | BR-04: SCD Type 1 — PN-001 after load 2 must have PART_NAME='Aileron Bracket v2' and WEIGHT_KG=13.0 (overwritten, no prior version)
-- Expected: FAILURE_COUNT = 0 when PN-001 reflects load-2 values
SELECT CASE WHEN COUNT(*) = 1 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS WHERE PART_NUMBER = 'PN-001' AND PART_NAME = 'Aileron Bracket v2' AND WEIGHT_KG = 13.0;

-- [VAL-012] Business rules / BUSINESS_RULE | FR-02 | BR-03: PN-003 dedup — retained record must have PART_NAME='Fuel Valve' and WEIGHT_KG=2.3 (latest UPDATED_AT 10:00 wins)
-- Expected: FAILURE_COUNT = 0 when PN-003 has correct deduplicated values
SELECT CASE WHEN COUNT(*) = 1 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS WHERE PART_NUMBER = 'PN-003' AND PART_NAME = 'Fuel Valve' AND WEIGHT_KG = 2.3;

-- [VAL-013] Business rules / BUSINESS_RULE | FR-06 | BR-07: PN-004 (source WEIGHT_KG=0), PN-005 (source WEIGHT_KG=-5.0), PN-011 (load-2 source WEIGHT_KG=-1.0) must all store WEIGHT_KG=-1
-- Expected: FAILURE_COUNT = 0 when all 3 parts have WEIGHT_KG=-1
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS WHERE PART_NUMBER IN ('PN-004','PN-005','PN-011') AND WEIGHT_KG <> -1;

-- [VAL-014] Business rules / BUSINESS_RULE | FR-05 | BR-06: Spot-check specific MANUFACTURER uppercasing — PN-013 must be 'BOEING', PN-004 must be 'SAFRAN', PN-019 must be 'ARTEX'
-- Expected: FAILURE_COUNT = 0 when all 3 parts have correctly uppercased MANUFACTURER
SELECT COUNT(*) AS FAILURE_COUNT FROM (SELECT PART_NUMBER, MANUFACTURER FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS WHERE (PART_NUMBER='PN-013' AND MANUFACTURER<>'BOEING') OR (PART_NUMBER='PN-004' AND MANUFACTURER<>'SAFRAN') OR (PART_NUMBER='PN-019' AND MANUFACTURER<>'ARTEX'));

-- [VAL-015] Load behaviour / LOAD_BEHAVIOUR | FR-08 | BR-12: ETL_RECONCILIATION_LOG must contain at least 2 records (one per pipeline run) after both loads complete
-- Expected: FAILURE_COUNT = 0 when log has >= 2 records
SELECT CASE WHEN COUNT(*) >= 2 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG;

-- [VAL-016] Load behaviour / LOAD_BEHAVIOUR | FR-08 | BR-12: Most recent ETL_RECONCILIATION_LOG record must have non-NULL source_count, target_count, inserted_count, updated_count, soft_deleted_count, and run_timestamp
-- Expected: FAILURE_COUNT = 0 when latest log row has no NULLs in required reconciliation columns
SELECT CASE WHEN source_count IS NULL OR target_count IS NULL OR inserted_count IS NULL OR updated_count IS NULL OR soft_deleted_count IS NULL OR run_timestamp IS NULL THEN 1 ELSE 0 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG ORDER BY run_timestamp DESC LIMIT 1;

-- [VAL-017] Load behaviour / LOAD_BEHAVIOUR | FR-01 | BR-01/BR-02: Incremental load 2 must have processed exactly 7 rows from source (4 changed + 3 new keys qualifying UPDATED_AT > '2024-01-01 23:00:00'); verify via log inserted_count + updated_count = 7 for the second run
-- Expected: FAILURE_COUNT = 0 when second log record shows inserted_count + updated_count = 7
SELECT CASE WHEN (inserted_count + updated_count) = 7 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM (SELECT inserted_count, updated_count, run_timestamp FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG ORDER BY run_timestamp ASC LIMIT 1 OFFSET 1);

-- [VAL-018] Load behaviour / LOAD_BEHAVIOUR | FR-04 | BR-05: Second ETL_RECONCILIATION_LOG record must show soft_deleted_count = 2 (PN-015 and PN-017 decommissioned in load 2)
-- Expected: FAILURE_COUNT = 0 when second log record has soft_deleted_count = 2
SELECT CASE WHEN soft_deleted_count = 2 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM (SELECT soft_deleted_count, run_timestamp FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG ORDER BY run_timestamp ASC LIMIT 1 OFFSET 1);

-- [VAL-019] Business rules / AGGREGATION | FR-07 | RISK_SCORE distribution in target must be exactly: 4 High Risk, 8 Medium Risk, 7 Low Risk (active rows only, excluding Decommissioned)
-- Expected: FAILURE_COUNT = 0 when risk score counts match expected distribution
SELECT CASE WHEN SUM(CASE WHEN RISK_SCORE='High Risk' THEN 1 ELSE 0 END)=4 AND SUM(CASE WHEN RISK_SCORE='Medium Risk' THEN 1 ELSE 0 END)=8 AND SUM(CASE WHEN RISK_SCORE='Low Risk' THEN 1 ELSE 0 END)=7 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS WHERE STATUS <> 'Decommissioned';

-- [VAL-020] Data quality / REFERENTIAL_INTEGRITY | FR-03 | Every PART_NUMBER in target AEROSPACE_PARTS that is not Decommissioned must exist in the current source AEROSPACE_PARTS_SOURCE (no orphaned active records)
-- Expected: FAILURE_COUNT = 0 when all active target PART_NUMBERs exist in source
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS t WHERE t.STATUS <> 'Decommissioned' AND NOT EXISTS (SELECT 1 FROM IDEA_2_DB.PUBLIC.AEROSPACE_PARTS_SOURCE s WHERE s.PART_NUMBER = t.PART_NUMBER);
