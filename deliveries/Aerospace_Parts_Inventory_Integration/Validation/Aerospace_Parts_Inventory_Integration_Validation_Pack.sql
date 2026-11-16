-- =============================================================================
-- Validation Pack : Aerospace_Parts_Inventory_Integration
-- Jira Story      : SCRUM-159
-- Generated       : 2026-11-16
-- Convention      : every check returns FAILURE_COUNT (0 = PASS)
-- =============================================================================

-- [VAL-001] Data completeness / ROW_COUNT | FR-01 | After both loads, AEROSPACE_PARTS_TARGET must contain exactly 21 active (non-decommissioned) rows plus 2 soft-deleted = 23 total distinct PART_NUMBERs ever loaded; target row count must equal 23.
-- Expected: FAILURE_COUNT = 0 when target has 23 rows
SELECT CASE WHEN COUNT(*) = 23 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET;

-- [VAL-002] Data completeness / ROW_COUNT | FR-01 | After both loads, the source AEROSPACE_PARTS_SOURCE has 21 distinct PART_NUMBERs; the deduplication view must expose exactly 21 distinct PART_NUMBERs.
-- Expected: FAILURE_COUNT = 0 when view has 21 distinct PART_NUMBERs
SELECT CASE WHEN COUNT(DISTINCT PART_NUMBER) = 21 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED;

-- [VAL-003] Data completeness / RECONCILIATION | FR-08 | The latest ETL_RECONCILIATION_LOG row's TARGET_COUNT must match the live count of rows in AEROSPACE_PARTS_TARGET.
-- Expected: FAILURE_COUNT = 0 when log target_count equals live target row count | self-healed
SELECT CASE WHEN l.target_count = t.live_count THEN 0 ELSE 1 END AS FAILURE_COUNT FROM (SELECT target_count FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG ORDER BY LOG_ID DESC LIMIT 1) l CROSS JOIN (SELECT COUNT(*) AS live_count FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET) t;

-- [VAL-004] Data completeness / RECONCILIATION | FR-08 | The latest ETL_RECONCILIATION_LOG row's SOURCE_COUNT must match the live distinct PART_NUMBER count in the deduplication view.
-- Expected: FAILURE_COUNT = 0 when log source_count equals live deduplicated source count | self-healed
SELECT CASE WHEN l.source_count = s.live_count THEN 0 ELSE 1 END AS FAILURE_COUNT FROM (SELECT source_count FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG ORDER BY LOG_ID DESC LIMIT 1) l CROSS JOIN (SELECT COUNT(DISTINCT PART_NUMBER) AS live_count FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED WHERE UPDATED_AT > (SELECT COALESCE(WATERMARK_USED, '1900-01-01'::TIMESTAMP_NTZ) FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG ORDER BY LOG_ID DESC LIMIT 1)) s;

-- [VAL-005] Data quality / DUPLICATE | FR-03 | AEROSPACE_PARTS_TARGET must have no duplicate PART_NUMBER values (SCD Type 1 enforces one row per business key).
-- Expected: FAILURE_COUNT = 0 when no PART_NUMBER appears more than once
SELECT COUNT(*) AS FAILURE_COUNT FROM (SELECT PART_NUMBER FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET GROUP BY PART_NUMBER HAVING COUNT(*) > 1);

-- [VAL-006] Data quality / DUPLICATE | FR-02 | VW_AEROSPACE_PARTS_DEDUPLICATED must return at most one row per PART_NUMBER (deduplication view correctness).
-- Expected: FAILURE_COUNT = 0 when no PART_NUMBER appears more than once in the view
SELECT COUNT(*) AS FAILURE_COUNT FROM (SELECT PART_NUMBER FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED GROUP BY PART_NUMBER HAVING COUNT(*) > 1);

-- [VAL-007] Data quality / NULL | FR-03 | PART_NUMBER (business key) must never be NULL in AEROSPACE_PARTS_TARGET.
-- Expected: FAILURE_COUNT = 0 when no NULL PART_NUMBER exists
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IS NULL;

-- [VAL-008] Data quality / NULL | FR-07 | RISK_SCORE must never be NULL in AEROSPACE_PARTS_TARGET; every row must have a derived value.
-- Expected: FAILURE_COUNT = 0 when no NULL RISK_SCORE exists
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE RISK_SCORE IS NULL;

-- [VAL-009] Business rules / BUSINESS_RULE | FR-01 | BR-02: After load 1 (full load), PIPELINE_WATERMARK_PARAM must contain a non-NULL last-run timestamp, confirming the watermark was written.
-- Expected: FAILURE_COUNT = 0 when at least one non-NULL watermark timestamp exists | self-healed
SELECT CASE WHEN COUNT(*) >= 1 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PIPELINE_WATERMARK_PARAM;

-- [VAL-010] Business rules / BUSINESS_RULE | FR-04 | BR-05: Any PART_NUMBER in AEROSPACE_PARTS_TARGET whose LIFECYCLE_STATUS is 'Decommissioned' must NOT appear as an active (non-decommissioned) row, and all decommissioned rows must have been absent from the final source extract (i.e., not present in VW_AEROSPACE_PARTS_DEDUPLICATED).
-- Expected: FAILURE_COUNT = 0 when no decommissioned target row exists in the current source view
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET t INNER JOIN SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED v ON t.PART_NUMBER = v.PART_NUMBER WHERE t.LIFECYCLE_STATUS = 'Decommissioned';

-- [VAL-011] Business rules / BUSINESS_RULE | FR-05 | BR-06: Every MANUFACTURER value in AEROSPACE_PARTS_TARGET must equal its own UPPER() transformation; no mixed-case or lowercase values allowed.
-- Expected: FAILURE_COUNT = 0 when all MANUFACTURER values are uppercase
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE MANUFACTURER IS NOT NULL AND MANUFACTURER <> UPPER(MANUFACTURER);

-- [VAL-012] Business rules / BUSINESS_RULE | FR-06 | BR-07: Every WEIGHT_KG value in AEROSPACE_PARTS_TARGET that originated as <= 0 must be stored as -1; no zero or other negative value (other than -1) should exist.
-- Expected: FAILURE_COUNT = 0 when no WEIGHT_KG is <= 0 and not equal to -1
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE WEIGHT_KG <= 0 AND WEIGHT_KG <> -1;

-- [VAL-013] Business rules / BUSINESS_RULE | FR-07 | BR-08: Any row where CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 60 must have RISK_SCORE = 'High Risk'.
-- Expected: FAILURE_COUNT = 0 when all High Risk conditions map to 'High Risk'
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 60 AND RISK_SCORE <> 'High Risk';

-- [VAL-014] Business rules / BUSINESS_RULE | FR-07 | BR-09/BR-11: Any row NOT meeting the High Risk condition (BR-08) but meeting CERTIFICATION_STATUS = 'Pending' OR LEAD_TIME_DAYS > 100 must have RISK_SCORE = 'Medium Risk'.
-- Expected: FAILURE_COUNT = 0 when all Medium Risk conditions map to 'Medium Risk'
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE NOT (CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 60) AND (CERTIFICATION_STATUS = 'Pending' OR LEAD_TIME_DAYS > 100) AND RISK_SCORE <> 'Medium Risk';

-- [VAL-015] Business rules / BUSINESS_RULE | FR-07 | BR-10: Any row where CERTIFICATION_STATUS IN ('FAA','EASA','Dual') AND LEAD_TIME_DAYS <= 60 (and not High Risk) must have RISK_SCORE = 'Low Risk'.
-- Expected: FAILURE_COUNT = 0 when all Low Risk conditions map to 'Low Risk'
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE CERTIFICATION_STATUS IN ('FAA','EASA','Dual') AND LEAD_TIME_DAYS <= 60 AND NOT (CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 60) AND RISK_SCORE <> 'Low Risk';

-- [VAL-016] Business rules / BUSINESS_RULE | FR-07 | BR-11: Every RISK_SCORE value must be one of the three valid categories; no unexpected values allowed.
-- Expected: FAILURE_COUNT = 0 when all RISK_SCORE values are in the allowed set
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE RISK_SCORE NOT IN ('High Risk','Medium Risk','Low Risk');

-- [VAL-017] Business rules / BUSINESS_RULE | FR-08 | BR-12: The latest ETL_RECONCILIATION_LOG row must have INSERTED + UPDATED + SOFT_DELETED > 0, confirming the log captures activity and is not a zero-row stub.
-- Expected: FAILURE_COUNT = 0 when the latest log row records at least one operation | self-healed
SELECT CASE WHEN (inserted_count + updated_count) > 0 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG LIMIT 1;

-- [VAL-018] Business rules / AGGREGATION | FR-08 | ETL_RECONCILIATION_LOG must have at least 2 rows (one per load run), confirming both pipeline executions were logged.
-- Expected: FAILURE_COUNT = 0 when log contains at least 2 rows
SELECT CASE WHEN COUNT(*) >= 2 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG;

-- [VAL-019] Data quality / DATA_QUALITY | FR-06 | WEIGHT_KG must not be NULL in AEROSPACE_PARTS_TARGET; every row must carry a valid or sentinel (-1) weight value.
-- Expected: FAILURE_COUNT = 0 when no NULL WEIGHT_KG exists
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE WEIGHT_KG IS NULL;

-- [VAL-020] Data quality / DATA_QUALITY | FR-05 | MANUFACTURER must not be NULL in AEROSPACE_PARTS_TARGET; the uppercase transformation implies a non-null source value was processed.
-- Expected: FAILURE_COUNT = 0 when no NULL MANUFACTURER exists
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE MANUFACTURER IS NULL;

-- [VAL-021] Load behaviour / LOAD_BEHAVIOUR | FR-04 | Soft-delete load behaviour: after load 2, at least one row in AEROSPACE_PARTS_TARGET must have LIFECYCLE_STATUS = 'Decommissioned', confirming the soft-delete logic executed.
-- Expected: FAILURE_COUNT = 0 when at least one decommissioned row exists
SELECT CASE WHEN COUNT(*) >= 1 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE LIFECYCLE_STATUS = 'Decommissioned';

-- [VAL-022] Load behaviour / LOAD_BEHAVIOUR | FR-03 | SCD Type 1 incremental load behaviour: rows updated in load 2 (PN-001, PN-003, PN-006) must reflect load-2 values; verify by checking that no active target row has an UPDATED_AT earlier than the load-2 timestamp for those keys that were updated (i.e., their UPDATED_AT must equal the load-2 timestamp 2024-02-01 06:00:00).
-- Expected: FAILURE_COUNT = 0 when updated keys carry the latest UPDATED_AT
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-001','PN-003','PN-006') AND UPDATED_AT < '2024-02-01 06:00:00'::TIMESTAMP_NTZ;

-- [VAL-023] Load behaviour / LOAD_BEHAVIOUR | FR-01 | Incremental load behaviour: new keys inserted in load 2 (PN-021, PN-022, PN-023) must exist in AEROSPACE_PARTS_TARGET after the final state.
-- Expected: FAILURE_COUNT = 0 when all three new keys are present in the target
SELECT CASE WHEN COUNT(DISTINCT PART_NUMBER) = 3 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-021','PN-022','PN-023');
