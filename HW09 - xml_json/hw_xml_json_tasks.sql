/*
                              Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "Выборки из XML и JSON полей".
Задания выполняются с использованием базы данных WideWorldImporters.                                               */

-- ---------------------------------------------------------------------------
-- Задание - написать выборки для получения указанных ниже данных.
-- ---------------------------------------------------------------------------

USE WideWorldImporters;

/*-------------------------------------------------------------------------------------
1. В личном кабинете есть файл StockItems.xml.
Это данные из таблицы Warehouse.StockItems.
Преобразовать эти данные в плоскую таблицу с полями, аналогичными Warehouse.StockItems.
Поля: StockItemName, SupplierID, UnitPackageID, OuterPackageID, QuantityPerOuter, 
      TypicalWeightPerUnit, LeadTimeDays, IsChillerStock, TaxRate, UnitPrice 
Загрузить эти данные в таблицу Warehouse.StockItems: 
- существующие записи в таблице обновить, 
- отсутствующие добавить (сопоставлять записи по полю StockItemName). 
Сделать два варианта: с помощью OPENXML и через XQuery.                              */

--1 -- с помощью OPENXML --------------------------------------------------
DECLARE @xmlDocument XML;

-- считываем XML-файл в переменную !!! измените путь к XML-файлу
SELECT @xmlDocument = BulkColumn
FROM OPENROWSET (BULK 'D:\OTUS\XML\StockItems.xml', SINGLE_CLOB) AS data;

-- проверяем, что в @xmlDocument
SELECT @xmlDocument AS [@xmlDocument];

-- парсим XML-файл во внутренний XML-документ и получаем дескриптор на него
DECLARE @docHandle INT;
EXEC sp_xml_preparedocument @docHandle OUTPUT, @xmlDocument;

-- можно вставить результат во временную таблицу
DROP TABLE IF EXISTS #StockItems;

-- извлекаем данные из XML и сохраняем в таблицу
SELECT *
INTO #StockItems
FROM OPENXML(@docHandle, N'/StockItems/Item')
WITH ( 
	[StockItemName]        NVARCHAR(100)  '@Name', 
	[SupplierID]           INT 'SupplierID',
	[UnitPackageID]        INT 'Package/UnitPackageID',
	[OuterPackageID]       INT 'Package/OuterPackageID',
	[QuantityPerOuter]     INT 'Package/QuantityPerOuter',
	[TypicalWeightPerUnit] DECIMAL(18,3) 'Package/TypicalWeightPerUnit',
	[LeadTimeDays]         INT 'LeadTimeDays',
	[IsChillerStock]       BIT 'IsChillerStock',
	[TaxRate]              DECIMAL(18,3) 'TaxRate',
	[UnitPrice]            DECIMAL(18,2) 'UnitPrice'
	 );
	
-- удаляем дескриптор
EXEC sp_xml_removedocument @docHandle;

-- загружаем данные из врем.таблицы в таблицу БД
MERGE Warehouse.StockItems AS Tgt
USING #StockItems AS Src ON Src.StockItemName = Tgt.StockItemName
WHEN MATCHED THEN     -- существующие записи в таблице обновляем
      UPDATE SET SupplierID = Src.SupplierID
	           , UnitPackageID = Src.UnitPackageID
			   , OuterPackageID = Src.OuterPackageID
			   , QuantityPerOuter = Src.QuantityPerOuter
	           , TypicalWeightPerUnit = Src.TypicalWeightPerUnit
			   , LeadTimeDays = Src.LeadTimeDays
			   , IsChillerStock = Src.IsChillerStock
			   , TaxRate = Src.TaxRate
			   , UnitPrice = Src.UnitPrice
WHEN NOT MATCHED BY TARGET THEN -- отсутствующие записи добавляем
		INSERT 
			   ( StockItemName, SupplierID
			   , UnitPackageID, OuterPackageID
			   , QuantityPerOuter, TypicalWeightPerUnit
			   , LeadTimeDays, IsChillerStock
			   , TaxRate, UnitPrice
			   , LastEditedBy
			   )    
		VALUES ( Src.StockItemName, Src.SupplierID
			   , Src.UnitPackageID, Src.OuterPackageID
			   , Src.QuantityPerOuter, Src.TypicalWeightPerUnit
			   , Src.LeadTimeDays, Src.IsChillerStock
			   , Src.TaxRate, Src.UnitPrice 
			   , 1
			   )
OUTPUT $action, deleted.*, inserted.*;  -- выводим результаты DML-операций

-- удаляем врем.таблицу
DROP TABLE IF EXISTS #StockItems;

--2 -- через XQuery ---------------------------------------------------------------------------
DECLARE @xmlDoc XML;
SET @xmlDoc = (SELECT * FROM OPENROWSET (BULK 'D:\OTUS\XML\StockItems.xml', SINGLE_BLOB)  AS d);

-- Проверяем, что в @xmlDocument
SELECT @xmlDoc AS [@xmlDocument];

-- можно вставить результат в таблицу
DROP TABLE IF EXISTS #StockItem;

-- извлекаем данные из XML и сохраняем в таблицу
SELECT   
  t.cln.value('(@Name)', 'nvarchar(100)')            AS [StockItemName],
  t.cln.value('(SupplierID)[1]', 'int')              AS [SupplierID],
  t.cln.value('(Package/UnitPackageID)[1]', 'int')   AS [UnitPackageID],
  t.cln.value('(Package/OuterPackageID)[1]', 'int')  AS [OuterPackageID],
  t.cln.value('(Package/QuantityPerOuter)[1]','int') AS [QuantityPerOuter],
  t.cln.value('(Package/TypicalWeightPerUnit)[1]','decimal(18,3)') 
                                                     AS [TypicalWeightPerUnit],
  t.cln.value('(LeadTimeDays)[1]', 'int')            AS [LeadTimeDays],
  t.cln.value('(IsChillerStock)[1]', 'bit')          AS [IsChillerStock],
  t.cln.value('(TaxRate)[1]', 'decimal(18,3)')       AS [TaxRate],
  t.cln.value('(UnitPrice)[1]', 'decimal(18,2)')     AS [UnitPrice]
INTO #StockItem
FROM @xmlDoc.nodes('/StockItems/Item') AS t(cln);

-- загружаем данные из врем.таблицы в таблицу БД
MERGE Warehouse.StockItems AS Tgt
USING #StockItem AS Src ON Src.StockItemName = Tgt.StockItemName
WHEN MATCHED THEN 
      UPDATE SET SupplierID = Src.SupplierID
	           , UnitPackageID = Src.UnitPackageID
			   , OuterPackageID = Src.OuterPackageID
			   , QuantityPerOuter = Src.QuantityPerOuter
	           , TypicalWeightPerUnit = Src.TypicalWeightPerUnit
			   , LeadTimeDays = Src.LeadTimeDays
			   , IsChillerStock = Src.IsChillerStock
			   , TaxRate = Src.TaxRate
			   , UnitPrice = Src.UnitPrice
WHEN NOT MATCHED BY TARGET THEN 
        INSERT 
			   ( StockItemName, SupplierID
			   , UnitPackageID, OuterPackageID
			   , QuantityPerOuter, TypicalWeightPerUnit
			   , LeadTimeDays, IsChillerStock
			   , TaxRate, UnitPrice
			   , LastEditedBy
			   )    
		VALUES ( Src.StockItemName, Src.SupplierID
			   , Src.UnitPackageID, Src.OuterPackageID
			   , Src.QuantityPerOuter, Src.TypicalWeightPerUnit
			   , Src.LeadTimeDays, Src.IsChillerStock
			   , Src.TaxRate, Src.UnitPrice 
			   , 1
			   )
OUTPUT $action, deleted.*, inserted.*;

-- удаляем врем.таблицу
DROP TABLE IF EXISTS #StockItem;


/*---------------------------------------------------------------------------------------------------------------------
2. Выгрузить данные из таблицы StockItems в такой же xml-файл, как StockItems.xml                                    */

USE master;
GO
-- разрешаем изменение расширенных параметров
EXEC sp_configure 'show advanced options', 1;  
RECONFIGURE;  
GO  
-- включаем процедуру 
EXEC sp_configure 'xp_cmdshell', 1;  
RECONFIGURE;  
GO 

-- получаем имя сервера
DECLARE @ServerName SYSNAME = @@SERVERNAME
      , @Cmd NVARCHAR(1000);

-- формируем запрос на выгрузку
SET @Cmd = N'bcp "SELECT StockItemName AS ''@Name'','
                      + 'SupplierID AS ''SupplierID'','
                      + 'UnitPackageID AS ''Package/UnitPackageID'','
                      + 'OuterPackageID AS ''Package/OuterPackageID'','
                      + 'QuantityPerOuter AS ''Package/QuantityPerOuter'','
                      + 'TypicalWeightPerUnit AS ''Package/TypicalWeightPerUnit'','
                      + 'LeadTimeDays AS ''LeadTimeDays'','
	                  + 'IsChillerStock AS ''IsChillerStock'','
	                  + 'TaxRate AS ''TaxRate'','
	                  + 'UnitPrice AS ''UnitPrice'''
              + ' FROM [WideWorldImporters].Warehouse.StockItems'
              + ' ORDER BY StockItemName'
              + ' FOR XML PATH(''Item''), ROOT(''StockItems''), TYPE" queryout "D:\OTUS\XML\_tmpBcpFile.xml" -T -w -S ' 
			  + @ServerName;

-- выгружаем данные из таблицы StockItems во временный(некрасивый) xml-файл
EXEC master..xp_cmdshell @Cmd;

-- формируем команду на форматирование временного файла
SET @Cmd = N'powershell -Command "$xml = Get-Content ''D:\OTUS\XML\_tmpBcpFile.xml'' -Raw;' 
                              +  '$doc = New-Object System.Xml.XmlDocument;' 
                              +  '$doc.LoadXml($xml);'
                              +  '$sw = New-Object System.IO.StringWriter;'
                              +  '$writer = New-Object System.Xml.XmlTextWriter($sw);'
                              +  '$writer.Formatting = [System.Xml.Formatting]::Indented;'
                              +  '$doc.WriteContentTo($writer);'
                              +  '$sw.ToString() | Set-Content ''D:\OTUS\XML\StockItemsET.xml'' -Encoding UTF8;'
                              +  'Remove-Item D:\OTUS\XML\_tmpBcpFile.xml -Force"';

-- сохраняем отформатированный xml-файл StockItemsET.xml на диске D
EXEC master..xp_cmdshell @Cmd;

-- выключаем процедуру 
EXEC sp_configure 'xp_cmdshell', 0;  
RECONFIGURE;  
GO 
-- возвращаем прежнюю настройку
EXEC sp_configure 'show advanced options', 0;  
RECONFIGURE;  
GO  
USE WideWorldImporters;


/*--------------------------------------------------------------------------
3. В таблице Warehouse.StockItems в колонке CustomFields есть данные в JSON.
Написать SELECT для вывода:
- StockItemID
- StockItemName
- CountryOfManufacture (из CustomFields)
- FirstTag (из поля CustomFields, первое значение из массива Tags)        */

SELECT StockItemID, StockItemName, CustomFields, t.*
FROM Warehouse.Stockitems
OUTER APPLY OPENJSON(CustomFields)
WITH ( 
    CountryOfManufacture nvarchar(20) '$.CountryOfManufacture',
                    Tag1 nvarchar(20) '$.Tags[0]' 
     ) t;


/*-----------------------------------------------------------------------
4. Найти в StockItems строки, где есть тэг "Vintage".
Вывести: 
- StockItemID
- StockItemName
- (опционально) все теги (из CustomFields) через запятую в одном поле.
Тэги искать в поле CustomFields, а не в Tags.
Запрос написать через функции работы с JSON.
Для поиска использовать равенство, использовать LIKE запрещено.
Должно быть в таком виде:
... where ... = 'Vintage'
Так принято не будет:
... where ... Tags like '%Vintage%'
... where ... CustomFields like '%Vintage%'                               */

-- I способ:---------------------------------------------------
SELECT i.StockItemID, i.StockItemName,
       STRING_AGG(CAST(t.value AS NVARCHAR(MAX)), ', ') AS Tags
FROM Warehouse.Stockitems AS i
CROSS APPLY 
	OPENJSON(i.CustomFields, '$.Tags') t
GROUP BY i.StockItemID, i.StockItemName
HAVING MAX(CASE WHEN t.value = 'Vintage' THEN 1 ELSE 0 END) = 1
ORDER BY i.StockItemID;

-- II способ:--------------------------------------
WITH cte_ftr AS 
(
	select StockItemID, StockItemName, CustomFields
	from Warehouse.Stockitems
	cross apply openjson(CustomFields, '$.Tags') t
	where t.value= 'Vintage'
)
SELECT
    cte_ftr.StockItemID,
    cte_ftr.StockItemName,
    STRING_AGG(CAST(t.value AS NVARCHAR(MAX)), ', ') AS Tags
FROM cte_ftr CROSS APPLY 
	OPENJSON(cte_ftr.CustomFields, '$.Tags') AS t
GROUP BY cte_ftr.StockItemID, cte_ftr.StockItemName
ORDER BY cte_ftr.StockItemID;

-- III способ:----------------------------------------
SELECT DISTINCT
    si.StockItemID,
    si.StockItemName,
    STUFF((
        SELECT ', ' + t2.value
        FROM OPENJSON(si.CustomFields, '$.Tags') AS t2
        FOR XML PATH(''), TYPE
    ).value('.', 'nvarchar(max)'), 1, 2, '') AS Tags
FROM Warehouse.StockItems AS si
CROSS APPLY 
	OPENJSON(si.CustomFields, '$.Tags') AS tag
WHERE tag.value = 'Vintage'
ORDER BY si.StockItemID;

