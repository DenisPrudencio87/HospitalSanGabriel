CREATE PROCEDURE dbo.usp_Catalog_List @kind varchar(20)
AS
BEGIN
 SET NOCOUNT ON;
 IF @kind='categories' SELECT id,name,description FROM dbo.Category ORDER BY name;
 ELSE IF @kind='units' SELECT id,name FROM dbo.Unit ORDER BY id;
 ELSE IF @kind='areas' SELECT id,name FROM dbo.Area ORDER BY id;
 ELSE IF @kind='reasons' SELECT id,name FROM dbo.EntryReason ORDER BY id;
 ELSE THROW 50001,'Catalogo invalido',1;
END;
GO
CREATE PROCEDURE dbo.usp_Category_Create @name nvarchar(100),@description nvarchar(500)
AS
BEGIN
 SET NOCOUNT ON;
 IF LEN(LTRIM(RTRIM(@name)))=0 THROW 50001,'Nombre obligatorio',1;
 INSERT dbo.Category(name,description) VALUES(LTRIM(RTRIM(@name)),@description);
 SELECT CAST(SCOPE_IDENTITY() AS int) id;
END;
GO
CREATE PROCEDURE dbo.usp_User_Get @username nvarchar(80)
AS BEGIN SET NOCOUNT ON; SELECT id,username,password_hash,active FROM dbo.AppUser WHERE username=@username; END;
GO
CREATE PROCEDURE dbo.usp_User_Create @username nvarchar(80),@password_hash nvarchar(500),@active bit=1
AS BEGIN SET NOCOUNT ON; INSERT dbo.AppUser(username,password_hash,active) VALUES(@username,@password_hash,@active); SELECT CAST(SCOPE_IDENTITY() AS int) id; END;
GO
CREATE PROCEDURE dbo.usp_Product_List
 @search nvarchar(150)='',@category_id int=NULL,@active bit=NULL,@id int=NULL,
 @page int=1,@page_size int=50
AS
BEGIN
 SET NOCOUNT ON;
 IF @page<1 OR @page_size<1 OR @page_size>200 THROW 50001,'Paginacion invalida',1;
 SELECT p.*,c.name category_name,u.name unit_name,
 COALESCE(s.available_stock,0) available_stock,COALESCE(s.expired_stock,0) expired_stock,
 s.next_expiry,COUNT(*) OVER() total_count
 FROM dbo.Product p JOIN dbo.Category c ON c.id=p.category_id JOIN dbo.Unit u ON u.id=p.unit_id
 OUTER APPLY(SELECT SUM(CASE WHEN l.expiry IS NULL OR l.expiry>=CONVERT(date,DATEADD(hour,-5,SYSUTCDATETIME())) THEN l.stock ELSE 0 END) available_stock,
 SUM(CASE WHEN l.expiry<CONVERT(date,DATEADD(hour,-5,SYSUTCDATETIME())) THEN l.stock ELSE 0 END) expired_stock,
 MIN(CASE WHEN l.stock>0 AND l.expiry>=CONVERT(date,DATEADD(hour,-5,SYSUTCDATETIME())) THEN l.expiry END) next_expiry
 FROM dbo.Lot l WHERE l.product_id=p.id) s
 WHERE (@id IS NULL OR p.id=@id) AND (@category_id IS NULL OR p.category_id=@category_id)
 AND (@active IS NULL OR p.active=@active) AND (p.code LIKE '%'+@search+'%' OR p.name LIKE '%'+@search+'%')
 ORDER BY p.id DESC OFFSET (@page-1)*@page_size ROWS FETCH NEXT @page_size ROWS ONLY;
END;
GO
CREATE PROCEDURE dbo.usp_Product_Save
 @id int,@code nvarchar(40),@name nvarchar(150),@description nvarchar(500),
 @category_id int,@unit_id int,@price decimal(18,2),@min_stock int,@tracks_expiry bit
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 SET @code=UPPER(LTRIM(RTRIM(@code)));
 IF LEN(@code)=0 OR LEN(LTRIM(RTRIM(@name)))=0 OR @price<=0 OR @min_stock<0 THROW 50001,'Producto invalido',1;
 BEGIN TRY
 BEGIN TRANSACTION;
 IF @id IS NULL
 BEGIN
 INSERT dbo.Product(code,name,description,category_id,unit_id,price,min_stock,tracks_expiry)
 VALUES(@code,@name,@description,@category_id,@unit_id,@price,@min_stock,@tracks_expiry);
 SET @id=SCOPE_IDENTITY();
 END
 ELSE
 BEGIN
 DECLARE @old_unit int,@old_expiry bit;
 SELECT @old_unit=unit_id,@old_expiry=tracks_expiry FROM dbo.Product WITH(UPDLOCK,HOLDLOCK) WHERE id=@id;
 IF @old_unit IS NULL THROW 50004,'Producto no encontrado',1;
 IF (@old_unit<>@unit_id OR @old_expiry<>@tracks_expiry) AND EXISTS(SELECT 1 FROM dbo.Movement WHERE product_id=@id)
 THROW 50009,'No se puede cambiar unidad o control de vencimiento con historial',1;
 UPDATE dbo.Product SET code=@code,name=@name,description=@description,category_id=@category_id,
 unit_id=@unit_id,price=@price,min_stock=@min_stock,tracks_expiry=@tracks_expiry WHERE id=@id;
 END;
 COMMIT; SELECT @id id;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO
CREATE PROCEDURE dbo.usp_Product_Deactivate @id int
AS BEGIN SET NOCOUNT ON; UPDATE dbo.Product SET active=0 WHERE id=@id; IF @@ROWCOUNT=0 THROW 50004,'Producto no encontrado',1; SELECT @id id; END;
GO
CREATE PROCEDURE dbo.usp_Lot_List @product_id int
AS BEGIN SET NOCOUNT ON; SELECT *,CASE WHEN expiry<CONVERT(date,DATEADD(hour,-5,SYSUTCDATETIME())) THEN 1 ELSE 0 END expired FROM dbo.Lot WHERE product_id=@product_id ORDER BY CASE WHEN expiry IS NULL THEN 1 ELSE 0 END,expiry,id; END;
GO
CREATE PROCEDURE dbo.usp_Movement_Register
 @request_id uniqueidentifier,@product_id int,@kind varchar(10),@quantity int,@movement_date date,
 @reason nvarchar(250),@entry_reason_id int,@area_id int,@user_id int,@lot_code nvarchar(80),@expiry date
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 DECLARE @today date=CONVERT(date,DATEADD(hour,-5,SYSUTCDATETIME()));
 IF @quantity<=0 OR @kind NOT IN ('ENTRY','EXIT') OR @movement_date>@today OR LEN(LTRIM(RTRIM(@reason)))=0
 THROW 50001,'Movimiento invalido',1;
 DECLARE @before int,@active bit,@tracks bit,@id int,@lot_id int,@lot_before int,@lot_expiry date;
 DECLARE @allocation TABLE(lot_id int PRIMARY KEY,quantity int,stock_before int,stock_after int);
 BEGIN TRY
 BEGIN TRANSACTION;
 SELECT @before=stock,@active=active,@tracks=tracks_expiry FROM dbo.Product WITH(UPDLOCK,HOLDLOCK) WHERE id=@product_id;
 IF @before IS NULL THROW 50004,'Producto no encontrado',1;
 SELECT @id=id FROM dbo.Movement WITH(UPDLOCK,HOLDLOCK) WHERE request_id=@request_id;
 IF @id IS NOT NULL
 BEGIN
 IF NOT EXISTS(SELECT 1 FROM dbo.Movement WHERE id=@id AND product_id=@product_id AND kind=@kind AND quantity=@quantity AND user_id=@user_id)
 THROW 50009,'Identificador de solicitud ya utilizado',1;
 COMMIT; SELECT @id id; RETURN;
 END;
 IF @active=0 THROW 50009,'Producto inactivo',1;
 IF @before<>(SELECT COALESCE(SUM(stock),0) FROM dbo.Lot WITH(UPDLOCK,HOLDLOCK) WHERE product_id=@product_id)
 THROW 50009,'Inconsistencia de stock; operacion detenida',1;
 IF @kind='ENTRY'
 BEGIN
 IF @entry_reason_id IS NULL OR @area_id IS NOT NULL OR NULLIF(LTRIM(RTRIM(@lot_code)),'') IS NULL OR (@tracks=1 AND @expiry IS NULL)
 THROW 50001,'Entrada requiere motivo, lote y vencimiento cuando corresponda',1;
 SELECT @lot_id=id,@lot_before=stock,@lot_expiry=expiry FROM dbo.Lot WITH(UPDLOCK,HOLDLOCK) WHERE product_id=@product_id AND code=@lot_code;
 IF @lot_id IS NULL
 BEGIN
 INSERT dbo.Lot(product_id,code,expiry,stock) VALUES(@product_id,@lot_code,@expiry,0);
 SET @lot_id=SCOPE_IDENTITY(); SET @lot_before=0;
 END
 ELSE IF (@lot_expiry<>@expiry OR (@lot_expiry IS NULL AND @expiry IS NOT NULL) OR (@lot_expiry IS NOT NULL AND @expiry IS NULL))
 THROW 50009,'El vencimiento no coincide con el lote existente',1;
 UPDATE dbo.Lot SET stock=stock+@quantity WHERE id=@lot_id;
 INSERT @allocation VALUES(@lot_id,@quantity,@lot_before,@lot_before+@quantity);
 END
 ELSE
 BEGIN
 IF @area_id IS NULL OR @entry_reason_id IS NOT NULL THROW 50001,'Salida requiere area hospitalaria',1;
 IF @quantity>(SELECT COALESCE(SUM(stock),0) FROM dbo.Lot WITH(UPDLOCK,HOLDLOCK) WHERE product_id=@product_id AND (expiry IS NULL OR (expiry>=@today AND expiry>=@movement_date)))
 THROW 50009,'Stock disponible insuficiente; los lotes vencidos no pueden utilizarse',1;
 DECLARE @remaining int=@quantity,@take int;
 WHILE @remaining>0
 BEGIN
 SET @lot_id=NULL;
 SELECT TOP(1) @lot_id=id,@lot_before=stock FROM dbo.Lot WITH(UPDLOCK,HOLDLOCK)
 WHERE product_id=@product_id AND stock>0 AND (expiry IS NULL OR (expiry>=@today AND expiry>=@movement_date))
 ORDER BY CASE WHEN expiry IS NULL THEN 1 ELSE 0 END,expiry,id;
 IF @lot_id IS NULL THROW 50009,'Stock disponible insuficiente',1;
 SET @take=CASE WHEN @lot_before<@remaining THEN @lot_before ELSE @remaining END;
 UPDATE dbo.Lot SET stock=stock-@take WHERE id=@lot_id;
 INSERT @allocation VALUES(@lot_id,@take,@lot_before,@lot_before-@take);
 SET @remaining=@remaining-@take;
 END;
 END;
 DECLARE @after int=(SELECT COALESCE(SUM(stock),0) FROM dbo.Lot WHERE product_id=@product_id);
 UPDATE dbo.Product SET stock=@after WHERE id=@product_id;
 INSERT dbo.Movement(request_id,product_id,kind,quantity,movement_date,reason,entry_reason_id,area_id,user_id,stock_before,stock_after)
 VALUES(@request_id,@product_id,@kind,@quantity,@movement_date,@reason,@entry_reason_id,@area_id,@user_id,@before,@after);
 SET @id=SCOPE_IDENTITY();
 INSERT dbo.MovementDetail(movement_id,lot_id,quantity,stock_before,stock_after) SELECT @id,lot_id,quantity,stock_before,stock_after FROM @allocation;
 COMMIT; SELECT @id id;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO
CREATE PROCEDURE dbo.usp_Movement_List
 @product_id int=NULL,@kind varchar(10)=NULL,@area_id int=NULL,@date_from date=NULL,@date_to date=NULL,@id int=NULL,
 @page int=1,@page_size int=50
AS
BEGIN
 SET NOCOUNT ON;
 IF @page<1 OR @page_size<1 OR @page_size>200 THROW 50001,'Paginacion invalida',1;
 SELECT m.*,p.code product_code,p.name product_name,a.name area_name,u.username,
 (SELECT d.lot_id,l.code lot_code,l.expiry,d.quantity,d.stock_before,d.stock_after FROM dbo.MovementDetail d JOIN dbo.Lot l ON l.id=d.lot_id WHERE d.movement_id=m.id FOR JSON PATH) lots,
 COUNT(*) OVER() total_count
 FROM dbo.Movement m JOIN dbo.Product p ON p.id=m.product_id JOIN dbo.AppUser u ON u.id=m.user_id LEFT JOIN dbo.Area a ON a.id=m.area_id
 WHERE (@id IS NULL OR m.id=@id) AND (@product_id IS NULL OR m.product_id=@product_id) AND (@kind IS NULL OR m.kind=@kind)
 AND (@area_id IS NULL OR m.area_id=@area_id) AND (@date_from IS NULL OR m.movement_date>=@date_from) AND (@date_to IS NULL OR m.movement_date<=@date_to)
 ORDER BY m.id DESC OFFSET (@page-1)*@page_size ROWS FETCH NEXT @page_size ROWS ONLY;
END;
GO
CREATE PROCEDURE dbo.usp_Dashboard @days int=30,@date_from date=NULL,@date_to date=NULL
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @today date=CONVERT(date,DATEADD(hour,-5,SYSUTCDATETIME()));
 SELECT p.*,COALESCE(s.available_stock,0) available_stock,COALESCE(s.expired_stock,0) expired_stock,
 COALESCE(s.expiring_stock,0) expiring_stock,s.next_expiry,c.name category_name
 INTO #Inventory FROM dbo.Product p JOIN dbo.Category c ON c.id=p.category_id
 OUTER APPLY(SELECT SUM(CASE WHEN expiry IS NULL OR expiry>=@today THEN stock ELSE 0 END) available_stock,
 SUM(CASE WHEN expiry<@today THEN stock ELSE 0 END) expired_stock,
 SUM(CASE WHEN expiry BETWEEN @today AND DATEADD(day,@days,@today) THEN stock ELSE 0 END) expiring_stock,
 MIN(CASE WHEN stock>0 AND expiry>=@today THEN expiry END) next_expiry FROM dbo.Lot WHERE product_id=p.id) s;
 SELECT COUNT(*) active_products,COALESCE(SUM(CASE WHEN available_stock<=min_stock THEN 1 ELSE 0 END),0) low_stock_products,
 COALESCE(SUM(CASE WHEN expiring_stock>0 THEN 1 ELSE 0 END),0) expiring_products,
 COALESCE(SUM(CASE WHEN expired_stock>0 THEN 1 ELSE 0 END),0) expired_products,
 COALESCE(SUM(price*stock),0) inventory_value FROM #Inventory WHERE active=1;
 SELECT * FROM #Inventory WHERE active=1 AND available_stock<=min_stock ORDER BY available_stock,name;
 SELECT * FROM #Inventory WHERE expiring_stock>0 OR expired_stock>0 ORDER BY next_expiry,name;
 SELECT movement_date,kind,SUM(quantity) quantity,COUNT(*) movements FROM dbo.Movement
 WHERE (@date_from IS NULL OR movement_date>=@date_from) AND (@date_to IS NULL OR movement_date<=@date_to)
 GROUP BY movement_date,kind ORDER BY movement_date DESC;
 SELECT TOP(10) p.id,p.name,SUM(m.quantity) quantity FROM dbo.Movement m JOIN dbo.Product p ON p.id=m.product_id
 WHERE m.kind='EXIT' AND (@date_from IS NULL OR m.movement_date>=@date_from) AND (@date_to IS NULL OR m.movement_date<=@date_to)
 GROUP BY p.id,p.name ORDER BY quantity DESC,p.id;
END;
GO
CREATE PROCEDURE dbo.usp_Health
AS BEGIN SET NOCOUNT ON; SELECT DB_NAME() database_name,COUNT(*) inconsistencies FROM dbo.Product p WHERE p.stock<>(SELECT COALESCE(SUM(stock),0) FROM dbo.Lot WHERE product_id=p.id); END;
