-- Synthetic demonstration data persisted in the actual database, not frontend mocks.
-- Dates are relative to initialization. Disabled audit user cannot log in.
SET XACT_ABORT ON;
BEGIN TRY
BEGIN TRANSACTION;
EXEC dbo.usp_User_Create @username=N'demo-auditoria',@password_hash=N'!disabled-no-login',@active=0;
DECLARE @user int=(SELECT id FROM dbo.AppUser WHERE username=N'demo-auditoria');
DECLARE @category int=(SELECT id FROM dbo.Category WHERE name=N'Medicamentos');
DECLARE @material int=(SELECT id FROM dbo.Category WHERE name=N'Material médico');
DECLARE @unit int=(SELECT MIN(id) FROM dbo.Unit),@area int=(SELECT MIN(id) FROM dbo.Area);
DECLARE @purchase int=(SELECT id FROM dbo.EntryReason WHERE name=N'Compra');
DECLARE @donation int=(SELECT id FROM dbo.EntryReason WHERE name=N'Donación');
DECLARE @return int=(SELECT id FROM dbo.EntryReason WHERE name=N'Devolución');
EXEC dbo.usp_Product_Save NULL,N'MED-001',N'Paracetamol 500 mg',N'Tabletas',@category,@unit,0.50,20,1;
EXEC dbo.usp_Product_Save NULL,N'INS-001',N'Guantes de examen',N'Unidad de demostración',@material,@unit,1.20,10,1;
EXEC dbo.usp_Product_Save NULL,N'INS-002',N'Gasas estériles',N'Stock pendiente de reposición',@material,@unit,2.50,5,1;
EXEC dbo.usp_Product_Save NULL,N'INS-003',N'Bandeja hospitalaria',N'Material sin vencimiento',@material,@unit,25,2,0;
DECLARE @p int=(SELECT id FROM dbo.Product WHERE code=N'MED-001');
DECLARE @g int=(SELECT id FROM dbo.Product WHERE code=N'INS-001');
DECLARE @b int=(SELECT id FROM dbo.Product WHERE code=N'INS-003');
DECLARE @today date=CONVERT(date,DATEADD(hour,-5,SYSUTCDATETIME()));
DECLARE @near date=DATEADD(day,10,@today),@far date=DATEADD(day,180,@today),@expired date=DATEADD(day,-5,@today);
DECLARE @request uniqueidentifier=NEWID();
EXEC dbo.usp_Movement_Register @request,@p,'ENTRY',40,@today,N'Compra inicial',@purchase,NULL,@user,N'PAR-PRONTO',@near;
SET @request=NEWID();
EXEC dbo.usp_Movement_Register @request,@p,'ENTRY',60,@today,N'Donación',@donation,NULL,@user,N'PAR-VIGENTE',@far;
SET @request=NEWID();
EXEC dbo.usp_Movement_Register @request,@p,'EXIT',15,@today,N'Atención hospitalaria',NULL,@area,@user,NULL,NULL;
SET @request=NEWID();
EXEC dbo.usp_Movement_Register @request,@g,'ENTRY',5,@today,N'Compra',@purchase,NULL,@user,N'GUA-VIGENTE',@far;
SET @request=NEWID();
EXEC dbo.usp_Movement_Register @request,@g,'ENTRY',20,@today,N'Devolución vencida: bloqueada para uso',@return,NULL,@user,N'GUA-VENCIDO',@expired;
SET @request=NEWID();
EXEC dbo.usp_Movement_Register @request,@b,'ENTRY',3,@today,N'Donación',@donation,NULL,@user,N'BAN-001',NULL;
COMMIT;
END TRY
BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
