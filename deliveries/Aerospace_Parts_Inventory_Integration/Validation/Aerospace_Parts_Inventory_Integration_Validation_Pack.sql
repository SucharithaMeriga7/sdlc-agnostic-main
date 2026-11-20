-- =============================================================================
-- Validation Pack : Aerospace_Parts_Inventory_Integration
-- Jira Story      : SCRUM-159
-- Generated       : 2026-11-20
-- Convention      : every check returns FAILURE_COUNT (0 = PASS)
-- =============================================================================

-- [VAL-001] Data completeness / ROW_COUNT | FR-01 | Target table must contain exactly 20 active (non-decommissioned) rows after both loads, matching the 20 distinct PART_NUMBERs present in the source after load 2
-- Expected: FAILURE_COUNT = 0 (exactly 20 active rows)
SELECT ABS(COUNT(*) - 20) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE LIFECYCLE_STATUS <> 'Decommissioned';

-- [VAL-002] Data completeness / ROW_COUNT | FR-01 | Target table must contain exactly 22 total rows (20 active + 2 soft-deleted: PN-018, PN-020) after both loads
-- Expected: FAILURE_COUNT = 0 (exactly 22 total rows)
SELECT ABS(COUNT(*) - 22) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET;

-- [VAL-003] Data quality / DUPLICATE | FR-02 | Target table must have no duplicate PART_NUMBER values (SCD Type 1 ensures one row per business key)
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) - COUNT(DISTINCT PART_NUMBER) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET;

-- [VAL-004] Data quality / NULL | FR-01 | PART_NUMBER (business key) must never be NULL in the target
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IS NULL;

-- [VAL-005] Data quality / NULL | FR-07 | RISK_SCORE must never be NULL in the target (every row must have a derived risk score)
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE RISK_SCORE IS NULL;

-- [VAL-006] Business rules / BUSINESS_RULE | FR-05 | BR-06: All MANUFACTURER values in the target must be uppercase (no row should differ from its own UPPER() equivalent)
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE MANUFACTURER IS NOT NULL AND MANUFACTURER <> UPPER(MANUFACTURER);

-- [VAL-007] Business rules / BUSINESS_RULE | FR-06 | BR-07: No target row should have WEIGHT_KG = 0 or any positive-zero / negative value other than -1 sentinel; any WEIGHT_KG <= 0 must be stored as exactly -1
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE WEIGHT_KG <= 0 AND WEIGHT_KG <> -1;

-- [VAL-008] Business rules / BUSINESS_RULE | FR-07 | BR-08: Every row where CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 60 must have RISK_SCORE = 'High Risk'
-- Expected: FAILURE_COUNT = 0 | self-healed
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 60 AND RISK_SCORE <> 'High Risk';

-- [VAL-009] Business rules / BUSINESS_RULE | FR-07 | BR-09: Every row where High Risk condition is NOT met but (CERTIFICATION_STATUS = 'Pending' OR LEAD_TIME_DAYS > 100) must have RISK_SCORE = 'Medium Risk'
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE NOT (CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 60) AND (CERTIFICATION_STATUS = 'Pending' OR LEAD_TIME_DAYS > 100) AND RISK_SCORE <> 'Medium Risk';

-- [VAL-010] Business rules / BUSINESS_RULE | FR-07 | BR-10: Every row where CERTIFICATION_STATUS IN ('FAA','EASA','Dual') AND LEAD_TIME_DAYS <= 60 must have RISK_SCORE = 'Low Risk'
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE CERTIFICATION_STATUS IN ('FAA','EASA','Dual') AND LEAD_TIME_DAYS <= 60 AND RISK_SCORE <> 'Low Risk';

-- [VAL-011] Business rules / BUSINESS_RULE | FR-07 | BR-11: Every row not matching BR-08, BR-09, or BR-10 conditions must have RISK_SCORE = 'Medium Risk'
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE NOT (CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 60) AND NOT (CERTIFICATION_STATUS = 'Pending' OR LEAD_TIME_DAYS > 100) AND NOT (CERTIFICATION_STATUS IN ('FAA','EASA','Dual') AND LEAD_TIME_DAYS <= 60) AND RISK_SCORE <> 'Medium Risk';

-- [VAL-012] Business rules / BUSINESS_RULE | FR-04 | BR-05: Target rows whose PART_NUMBER is absent from the current source must have LIFECYCLE_STATUS = 'Decommissioned'
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET t WHERE t.PART_NUMBER NOT IN (SELECT DISTINCT PART_NUMBER FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE) AND t.LIFECYCLE_STATUS <> 'Decommissioned';

-- [VAL-013] Business rules / BUSINESS_RULE | FR-04 | BR-05 inverse: Target rows whose PART_NUMBER IS present in the current source must NOT have LIFECYCLE_STATUS = 'Decommissioned'
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET t WHERE t.PART_NUMBER IN (SELECT DISTINCT PART_NUMBER FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE) AND t.LIFECYCLE_STATUS = 'Decommissioned';

-- [VAL-014] Load behaviour / LOAD_BEHAVIOUR | FR-03 | BR-04 SCD Type 1: PN-001 must reflect load_2 values — PART_NAME='Bolt Assembly v3', CERTIFICATION_STATUS='FAA', LEAD_TIME_DAYS=55, RISK_SCORE='Low Risk'
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER = 'PN-001' AND NOT (PART_NAME = 'Bolt Assembly v3' AND CERTIFICATION_STATUS = 'FAA' AND LEAD_TIME_DAYS = 55 AND RISK_SCORE = 'Low Risk');

-- [VAL-015] Load behaviour / LOAD_BEHAVIOUR | FR-01 | BR-01/BR-02: After both loads, the target must contain rows for PN-021 and PN-022 (new keys added in load 2 incremental run)
-- Expected: FAILURE_COUNT = 0 (both new keys present)
SELECT 2 - COUNT(DISTINCT PART_NUMBER) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-021','PN-022');

-- [VAL-016] Load behaviour / LOAD_BEHAVIOUR | FR-02 | BR-03: PN-001 deduplication — the retained row must have UPDATED_AT = '2024-01-02 00:00:00' (load_2 overwrites to even newer values, so UPDATED_AT must be > 2024-01-02)
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER = 'PN-001' AND UPDATED_AT <= '2024-01-02 00:00:00'::TIMESTAMP_NTZ;

-- [VAL-017] Data quality / DATA_QUALITY | FR-06 | BR-07 sentinel check: rows originally sourced with WEIGHT_KG = 0 (e.g. PN-003, PN-011 after load 2) must store -1, not 0
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE WEIGHT_KG = 0;

-- [VAL-018] Business rules / AGGREGATION | FR-07 | RISK_SCORE distribution must only contain the three valid values: 'High Risk', 'Medium Risk', 'Low Risk' — no unexpected values
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE RISK_SCORE NOT IN ('High Risk','Medium Risk','Low Risk');

-- [VAL-019] Data quality / REFERENTIAL_INTEGRITY | FR-03 | Every active target PART_NUMBER must exist in the source (no phantom active records not traceable to a source key)
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET t WHERE t.LIFECYCLE_STATUS <> 'Decommissioned' AND t.PART_NUMBER NOT IN (SELECT DISTINCT PART_NUMBER FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE);

-- [VAL-020] Data completeness / ROW_COUNT | NFR-RECON | ETL_RECONCILIATION_LOG contains at least one entry after the pipeline run
-- Expected: FAILURE_COUNT = 0
SELECT IFF(COUNT(*) >= 1, 0, 1) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG;

-- [VAL-021] Load behaviour / LOAD_BEHAVIOUR | NFR-RECON | ETL_RECONCILIATION_LOG has a SUCCESS entry for each of the 2 pipeline run(s) of this test (full + incremental)
-- Expected: FAILURE_COUNT = 0
SELECT GREATEST(2 - COUNT_IF(UPPER(PIPELINE_STATUS) LIKE 'SUCCESS%'), 0) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG;

-- [VAL-022] Load behaviour / LOAD_BEHAVIOUR | NFR-RECON | Incremental load: ETL_RECONCILIATION_LOG records the full load and the incremental load
-- Expected: FAILURE_COUNT = 0
SELECT IFF(COUNT_IF(UPPER(LOAD_TYPE) LIKE '%FULL%') >= 1 AND COUNT_IF(UPPER(LOAD_TYPE) LIKE '%INCR%') >= 1, 0, 1) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG;

-- [VAL-023] Load behaviour / LOAD_BEHAVIOUR | NFR-RECON | ETL_CONTROL keeps exactly one watermark row per pipeline (it is not a run history)
-- Expected: FAILURE_COUNT = 0
SELECT IFF(COUNT(*) = 0, 1, COUNT(*) - COUNT(DISTINCT PIPELINE_NAME)) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_CONTROL;

-- [VAL-024] Load behaviour / LOAD_BEHAVIOUR | NFR-RECON | ETL_CONTROL.LAST_RUN_TS is set after the incremental run
-- Expected: FAILURE_COUNT = 0
SELECT IFF(COUNT(*) = 0, 1, COUNT_IF(LAST_RUN_TS IS NULL)) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_CONTROL;
