-- ============================================================================
-- E-COMMERCE INVENTORY & ORDER MANAGEMENT SYSTEM (DBMS PROJECT)
-- Dialect: Oracle Database (PL/SQL)
-- Master Runner Script: run_all_oracle.sql
-- ============================================================================
-- Instructions:
-- In Oracle SQL Developer / SQL*Plus / Oracle Cloud Live SQL:
--
-- In SQL*Plus / SQLcl:
--   SET SERVEROUTPUT ON;
--   @01_schema_ddl.sql
--   @02_triggers.sql
--   @03_procedures_functions.sql
--   @04_views.sql
--   @05_seed_data.sql
--   @06_analytical_queries.sql
-- ============================================================================

SET SERVEROUTPUT ON;
SET FEEDBACK ON;

PROMPT =======================================================;
PROMPT EXECUTING 01_schema_ddl.sql;
PROMPT =======================================================;
@@01_schema_ddl.sql;

PROMPT =======================================================;
PROMPT EXECUTING 02_triggers.sql;
PROMPT =======================================================;
@@02_triggers.sql;

PROMPT =======================================================;
PROMPT EXECUTING 03_procedures_functions.sql;
PROMPT =======================================================;
@@03_procedures_functions.sql;

PROMPT =======================================================;
PROMPT EXECUTING 04_views.sql;
PROMPT =======================================================;
@@04_views.sql;

PROMPT =======================================================;
PROMPT EXECUTING 05_seed_data.sql;
PROMPT =======================================================;
@@05_seed_data.sql;

PROMPT =======================================================;
PROMPT EXECUTING 06_analytical_queries.sql;
PROMPT =======================================================;
@@06_analytical_queries.sql;

PROMPT =======================================================;
PROMPT ALL ORACLE SCRIPTS EXECUTED SUCCESSFULLY!;
PROMPT =======================================================;

