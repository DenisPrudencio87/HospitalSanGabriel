SET XACT_ABORT ON;
BEGIN TRANSACTION;
INSERT dbo.Category(name,description) VALUES
 (N'Medicamentos',N'Productos farmacéuticos'),(N'Material médico',N'Insumos de atención'),
 (N'Laboratorio',N'Insumos de laboratorio'),(N'Limpieza hospitalaria',N'Limpieza y desinfección');
INSERT dbo.Unit(name) VALUES(N'Unidad'),(N'Caja'),(N'Frasco'),(N'Paquete');
INSERT dbo.Area(name) VALUES(N'Emergencia'),(N'Hospitalización'),(N'Consultorios externos'),(N'Laboratorio');
INSERT dbo.EntryReason(name) VALUES(N'Compra'),(N'Donación'),(N'Devolución');
COMMIT;
