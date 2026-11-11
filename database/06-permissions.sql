-- OPTIONAL: administrator runs this ONLY in the dedicated project database.
-- Not part of automatic setup. Does not create logins or change server settings.
IF DATABASEPROPERTYEX(DB_NAME(),'Status')<>'ONLINE' THROW 50001,'Base no disponible',1;
IF OBJECT_ID('dbo.Product','U') IS NULL THROW 50001,'Seleccione la base del proyecto',1;
IF DATABASE_PRINCIPAL_ID('hsg_app') IS NULL CREATE ROLE hsg_app;
GRANT EXECUTE ON dbo.usp_User_Get TO hsg_app;
GRANT EXECUTE ON dbo.usp_Catalog_List TO hsg_app;
GRANT EXECUTE ON dbo.usp_Category_Create TO hsg_app;
GRANT EXECUTE ON dbo.usp_Product_List TO hsg_app;
GRANT EXECUTE ON dbo.usp_Product_Save TO hsg_app;
GRANT EXECUTE ON dbo.usp_Product_Deactivate TO hsg_app;
GRANT EXECUTE ON dbo.usp_Lot_List TO hsg_app;
GRANT EXECUTE ON dbo.usp_Movement_Register TO hsg_app;
GRANT EXECUTE ON dbo.usp_Movement_List TO hsg_app;
GRANT EXECUTE ON dbo.usp_Dashboard TO hsg_app;
GRANT EXECUTE ON dbo.usp_Health TO hsg_app;
-- Administrator provisions an authorized database user and assigns it:
-- ALTER ROLE hsg_app ADD MEMBER [authorized_database_user];
-- No SELECT/INSERT/UPDATE/DELETE permissions on tables are granted.
