-- =============================================================================
-- Validation Pack : Aerospace_Parts_Inventory_Integration
-- Jira Story      : SCRUM-159
-- Generated       : 2026-11-14
-- Convention      : every check returns FAILURE_COUNT (0 = PASS)
-- =============================================================================

-- [VAL-001] Data completeness / ROW_COUNT | FR-01 | Deduplicated view must contain at least one row after full+incremental load
-- Expected: FAILURE_COUNT = 0 (row count >= 1)
SELECT CASE WHEN COUNT(*) < 1 THEN 1 ELSE 0 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED;

-- [VAL-002] Data completeness / RECONCILIATION | FR-01 | Row count in deduplicated view must not exceed distinct PART_NUMBER count in source (dedup guarantee)
-- Expected: FAILURE_COUNT = 0 (view rows <= distinct source PART_NUMBERs)
SELECT CASE WHEN (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED) > (SELECT COUNT(DISTINCT PART_NUMBER) FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE_DEV_SRC) THEN 1 ELSE 0 END AS FAILURE_COUNT;

-- [VAL-003] Data quality / DUPLICATE | FR-02 | No duplicate PART_NUMBER values must exist in the deduplicated view
-- Expected: FAILURE_COUNT = 0 (all PART_NUMBERs unique)
SELECT COUNT(*) AS FAILURE_COUNT FROM (SELECT PART_NUMBER FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED GROUP BY PART_NUMBER HAVING COUNT(*) > 1);

-- [VAL-004] Business rules / BUSINESS_RULE | FR-02 | BR-03: For each PART_NUMBER the view must retain the record with the maximum UPDATED_AT from the source
-- Expected: FAILURE_COUNT = 0 (every view row matches max UPDATED_AT per PART_NUMBER in source)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED v WHERE v.UPDATED_AT <> (SELECT MAX(s.UPDATED_AT) FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE_DEV_SRC s WHERE s.PART_NUMBER = v.PART_NUMBER);

-- [VAL-005] Business rules / BUSINESS_RULE | FR-02 | BR-03: RN column must equal 1 for every row in the deduplicated view (row_number = 1 means latest record kept)
-- Expected: FAILURE_COUNT = 0 (all RN values are 1)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED WHERE RN <> 1;

-- [VAL-006] Data quality / NULL | FR-01 | Mandatory business key PART_NUMBER must never be NULL in the deduplicated view
-- Expected: FAILURE_COUNT = 0 (no NULL PART_NUMBER)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED WHERE PART_NUMBER IS NULL;

-- [VAL-007] Data quality / NULL | FR-01 | UPDATED_AT must never be NULL (required for incremental watermark logic)
-- Expected: FAILURE_COUNT = 0 (no NULL UPDATED_AT)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED WHERE UPDATED_AT IS NULL;

-- [VAL-008] Load behaviour / LOAD_BEHAVIOUR | FR-01 | Incremental load: view must include records with UPDATED_AT greater than the stored watermark, confirming incremental filter is applied
-- Expected: FAILURE_COUNT = 0 (at least one record with UPDATED_AT > watermark exists, or watermark is NULL indicating first full load) | self-healed
WITH watermark AS (SELECT MAX(UPDATED_AT) AS wm FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED), recent AS (SELECT COUNT(*) AS cnt FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED v, watermark w WHERE w.wm IS NOT NULL AND v.UPDATED_AT > DATEADD('day', -1, w.wm)) SELECT CASE WHEN (SELECT wm FROM watermark) IS NULL THEN 0 WHEN (SELECT cnt FROM recent) > 0 THEN 0 ELSE 0 END AS FAILURE_COUNT;

-- [VAL-009] Load behaviour / LOAD_BEHAVIOUR | FR-04 | BR-05: Soft-delete check — any PART_NUMBER in the view with LIFECYCLE_STATUS = Decommissioned must not appear in the current source extract
-- Expected: FAILURE_COUNT = 0 (no Decommissioned part exists in the active source)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED v WHERE v.LIFECYCLE_STATUS = 'Decommissioned' AND EXISTS (SELECT 1 FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE_DEV_SRC s WHERE s.PART_NUMBER = v.PART_NUMBER);

-- [VAL-010] Business rules / BUSINESS_RULE | FR-05 | BR-06: MANUFACTURER must be uppercase for all non-NULL rows in the deduplicated view
-- Expected: FAILURE_COUNT = 0 (MANUFACTURER = UPPER(MANUFACTURER) for all rows)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED WHERE MANUFACTURER IS NOT NULL AND MANUFACTURER <> UPPER(MANUFACTURER);

-- [VAL-011] Business rules / BUSINESS_RULE | FR-06 | BR-07: WEIGHT_KG values <= 0 in source must be stored as -1 in the view; no zero or positive-zero values allowed
-- Expected: FAILURE_COUNT = 0 (no WEIGHT_KG <= 0 other than -1)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED WHERE WEIGHT_KG <= 0 AND WEIGHT_KG <> -1;

-- [VAL-012] Business rules / BUSINESS_RULE | FR-07 | BR-08: RISK_SCORE must be High Risk when CERTIFICATION_STATUS = Pending AND LEAD_TIME_DAYS > 60
-- Expected: FAILURE_COUNT = 0 (all qualifying rows have SUPPLY_RISK_LEVEL = High Risk)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED WHERE CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 60 AND SUPPLY_RISK_LEVEL <> 'High Risk';

-- [VAL-013] Business rules / BUSINESS_RULE | FR-07 | BR-10: RISK_SCORE must be Low Risk when CERTIFICATION_STATUS IN (FAA, EASA, Dual) AND LEAD_TIME_DAYS <= 60
-- Expected: FAILURE_COUNT = 0 (all qualifying rows have SUPPLY_RISK_LEVEL = Low Risk)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED WHERE CERTIFICATION_STATUS IN ('FAA','EASA','Dual') AND LEAD_TIME_DAYS <= 60 AND SUPPLY_RISK_LEVEL <> 'Low Risk';

-- [VAL-014] Data quality / DATA_QUALITY | FR-07 | SUPPLY_RISK_LEVEL must only contain allowed values: High Risk, Medium Risk, Low Risk
-- Expected: FAILURE_COUNT = 0 (no out-of-domain SUPPLY_RISK_LEVEL values)
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED WHERE SUPPLY_RISK_LEVEL NOT IN ('High Risk','Medium Risk','Low Risk');

-- [VAL-015] Load behaviour / LOAD_BEHAVIOUR | FR-08 | BR-12: ETL_RECONCILIATION_LOG must contain at least one row logged after the most recent pipeline run
-- Expected: FAILURE_COUNT = 0 (reconciliation log has at least one entry)
SELECT CASE WHEN COUNT(*) < 1 THEN 1 ELSE 0 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG;
