/*
                                     Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "Секционирование таблиц".
Задание выполняется с использованием базы данных WideWorldImporters.                                                             */
----------------------------------------------------------------------------------------------
-- Выбираем в своем проекте таблицу-кандидат для секционирования и добавляем партиционирование.
-- Если в проекте нет такой таблицы, то делаем анализ базы данных из первого модуля, 
--      выбираем таблицу и делаем ее секционирование, с переносом данных по секциям (партициям) 
--     исходя из того, что таблица большая, пишем скрипты миграции в секционированную таблицу
----------------------------------------------------------------------------------------------
             
Use master;
/*--------------------------------------------------------------------------------------------
Т.к. в моём проекте БД маленькая, данных мало, больших таблиц нет, 
поэтому реализую второй вариант -- секционирование таблиц из БД WideWorldImporters   */


----------------------------------------------------------------------------------------------
--I ЭТАП - СОЗДАНИЕ В БД НЕОБХОДИМЫХ ДЛЯ ВЫПОЛНЕНИЯ СЕКЦИОНИРОВАНИЯ ОБЪЕКТОВ 
----------------------------------------------------------------------------------------------
-- создадим файловую группу
IF NOT EXISTS (SELECT 1 FROM sys.filegroups WHERE name = N'SECONDARY')
	ALTER DATABASE [WideWorldImporters] ADD FILEGROUP [SECONDARY];
GO

-- добавляем файл БД в файловую группу
ALTER DATABASE [WideWorldImporters] ADD FILE 
( 
	NAME = N'OrderYears', FILENAME = N'D:\SQL\Engine\Data\OrderYears.ndf' , 
	SIZE = 1097152KB , FILEGROWTH = 65536KB 
) TO FILEGROUP [SECONDARY];
GO


USE WideWorldImporters;
-- граничные точки
CREATE PARTITION FUNCTION [fn_YearParts](DATE) 
AS 
	RANGE RIGHT FOR VALUES ('20120101','20130101','20140101','20150101','20160101','20170101','20180101','20190101', 
	                        '20200101','20210101','20220101','20230101','20240101','20250101','20260101','20270101');
GO

-- расположение секций 
CREATE PARTITION SCHEME [sch_YearParts] 
AS 
	PARTITION [fn_YearParts] ALL TO ([SECONDARY]);
GO


-------------------------------------------------------------------------------
--II ЭТАП - СОЗДАНИЕ ТАБЛИЦ-ЗАГОТОВОК С НАШЕЙ НОВОЙ СХЕМОЙ РАСПРЕДЕЛЕНИЯ ДАННЫХ
-------------------------------------------------------------------------------
-- создадим новую секционированную таблицу
CREATE TABLE [Sales].[OrderLinesYears]
(
	[OrderLineID] [int] NOT NULL,
	[OrderID] [int] NOT NULL,
	[OrderDate] [date] NOT NULL, 
	[StockItemID] [int] NOT NULL,
	[Description] [nvarchar](100) NOT NULL,
	[PackageTypeID] [int] NOT NULL,
	[Quantity] [int] NOT NULL,
	[UnitPrice] [decimal](18, 2) NULL,
	[TaxRate] [decimal](18, 3) NOT NULL,
	[PickedQuantity] [int] NOT NULL,
	[PickingCompletedWhen] [datetime2](7) NULL,
	[LastEditedBy] [int] NOT NULL,
	[LastEditedWhen] [datetime2](7) NOT NULL
) 
ON [sch_YearParts]([OrderDate]);
GO

-- создадим кластерный индекс в той же схеме с ключом секционирования
ALTER TABLE [Sales].[OrderLinesYears] 
	ADD CONSTRAINT PK_Sales_OrderLinesYears 
	PRIMARY KEY CLUSTERED  (OrderDate, OrderID, OrderLineID) ON [sch_YearParts]([OrderDate]);

-- то же самое для второй таблицы
CREATE TABLE [Sales].[OrdersYears]
(
	[OrderID] [int] NOT NULL,
	[CustomerID] [int] NOT NULL,
	[SalespersonPersonID] [int] NOT NULL,
	[PickedByPersonID] [int] NULL,
	[ContactPersonID] [int] NOT NULL,
	[BackorderOrderID] [int] NULL,
	[OrderDate] [date] NOT NULL,
	[ExpectedDeliveryDate] [date] NOT NULL,
	[CustomerPurchaseOrderNumber] [nvarchar](20) NULL,
	[IsUndersupplyBackordered] [bit] NOT NULL,
	[Comments] [nvarchar](max) NULL,
	[DeliveryInstructions] [nvarchar](max) NULL,
	[InternalComments] [nvarchar](max) NULL,
	[PickingCompletedWhen] [datetime2](7) NULL,
	[LastEditedBy] [int] NOT NULL,
	[LastEditedWhen] [datetime2](7) NOT NULL
) 
ON [sch_YearParts]([OrderDate]);
GO

-- создадим кластерный индекс в той же схеме с ключом секционирования
ALTER TABLE [Sales].[OrdersYears] 
	ADD CONSTRAINT PK_Sales_OrdersYears 
	PRIMARY KEY CLUSTERED  (OrderDate, OrderID) ON [sch_YearParts]([OrderDate]);


--------------------------------------------------------------------------------
--III ЭТАП - НАПОЛНЕНИЕ ТАБЛИЦ РЕАЛЬНЫМИ ДАННЫМИ С РАСПРЕДЕЛЕНИЕМ ИХ ПО СЕКЦИЯМ
--------------------------------------------------------------------------------
-- переключаемся для изменения настроек
USE master;

-- разрешаем изменение расширенных параметров
EXEC sp_configure 'show advanced options', 1;  
RECONFIGURE; 
GO  
-- включаем процедуру
EXEC sp_configure 'xp_cmdshell', 1;  
RECONFIGURE; 
GO

-- получаем имя сервера
DECLARE @ServerName SYSNAME = @@SERVERNAME,
        @Cmd NVARCHAR(1000);

-- выгрузка (строки + дата заказа): 231 412 rows
SET @Cmd = N'bcp "SELECT [OrderLineID],L.[OrderID],O.[OrderDate],[StockItemID],'
         + '[Description],[PackageTypeID],[Quantity],[UnitPrice],[TaxRate],'
		 + '[PickedQuantity],L.[PickingCompletedWhen],L.[LastEditedBy],'
		 + 'L.[LastEditedWhen] FROM [WideWorldImporters].Sales.Orders '
		 + 'AS O JOIN [WideWorldImporters].Sales.OrderLines AS L '
		 + 'ON O.OrderID = L.OrderID" queryout "D:\TEMP\OrderLines.txt" -T -w -t "@eu&$" -S ' 
		 + @ServerName;
exec master..xp_cmdshell @Cmd;

-- выгрузка (шапки заказа): 73 595 rows
SET @Cmd = N'bcp "[WideWorldImporters].Sales.Orders" out "D:\TEMP\Orders.txt" -T -w -t "@eu&$" -S ' 
           + @ServerName;
exec master..xp_cmdshell @Cmd;


USE WideWorldImporters;

-- загрузка строк заказов
DECLARE 
	@Path      NVARCHAR(256) = N'D:\TEMP\',
	@FileName  NVARCHAR(256) = N'OrderLines.txt',
	@Query	   NVARCHAR(MAX),
	@DbName    NVARCHAR(255) = DB_NAME(),
	@BatchSize INT = 1000;
	
BEGIN TRY
	IF @FileName IS NOT NULL
	BEGIN
		SET @Query = N'BULK INSERT ['+ @DbName + '].[Sales].[OrderLinesYears]
				     FROM "' + @Path + @FileName + N'"
				     WITH 
					 (
						BATCHSIZE = ' + CAST(@BatchSize AS NVARCHAR(255)) + N', 
						DATAFILETYPE = ''widechar'',
						FIELDTERMINATOR = ''@eu&$'',
						ROWTERMINATOR =''\n'',
						KEEPNULLS,
						TABLOCK        
					);'

		EXEC sp_executesql @Query;
	END;
END TRY
BEGIN CATCH
	SELECT   
		ERROR_NUMBER() AS ErrorNumber  
	  , ERROR_MESSAGE() AS ErrorMessage; 

	PRINT 'ERROR IN BULK INSERT '+ @FileName;
END CATCH;
GO

-- загрузка шапок заказов
DECLARE 
	@Path      NVARCHAR(256) = N'D:\TEMP\',
	@FileName  NVARCHAR(256) = N'Orders.txt',
	@Query	   NVARCHAR(MAX),
	@DbName    NVARCHAR(255) = DB_NAME(),
	@BatchSize INT = 1000;
	
BEGIN TRY
	IF @FileName IS NOT NULL
	BEGIN
		SET @Query = N'BULK INSERT ['+ @DbName + '].[Sales].[OrdersYears]
				     FROM "' + @Path + @FileName + N'"
				     WITH 
					(
						BATCHSIZE = ' + CAST(@BatchSize AS NVARCHAR(255)) + N', 
						DATAFILETYPE = ''widechar'',
						FIELDTERMINATOR = ''@eu&$'',
						ROWTERMINATOR =''\n'',
						KEEPNULLS,
						TABLOCK        
					);'

		EXEC sp_executesql @Query;
	END;
END TRY
BEGIN CATCH
	SELECT   
		ERROR_NUMBER() AS ErrorNumber  
	  , ERROR_MESSAGE() AS ErrorMessage; 

	PRINT 'ERROR IN BULK INSERT ' + @FileName;
END CATCH;
GO


---------------------------------------------------------------------------
--IV ЭТАП - ПРОВЕРКА 
---------------------------------------------------------------------------
-- проверка количества
SELECT COUNT(*) FROM Sales.OrderLinesYears;  -- 231 412 rows
SELECT COUNT(*) FROM Sales.OrdersYears; -- 73 595 rows

-- секционированные таблицы
SELECT DISTINCT object_name(object_id)
FROM sys.partitions p
WHERE partition_number > 1

-- вся информация по секционированию
SELECT f.name
	, IIF(f.boundary_value_on_right = 0, 'left', 'right') AS LeftORRight
	, v.value
	, v.boundary_id
	, t.name 
FROM sys.partition_functions f
JOIN sys.partition_range_values v ON f.function_id = v.function_id
JOIN sys.partition_parameters p ON f.function_id = p.function_id
JOIN sys.types t ON t.system_type_id = p.system_type_id
ORDER BY f.name, boundary_id

-- распределение по диапазонам 73 595 заказов
SELECT $partition.fn_YearParts([OrderDate]) AS NumPartition
	 , COUNT(*) as Qty
	 , MIN([OrderDate]) as MinDate
	 , MAX([OrderDate]) as MaxDate 
FROM Sales.OrdersYears
GROUP BY $partition.fn_YearParts([OrderDate]) 
ORDER BY 1;

-- распределение по диапазонам 231 412 строк заказов
SELECT $partition.fn_YearParts([OrderDate]) AS NumPartition
	 , COUNT(*) AS Qty
	 , MIN([OrderDate]) AS MinDate
	 , MAX([OrderDate]) AS MaxDate
FROM Sales.OrderLinesYears
GROUP BY $partition.fn_YearParts([OrderDate]) 
ORDER BY 1;

-- распределение по секциям 73 595 заказов
SELECT $partition.fn_YearParts([OrderDate]) AS Section, 
       MIN([OrderDate]) AS MinDate, 
	   MAX([OrderDate]) AS MaxDate,
       COUNT(*) AS Qty, 
	   fg.name as Fg
FROM Sales.OrdersYears
JOIN sys.partitions p ON $partition.fn_YearParts([OrderDate]) = p.partition_number 
JOIN sys.destination_data_spaces dds ON  p.partition_number = dds.destination_id
JOIN (
		select data_space_id 
		from sys.partition_schemes 
		where name = 'sch_YearParts'
     ) ps
ON dds.partition_scheme_id = ps.data_space_id
JOIN sys.filegroups fg ON dds.data_space_id = fg.data_space_id
WHERE p.object_id = object_id('Sales.OrdersYears') 
GROUP BY $partition.fn_YearParts([OrderDate]), fg.name
ORDER BY Section;

-- распределение по секциям  231 412 строк заказов
SELECT $partition.fn_YearParts([OrderDate]) AS Section, 
       MIN([OrderDate]) AS MinDate, 
	   MAX([OrderDate]) AS MaxDate,
       COUNT(*) AS Qty, 
	   fg.name as Fg
FROM Sales.OrderLinesYears
JOIN sys.partitions p ON $partition.fn_YearParts([OrderDate]) = p.partition_number
JOIN sys.destination_data_spaces dds ON p.partition_number = dds.destination_id
JOIN (
		select data_space_id 
		from sys.partition_schemes 
		where name = 'sch_YearParts'
     ) ps
ON dds.partition_scheme_id = ps.data_space_id
JOIN sys.filegroups fg ON dds.data_space_id = fg.data_space_id
WHERE p.object_id = object_id('Sales.OrderLinesYears') 
GROUP BY $partition.fn_YearParts([OrderDate]), fg.name
ORDER BY Section;


-----------------------------------------------------------------
--V ЭТАП - ОЧИЩЕНИЕ БД 
-----------------------------------------------------------------
-- удаление таблиц
DROP TABLE IF EXISTS [Sales].[OrdersYears];
DROP TABLE IF EXISTS [Sales].[OrderLinesYears];

-- удаление схемы
DROP  PARTITION SCHEME [sch_YearParts];

-- удаление функции
DROP PARTITION FUNCTION [fn_YearParts];

-- удаление файла из ФГ
ALTER DATABASE [WideWorldImporters]  REMOVE FILE [OrderYears];

-- удаление файловой группы
ALTER DATABASE [WideWorldImporters] REMOVE FILEGROUP [SECONDARY];

-- выключаем процедуру
EXEC sp_configure 'xp_cmdshell', 0;  
RECONFIGURE; 

-- запрещаем изменение расширенных параметров
EXEC sp_configure 'show advanced options', 0;  
RECONFIGURE; 
-----------------------------------------------------------------