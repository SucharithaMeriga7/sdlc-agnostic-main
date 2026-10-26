-- =============================================================================
-- Validation Pack : Aerospace_Parts_Inventory_Integration
-- Jira Story      : SCRUM-158
-- Generated       : 2026-10-26
-- Convention      : every check returns FAILURE_COUNT (0 = PASS)
-- =============================================================================

-- [VAL-001] Data completeness / ROW_COUNT | FR-01 | Target must contain exactly 21 active (non-deleted) rows after both loads (22 ever-loaded keys minus 1 soft-deleted PN-020)
-- Expected: FAILURE_COUNT = 0 when active target rows = 21
SELECT ABS(COUNT(*) - 21) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE COALESCE(IS_DELETED, FALSE) = FALSE;

-- [VAL-002] Data completeness / ROW_COUNT | FR-01 | Target must contain exactly 22 total rows (21 active + 1 soft-deleted PN-020) after both loads
-- Expected: FAILURE_COUNT = 0 when total target rows = 22
SELECT ABS(COUNT(*) - 22) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET;

-- [VAL-003] Data completeness / RECONCILIATION | FR-01 | Distinct active PART_NUMBERs in target must equal 21 (matching distinct keys in source after load 2)
-- Expected: FAILURE_COUNT = 0 when distinct active PART_NUMBERs = 21
SELECT ABS(COUNT(DISTINCT PART_NUMBER) - 21) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE COALESCE(IS_DELETED, FALSE) = FALSE;

-- [VAL-004] Data quality / DUPLICATE | FR-02 | No duplicate PART_NUMBER values among active (non-deleted) target rows after deduplication
-- Expected: FAILURE_COUNT = 0 when no PART_NUMBER appears more than once in active rows
SELECT COUNT(*) AS FAILURE_COUNT FROM (SELECT PART_NUMBER FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE COALESCE(IS_DELETED, FALSE) = FALSE GROUP BY PART_NUMBER HAVING COUNT(*) > 1);

-- [VAL-005] Data quality / NULL | FR-01 | No NULL values in mandatory columns PART_NUMBER, PART_NAME, MANUFACTURER, CERTIFICATION_STATUS, RISK_SCORE
-- Expected: FAILURE_COUNT = 0 when all mandatory columns are non-null
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IS NULL OR PART_NAME IS NULL OR MANUFACTURER IS NULL OR CERTIFICATION_STATUS IS NULL OR RISK_SCORE IS NULL;

-- [VAL-006] Business rules / BUSINESS_RULE | FR-02 | BR-03: PN-001 deduplication — target must retain only the later row with PART_NAME='Bolt Assembly v3' and WEIGHT_KG=1.8 (post load_2 SCD1 overwrite)
-- Expected: FAILURE_COUNT = 0 when PN-001 has PART_NAME='Bolt Assembly v3' and WEIGHT_KG=1.8
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER = 'PN-001' AND NOT (PART_NAME = 'Bolt Assembly v3' AND WEIGHT_KG = 1.8);

-- [VAL-007] Business rules / BUSINESS_RULE | FR-03 | BR-04: SCD Type 1 — PN-009 overwritten; CERTIFICATION_STATUS='FAA', LEAD_TIME_DAYS=55, RISK_SCORE='Low Risk' after load_2
-- Expected: FAILURE_COUNT = 0 when PN-009 has CERTIFICATION_STATUS='FAA', LEAD_TIME_DAYS=55, RISK_SCORE='Low Risk'
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER = 'PN-009' AND NOT (CERTIFICATION_STATUS = 'FAA' AND LEAD_TIME_DAYS = 55 AND RISK_SCORE = 'Low Risk');

-- [VAL-008] Business rules / BUSINESS_RULE | FR-04 | BR-05: PN-020 soft-deleted — LIFECYCLE_STATUS must be 'Decommissioned' and IS_DELETED must be TRUE
-- Expected: FAILURE_COUNT = 0 when PN-020 is marked Decommissioned
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER = 'PN-020' AND NOT (LIFECYCLE_STATUS = 'Decommissioned' AND IS_DELETED = TRUE);

-- [VAL-009] Business rules / BUSINESS_RULE | FR-05 | BR-06: MANUFACTURER uppercase — PN-001 must have MANUFACTURER='ACME CORP UPDATED' and PN-003 must have MANUFACTURER='PARKER HANNIFIN'
-- Expected: FAILURE_COUNT = 0 when both MANUFACTURER values are uppercase
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE (PART_NUMBER = 'PN-001' AND MANUFACTURER != 'ACME CORP UPDATED') OR (PART_NUMBER = 'PN-003' AND MANUFACTURER != 'PARKER HANNIFIN');

-- [VAL-010] Data quality / DATA_QUALITY | FR-05 | BR-06: All MANUFACTURER values in target must equal their UPPER() form (no lowercase characters anywhere)
-- Expected: FAILURE_COUNT = 0 when all MANUFACTURER values are fully uppercase
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE MANUFACTURER IS NOT NULL AND MANUFACTURER != UPPER(MANUFACTURER);

-- [VAL-011] Business rules / BUSINESS_RULE | FR-06 | BR-07: WEIGHT_KG replacement — PN-003 must have WEIGHT_KG=-1, PN-004 must have WEIGHT_KG=-1, PN-022 must have WEIGHT_KG=-1
-- Expected: FAILURE_COUNT = 0 when all three parts have WEIGHT_KG=-1
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-003','PN-004','PN-022') AND WEIGHT_KG != -1;

-- [VAL-012] Data quality / DATA_QUALITY | FR-06 | BR-07: No WEIGHT_KG value of 0 or negative (other than -1 sentinel) exists in the target
-- Expected: FAILURE_COUNT = 0 when no WEIGHT_KG <= 0 except the -1 sentinel
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE WEIGHT_KG < -1 OR WEIGHT_KG = 0;

-- [VAL-013] Business rules / BUSINESS_RULE | FR-07 | BR-08: High Risk — PN-001 (Pending, LEAD_TIME=70), PN-011 (Pending, LEAD_TIME=61), PN-021 (Pending, LEAD_TIME=110) must all have RISK_SCORE='High Risk'
-- Expected: FAILURE_COUNT = 0 when all three High Risk parts are correctly scored
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-001','PN-011','PN-021') AND RISK_SCORE != 'High Risk';

-- [VAL-014] Business rules / BUSINESS_RULE | FR-07 | BR-09/BR-11: Medium Risk — PN-005 (Pending,50), PN-006 (FAA,110), PN-013 (FAA,105), PN-015 (Unknown,40), PN-017 (Dual,61), PN-008 (Dual,90), PN-018 (EASA,100) must all have RISK_SCORE='Medium Risk'
-- Expected: FAILURE_COUNT = 0 when all Medium Risk parts are correctly scored
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-005','PN-006','PN-013','PN-015','PN-017','PN-008','PN-018') AND RISK_SCORE != 'Medium Risk';

-- [VAL-015] Business rules / BUSINESS_RULE | FR-07 | BR-10: Low Risk — PN-002 (FAA,60), PN-007 (EASA,20), PN-012 (Dual,15), PN-014 (EASA,60), PN-022 (Dual,10) must all have RISK_SCORE='Low Risk'
-- Expected: FAILURE_COUNT = 0 when all Low Risk parts are correctly scored | self-healed
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-002','PN-007','PN-012','PN-014','PN-022') AND RISK_SCORE != 'Low Risk';

-- [VAL-016] Business rules / AGGREGATION | FR-07 | RISK_SCORE distribution — exactly 3 High Risk, at least 7 Medium Risk, at least 5 Low Risk among active rows after both loads
-- Expected: FAILURE_COUNT = 0 when risk score counts meet minimums
SELECT CASE WHEN SUM(CASE WHEN RISK_SCORE = 'High Risk' THEN 1 ELSE 0 END) != 3 THEN 1 WHEN SUM(CASE WHEN RISK_SCORE = 'Medium Risk' THEN 1 ELSE 0 END) < 7 THEN 1 WHEN SUM(CASE WHEN RISK_SCORE = 'Low Risk' THEN 1 ELSE 0 END) < 5 THEN 1 ELSE 0 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE COALESCE(IS_DELETED, FALSE) = FALSE;

-- [VAL-017] Load behaviour / LOAD_BEHAVIOUR | FR-08 | BR-12: ETL_RECONCILIATION_LOG must have at least 2 entries (one per run) after both loads
-- Expected: FAILURE_COUNT = 0 when log contains >= 2 rows
SELECT CASE WHEN COUNT(*) >= 2 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG;

-- [VAL-018] Load behaviour / LOAD_BEHAVIOUR | FR-08 | BR-12: Each log entry must have non-null SOURCE_COUNT, TARGET_COUNT, INSERTED_COUNT, UPDATED_COUNT, DELETED_COUNT, DISCREPANCY_COUNT
-- Expected: FAILURE_COUNT = 0 when all reconciliation fields are populated
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG WHERE SOURCE_COUNT IS NULL OR TARGET_COUNT IS NULL OR INSERTED_COUNT IS NULL OR UPDATED_COUNT IS NULL OR DELETED_COUNT IS NULL OR DISCREPANCY_COUNT IS NULL;

-- [VAL-019] Load behaviour / LOAD_BEHAVIOUR | FR-01 | BR-01/BR-02: First log entry must have LOAD_TYPE='FULL' and second must have LOAD_TYPE='INCREMENTAL'
-- Expected: FAILURE_COUNT = 0 when load types are correctly recorded in order
SELECT COUNT(*) AS FAILURE_COUNT FROM (SELECT ROW_NUMBER() OVER (ORDER BY RUN_TS ASC) AS RN, LOAD_TYPE FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG) t WHERE (RN = 1 AND LOAD_TYPE != 'FULL') OR (RN = 2 AND LOAD_TYPE != 'INCREMENTAL');

-- [VAL-020] Load behaviour / LOAD_BEHAVIOUR | FR-03 | BR-04: SCD Type 1 — only one row per PART_NUMBER exists in target (no history rows retained for any key including PN-001)
-- Expected: FAILURE_COUNT = 0 when no PART_NUMBER has more than one row total
SELECT COUNT(*) AS FAILURE_COUNT FROM (SELECT PART_NUMBER FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET GROUP BY PART_NUMBER HAVING COUNT(*) > 1);

-- [VAL-021] Data completeness / RECONCILIATION | FR-08 | BR-12: Incremental run log entry must record UPDATED_COUNT=4 (PN-001,PN-003,PN-009,PN-011) and INSERTED_COUNT=2 (PN-021,PN-022) and DELETED_COUNT=1 (PN-020)
-- Expected: FAILURE_COUNT = 0 when incremental log row has correct change counts
SELECT COUNT(*) AS FAILURE_COUNT FROM (SELECT LOG_ID FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG WHERE LOAD_TYPE = 'INCREMENTAL' AND UPDATED_COUNT = 4 AND INSERTED_COUNT = 2 AND DELETED_COUNT = 1) t HAVING COUNT(*) = 0;

-- [VAL-022] Data quality / REFERENTIAL_INTEGRITY | FR-01 | New keys PN-021 and PN-022 from load_2 must exist as active rows in the target
-- Expected: FAILURE_COUNT = 0 when both new keys are present and active
SELECT ABS(COUNT(*) - 2) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-021','PN-022') AND COALESCE(IS_DELETED, FALSE) = FALSE;

-- [VAL-023] Data quality / DATA_QUALITY | FR-07 | RISK_SCORE must only contain values from the allowed set: 'High Risk', 'Medium Risk', 'Low Risk'
-- Expected: FAILURE_COUNT = 0 when all RISK_SCORE values are within the allowed set
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE RISK_SCORE NOT IN ('High Risk','Medium Risk','Low Risk');
