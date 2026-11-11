SET NOCOUNT ON;
IF (SELECT COUNT(*) FROM sys.tables WHERE schema_id=SCHEMA_ID('dbo') AND name IN
 ('Category','Unit','Area','EntryReason','AppUser','Product','Lot','Movement','MovementDetail'))<>9
 THROW 50009,'Faltan tablas',1;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE is_disabled=1 OR is_not_trusted=1)
 THROW 50009,'Claves foraneas deshabilitadas o no confiables',1;
IF EXISTS(SELECT 1 FROM sys.check_constraints WHERE is_disabled=1 OR is_not_trusted=1)
 THROW 50009,'Restricciones deshabilitadas o no confiables',1;
IF (SELECT COUNT(*) FROM sys.key_constraints WHERE type='PK' AND schema_id=SCHEMA_ID('dbo'))<>9
 THROW 50009,'Faltan claves primarias',1;
IF (SELECT COUNT(*) FROM sys.foreign_keys WHERE schema_id=SCHEMA_ID('dbo'))<>9
 THROW 50009,'Faltan relaciones',1;
IF EXISTS(SELECT 1 FROM dbo.Product p WHERE p.stock<>(SELECT COALESCE(SUM(stock),0) FROM dbo.Lot WHERE product_id=p.id))
 THROW 50009,'Stock producto/lotes inconsistente',1;
IF EXISTS(SELECT 1 FROM dbo.Movement m WHERE m.quantity<>(SELECT COALESCE(SUM(quantity),0) FROM dbo.MovementDetail WHERE movement_id=m.id))
 THROW 50009,'Detalle de movimientos inconsistente',1;
IF (SELECT COUNT(*) FROM dbo.EntryReason)<>3 OR (SELECT COUNT(*) FROM dbo.Area)<4
 THROW 50009,'Catalogos incompletos',1;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_Lot_FEFO') OR NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name='IX_Movement_Filter')
 THROW 50009,'Faltan indices',1;
EXEC dbo.usp_Health;
