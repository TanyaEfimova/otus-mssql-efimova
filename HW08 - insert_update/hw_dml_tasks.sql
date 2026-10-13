/*
                              Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "10 - Операторы изменения данных".
Задания выполняются с использованием базы данных WideWorldImporters.                                               */
-- ---------------------------------------------------------------------------
-- Задание - написать выборки для получения указанных ниже данных.
-- ---------------------------------------------------------------------------

USE WideWorldImporters;

/*-------------------------------------------------------------------------------------------------
1. Довставлять в базу пять записей используя insert в таблицу Customers или Suppliers            */

INSERT INTO  Sales.Customers  
           ( CustomerName,       BillToCustomerID  
           , CustomerCategoryID, BuyingGroupID 
           , PrimaryContactPersonID, AlternateContactPersonID 
           , DeliveryMethodID, DeliveryCityID, PostalCityID 
           , CreditLimit,      AccountOpenedDate,      StandardDiscountPercentage 
           , IsStatementSent, IsOnCreditHold, PaymentDays 
           , PhoneNumber, FaxNumber 
           , DeliveryRun, RunPosition, WebsiteURL 
           , DeliveryAddressLine1, DeliveryAddressLine2, DeliveryPostalCode, DeliveryLocation 
           , PostalAddressLine1, PostalAddressLine2, PostalPostalCode 
           , LastEditedBy      )
     OUTPUT INSERTED.CustomerID   -- вывожу все вставленные ID (понадобятся для следующего задания)
-- чтобы меньше значений придумывать, беру их из таблицы Suppliers, т.к.много схожих полей
SELECT TOP(5)  -- любые 5 строк     
             SupplierName, 801 AS BillToCustomerID
           , 1,           NULL AS BuyingGroupID 
           , PrimaryContactPersonID, AlternateContactPersonID
           , 3,                DeliveryCityID, PostalCityID
           , NULL, CONVERT(DATE,SYSUTCDATETIME()), 0 AS StandardDiscountPercentage
           , 0,               0,              PaymentDays
           , PhoneNumber, FaxNumber
           , NULL, NULL AS RunPosition, WebsiteURL
           , DeliveryAddressLine1, DeliveryAddressLine2, DeliveryPostalCode, DeliveryLocation
           , PostalAddressLine1, PostalAddressLine2, PostalPostalCode
           , LastEditedBy
FROM Purchasing.Suppliers;


/*-------------------------------------------------------------------
2. Удалите одну запись из Customers, которая была вами добавлена   */

DELETE FROM Sales.Customers 
WHERE CustomerID = 1066;  -- (последний ID был 1061 + 5 строк = 1066)

       -- или так:
;WITH cte_delete AS
(
	select top(1) *    -- последнюю из добавленных 
	from Sales.Customers
	order by CustomerID desc
)
DELETE FROM cte_delete;  -- т.к. 1066 удалили, то удаляем 1065


/*-------------------------------------------------------------------------------------------
3. Изменить одну запись из добавленных через UPDATE                                        */

UPDATE Sales.Customers
SET CustomerCategoryID = 3
WHERE CustomerID = 1064;  -- т.к. 1066 и 1065 удалили в задании 2
  
       -- или так:
UPDATE c
	SET c.CustomerCategoryID = 8, 
        c.CustomerID = c.CustomerID -- не меняем, просто чтоб попал в inserted, и выведем:
	OUTPUT INSERTED.CustomerID AS CustomerID,                     --  c каким ID строку меняли,
	       INSERTED.CustomerCategoryID AS NewCategoryID,  -- новое значение CustomerCategoryID,
	       DELETED.CustomerCategoryID AS OldCategoryID    -- старое значение CustomerCategoryID
	FROM 
	( 
		select top(1) *
		from Sales.Customers
		order by CustomerID desc
	) AS c;


/*-----------------------------------------------------------------------------------------------------------
4. Написать MERGE, который вставит запись в клиенты если ее там нет, 
                         и изменит если она уже есть                                                       */

/* Решение:
   используя уникальность CustomerName и запрос из задания 1, 
      довставляем оставшиеся строки и 
      изменим те, которые добавили ранее 
 таким образом  target -  Sales.Customers
                source -  Purchasing.Suppliers
если в target нет такого же Name -> insert into target 
если в source есть тот же Name   -> update target -> source.DeliveryMethodID 
*/
MERGE Sales.Customers AS Tgt
USING Purchasing.Suppliers AS Src ON Src.SupplierName = Tgt.CustomerName
WHEN MATCHED THEN 
    UPDATE SET DeliveryMethodID = ISNULL(Src.DeliveryMethodID,1)
WHEN NOT MATCHED BY TARGET THEN 
    INSERT 
           ( CustomerName, BillToCustomerID  
           , CustomerCategoryID, BuyingGroupID 
           , PrimaryContactPersonID, AlternateContactPersonID 
           , DeliveryMethodID, DeliveryCityID, PostalCityID 
           , CreditLimit,      AccountOpenedDate,      StandardDiscountPercentage 
           , IsStatementSent, IsOnCreditHold, PaymentDays 
           , PhoneNumber, FaxNumber 
           , DeliveryRun, RunPosition, WebsiteURL 
           , DeliveryAddressLine1, DeliveryAddressLine2, DeliveryPostalCode, DeliveryLocation 
           , PostalAddressLine1, PostalAddressLine2, PostalPostalCode 
           , LastEditedBy    )
    VALUES ( Src.SupplierName, 801 
           , 1, NULL 
           , Src.PrimaryContactPersonID, Src.AlternateContactPersonID
           , 3, Src.DeliveryCityID, Src.PostalCityID
           , NULL, CONVERT(DATE,SYSUTCDATETIME()), 0 
           , 0, 0, Src.PaymentDays
           , Src.PhoneNumber, Src.FaxNumber
           , NULL, NULL, Src.WebsiteURL
           , Src.DeliveryAddressLine1, Src.DeliveryAddressLine2, Src.DeliveryPostalCode, Src.DeliveryLocation
           , Src.PostalAddressLine1, Src.PostalAddressLine2, Src.PostalPostalCode
           , Src.LastEditedBy )
OUTPUT $action, deleted.*, inserted.*;


/*-----------------------------------------------------------------------------------------------------------------------
5. Напишите запрос, который выгрузит данные через bcp out и загрузит через bulk insert                                 */

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
-- сохраняем имя сервера
DECLARE @ServerName SYSNAME = @@SERVERNAME
      , @Cmd NVARCHAR(1000);

-- ВЫГРУЖАЕМ ДАННЫЕ -- (из таблицы БД в текстовый файл)
SET @Cmd = N'bcp "[WideWorldImporters].Sales.Customers" out  "D:\OTUS\BCP\CustomersTable.txt" -T -w -t"|" -S ' + @ServerName;
EXEC master..xp_cmdshell @Cmd;

-- выключаем процедуру 
EXEC sp_configure 'xp_cmdshell', 0;  
RECONFIGURE;  
GO 
-- возвращаем прежнюю настройку
EXEC sp_configure 'show advanced options', 0;  
RECONFIGURE;  
GO  

-- подключаемся к БД
USE WideWorldImporters;

-- подготавливаем таблицу для загрузки
DROP TABLE IF EXISTS Sales.CustomersFromFile;
SELECT * INTO Sales.CustomersFromFile from Sales.Customers where 1 = 0;

-- ЗАГРУЖАЕМ ДАННЫЕ -- (из файла в таблицу БД)
BULK INSERT Sales.CustomersFromFile
FROM "D:\OTUS\BCP\CustomersTable.txt"
WITH (
		BATCHSIZE = 100,           
		DATAFILETYPE = 'widechar', 
		FIELDTERMINATOR = '|', 
		ROWTERMINATOR ='\n',   
		KEEPNULLS,
		TABLOCK         
	 );

-- проверяем сколько записей 
SELECT COUNT(*) FROM Sales.CustomersFromFile;

-- удаляем таблицу если не нужна
DROP TABLE IF EXISTS Sales.CustomersFromFile;