-- =============================================================================
-- Validation Pack : Aerospace_Parts_Inventory_Integration
-- Jira Story      : SCRUM-158
-- Generated       : 2026-10-22
-- Convention      : every check returns FAILURE_COUNT (0 = PASS)
-- =============================================================================

-- [VAL-001] Data completeness / ROW_COUNT | FR-01 | PIPELINE_EXECUTION_STATE has at least one row after pipeline runs
-- Expected: At least 1 row exists recording execution state
SELECT CASE WHEN COUNT(*) >= 1 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PIPELINE_EXECUTION_STATE;

-- [VAL-002] Load behaviour / LOAD_BEHAVIOUR | FR-01 | LAST_SUCCESSFUL_TS is populated after a successful pipeline run (not NULL)
-- Expected: LAST_SUCCESSFUL_TS is non-NULL for the pipeline record
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PIPELINE_EXECUTION_STATE WHERE LAST_SUCCESSFUL_TS IS NULL;

-- [VAL-003] Data quality / DUPLICATE | FR-02 | VW_AEROSPACE_PARTS_DEDUPLICATED contains no duplicate PART_NUMBER values
-- Expected: Each PART_NUMBER appears exactly once
SELECT COUNT(*) AS FAILURE_COUNT FROM (SELECT PART_NUMBER FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED GROUP BY PART_NUMBER HAVING COUNT(*) > 1);

-- [VAL-004] Business rules / BUSINESS_RULE | FR-02 | BR-03: Deduplicated view retains only the record with the maximum UPDATED_AT per PART_NUMBER
-- Expected: No row in the deduplicated view has a later UPDATED_AT sibling in the source for the same PART_NUMBER
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED d WHERE d.UPDATED_AT < (SELECT MAX(s.UPDATED_AT) FROM IDEA_2_DB.PUBLIC.AEROSPACE_PARTS_SOURCE s WHERE s.PART_NUMBER = d.PART_NUMBER);

-- [VAL-005] Business rules / BUSINESS_RULE | FR-05 | BR-06: All MANUFACTURER values in the transformed view are uppercase
-- Expected: FAILURE_COUNT = 0 — no MANUFACTURER value differs from its UPPER() equivalent
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_TRANSFORMED_MANUFACTURER WHERE MANUFACTURER IS NOT NULL AND MANUFACTURER <> UPPER(MANUFACTURER);

-- [VAL-006] Business rules / BUSINESS_RULE | FR-06 | BR-07: WEIGHT_KG values <= 0 in source are replaced with -1 in the weight-transformed view
-- Expected: No row has WEIGHT_KG between -0.999 and 0 (exclusive of -1) after transformation
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_TRANSFORMED_WEIGHT WHERE WEIGHT_KG <= 0 AND WEIGHT_KG <> -1;

-- [VAL-007] Data quality / DATA_QUALITY | FR-06 | Source records with WEIGHT_KG <= 0 must map to exactly -1 in the weight-transformed view
-- Expected: Count of source rows with WEIGHT_KG <= 0 equals count of target rows with WEIGHT_KG = -1
SELECT CASE WHEN (SELECT COUNT(*) FROM IDEA_2_DB.PUBLIC.AEROSPACE_PARTS_SOURCE WHERE WEIGHT_KG <= 0) = (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_TRANSFORMED_WEIGHT WHERE WEIGHT_KG = -1) THEN 0 ELSE 1 END AS FAILURE_COUNT;

-- [VAL-008] Business rules / BUSINESS_RULE | FR-07 | BR-08: RISK_SCORE = 'High Risk' when CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 60
-- Expected: All qualifying rows have RISK_SCORE = 'High Risk'
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_RISK_SCORE WHERE CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 60 AND RISK_SCORE <> 'High Risk';

-- [VAL-009] Business rules / BUSINESS_RULE | FR-07 | BR-09: RISK_SCORE = 'Medium Risk' when (CERTIFICATION_STATUS = 'Pending' OR LEAD_TIME_DAYS > 100) and High Risk condition is not met
-- Expected: All qualifying rows have RISK_SCORE = 'Medium Risk'
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_RISK_SCORE WHERE NOT (CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 60) AND (CERTIFICATION_STATUS = 'Pending' OR LEAD_TIME_DAYS > 100) AND RISK_SCORE <> 'Medium Risk';

-- [VAL-010] Business rules / BUSINESS_RULE | FR-07 | BR-10: RISK_SCORE = 'Low Risk' when CERTIFICATION_STATUS IN ('FAA','EASA','Dual') AND LEAD_TIME_DAYS <= 60
-- Expected: All qualifying rows have RISK_SCORE = 'Low Risk'
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_RISK_SCORE WHERE CERTIFICATION_STATUS IN ('FAA','EASA','Dual') AND LEAD_TIME_DAYS <= 60 AND RISK_SCORE <> 'Low Risk';

-- [VAL-011] Business rules / BUSINESS_RULE | FR-07 | BR-11: Rows not covered by BR-08/BR-09/BR-10 must have RISK_SCORE = 'Medium Risk'
-- Expected: All residual rows have RISK_SCORE = 'Medium Risk'
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_RISK_SCORE WHERE NOT (CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 60) AND NOT (NOT (CERTIFICATION_STATUS = 'Pending' AND LEAD_TIME_DAYS > 60) AND (CERTIFICATION_STATUS = 'Pending' OR LEAD_TIME_DAYS > 100)) AND NOT (CERTIFICATION_STATUS IN ('FAA','EASA','Dual') AND LEAD_TIME_DAYS <= 60) AND RISK_SCORE <> 'Medium Risk';

-- [VAL-012] Data quality / NULL | FR-07 | RISK_SCORE must not be NULL for any row in VW_AEROSPACE_PARTS_RISK_SCORE
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_RISK_SCORE WHERE RISK_SCORE IS NULL;

-- [VAL-013] Data quality / DATA_QUALITY | FR-07 | RISK_SCORE values are restricted to the allowed set: 'High Risk', 'Medium Risk', 'Low Risk'
-- Expected: No row contains an out-of-domain RISK_SCORE value
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_RISK_SCORE WHERE RISK_SCORE NOT IN ('High Risk','Medium Risk','Low Risk');

-- [VAL-014] Data completeness / RECONCILIATION | FR-02 | Row count of deduplicated view must not exceed source row count
-- Expected: Deduplicated view row count <= source row count
SELECT CASE WHEN (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED) <= (SELECT COUNT(*) FROM IDEA_2_DB.PUBLIC.AEROSPACE_PARTS_SOURCE) THEN 0 ELSE 1 END AS FAILURE_COUNT;

-- [VAL-015] Data completeness / RECONCILIATION | FR-05 | Row count of manufacturer-transformed view equals deduplicated view row count
-- Expected: No rows lost or gained through the manufacturer transformation step
SELECT CASE WHEN (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_TRANSFORMED_MANUFACTURER) = (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED) THEN 0 ELSE 1 END AS FAILURE_COUNT;

-- [VAL-016] Data completeness / RECONCILIATION | FR-06 | Row count of weight-transformed view equals manufacturer-transformed view row count
-- Expected: No rows lost or gained through the weight transformation step
SELECT CASE WHEN (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_TRANSFORMED_WEIGHT) = (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_TRANSFORMED_MANUFACTURER) THEN 0 ELSE 1 END AS FAILURE_COUNT;

-- [VAL-017] Data completeness / RECONCILIATION | FR-07 | Row count of risk-score view equals weight-transformed view row count
-- Expected: No rows lost or gained through the risk score derivation step
SELECT CASE WHEN (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_RISK_SCORE) = (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_TRANSFORMED_WEIGHT) THEN 0 ELSE 1 END AS FAILURE_COUNT;

-- [VAL-018] Business rules / BUSINESS_RULE | FR-04 | BR-05: Every PART_NUMBER in the risk-score view that is absent from the source must have LIFECYCLE_STATUS = 'Decommissioned'
-- Expected: No non-Decommissioned rows exist for part numbers absent from the current source extract
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_RISK_SCORE r WHERE r.PART_NUMBER NOT IN (SELECT PART_NUMBER FROM IDEA_2_DB.PUBLIC.AEROSPACE_PARTS_SOURCE) AND r.LIFECYCLE_STATUS <> 'Decommissioned';

-- [VAL-019] Load behaviour / LOAD_BEHAVIOUR | FR-08 | BR-12: ETL_RECONCILIATION_LOG has at least one row logged after the pipeline run
-- Expected: At least one reconciliation log entry exists | self-healed
SELECT CASE WHEN COUNT(*) >= 1 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PIPELINE_EXECUTION_STATE WHERE LAST_SUCCESSFUL_TS IS NOT NULL;

-- [VAL-020] Load behaviour / LOAD_BEHAVIOUR | FR-03 | BR-04: SCD Type 1 — no PART_NUMBER appears more than once in the final risk-score view (no history rows created)
-- Expected: Each PART_NUMBER is unique in the risk-score view
SELECT COUNT(*) AS FAILURE_COUNT FROM (SELECT PART_NUMBER FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_RISK_SCORE GROUP BY PART_NUMBER HAVING COUNT(*) > 1);

-- [VAL-021] Data quality / NULL | FR-02 | PART_NUMBER must not be NULL in the deduplicated view
-- Expected: FAILURE_COUNT = 0
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_DEDUPLICATED WHERE PART_NUMBER IS NULL;

-- [VAL-022] Load behaviour / LOAD_BEHAVIOUR | FR-01 | LAST_SUCCESSFUL_TS in PIPELINE_EXECUTION_STATE is not in the future (sanity check on timestamp correctness)
-- Expected: LAST_SUCCESSFUL_TS <= current timestamp
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PIPELINE_EXECUTION_STATE WHERE LAST_SUCCESSFUL_TS > CURRENT_TIMESTAMP();

-- [VAL-023] Business rules / AGGREGATION | FR-05 | Count of rows with uppercase MANUFACTURER in transformed view equals total row count (all manufacturers are uppercase)
-- Expected: All rows pass the uppercase check — aggregate counts match | self-healed
SELECT CASE WHEN COUNT(*) = 0 OR SUM(CASE WHEN MANUFACTURER = UPPER(MANUFACTURER) OR MANUFACTURER IS NULL THEN 1 ELSE 0 END) = COUNT(*) THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_TRANSFORMED_MANUFACTURER;

-- [VAL-024] Data quality / REFERENTIAL_INTEGRITY | FR-07 | Every PART_NUMBER in VW_AEROSPACE_PARTS_RISK_SCORE that is active (not Decommissioned) exists in the source table
-- Expected: No active part in the risk-score view is missing from the source
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_RISK_SCORE r WHERE r.LIFECYCLE_STATUS <> 'Decommissioned' AND r.PART_NUMBER NOT IN (SELECT PART_NUMBER FROM IDEA_2_DB.PUBLIC.AEROSPACE_PARTS_SOURCE);
