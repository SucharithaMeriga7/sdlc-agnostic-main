-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_FILTERED
-- Object Type   : VIEW
-- Jira Story    : SCRUM-158
-- Requirements  : FR-05
-- Reuse Route   : CREATE_NEW
-- Description   : Filters out records where LIFECYCLE_STATUS = 'End of Life' AND INSTALLATION_DATE is older than 3 years from current date. Reads from the deduplicated+transformed+risk-scored view chain.
-- Author        : Sucharitha
-- Created Date  : 2026-10-21
-- Dependencies  :
--   - SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_RISK_SCORED
-- Business Rules: BR-08
-- Change History:
--   2026-10-21  Sucharitha  SCRUM-158  Initial generation (CREATE_NEW)
-- =============================================================================

CREATE OR REPLACE VIEW SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_FILTERED
COMMENT = 'FR-05 / BR-08: Excludes End-of-Life parts with installation older than 3 years. Downstream of VW_AEROSPACE_PARTS_RISK_SCORED.'
AS
SELECT
    -- Explicit column list; all columns from the risk-scored view are projected
    PART_NUMBER,
    PART_NAME,
    MANUFACTURER,
    CATEGORY,
    WEIGHT_KG,
    UNIT_PRICE_USD,
    QUANTITY_ON_HAND,
    REORDER_LEVEL,
    LIFECYCLE_STATUS,
    CERTIFICATION_STATUS,
    INSTALLATION_DATE,
    LEAD_TIME_DAYS,
    SUPPLIER,
    WAREHOUSE_LOCATION,
    COUNTRY_OF_ORIGIN,
    CREATED_AT,
    UPDATED_AT,
    RISK_SCORE
FROM SDLC_DB.SDLC_PIPELINES.VW_AEROSPACE_PARTS_RISK_SCORED
WHERE
    -- BR-08: Exclude records that are End of Life AND installed more than 3 years ago
    NOT (
        LIFECYCLE_STATUS = 'End of Life'
        AND INSTALLATION_DATE < DATEADD(YEAR, -3, CURRENT_DATE())
    );
