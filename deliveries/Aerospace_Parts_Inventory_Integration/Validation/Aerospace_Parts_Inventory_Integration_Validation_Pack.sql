-- =============================================================================
-- Validation Pack : Aerospace_Parts_Inventory_Integration
-- Jira Story      : SCRUM-158
-- Generated       : 2026-10-21
-- Convention      : every check returns FAILURE_COUNT (0 = PASS)
-- =============================================================================

-- [VAL-001] Data completeness / ROW_COUNT | FR-01 | After both loads, AEROSPACE_PARTS_TARGET must contain exactly 22 rows (19 from load 1 + 3 new from load 2; PN-015 and PN-019 soft-deleted remain in target as Decommissioned)
-- Expected: FAILURE_COUNT = 0 when row count = 22
SELECT CASE WHEN COUNT(*) = 22 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET;

-- [VAL-002] Data quality / DUPLICATE | FR-03 | AEROSPACE_PARTS_TARGET must have no duplicate PART_NUMBER values (SCD Type 1, one row per key)
-- Expected: FAILURE_COUNT = 0 when all PART_NUMBERs are distinct
SELECT COUNT(*) AS FAILURE_COUNT FROM (SELECT PART_NUMBER FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET GROUP BY PART_NUMBER HAVING COUNT(*) > 1);

-- [VAL-003] Data completeness / RECONCILIATION | FR-08 | After load 2, ETL_RECONCILIATION_LOG must record the final incremental run with source_count=7, target_count=22, inserted=3, updated=3, soft_deleted=2, discrepancies=0
-- Expected: FAILURE_COUNT = 0 when the latest log row matches expected values
SELECT CASE WHEN COUNT(*) >= 1 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG WHERE SOURCE_COUNT = 7 AND TARGET_COUNT = 22 AND INSERTED_COUNT = 3 AND UPDATED_COUNT = 3 AND SOFT_DELETED_COUNT = 2 AND DISCREPANCIES = 0;

-- [VAL-004] Load behaviour / LOAD_BEHAVIOUR | FR-08 | ETL_RECONCILIATION_LOG must contain at least 2 rows (one for load 1 full run, one for load 2 incremental run)
-- Expected: FAILURE_COUNT = 0 when log has >= 2 rows
SELECT CASE WHEN COUNT(*) >= 2 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG;

-- [VAL-005] Load behaviour / LOAD_BEHAVIOUR | FR-01 | PIPELINE_EXECUTION_LOG must contain at least 2 successful execution records (one full load, one incremental), confirming scheduling and timestamp tracking
-- Expected: FAILURE_COUNT = 0 when >= 2 successful runs are logged
SELECT CASE WHEN COUNT(*) >= 2 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PIPELINE_EXECUTION_LOG WHERE UPPER(STATUS) = 'SUCCESS';

-- [VAL-006] Load behaviour / LOAD_BEHAVIOUR | FR-04 | PN-015 and PN-019 must exist in AEROSPACE_PARTS_TARGET with LIFECYCLE_STATUS = 'Decommissioned' after load 2 soft delete
-- Expected: FAILURE_COUNT = 0 when both soft-deleted rows are present with correct status
SELECT CASE WHEN COUNT(*) = 2 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-015','PN-019') AND LIFECYCLE_STATUS = 'Decommissioned';

-- [VAL-007] Business rules / BUSINESS_RULE | FR-03 | BR-04: After load 2, PN-001 must be overwritten with MANUFACTURER='BOEING UPDATED', WEIGHT_KG=13.0, UNIT_PRICE_USD=460.00 (SCD Type 1 overwrite verified by business key)
-- Expected: FAILURE_COUNT = 0 when PN-001 has the load-2 values
SELECT CASE WHEN COUNT(*) = 1 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER = 'PN-001' AND MANUFACTURER = 'BOEING UPDATED' AND WEIGHT_KG = 13.0 AND UNIT_PRICE_USD = 460.00;

-- [VAL-008] Business rules / BUSINESS_RULE | FR-02 | BR-03: PN-003 deduplication — target must contain exactly one row for PN-003 with PART_NAME='Fuel Valve' (latest UPDATED_AT=2024-01-03 10:00:00 wins)
-- Expected: FAILURE_COUNT = 0 when exactly one PN-003 row with correct PART_NAME exists
SELECT CASE WHEN COUNT(*) = 1 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER = 'PN-003' AND PART_NAME = 'Fuel Valve';

-- [VAL-009] Business rules / BUSINESS_RULE | FR-02 | BR-03 (Load 2): PN-004 deduplication — target must contain exactly one row for PN-004 with PART_NAME='Landing Gear Strut' and UNIT_PRICE_USD=9600.00
-- Expected: FAILURE_COUNT = 0 when PN-004 has the correct deduplicated load-2 values
SELECT CASE WHEN COUNT(*) = 1 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER = 'PN-004' AND PART_NAME = 'Landing Gear Strut' AND UNIT_PRICE_USD = 9600.00;

-- [VAL-010] Business rules / BUSINESS_RULE | FR-05 | BR-06: MANUFACTURER values must be uppercase — spot-check PN-001='BOEING UPDATED', PN-002='AIRBUS', PN-009='GE AVIATION', PN-011='SPIRIT AEROSYSTEMS'
-- Expected: FAILURE_COUNT = 0 when all four spot-check rows have correct uppercase MANUFACTURER
SELECT CASE WHEN COUNT(*) = 4 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE (PART_NUMBER='PN-001' AND MANUFACTURER='BOEING UPDATED') OR (PART_NUMBER='PN-002' AND MANUFACTURER='AIRBUS') OR (PART_NUMBER='PN-009' AND MANUFACTURER='GE AVIATION') OR (PART_NUMBER='PN-011' AND MANUFACTURER='SPIRIT AEROSYSTEMS');

-- [VAL-011] Data quality / DATA_QUALITY | FR-05 | BR-06: No MANUFACTURER value in AEROSPACE_PARTS_TARGET should contain any lowercase letter
-- Expected: FAILURE_COUNT = 0 when all MANUFACTURER values are fully uppercase
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE MANUFACTURER != UPPER(MANUFACTURER);

-- [VAL-012] Business rules / BUSINESS_RULE | FR-06 | BR-07: PN-005 WEIGHT_KG must be -1 (source value <=0 replaced); PN-006 WEIGHT_KG must be -1; all other active rows must have WEIGHT_KG > 0 or exactly -1
-- Expected: FAILURE_COUNT = 0 when PN-005 and PN-006 both have WEIGHT_KG = -1
SELECT CASE WHEN COUNT(*) = 2 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-005','PN-006') AND WEIGHT_KG = -1;

-- [VAL-013] Data quality / DATA_QUALITY | FR-06 | BR-07: No WEIGHT_KG value in AEROSPACE_PARTS_TARGET should be 0 or any negative value other than -1
-- Expected: FAILURE_COUNT = 0 when no invalid WEIGHT_KG values exist
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE WEIGHT_KG <= 0 AND WEIGHT_KG != -1;

-- [VAL-014] Business rules / BUSINESS_RULE | FR-07 | BR-08: High Risk rows — PN-004, PN-005, PN-016 must all have RISK_SCORE='High Risk' (Pending + lead_time > 60)
-- Expected: FAILURE_COUNT = 0 when all three High Risk parts are correctly scored
SELECT CASE WHEN COUNT(*) = 3 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-004','PN-005','PN-016') AND RISK_SCORE = 'High Risk';

-- [VAL-015] Business rules / BUSINESS_RULE | FR-07 | BR-09/BR-11: Medium Risk rows — PN-007, PN-008, PN-009, PN-010, PN-012, PN-013, PN-014, PN-017, PN-022 must all have RISK_SCORE='Medium Risk'
-- Expected: FAILURE_COUNT = 0 when all nine Medium Risk parts are correctly scored
SELECT CASE WHEN COUNT(*) = 9 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-007','PN-008','PN-009','PN-010','PN-012','PN-013','PN-014','PN-017','PN-022') AND RISK_SCORE = 'Medium Risk';

-- [VAL-016] Business rules / BUSINESS_RULE | FR-07 | BR-10: Low Risk rows — PN-001, PN-002, PN-003, PN-006, PN-011, PN-015, PN-018, PN-021 must all have RISK_SCORE='Low Risk'
-- Expected: FAILURE_COUNT = 0 when all eight Low Risk parts are correctly scored
SELECT CASE WHEN COUNT(*) = 8 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-001','PN-002','PN-003','PN-006','PN-011','PN-015','PN-018','PN-021') AND RISK_SCORE = 'Low Risk';

-- [VAL-017] Data quality / DATA_QUALITY | FR-07 | RISK_SCORE must only contain values from the allowed set: 'High Risk', 'Medium Risk', 'Low Risk'; no NULLs or unexpected values
-- Expected: FAILURE_COUNT = 0 when all RISK_SCORE values are valid
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE RISK_SCORE NOT IN ('High Risk','Medium Risk','Low Risk') OR RISK_SCORE IS NULL;

-- [VAL-018] Data quality / NULL | FR-03 | PART_NUMBER must never be NULL in AEROSPACE_PARTS_TARGET (primary business key)
-- Expected: FAILURE_COUNT = 0 when no NULL PART_NUMBER rows exist
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IS NULL;

-- [VAL-019] Business rules / AGGREGATION | FR-08 | Sum of INSERTED_COUNT across all ETL_RECONCILIATION_LOG rows must equal 22 (19 from load 1 + 3 from load 2)
-- Expected: FAILURE_COUNT = 0 when total inserted across all runs = 22
SELECT CASE WHEN SUM(INSERTED_COUNT) = 22 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG;

-- [VAL-020] Data quality / REFERENTIAL_INTEGRITY | FR-08 | Every PART_NUMBER in AEROSPACE_PARTS_TARGET must exist in IDEA_2_DB.PUBLIC.AEROSPACE_PARTS_SOURCE or have LIFECYCLE_STATUS='Decommissioned' (soft-deleted rows are allowed to be absent from source)
-- Expected: FAILURE_COUNT = 0 when no orphaned active target rows exist
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET t WHERE t.LIFECYCLE_STATUS != 'Decommissioned' AND NOT EXISTS (SELECT 1 FROM IDEA_2_DB.PUBLIC.AEROSPACE_PARTS_SOURCE s WHERE s.PART_NUMBER = t.PART_NUMBER);

-- [VAL-021] Load behaviour / LOAD_BEHAVIOUR | FR-08 | Load 1 reconciliation log row must record source_count=19, inserted=19, updated=0, soft_deleted=0 (full load baseline)
-- Expected: FAILURE_COUNT = 0 when load 1 log row matches expected values
SELECT CASE WHEN COUNT(*) >= 1 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG WHERE SOURCE_COUNT = 19 AND INSERTED_COUNT = 19 AND UPDATED_COUNT = 0 AND SOFT_DELETED_COUNT = 0;

-- [VAL-022] Data completeness / ROW_COUNT | FR-03 | AEROSPACE_PARTS_TARGET must contain exactly 3 newly inserted rows from load 2 (PN-020, PN-021, PN-022)
-- Expected: FAILURE_COUNT = 0 when all three new keys are present in target
SELECT CASE WHEN COUNT(*) = 3 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-020','PN-021','PN-022');
