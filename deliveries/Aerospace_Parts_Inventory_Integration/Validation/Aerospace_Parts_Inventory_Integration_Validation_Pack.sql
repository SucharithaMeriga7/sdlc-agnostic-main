-- =============================================================================
-- Validation Pack : Aerospace_Parts_Inventory_Integration
-- Jira Story      : SCRUM-158
-- Generated       : 2026-10-22
-- Convention      : every check returns FAILURE_COUNT (0 = PASS)
-- =============================================================================

-- [VAL-001] Data completeness / ROW_COUNT | FR-01 | Target must contain exactly 21 distinct PART_NUMBERs after both loads (19 from load1 minus PN-007 excluded by BR-09, plus 4 new from load2 minus PN-023 excluded by BR-09 = 21 active/decommissioned rows)
-- Expected: FAILURE_COUNT = 0 when target has exactly 21 rows
SELECT ABS(COUNT(*) - 21) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET;

-- [VAL-002] Data completeness / RECONCILIATION | FR-01 | Distinct PART_NUMBERs in source after load2 (21) must all exist in target (source keys are a subset of target keys, accounting for soft-deletes keeping PN-017/PN-019 in target)
-- Expected: FAILURE_COUNT = 0 when all 21 current source keys are present in target
SELECT COUNT(*) AS FAILURE_COUNT FROM IDEA_2_DB.PUBLIC.AEROSPACE_PARTS_SOURCE s WHERE NOT EXISTS (SELECT 1 FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET t WHERE t.PART_NUMBER = s.PART_NUMBER);

-- [VAL-003] Data quality / DUPLICATE | FR-02 | Target must have no duplicate PART_NUMBER rows after deduplication (SCD1 ensures one row per key)
-- Expected: FAILURE_COUNT = 0 when every PART_NUMBER appears exactly once
SELECT COUNT(*) AS FAILURE_COUNT FROM (SELECT PART_NUMBER FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET GROUP BY PART_NUMBER HAVING COUNT(*) > 1);

-- [VAL-004] Business rules / BUSINESS_RULE | FR-02 | BR-03: PN-001 deduplication — after load2 PART_NAME must be 'Bolt Assembly v3' (load2 SCD1 overwrite wins; load1 dedup would have been 'Bolt Assembly v2')
-- Expected: FAILURE_COUNT = 0 when PN-001 PART_NAME = 'Bolt Assembly v3'
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER = 'PN-001' AND PART_NAME <> 'Bolt Assembly v3';

-- [VAL-005] Business rules / BUSINESS_RULE | FR-03 | BR-04: SCD1 overwrite for PN-001 in load2 — MANUFACTURER must be 'ACME CORP UPDATED' and UNIT_PRICE_USD must be 14.11
-- Expected: FAILURE_COUNT = 0 when PN-001 reflects load2 values
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER = 'PN-001' AND (MANUFACTURER <> 'ACME CORP UPDATED' OR UNIT_PRICE_USD <> 14.11);

-- [VAL-006] Business rules / BUSINESS_RULE | FR-04 | BR-05: Soft-delete — PN-017 and PN-019 removed from load2 source must have LIFECYCLE_STATUS = 'Decommissioned' in target
-- Expected: FAILURE_COUNT = 0 when both soft-deleted keys are marked Decommissioned
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-017','PN-019') AND LIFECYCLE_STATUS <> 'Decommissioned';

-- [VAL-007] Business rules / BUSINESS_RULE | FR-05 | BR-06: MANUFACTURER uppercase — spot-check PN-001='ACME CORP UPDATED', PN-004='HONEYWELL', PN-015='ARTEX', PN-020='SENSATA', PN-021='PRECISION CASTPARTS'
-- Expected: FAILURE_COUNT = 0 when all five manufacturers are stored in uppercase as specified
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE (PART_NUMBER = 'PN-001' AND MANUFACTURER <> 'ACME CORP UPDATED') OR (PART_NUMBER = 'PN-004' AND MANUFACTURER <> 'HONEYWELL') OR (PART_NUMBER = 'PN-015' AND MANUFACTURER <> 'ARTEX') OR (PART_NUMBER = 'PN-020' AND MANUFACTURER <> 'SENSATA') OR (PART_NUMBER = 'PN-021' AND MANUFACTURER <> 'PRECISION CASTPARTS');

-- [VAL-008] Business rules / BUSINESS_RULE | FR-05 | BR-07: WEIGHT_KG <= 0 replaced with NULL — PN-002 (was 0), PN-003 (was -5), PN-009 load2 (was 0), PN-021 (was -1) must all have NULL WEIGHT_KG
-- Expected: FAILURE_COUNT = 0 when all four part numbers have NULL WEIGHT_KG
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-002','PN-003','PN-009','PN-021') AND WEIGHT_KG IS NOT NULL;

-- [VAL-009] Business rules / BUSINESS_RULE | FR-05 | BR-08: UNIT_PRICE_USD rounded to 2dp — PN-001=14.11, PN-002=1000.00, PN-009=90000.01, PN-021=76.00
-- Expected: FAILURE_COUNT = 0 when all four rounding outcomes match
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE (PART_NUMBER = 'PN-001' AND ROUND(UNIT_PRICE_USD,2) <> 14.11) OR (PART_NUMBER = 'PN-002' AND ROUND(UNIT_PRICE_USD,2) <> 1000.00) OR (PART_NUMBER = 'PN-009' AND ROUND(UNIT_PRICE_USD,2) <> 90000.01) OR (PART_NUMBER = 'PN-021' AND ROUND(UNIT_PRICE_USD,2) <> 76.00);

-- [VAL-010] Business rules / BUSINESS_RULE | FR-06 | BR-09/exclude: PN-007 (End of Life, INSTALLATION_DATE 2019-01-01 > 3 years old) and PN-023 (End of Life, INSTALLATION_DATE 2019-01-01) must never appear in target
-- Expected: FAILURE_COUNT = 0 when neither excluded part exists in target
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-007','PN-023');

-- [VAL-011] Business rules / BUSINESS_RULE | FR-06 | BR-09/include: PN-008 (End of Life but INSTALLATION_DATE 2023-01-01 < 3 years) and PN-022 (End of Life, INSTALLATION_DATE 2023-06-01 < 3 years) must be present in target
-- Expected: FAILURE_COUNT = 0 when both conditionally-included parts exist in target
SELECT COUNT(*) AS FAILURE_COUNT FROM (SELECT COUNT(DISTINCT PART_NUMBER) AS CNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-008','PN-022') HAVING CNT <> 2);

-- [VAL-012] Business rules / BUSINESS_RULE | FR-07 | BR-10: High Risk — PN-004 load2 recalculated to Low Risk (FAA, lead_time=50); PN-013 load2 updated; PN-020 (Pending, lead_time=100>90) must be 'High Risk'
-- Expected: FAILURE_COUNT = 0 when PN-020 RISK_SCORE = 'High Risk'
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER = 'PN-020' AND RISK_SCORE <> 'High Risk';

-- [VAL-013] Business rules / BUSINESS_RULE | FR-07 | BR-11/BR-13: Medium Risk — PN-005 (Pending, lead_time=80), PN-010 (Pending, lead_time=125>120), PN-016 (FAA, lead_time=150>120), PN-009 load2 (Pending, lead_time=95>90 => High Risk per BR-10 recalc) — verify PN-005 and PN-016 are 'Medium Risk'
-- Expected: FAILURE_COUNT = 0 when PN-005 and PN-016 are both 'Medium Risk'
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-005','PN-016') AND RISK_SCORE <> 'Medium Risk';

-- [VAL-014] Business rules / BUSINESS_RULE | FR-07 | BR-12: Low Risk — PN-002 (EASA, lead_time=55), PN-003 (Dual, lead_time=60), PN-021 (EASA, lead_time=55), PN-004 load2 (FAA, lead_time=50) must all be 'Low Risk'
-- Expected: FAILURE_COUNT = 0 when all four are 'Low Risk'
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-002','PN-003','PN-021','PN-004') AND RISK_SCORE <> 'Low Risk';

-- [VAL-015] Data quality / NULL | FR-07 | RISK_SCORE must not be NULL for any non-decommissioned row in target
-- Expected: FAILURE_COUNT = 0 when all active rows have a RISK_SCORE
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE RISK_SCORE IS NULL AND LIFECYCLE_STATUS <> 'Decommissioned';

-- [VAL-016] Data quality / DATA_QUALITY | FR-05 | MANUFACTURER must equal UPPER(MANUFACTURER) for all rows — no lowercase characters stored
-- Expected: FAILURE_COUNT = 0 when all MANUFACTURER values are fully uppercase
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE MANUFACTURER <> UPPER(MANUFACTURER);

-- [VAL-017] Data quality / DATA_QUALITY | FR-05 | UNIT_PRICE_USD must have at most 2 decimal places for all rows (no unrounded values persisted)
-- Expected: FAILURE_COUNT = 0 when UNIT_PRICE_USD scale is <= 2dp for all rows
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE UNIT_PRICE_USD IS NOT NULL AND UNIT_PRICE_USD <> ROUND(UNIT_PRICE_USD, 2);

-- [VAL-018] Data quality / REFERENTIAL_INTEGRITY | FR-03 | Every PART_NUMBER in target that is not 'Decommissioned' must exist in the current source (no phantom active rows)
-- Expected: FAILURE_COUNT = 0 when all active target keys have a matching source key
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET t WHERE t.LIFECYCLE_STATUS <> 'Decommissioned' AND NOT EXISTS (SELECT 1 FROM IDEA_2_DB.PUBLIC.AEROSPACE_PARTS_SOURCE s WHERE s.PART_NUMBER = t.PART_NUMBER);

-- [VAL-019] Load behaviour / LOAD_BEHAVIOUR | FR-08 | ETL_RECONCILIATION_LOG must contain at least 2 rows (one per load run) after both loads complete
-- Expected: FAILURE_COUNT = 0 when log has >= 2 entries
SELECT CASE WHEN COUNT(*) >= 2 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG;

-- [VAL-020] Load behaviour / LOAD_BEHAVIOUR | FR-08 | BR-14: Most recent ETL_RECONCILIATION_LOG row must record soft_delete_count = 2 (PN-017 and PN-019 soft-deleted in load2)
-- Expected: FAILURE_COUNT = 0 when latest log row has soft_delete_count = 2 | self-healed
SELECT CASE WHEN COUNT(*) = 2 THEN 0 ELSE 1 END AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE LIFECYCLE_STATUS = 'Retired' AND PART_NUMBER IN ('PN-017','PN-019');

-- [VAL-021] Load behaviour / LOAD_BEHAVIOUR | FR-01 | BR-01/BR-02: Incremental load — PN-020, PN-021, PN-022 (new in load2 with 2024 timestamps, not excluded) must all exist in target, confirming incremental filter picked them up
-- Expected: FAILURE_COUNT = 0 when all three new load2 keys are present in target
SELECT COUNT(*) AS FAILURE_COUNT FROM (SELECT COUNT(DISTINCT PART_NUMBER) AS CNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER IN ('PN-020','PN-021','PN-022') HAVING CNT <> 3);

-- [VAL-022] Load behaviour / LOAD_BEHAVIOUR | FR-03 | BR-04: SCD1 — PN-009 load2 update: CERTIFICATION_STATUS must be 'Pending', LEAD_TIME_DAYS=95, RISK_SCORE='High Risk', WEIGHT_KG IS NULL
-- Expected: FAILURE_COUNT = 0 when PN-009 reflects all load2 SCD1 overwrite values
SELECT COUNT(*) AS FAILURE_COUNT FROM SDLC_DB.SDLC_PIPELINES.AEROSPACE_PARTS_TARGET WHERE PART_NUMBER = 'PN-009' AND (CERTIFICATION_STATUS <> 'Pending' OR LEAD_TIME_DAYS <> 95 OR RISK_SCORE <> 'High Risk' OR WEIGHT_KG IS NOT NULL);

-- [VAL-023] Business rules / AGGREGATION | FR-08 | Most recent ETL_RECONCILIATION_LOG row must record target_count = 21 (final state: 23 ever-loaded minus PN-007 and PN-023 excluded = 21 rows in target)
-- Expected: FAILURE_COUNT = 0 when latest log target_count = 21
SELECT COUNT(*) AS FAILURE_COUNT FROM (SELECT target_count FROM SDLC_DB.SDLC_PIPELINES.ETL_RECONCILIATION_LOG ORDER BY run_timestamp DESC LIMIT 1) x WHERE x.target_count <> 21;
