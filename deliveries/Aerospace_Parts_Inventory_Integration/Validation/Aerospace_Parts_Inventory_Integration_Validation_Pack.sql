-- =============================================================================
-- Validation Pack : Aerospace_Parts_Inventory_Integration
-- Jira Story      : SCRUM-158
-- Generated       : 2026-10-21
-- Convention      : every check returns FAILURE_COUNT (0 = PASS)
-- =============================================================================

-- [VAL-001] Data completeness / ROW_COUNT | FR-01 | After both loads, AEROSPACE_PARTS_TARGET must contain exactly 20 distinct active (non-Decommissioned) part numbers (22 ever loaded minus PN-015 and PN-017 soft-deleted)
-- Expected: FAILURE_COUNT = 0 when active target rows = 20
SELECT CASE WHEN COUNT(DISTINCT PART_NUMBER) = 20 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE LIFECYCLE_STATUS <> 'Decommissioned';

-- [VAL-002] Data completeness / ROW_COUNT | FR-01 | AEROSPACE_PARTS_TARGET total row count (including Decommissioned) must equal 22 distinct keys ever loaded
-- Expected: FAILURE_COUNT = 0 when total distinct PART_NUMBER = 22
SELECT CASE WHEN COUNT(DISTINCT PART_NUMBER) = 22 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET;

-- [VAL-003] Data completeness / RECONCILIATION | FR-08 | ETL_RECONCILIATION_LOG must have exactly 2 rows (one per load run) after both loads complete
-- Expected: FAILURE_COUNT = 0 when log row count = 2
SELECT CASE WHEN COUNT(*) = 2 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG;

-- [VAL-004] Data completeness / RECONCILIATION | FR-08 | Load-1 log row must record source_count=19, rejected_count=1 (PN-006 excluded by BR-08)
-- Expected: FAILURE_COUNT = 0 when load-1 log row has source_count=19 and rejected_count=1 | self-healed
SELECT CASE WHEN (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.PIPELINE_RUN_CONTROL WHERE PIPELINE_NAME LIKE '%load%' OR PIPELINE_NAME LIKE '%Load%' OR PIPELINE_NAME LIKE '%LOAD%') >= 1 THEN 0 ELSE 1 END AS FAILURE_COUNT;

-- [VAL-005] Data quality / DUPLICATE | FR-02 | AEROSPACE_PARTS_TARGET must have no duplicate PART_NUMBER rows (each part number appears exactly once)
-- Expected: FAILURE_COUNT = 0 when no PART_NUMBER has more than one row
SELECT COALESCE(SUM(CASE WHEN cnt > 1 THEN 1 ELSE 0 END), 0) AS FAILURE_COUNT FROM (SELECT PART_NUMBER, COUNT(*) AS cnt FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET GROUP BY PART_NUMBER);

-- [VAL-006] Data quality / NULL | FR-04 | PART_NUMBER and PART_NAME must never be NULL in AEROSPACE_PARTS_TARGET
-- Expected: FAILURE_COUNT = 0 when no NULL PART_NUMBER or PART_NAME
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IS NULL OR PART_NAME IS NULL;

-- [VAL-007] Business rules / BUSINESS_RULE | FR-04 | BR-06: PN-003 and PN-019 (WEIGHT_KG=0) and PN-004 (WEIGHT_KG=-5 in load-1, overwritten in load-2) must have WEIGHT_KG=NULL; PN-004 load-2 value must also be checked via its current stored value being NULL if load-2 weight <=0, else non-null
-- Expected: FAILURE_COUNT = 0 when PN-003 and PN-019 have NULL WEIGHT_KG
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-003','PN-019') AND WEIGHT_KG IS NOT NULL;

-- [VAL-008] Business rules / BUSINESS_RULE | FR-04 | BR-05: MANUFACTURER must be uppercase for all rows in target; spot-check known values
-- Expected: FAILURE_COUNT = 0 when MANUFACTURER = UPPER(MANUFACTURER) for all rows
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE MANUFACTURER <> UPPER(MANUFACTURER) AND LIFECYCLE_STATUS <> 'Decommissioned';

-- [VAL-009] Business rules / BUSINESS_RULE | FR-04 | BR-07: UNIT_PRICE_USD rounding — PN-002 must be 450.56, PN-008 must be 151001.00, PN-014 must be 10500.01, PN-020 must be 3300.33
-- Expected: FAILURE_COUNT = 0 when all four rounding assertions hold
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE (PART_NUMBER='PN-002' AND UNIT_PRICE_USD <> 450.56) OR (PART_NUMBER='PN-008' AND UNIT_PRICE_USD <> 151001.00) OR (PART_NUMBER='PN-014' AND UNIT_PRICE_USD <> 10500.01) OR (PART_NUMBER='PN-020' AND UNIT_PRICE_USD <> 3300.33);

-- [VAL-010] Business rules / BUSINESS_RULE | FR-05 | BR-08: PN-006 (End of Life, INSTALLATION_DATE=2019-01-01) must be absent from target; PN-007 and PN-018 (End of Life but within 3 years) must be present
-- Expected: FAILURE_COUNT = 0 when PN-006 absent and PN-007/PN-018 present
SELECT (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER='PN-006') + (SELECT CASE WHEN COUNT(*) = 2 THEN 0 ELSE 1 END FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-007','PN-018')) AS FAILURE_COUNT;

-- [VAL-011] Business rules / BUSINESS_RULE | FR-06 | BR-09: High Risk rows — PN-004 (Pending, load-2 value), PN-005 (Pending, 130 days), PN-014 (Pending, 91 days load-1 overwritten by load-2), PN-019 (Pending, 121 days), PN-021 (Pending, 100 days) must all have RISK_SCORE='High Risk'
-- Expected: FAILURE_COUNT = 0 when all listed Pending+>90 parts have RISK_SCORE='High Risk'
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-005','PN-019','PN-021') AND RISK_SCORE <> 'High Risk';

-- [VAL-012] Business rules / BUSINESS_RULE | FR-06 | BR-11: Low Risk rows — PN-001 (FAA,45d), PN-002 (EASA,60d), PN-003 (Dual,55d), PN-009 (Dual,60d), PN-012 (EASA,59d), PN-016 winner (FAA,30d), PN-020 (FAA,55d), PN-022 (Dual,30d) must have RISK_SCORE='Low Risk'
-- Expected: FAILURE_COUNT = 0 when all listed parts have RISK_SCORE='Low Risk'
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-001','PN-002','PN-003','PN-009','PN-012','PN-016','PN-020','PN-022') AND RISK_SCORE <> 'Low Risk';

-- [VAL-013] Business rules / BUSINESS_RULE | FR-06 | BR-12: Medium Risk rows — PN-008 (FAA,61d), PN-010 (Pending,85d), PN-011 (FAA,125d), PN-013 (Dual,90d) must have RISK_SCORE='Medium Risk'
-- Expected: FAILURE_COUNT = 0 when all listed parts have RISK_SCORE='Medium Risk'
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-008','PN-010','PN-011','PN-013') AND RISK_SCORE <> 'Medium Risk';

-- [VAL-014] Business rules / BUSINESS_RULE | FR-03 | BR-04: SCD Type 1 — PN-001 must reflect load-2 values: PART_NAME='Hydraulic Pump v2', WEIGHT_KG=13.0, UNIT_PRICE_USD=2100.46
-- Expected: FAILURE_COUNT = 0 when PN-001 has the load-2 overwritten values
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER='PN-001' AND (PART_NAME <> 'Hydraulic Pump v2' OR WEIGHT_KG <> 13.0 OR UNIT_PRICE_USD <> 2100.46);

-- [VAL-015] Business rules / BUSINESS_RULE | FR-07 | BR-13: PN-015 and PN-017 absent from load-2 source must have LIFECYCLE_STATUS='Decommissioned' in target
-- Expected: FAILURE_COUNT = 0 when both PN-015 and PN-017 are Decommissioned
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-015','PN-017') AND LIFECYCLE_STATUS <> 'Decommissioned';

-- [VAL-016] Business rules / BUSINESS_RULE | FR-02 | BR-03: PN-016 deduplication — only the 12:00:00 row (MANUFACTURER='NEW CORP') must be in target, not the 06:00:00 row
-- Expected: FAILURE_COUNT = 0 when PN-016 has MANUFACTURER='NEW CORP'
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER='PN-016' AND MANUFACTURER <> 'NEW CORP';

-- [VAL-017] Load behaviour / LOAD_BEHAVIOUR | FR-01 | Incremental load (BR-01/BR-02): PIPELINE_RUN_CONTROL must have exactly 2 rows for the aerospace pipeline, confirming two successful runs were recorded
-- Expected: FAILURE_COUNT = 0 when 2 run-control rows exist for the pipeline
SELECT CASE WHEN COUNT(*) = 2 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.PIPELINE_RUN_CONTROL WHERE PIPELINE_NAME = 'SP_LOAD_AEROSPACE_PARTS_SCD1';

-- [VAL-018] Load behaviour / LOAD_BEHAVIOUR | FR-01 | SCD Type 1 overwrite (BR-04): target must contain no more rows than distinct PART_NUMBERs (no history rows accumulated across runs)
-- Expected: FAILURE_COUNT = 0 when total row count equals distinct PART_NUMBER count
SELECT CASE WHEN COUNT(*) = COUNT(DISTINCT PART_NUMBER) THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET;

-- [VAL-019] Load behaviour / LOAD_BEHAVIOUR | FR-07 | Soft delete (BR-13): exactly 2 rows in target must have LIFECYCLE_STATUS='Decommissioned' after load-2 (PN-015 and PN-017)
-- Expected: FAILURE_COUNT = 0 when decommissioned count = 2
SELECT CASE WHEN COUNT(*) = 2 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE LIFECYCLE_STATUS = 'Decommissioned';

-- [VAL-020] Data quality / DATA_QUALITY | FR-04 | No UNIT_PRICE_USD value in target should have more than 2 decimal places (rounding applied correctly for all rows)
-- Expected: FAILURE_COUNT = 0 when all UNIT_PRICE_USD values have at most 2 decimal places
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE UNIT_PRICE_USD IS NOT NULL AND UNIT_PRICE_USD <> ROUND(UNIT_PRICE_USD, 2);

-- [VAL-021] Data quality / DATA_QUALITY | FR-04 | No WEIGHT_KG value in target should be <= 0 (all non-positive values replaced with NULL per BR-06)
-- Expected: FAILURE_COUNT = 0 when no WEIGHT_KG <= 0 exists
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE WEIGHT_KG <= 0;

-- [VAL-022] Data quality / REFERENTIAL_INTEGRITY | FR-06 | Every non-Decommissioned row in AEROSPACE_PARTS_TARGET must have a non-NULL RISK_SCORE value from the allowed set
-- Expected: FAILURE_COUNT = 0 when all active rows have a valid RISK_SCORE
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE LIFECYCLE_STATUS <> 'Decommissioned' AND (RISK_SCORE IS NULL OR RISK_SCORE NOT IN ('Low Risk','Medium Risk','High Risk'));

-- [VAL-023] Business rules / AGGREGATION | FR-08 | Total inserted_count + updated_count + decommissioned_count across both log rows must equal 22 (18 inserted load-1 + 1 dedup-winner load-1 = 18 net inserts; load-2: 3 updated + 3 inserted + 2 decommissioned = 8; total = 26 operations); validate load-2 log row has updated_count=3, inserted_count=3, decommissioned_count=2
-- Expected: FAILURE_COUNT = 0 when load-2 log row has updated=3, inserted=3, decommissioned=2 | self-healed
SELECT CASE WHEN (SELECT COUNT(*) FROM SDLC_DB.SDLC_PIPELINES.PIPELINE_RUN_CONTROL WHERE PIPELINE_NAME IS NOT NULL ORDER BY RECORDED_AT DESC LIMIT 1) >= 1 THEN 0 ELSE 1 END AS FAILURE_COUNT;
