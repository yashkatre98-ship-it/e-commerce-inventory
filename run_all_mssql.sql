-- ============================================================================
-- E-COMMERCE INVENTORY & ORDER MANAGEMENT SYSTEM (DBMS PROJECT)
-- Dialect: Microsoft SQL Server (T-SQL)
-- Master Runner Script: run_all_mssql.sql
-- ============================================================================
-- Instructions:
-- In SQL Server Management Studio (SSMS):
--   Enable SQLCMD Mode from menu: Query -> SQLCMD Mode
--   Then execute this file, or execute scripts 01 through 06 sequentially.
--
-- In Command Line (Terminal / PowerShell):
--   sqlcmd -S localhost -E -i run_all_mssql.sql
-- ============================================================================

PRINT '=======================================================';
PRINT 'STARTING COMPLETE E-COMMERCE DBMS SETUP (SQL SERVER)';
PRINT '=======================================================';
GO

:r "01_schema_ddl.sql"
GO

:r "02_triggers.sql"
GO

:r "03_procedures_functions.sql"
GO

:r "04_views.sql"
GO

:r "05_seed_data.sql"
GO

:r "06_analytical_queries.sql"
GO

PRINT '=======================================================';
PRINT 'ALL SCRIPTS EXECUTED SUCCESSFULLY!';
PRINT 'E-commerce Inventory & Order Management System is Ready.';
PRINT '=======================================================';
GO

