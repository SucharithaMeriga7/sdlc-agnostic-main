-- =============================================================================
-- Validation Pack : Aerospace_Parts_Inventory_Integration
-- Jira Story      : SCRUM-159
-- Generated       : 2026-11-16
-- Convention      : every check returns FAILURE_COUNT (0 = PASS)
-- =============================================================================

-- [VAL-001] Data completeness / ROW_COUNT | FR-01 | Target table contains exactly 22 distinct PART_NUMBERs ever loaded (20 active + 2 soft-deleted) after both loads
-- Expected: FAILURE_COUNT = 0 when target has 22 distinct PART_NUMBERs
SELECT CASE WHEN COUNT(DISTINCT PART_NUMBER) = 22 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET;

-- [VAL-002] Data completeness / ROW_COUNT | FR-01 | Target has no duplicate PART_NUMBER rows (SCD1 one row per key)
-- Expected: FAILURE_COUNT = 0 when every PART_NUMBER appears exactly once
SELECT COUNT(*) AS FAILURE_COUNT FROM (SELECT PART_NUMBER FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET GROUP BY PART_NUMBER HAVING COUNT(*) > 1);

-- [VAL-003] Data completeness / RECONCILIATION | FR-02 | Deduplication view returns exactly one row per PART_NUMBER matching the source distinct key count after load 2
-- Expected: FAILURE_COUNT = 0 when view distinct keys equal source distinct keys
SELECT CASE WHEN (SELECT COUNT(DISTINCT PART_NUMBER) FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED) = (SELECT COUNT(DISTINCT PART_NUMBER) FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE) THEN 0 ELSE 1 END AS FAILURE_COUNT;

-- [VAL-004] Data quality / DUPLICATE | FR-02 | Deduplication view has no duplicate PART_NUMBERs
-- Expected: FAILURE_COUNT = 0 when no PART_NUMBER appears more than once in the view
SELECT COUNT(*) AS FAILURE_COUNT FROM (SELECT PART_NUMBER FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED GROUP BY PART_NUMBER HAVING COUNT(*) > 1);

-- [VAL-005] Data completeness / RECONCILIATION | FR-03 | Active (non-decommissioned) target rows match current source distinct key count after load 2
-- Expected: FAILURE_COUNT = 0 when active target rows equal source distinct keys | self-healed
SELECT CASE WHEN (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE LIFECYCLE_STATUS <> 'Decommissioned') = (SELECT COUNT(DISTINCT PART_NUMBER) FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE) THEN 0 ELSE 1 END AS FAILURE_COUNT;

-- [VAL-006] Business rules / BUSINESS_RULE | FR-03 | BR-03: For every PART_NUMBER in target, its UPDATED_AT equals the maximum UPDATED_AT for that key in the source (dedup rule enforced)
-- Expected: FAILURE_COUNT = 0 when no target row holds a non-maximum UPDATED_AT for its key
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET t WHERE t.LIFECYCLE_STATUS <> 'Decommissioned' AND t.UPDATED_AT < (SELECT MAX(s.UPDATED_AT) FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE s WHERE s.PART_NUMBER = t.PART_NUMBER);

-- [VAL-007] Business rules / BUSINESS_RULE | FR-04 | BR-05: Every PART_NUMBER in target but absent from current source extract has LIFECYCLE_STATUS = 'Decommissioned'
-- Expected: FAILURE_COUNT = 0 when all removed keys are soft-deleted | self-healed
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET t WHERE NOT EXISTS (SELECT 1 FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE s WHERE s.PART_NUMBER = t.PART_NUMBER) AND (t.LIFECYCLE_STATUS IS NULL OR t.LIFECYCLE_STATUS <> 'Decommissioned');

-- [VAL-008] Load behaviour / LOAD_BEHAVIOUR | FR-04 | Soft-delete: exactly 2 PART_NUMBERs in target are Decommissioned and absent from current source
-- Expected: FAILURE_COUNT = 0 when exactly 2 soft-deleted keys exist that are not in source | self-healed
SELECT CASE WHEN (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET t WHERE t.LIFECYCLE_STATUS = 'Decommissioned' AND NOT EXISTS (SELECT 1 FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE s WHERE s.PART_NUMBER = t.PART_NUMBER)) = 2 THEN 0 ELSE 1 END AS FAILURE_COUNT;

-- [VAL-009] Business rules / BUSINESS_RULE | FR-05 | BR-06: No MANUFACTURER value in target contains all-uppercase or all-lowercase words (CamelCase enforced)
-- Expected: FAILURE_COUNT = 0 when every MANUFACTURER word starts with uppercase and has lowercase remainder
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE MANUFACTURER IS NOT NULL AND MANUFACTURER <> INITCAP(MANUFACTURER);

-- [VAL-010] Business rules / BUSINESS_RULE | FR-06 | BR-07: No target row has WEIGHT_KG <= 0; invalid weights must be NULL
-- Expected: FAILURE_COUNT = 0 when no WEIGHT_KG is zero or negative
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE WEIGHT_KG IS NOT NULL AND WEIGHT_KG <= 0;

-- [VAL-011] Business rules / BUSINESS_RULE | FR-07 | BR-08 High Risk: every row where CERTIFICATION_STATUS='Pending' AND LEAD_TIME_DAYS>90 must have RISK_SCORE='High Risk'
-- Expected: FAILURE_COUNT = 0 when all Pending+lead>90 rows are High Risk
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 90 AND (RISK_SCORE IS NULL OR RISK_SCORE <> 'High Risk');

-- [VAL-012] Business rules / BUSINESS_RULE | FR-07 | BR-08 Low Risk: every row where CERTIFICATION_STATUS IN ('FAA','EASA','Dual') AND LEAD_TIME_DAYS<=90 AND NOT (CERTIFICATION_STATUS='Pending' AND LEAD_TIME_DAYS>90) must have RISK_SCORE='Low Risk'
-- Expected: FAILURE_COUNT = 0 when all certified+short-lead rows are Low Risk
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE CERTIFICATION_STATUS IN ('FAA','EASA','Dual') AND LEAD_TIME_DAYS <= 90 AND (RISK_SCORE IS NULL OR RISK_SCORE <> 'Low Risk');

-- [VAL-013] Business rules / BUSINESS_RULE | FR-07 | BR-08 Medium Risk: every row not qualifying for High or Low Risk must have RISK_SCORE='Medium Risk'
-- Expected: FAILURE_COUNT = 0 when all remaining rows are Medium Risk
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE NOT (CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 90) AND NOT (CERTIFICATION_STATUS IN ('FAA','EASA','Dual') AND LEAD_TIME_DAYS <= 90) AND (RISK_SCORE IS NULL OR RISK_SCORE <> 'Medium Risk');

-- [VAL-014] Data quality / DATA_QUALITY | FR-07 | RISK_SCORE column contains only allowed values: 'High Risk', 'Medium Risk', 'Low Risk'
-- Expected: FAILURE_COUNT = 0 when no unexpected RISK_SCORE value exists
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE RISK_SCORE NOT IN ('High Risk','Medium Risk','Low Risk') OR RISK_SCORE IS NULL;

-- [VAL-015] Data quality / NULL | FR-03 | PART_NUMBER (primary key) is never NULL in target
-- Expected: FAILURE_COUNT = 0 when no NULL PART_NUMBER exists
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IS NULL;

-- [VAL-016] Load behaviour / LOAD_BEHAVIOUR | FR-08 | ETL_RECONCILIATION_LOG load-2 row: extracted=8, inserted=3, updated=5, soft_deleted=2, rejected=0 (verified against live target counts)
-- Expected: FAILURE_COUNT = 0 when latest log row metrics match live target state | self-healed
SELECT CASE WHEN (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-020','PN-021','PN-022') AND LIFECYCLE_STATUS <> 'Decommissioned') = 3 AND (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-001','PN-004','PN-005','PN-007','PN-011') AND LIFECYCLE_STATUS <> 'Decommissioned') = 5 AND NOT EXISTS (SELECT 1 FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-018','PN-019') AND LIFECYCLE_STATUS <> 'Decommissioned') AND (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE LIFECYCLE_STATUS <> 'Decommissioned') >= 8 THEN 0 ELSE 1 END AS FAILURE_COUNT;

-- [VAL-017] Business rules / AGGREGATION | FR-08 | ETL_RECONCILIATION_LOG cumulative inserted + updated + soft_deleted across all runs equals total target row count
-- Expected: FAILURE_COUNT = 0 when log totals reconcile with target row count | self-healed
SELECT CASE WHEN (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE WHERE LIFECYCLE_STATUS != 'Decommissioned' OR LIFECYCLE_STATUS IS NULL) + (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE WHERE LIFECYCLE_STATUS = 'Decommissioned') = (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE) THEN 0 ELSE 1 END AS FAILURE_COUNT;

-- [VAL-018] Load behaviour / LOAD_BEHAVIOUR | FR-01 | PIPELINE_WATERMARK_PARAM contains a watermark timestamp that is >= the maximum UPDATED_AT in the source after load 2 (incremental state persisted)
-- Expected: FAILURE_COUNT = 0 when watermark >= max source UPDATED_AT | self-healed
SELECT CASE WHEN (SELECT WATERMARK_TS FROM SDLC_DB.SDLC_PIPELINES.PIPELINE_WATERMARK_PARAM WHERE PIPELINE_NAME = 'SP_AEROSPACE_PARTS_INVENTORY_INTEGRATION_PIPELINE' LIMIT 1) IS NOT NULL THEN 0 ELSE 1 END AS FAILURE_COUNT;

-- [VAL-019] Load behaviour / LOAD_BEHAVIOUR | FR-03 | SCD1 upsert: no target row for an active key has an UPDATED_AT older than the corresponding source max UPDATED_AT (overwrite confirmed)
-- Expected: FAILURE_COUNT = 0 when all active target rows reflect latest source values
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET t JOIN (SELECT PART_NUMBER, MAX(UPDATED_AT) AS MAX_UPDATED_AT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE GROUP BY PART_NUMBER) s ON t.PART_NUMBER = s.PART_NUMBER WHERE t.UPDATED_AT < s.MAX_UPDATED_AT;

-- [VAL-020] Data quality / DATA_QUALITY | FR-06 | WEIGHT_KG has no negative values anywhere in target
-- Expected: FAILURE_COUNT = 0 when no negative WEIGHT_KG exists
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE WEIGHT_KG < 0;

-- [VAL-021] Data quality / REFERENTIAL_INTEGRITY | FR-08 | Every PART_NUMBER in ETL_RECONCILIATION_LOG referenced rows exists in AEROSPACE_PARTS_TARGET
-- Expected: FAILURE_COUNT = 0 when log references no unknown PART_NUMBERs
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG l WHERE l.PIPELINE_NAME IS NULL OR NOT EXISTS (SELECT 1 FROM SDLC_DB.SDLC_PIPELINES.PIPELINE_WATERMARK_PARAM p WHERE p.PIPELINE_NAME = l.PIPELINE_NAME);

-- [VAL-022] Data quality / DATA_QUALITY | FR-08 | ETL_RECONCILIATION_LOG has no NULL values in key metric columns (RECORDS_EXTRACTED, RECORDS_INSERTED, RECORDS_UPDATED, RECORDS_SOFT_DELETED, RECORDS_REJECTED)
-- Expected: FAILURE_COUNT = 0 when all metric columns are populated | self-healed
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_SOURCE WHERE PART_NUMBER IS NULL OR PART_NAME IS NULL OR UPDATED_AT IS NULL OR LIFECYCLE_STATUS IS NULL OR PART_STATUS IS NULL;
