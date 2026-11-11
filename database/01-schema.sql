SET XACT_ABORT ON;
BEGIN TRANSACTION;
CREATE TABLE dbo.Category (
 id int IDENTITY PRIMARY KEY, name nvarchar(100) NOT NULL UNIQUE,
 description nvarchar(500) NOT NULL DEFAULT ''
);
CREATE TABLE dbo.Unit (id int IDENTITY PRIMARY KEY, name nvarchar(60) NOT NULL UNIQUE);
CREATE TABLE dbo.Area (id int IDENTITY PRIMARY KEY, name nvarchar(100) NOT NULL UNIQUE);
CREATE TABLE dbo.EntryReason (id int IDENTITY PRIMARY KEY, name nvarchar(50) NOT NULL UNIQUE);
CREATE TABLE dbo.AppUser (
 id int IDENTITY PRIMARY KEY, username nvarchar(80) NOT NULL UNIQUE,
 password_hash nvarchar(500) NOT NULL, active bit NOT NULL DEFAULT 1
);
CREATE TABLE dbo.Product (
 id int IDENTITY PRIMARY KEY, code nvarchar(40) NOT NULL UNIQUE,
 name nvarchar(150) NOT NULL, description nvarchar(500) NOT NULL DEFAULT '',
 category_id int NOT NULL REFERENCES dbo.Category(id),
 unit_id int NOT NULL REFERENCES dbo.Unit(id),
 price decimal(18,2) NOT NULL CHECK(price>0),
 min_stock int NOT NULL CHECK(min_stock>=0),
 stock int NOT NULL DEFAULT 0 CHECK(stock>=0),
 tracks_expiry bit NOT NULL DEFAULT 1, active bit NOT NULL DEFAULT 1
);
CREATE TABLE dbo.Lot (
 id int IDENTITY PRIMARY KEY, product_id int NOT NULL REFERENCES dbo.Product(id),
 code nvarchar(80) NOT NULL, expiry date NULL,
 stock int NOT NULL DEFAULT 0 CHECK(stock>=0),
 CONSTRAINT UQ_Lot UNIQUE(product_id,code)
);
CREATE TABLE dbo.Movement (
 id int IDENTITY PRIMARY KEY, request_id uniqueidentifier NOT NULL UNIQUE,
 product_id int NOT NULL REFERENCES dbo.Product(id),
 kind varchar(10) NOT NULL CHECK(kind IN ('ENTRY','EXIT')),
 quantity int NOT NULL CHECK(quantity>0), movement_date date NOT NULL,
 registered_at datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
 reason nvarchar(250) NOT NULL,
 entry_reason_id int NULL REFERENCES dbo.EntryReason(id),
 area_id int NULL REFERENCES dbo.Area(id), user_id int NOT NULL REFERENCES dbo.AppUser(id),
 stock_before int NOT NULL CHECK(stock_before>=0), stock_after int NOT NULL CHECK(stock_after>=0),
 CONSTRAINT CK_Movement_Destination CHECK (
 (kind='ENTRY' AND entry_reason_id IS NOT NULL AND area_id IS NULL) OR
 (kind='EXIT' AND area_id IS NOT NULL AND entry_reason_id IS NULL))
);
CREATE TABLE dbo.MovementDetail (
 id int IDENTITY PRIMARY KEY, movement_id int NOT NULL REFERENCES dbo.Movement(id),
 lot_id int NOT NULL REFERENCES dbo.Lot(id), quantity int NOT NULL CHECK(quantity>0),
 stock_before int NOT NULL CHECK(stock_before>=0), stock_after int NOT NULL CHECK(stock_after>=0),
 CONSTRAINT UQ_MovementDetail UNIQUE(movement_id,lot_id)
);
CREATE INDEX IX_Lot_FEFO ON dbo.Lot(product_id,expiry,id) INCLUDE(stock);
CREATE INDEX IX_Movement_Filter ON dbo.Movement(movement_date,product_id,kind,area_id);
COMMIT;
