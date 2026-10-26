-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.FN_CAMELCASE_MANUFACTURER
-- Object Type   : FUNCTION
-- Jira Story    : SCRUM-158
-- Requirements  : FR-05
-- Reuse Route   : CREATE_NEW
-- Description   : Scalar UDF that converts MANUFACTURER string to UPPERCASE per BR-06. Named FN_CAMELCASE_MANUFACTURER for compatibility with existing references but implements UPPER() transformation as required.
-- Author        : Sucharitha
-- Created Date  : 2026-10-23
-- Dependencies  :
--   - none
-- Business Rules: BR-06
-- Change History:
--   2026-10-23  Sucharitha  SCRUM-158  Initial generation (CREATE_NEW)
-- =============================================================================

CREATE OR REPLACE FUNCTION SDLC_DB.SDLC_PIPELINES.FN_CAMELCASE_MANUFACTURER(
    MANUFACTURER_INPUT VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    -- BR-06: Convert MANUFACTURER to uppercase before target load
    -- e.g. 'Boeing' -> 'BOEING', 'general electric' -> 'GENERAL ELECTRIC'
    UPPER(MANUFACTURER_INPUT)
$$;
