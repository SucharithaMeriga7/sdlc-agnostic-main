-- =============================================================================
-- Object        : SDLC_DB.SDLC_PIPELINES.FN_NORMALIZE_WEIGHT
-- Object Type   : FUNCTION
-- Jira Story    : SCRUM-158
-- Requirements  : FR-06
-- Reuse Route   : CREATE_NEW
-- Description   : Scalar UDF that replaces WEIGHT_KG values <= 0 with -1, preserving valid positive values per BR-07.
-- Author        : Sucharitha
-- Created Date  : 2026-10-23
-- Dependencies  :
--   - none
-- Business Rules: BR-07
-- Change History:
--   2026-10-23  Sucharitha  SCRUM-158  Initial generation (CREATE_NEW)
-- =============================================================================

CREATE OR REPLACE FUNCTION SDLC_DB.SDLC_PIPELINES.FN_NORMALIZE_WEIGHT(
    WEIGHT_KG_INPUT NUMBER(10,3)
)
RETURNS NUMBER(10,3)
LANGUAGE SQL
AS
$$
    -- BR-07: Replace WEIGHT_KG <= 0 with sentinel value -1
    -- Positive values are preserved as-is
    CASE
        WHEN WEIGHT_KG_INPUT <= 0 THEN -1
        ELSE WEIGHT_KG_INPUT
    END
$$;
