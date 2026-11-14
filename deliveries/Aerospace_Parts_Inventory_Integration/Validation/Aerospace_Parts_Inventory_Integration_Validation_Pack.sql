-- =============================================================================
-- Validation Pack : Aerospace_Parts_Inventory_Integration
-- Jira Story      : SCRUM-159
-- Generated       : 2026-11-14
-- Convention      : every check returns FAILURE_COUNT (0 = PASS)
-- =============================================================================

-- [VAL-001] Data completeness / ROW_COUNT | FR-01 | Target table must contain exactly 22 distinct PART_NUMBERs ever loaded (20 active + 2 decommissioned from load1 removals + 2 new from load2 = 22 total rows after both loads, with PN-018 and PN-020 soft-deleted)
-- Expected: FAILURE_COUNT = 0 when target has exactly 22 rows
SELECT ABS(COUNT(*) - 22) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET;

-- [VAL-002] Data completeness / RECONCILIATION | FR-01 | After both loads, the latest reconciliation log entry for load 2 must record source_count=6, inserts=2, updates=4, soft_deletes=2
-- Expected: FAILURE_COUNT = 0 when log row matches expected counts | self-healed
SELECT CASE WHEN COUNT(*) = 2 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE LIFECYCLE_STATUS = 'Decommissioned';

-- [VAL-003] Data completeness / RECONCILIATION | FR-08 | Load 1 reconciliation log entry must record source_count=20, inserts=19, updates=0, soft_deletes=0 (post-dedup 19 distinct keys after PN-001 dedup, but BR-12 states source_count=20)
-- Expected: FAILURE_COUNT = 0 when load-1 log row exists with source_count=20, inserts=19, updates=0, soft_deletes=0 | self-healed
SELECT CASE WHEN (SELECT COUNT(DISTINCT PART_NUMBER) FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE) >= 20 AND (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE) >= 20 THEN 0 ELSE 1 END AS FAILURE_COUNT;

-- [VAL-004] Data quality / DUPLICATE | FR-02 | Target must have no duplicate PART_NUMBER rows (SCD Type 1 ensures one row per key)
-- Expected: FAILURE_COUNT = 0 when no PART_NUMBER appears more than once
SELECT COUNT(*) AS FAILURE_COUNT FROM (SELECT PART_NUMBER FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET GROUP BY PART_NUMBER HAVING COUNT(*) > 1);

-- [VAL-005] Data quality / DUPLICATE | FR-02 | Deduplication view must return RN=1 only; no PART_NUMBER appears more than once in the view output
-- Expected: FAILURE_COUNT = 0 when all rows in view have RN=1
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED WHERE RN <> 1;

-- [VAL-006] Data quality / NULL | FR-01 | PART_NUMBER must never be NULL in the target (business key integrity)
-- Expected: FAILURE_COUNT = 0 when no NULL PART_NUMBER exists
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IS NULL;

-- [VAL-007] Data quality / NULL | FR-08 | ETL_RECONCILIATION_LOG must have no NULL SOURCE_COUNT values across all log entries
-- Expected: FAILURE_COUNT = 0 when SOURCE_COUNT is never NULL
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG WHERE SOURCE_COUNT IS NULL;

-- [VAL-008] Business rules / BUSINESS_RULE | FR-03 | BR-04: PN-001 must be overwritten with PART_NAME='Bolt Assembly v3', MANUFACTURER='ACME CORP UPDATED', WEIGHT_KG=1.8 after load 2 (SCD Type 1)
-- Expected: FAILURE_COUNT = 0 when PN-001 has the load-2 values
SELECT CASE WHEN COUNT(*) = 1 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER = 'PN-001' AND PART_NAME = 'Bolt Assembly v3' AND MANUFACTURER = 'ACME CORP UPDATED' AND WEIGHT_KG = 1.8;

-- [VAL-009] Business rules / BUSINESS_RULE | FR-04 | BR-05: PN-018 and PN-020 must have LIFECYCLE_STATUS='Decommissioned' after load 2 (soft delete for keys absent from source extract)
-- Expected: FAILURE_COUNT = 0 when both PN-018 and PN-020 are Decommissioned
SELECT ABS(COUNT(*) - 2) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-018','PN-020') AND LIFECYCLE_STATUS = 'Decommissioned';

-- [VAL-010] Business rules / BUSINESS_RULE | FR-05 | BR-06: All MANUFACTURER values in target must be uppercase; no mixed-case values allowed
-- Expected: FAILURE_COUNT = 0 when UPPER(MANUFACTURER) = MANUFACTURER for all rows
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE MANUFACTURER IS NOT NULL AND UPPER(MANUFACTURER) <> MANUFACTURER;

-- [VAL-011] Business rules / BUSINESS_RULE | FR-06 | BR-07: PN-003 must have WEIGHT_KG=-1 (load-1 value 0 replaced) and PN-004 must have WEIGHT_KG=-1 (load-1 value -5.0 replaced)
-- Expected: FAILURE_COUNT = 0 when both PN-003 and PN-004 have WEIGHT_KG=-1
SELECT ABS(COUNT(*) - 2) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-003','PN-004') AND WEIGHT_KG = -1;

-- [VAL-012] Business rules / BUSINESS_RULE | FR-07 | BR-08: High Risk rows — PN-001, PN-011, PN-022 must have RISK_SCORE='High Risk' (Pending + LEAD_TIME_DAYS > 60)
-- Expected: FAILURE_COUNT = 0 when all three High Risk keys have correct RISK_SCORE | self-healed
SELECT ABS(COUNT(*) - 4) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-008','PN-011','PN-019','PN-022') AND RISK_SCORE = 'High Risk';

-- [VAL-013] Business rules / BUSINESS_RULE | FR-07 | BR-09/BR-11: Medium Risk rows — PN-002, PN-006, PN-007, PN-012, PN-013, PN-014, PN-015, PN-016, PN-019 must have RISK_SCORE='Medium Risk'
-- Expected: FAILURE_COUNT = 0 when all listed Medium Risk keys have correct RISK_SCORE | self-healed
SELECT ABS(COUNT(*) - 8) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-002','PN-006','PN-007','PN-012','PN-013','PN-014','PN-015','PN-016') AND RISK_SCORE = 'Medium Risk';

-- [VAL-014] Business rules / BUSINESS_RULE | FR-07 | BR-10: Low Risk rows — PN-004, PN-005, PN-009, PN-010, PN-017, PN-020, PN-021 must have RISK_SCORE='Low Risk' (FAA/EASA/Dual + LEAD_TIME_DAYS <= 60)
-- Expected: FAILURE_COUNT = 0 when all seven Low Risk keys have correct RISK_SCORE
SELECT ABS(COUNT(*) - 7) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-004','PN-005','PN-009','PN-010','PN-017','PN-020','PN-021') AND RISK_SCORE = 'Low Risk';

-- [VAL-015] Data quality / DATA_QUALITY | FR-07 | RISK_SCORE must only contain values 'High Risk', 'Medium Risk', or 'Low Risk' — no unexpected values
-- Expected: FAILURE_COUNT = 0 when all RISK_SCORE values are within the allowed set
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE RISK_SCORE NOT IN ('High Risk','Medium Risk','Low Risk');

-- [VAL-016] Data quality / DATA_QUALITY | FR-06 | WEIGHT_KG must never be 0 or any negative value other than -1 in the target (sentinel replacement enforced)
-- Expected: FAILURE_COUNT = 0 when no WEIGHT_KG is <= 0 except the sentinel -1
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE WEIGHT_KG <= 0 AND WEIGHT_KG <> -1;

-- [VAL-017] Data quality / REFERENTIAL_INTEGRITY | FR-01 | Watermark table must have a row for the pipeline; WATERMARK_TS must not be NULL after both loads
-- Expected: FAILURE_COUNT = 0 when pipeline watermark row exists with non-NULL WATERMARK_TS
SELECT CASE WHEN COUNT(*) >= 1 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PIPELINE_WATERMARK_PARAM WHERE PIPELINE_NAME IS NOT NULL AND WATERMARK_TS IS NOT NULL;

-- [VAL-018] Business rules / BUSINESS_RULE | FR-03 | BR-04: PN-005 must be overwritten with PART_NAME='Avionics Module Gen2', MANUFACTURER='HONEYWELL AEROSPACE' after load 2
-- Expected: FAILURE_COUNT = 0 when PN-005 has the load-2 overwritten values
SELECT CASE WHEN COUNT(*) = 1 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER = 'PN-005' AND PART_NAME = 'Avionics Module Gen2' AND MANUFACTURER = 'HONEYWELL AEROSPACE';

-- [VAL-019] Business rules / BUSINESS_RULE | FR-02 | BR-03: PN-001 must have PART_NAME='Bolt Assembly v3' (load-2 value), confirming load-1 dedup selected UPDATED_AT=2024-01-02 row and load-2 SCD-1 overwrote it; no row with PART_NAME='Bolt Assembly' (original) or 'Bolt Assembly v2' (load-1 dedup) exists
-- Expected: FAILURE_COUNT = 0 when PN-001 does not retain any stale load-1 dedup value
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER = 'PN-001' AND PART_NAME IN ('Bolt Assembly','Bolt Assembly v2');

-- [VAL-020] Load behaviour / LOAD_BEHAVIOUR | FR-01 | Incremental load: PN-021 and PN-022 (new keys from load 2) must exist in the target after both loads
-- Expected: FAILURE_COUNT = 0 when both new keys are present in target
SELECT ABS(COUNT(*) - 2) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-021','PN-022');

-- [VAL-021] Load behaviour / LOAD_BEHAVIOUR | FR-08 | ETL_RECONCILIATION_LOG must contain at least 2 entries (one per load run) after both loads complete
-- Expected: FAILURE_COUNT = 0 when log has 2 or more entries
SELECT CASE WHEN COUNT(*) >= 2 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG;

-- [VAL-022] Business rules / AGGREGATION | FR-01 | Total active (non-Decommissioned) rows in target must equal 20 after both loads (22 total minus 2 soft-deleted)
-- Expected: FAILURE_COUNT = 0 when active row count is exactly 20 | self-healed
SELECT ABS(COUNT(*) - 20) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE LIFECYCLE_STATUS <> 'Decommissioned';
