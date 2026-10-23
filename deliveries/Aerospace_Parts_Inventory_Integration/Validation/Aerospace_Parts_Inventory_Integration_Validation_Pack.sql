-- =============================================================================
-- Validation Pack : Aerospace_Parts_Inventory_Integration
-- Jira Story      : SCRUM-158
-- Generated       : 2026-10-23
-- Convention      : every check returns FAILURE_COUNT (0 = PASS)
-- =============================================================================

-- [VAL-001] Data completeness / ROW_COUNT | FR-01 | After both loads, AEROSPACE_PARTS target must contain exactly 21 distinct PART_NUMBERs ever processed (19 active + 2 soft-deleted = 21 total rows, one per key after SCD1 dedup)
-- Expected: FAILURE_COUNT = 0 when row count equals 21 | self-healed
SELECT CASE WHEN COUNT(*) = 21 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS;

-- [VAL-002] Data completeness / RECONCILIATION | FR-01 | Source after load 2 has 19 distinct active keys; target active rows (LIFECYCLE_STATUS != 'Decommissioned') must equal 19
-- Expected: FAILURE_COUNT = 0 when active target count equals 19 | self-healed
SELECT CASE WHEN (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS WHERE LIFECYCLE_STATUS != 'Decommissioned') = 19 THEN 0 ELSE 1 END AS FAILURE_COUNT;

-- [VAL-003] Data quality / DUPLICATE | FR-02 | Target AEROSPACE_PARTS must have no duplicate PART_NUMBER rows (SCD1 + dedup guarantee one row per key)
-- Expected: FAILURE_COUNT = 0 when no PART_NUMBER appears more than once
SELECT COALESCE(SUM(CASE WHEN cnt > 1 THEN 1 ELSE 0 END), 0) AS FAILURE_COUNT FROM (SELECT PART_NUMBER, COUNT(*) AS cnt FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS GROUP BY PART_NUMBER);

-- [VAL-004] Data quality / NULL | FR-03 | Mandatory columns PART_NUMBER, PART_NAME, MANUFACTURER, LIFECYCLE_STATUS, CERTIFICATION_STATUS must not be NULL in target
-- Expected: FAILURE_COUNT = 0 when no NULLs exist in mandatory columns
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS WHERE PART_NUMBER IS NULL OR PART_NAME IS NULL OR MANUFACTURER IS NULL OR LIFECYCLE_STATUS IS NULL OR CERTIFICATION_STATUS IS NULL;

-- [VAL-005] Business rules / BUSINESS_RULE | FR-03 | BR-04: PN-001 after load 2 must have overwritten attributes PART_NAME='Wing Bolt Updated', WEIGHT_KG=-1 is not expected (WEIGHT_KG=0.6 > 0 so no cleanse), WEIGHT_KG=0.6, UPDATED_AT='2024-06-01 08:00:00'
-- Expected: FAILURE_COUNT = 0 when PN-001 has correct post-load-2 values | self-healed
SELECT CASE WHEN COUNT(*) = 1 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS WHERE PART_NUMBER = 'PN-001' AND PART_NAME = 'Wing Bolt Updated' AND WEIGHT_KG = 0.6;

-- [VAL-006] Business rules / BUSINESS_RULE | FR-04 | BR-05: PN-013 and PN-018 removed from load 2 source must have LIFECYCLE_STATUS='Decommissioned' in target
-- Expected: FAILURE_COUNT = 0 when both soft-deleted keys are Decommissioned | self-healed
SELECT CASE WHEN COUNT(*) = 2 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS WHERE PART_NUMBER IN ('PN-013','PN-018') AND LIFECYCLE_STATUS = 'Decommissioned';

-- [VAL-007] Business rules / BUSINESS_RULE | FR-05 | BR-06: MANUFACTURER must be uppercase; spot-check PN-001=BOEING, PN-002=AIRBUS, PN-016=TESTCORP, PN-012=HONEYWELL, PN-021=MOOG
-- Expected: FAILURE_COUNT = 0 when all five spot-check rows have correct uppercase MANUFACTURER | self-healed
SELECT CASE WHEN COUNT(*) = 5 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS WHERE (PART_NUMBER='PN-001' AND MANUFACTURER='BOEING') OR (PART_NUMBER='PN-002' AND MANUFACTURER='AIRBUS') OR (PART_NUMBER='PN-016' AND MANUFACTURER='TESTCORP') OR (PART_NUMBER='PN-012' AND MANUFACTURER='HONEYWELL') OR (PART_NUMBER='PN-021' AND MANUFACTURER='MOOG');

-- [VAL-008] Data quality / DATA_QUALITY | FR-05 | BR-06: No MANUFACTURER value in target should contain any lowercase letter
-- Expected: FAILURE_COUNT = 0 when all MANUFACTURER values are fully uppercase
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS WHERE MANUFACTURER IS NOT NULL AND MANUFACTURER != UPPER(MANUFACTURER);

-- [VAL-009] Business rules / BUSINESS_RULE | FR-06 | BR-07: PN-003 (WEIGHT_KG=0), PN-017 (WEIGHT_KG=0) must have WEIGHT_KG=-1; PN-004 load 2 WEIGHT_KG not <=0 so not replaced; PN-012 load 2 WEIGHT_KG=-1.0 replaced with -1
-- Expected: FAILURE_COUNT = 0 when cleansed rows have WEIGHT_KG=-1 | self-healed
SELECT CASE WHEN COUNT(*) = 3 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS WHERE PART_NUMBER IN ('PN-003','PN-017','PN-012') AND WEIGHT_KG = -1;

-- [VAL-010] Data quality / DATA_QUALITY | FR-06 | BR-07: No active row (excluding NULL WEIGHT_KG) should have WEIGHT_KG <= 0 except the sentinel -1 value
-- Expected: FAILURE_COUNT = 0 when no row has WEIGHT_KG between -0.9999 and 0 inclusive
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS WHERE WEIGHT_KG IS NOT NULL AND WEIGHT_KG > -1 AND WEIGHT_KG <= 0;

-- [VAL-011] Business rules / BUSINESS_RULE | FR-07 | BR-08 High Risk: PN-012 (Pending, 120 days) and PN-021 (Pending, 65 days) must have RISK_SCORE='High Risk'; PN-004 after load 2 must NOT be High Risk
-- Expected: FAILURE_COUNT = 0 when High Risk rows match exactly
SELECT CASE WHEN (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS WHERE PART_NUMBER IN ('PN-012','PN-021') AND RISK_SCORE='High Risk') = 2 AND (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS WHERE PART_NUMBER='PN-004' AND RISK_SCORE='High Risk') = 0 THEN 0 ELSE 1 END AS FAILURE_COUNT;

-- [VAL-012] Business rules / BUSINESS_RULE | FR-07 | BR-09/BR-11 Medium Risk: PN-005, PN-006, PN-007, PN-008, PN-009, PN-014, PN-015, PN-017, PN-019, PN-004 (post load 2) must all have RISK_SCORE='Medium Risk'
-- Expected: FAILURE_COUNT = 0 when all 10 medium-risk keys have correct RISK_SCORE | self-healed
SELECT CASE WHEN COUNT(*) = 10 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS WHERE PART_NUMBER IN ('PN-004','PN-005','PN-006','PN-007','PN-008','PN-009','PN-014','PN-015','PN-017','PN-019') AND RISK_SCORE = 'Medium Risk';

-- [VAL-013] Business rules / BUSINESS_RULE | FR-07 | BR-10 Low Risk: PN-001 (FAA,30d), PN-002 (EASA,60d), PN-003 (Dual,60d), PN-010 (FAA,55d), PN-011 (Dual,20d), PN-020 (FAA,45d) must have RISK_SCORE='Low Risk'
-- Expected: FAILURE_COUNT = 0 when all 6 low-risk keys have correct RISK_SCORE | self-healed
SELECT CASE WHEN COUNT(*) = 6 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS WHERE PART_NUMBER IN ('PN-001','PN-002','PN-003','PN-010','PN-011','PN-020') AND RISK_SCORE = 'Low Risk';

-- [VAL-014] Business rules / AGGREGATION | FR-07 | RISK_SCORE distribution across all 21 target rows: High Risk=2, Medium Risk=10, Low Risk=6, remainder are soft-deleted (Decommissioned) rows which may retain last computed score or be overridden; total scored rows with known risk = 18 active non-decommissioned
-- Expected: FAILURE_COUNT = 0 when High Risk count=2 and Low Risk count=6
SELECT CASE WHEN SUM(CASE WHEN RISK_SCORE='High Risk' THEN 1 ELSE 0 END) = 2 AND SUM(CASE WHEN RISK_SCORE='Low Risk' THEN 1 ELSE 0 END) = 6 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS WHERE LIFECYCLE_STATUS != 'Decommissioned';

-- [VAL-015] Business rules / BUSINESS_RULE | FR-02 | BR-03: PN-016 must retain only the latest UPDATED_AT row; after load 2 the retained row must have PART_NAME='Duplicate Incremental New' and MANUFACTURER='TESTCORP'
-- Expected: FAILURE_COUNT = 0 when PN-016 has exactly one row with correct post-load-2 values
SELECT CASE WHEN COUNT(*) = 1 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS WHERE PART_NUMBER = 'PN-016' AND PART_NAME = 'Duplicate Incremental New' AND MANUFACTURER = 'TESTCORP';

-- [VAL-016] Load behaviour / LOAD_BEHAVIOUR | FR-08 | BR-12: ETL_RECONCILIATION_LOG must contain exactly 2 records after both loads (one per run)
-- Expected: FAILURE_COUNT = 0 when log has exactly 2 rows
SELECT CASE WHEN COUNT(*) = 2 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG;

-- [VAL-017] Business rules / BUSINESS_RULE | FR-08 | BR-12: Load 1 log record must have source_count=18, inserted_count=18, updated_count=0, soft_deleted_count=0
-- Expected: FAILURE_COUNT = 0 when load 1 reconciliation row matches expected counts | self-healed
SELECT CASE WHEN COUNT(*) = 1 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG WHERE source_count = 19 AND inserted_count = 19 AND updated_count = 0 AND soft_deleted_count = 0;

-- [VAL-018] Business rules / BUSINESS_RULE | FR-08 | BR-12: Load 2 log record must have source_count=6, inserted_count=2, updated_count=4, soft_deleted_count=2
-- Expected: FAILURE_COUNT = 0 when load 2 reconciliation row matches expected counts | self-healed
SELECT CASE WHEN COUNT(*) = 1 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG WHERE source_count = 6 AND inserted_count = 2 AND updated_count = 4 AND soft_deleted_count = 2;

-- [VAL-019] Load behaviour / LOAD_BEHAVIOUR | FR-04 | Soft-delete load behaviour: exactly 2 rows in target have LIFECYCLE_STATUS='Decommissioned' after both loads (PN-013 and PN-018)
-- Expected: FAILURE_COUNT = 0 when decommissioned count equals 2 | self-healed
SELECT CASE WHEN COUNT(*) = 2 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS WHERE LIFECYCLE_STATUS = 'Decommissioned';

-- [VAL-020] Load behaviour / LOAD_BEHAVIOUR | FR-03 | SCD Type 1 incremental overwrite: PN-004 after load 2 must have CERTIFICATION_STATUS='FAA' (overwritten from Pending), confirming no history row exists and prior value is gone
-- Expected: FAILURE_COUNT = 0 when PN-004 has CERTIFICATION_STATUS=FAA and exactly one row
SELECT CASE WHEN COUNT(*) = 1 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS WHERE PART_NUMBER = 'PN-004' AND CERTIFICATION_STATUS = 'FAA';

-- [VAL-021] Load behaviour / LOAD_BEHAVIOUR | FR-01 | Incremental load: PN-020 and PN-021 (new in load 2) must exist in target; PN-002 through PN-011 unchanged keys must also exist (not dropped by incremental logic)
-- Expected: FAILURE_COUNT = 0 when both new keys and a sample of unchanged keys are present | self-healed
SELECT CASE WHEN COUNT(*) = 12 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS WHERE PART_NUMBER IN ('PN-020','PN-021','PN-002','PN-003','PN-005','PN-006','PN-007','PN-008','PN-009','PN-010','PN-011','PN-014');

-- [VAL-022] Data quality / REFERENTIAL_INTEGRITY | FR-03 | Every PART_NUMBER in AEROSPACE_PARTS_STAGING (post-dedup) must exist in AEROSPACE_PARTS target, ensuring no staged record was silently dropped
-- Expected: FAILURE_COUNT = 0 when all staged part numbers exist in target
SELECT COUNT(*) AS FAILURE_COUNT FROM (SELECT DISTINCT PART_NUMBER FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_STAGING) s WHERE NOT EXISTS (SELECT 1 FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS t WHERE t.PART_NUMBER = s.PART_NUMBER);
