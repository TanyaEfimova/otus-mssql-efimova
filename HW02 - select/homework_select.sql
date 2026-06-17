/*
                              Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "02 - Оператор SELECT и простые фильтры, JOIN".
Задания выполняются с использованием базы данных WideWorldImporters.
-- ---------------------------------------------------------------------------
-- Задание - написать выборки для получения указанных ниже данных.
-- ---------------------------------------------------------------------------
*/
USE WideWorldImporters;

/*---------------------------------------------------------------------------------
1. Все товары, в названии которых есть "urgent" или название начинается с "Animal".
Вывести: ИД товара (StockItemID), наименование товара (StockItemName).
Таблицы: Warehouse.StockItems.   */

SELECT StockItemID as 'ИД товара', StockItemName as 'наименование товара'
FROM Warehouse.StockItems
WHERE StockItemName like '%URGENT%' OR
      StockItemName like 'ANIMAL%';


/*--------------------------------------------------------------------------------------
2. Поставщиков (Suppliers), у которых не было сделано ни одного заказа (PurchaseOrders).
Сделать через JOIN, с подзапросом задание принято не будет.
Вывести: ИД поставщика (SupplierID), наименование поставщика (SupplierName).
Таблицы: Purchasing.Suppliers, Purchasing.PurchaseOrders.
По каким колонкам делать JOIN подумайте самостоятельно. */

SELECT s.SupplierID as 'ИД поставщика', s.SupplierName as 'наименование поставщика'
FROM      Purchasing.Suppliers s
LEFT JOIN Purchasing.PurchaseOrders o
       ON o.SupplierID = s.SupplierID
WHERE o.PurchaseOrderID IS NULL;


/*---------------------------------------------------------------------------------------
3. Заказы (Orders) с ценой товара (UnitPrice) более 100$ 
либо количеством единиц (Quantity) товара более 20 штук
и присутствующей датой комплектации всего заказа (PickingCompletedWhen).
Вывести:
* OrderID
* дату заказа (OrderDate) в формате ДД.ММ.ГГГГ
* название месяца, в котором был сделан заказ
* номер квартала, в котором был сделан заказ
* треть года, к которой относится дата заказа (каждая треть по 4 месяца)
* имя заказчика (Customer)
Сортировка должна быть по номеру квартала, трети года, дате заказа (везде по возрастанию).
Таблицы: Sales.Orders, Sales.OrderLines, Sales.Customers.     */

SELECT o.OrderID
      ,CONVERT(varchar(10), o.OrderDate, 104) as [дата заказа]  --I способ
      ,FORMAT(o.OrderDate, 'dd.MM.yyyy')      as OrderDate      --II способ
      ,DATENAME(month, o.OrderDate)         as [название месяца заказа]  --1 способ
	  ,FORMAT(o.OrderDate, 'MMMM', 'ru-ru') as [месяц заказа Ru]         --2 способ
      ,FORMAT(o.OrderDate, 'MMMM', 'en-US') as [месяц заказа Eng]        --3 способ
      ,DATEPART(QUARTER, o.OrderDate)   as [номер квартала заказа] --I variant
      ,DATENAME(QUARTER, o.OrderDate)   as QuarterNumber           --II variant
      ,(MONTH(o.OrderDate) - 1) / 3 + 1 as QuarterNum              --III variant
      ,(MONTH(o.OrderDate) - 1) / 4 + 1     as [треть года] --1 way
      ,CASE
            WHEN MONTH(o.OrderDate) BETWEEN 1 AND 4 THEN 1
            WHEN MONTH(o.OrderDate) BETWEEN 5 AND 8 THEN 2
                                                    ELSE 3
       END                                  as ThirdOfYear  --2 way
      ,c.CustomerName as [имя заказчика]
FROM Sales.Orders o
JOIN Sales.OrderLines l ON l.OrderID = o.OrderID
JOIN Sales.Customers  c ON c.CustomerID = o.CustomerID
WHERE (l.UnitPrice > 100.00)
   OR (l.Quantity>20 and o.PickingCompletedWhen is not null)
ORDER BY [номер квартала заказа], [треть года], o.OrderDate;

/* Добавьте вариант этого запроса с постраничной выборкой,
пропустив первую 1000 и отобразив следующие 100 записей:  */

DECLARE @pagesize BIGINT = 100, -- Размер страницы
	     @pagenum BIGINT = 11;  -- Номер страницы   (1000/100=10 страниц пропускаем и выводим следующую)

SELECT o.OrderID
      ,CONVERT(varchar(10), o.OrderDate, 104) as [дата заказа]  --I способ
      ,FORMAT(o.OrderDate, 'dd.MM.yyyy')      as OrderDate      --II способ
      ,DATENAME(month, o.OrderDate)         as [название месяца заказа]  --1 способ
	  ,FORMAT(o.OrderDate, 'MMMM', 'ru-ru') as [месяц заказа Ru]         --2 способ
      ,FORMAT(o.OrderDate, 'MMMM', 'en-US') as [месяц заказа Eng]        --3 способ
      ,DATEPART(QUARTER, o.OrderDate)   as [номер квартала заказа] --I variant
      ,DATENAME(QUARTER, o.OrderDate)   as QuarterNumber           --II variant
      ,(MONTH(o.OrderDate) - 1) / 3 + 1 as QuarterNum              --III variant
      ,(MONTH(o.OrderDate) - 1) / 4 + 1     as [треть года] --1 way
      ,CASE
            WHEN MONTH(o.OrderDate) BETWEEN 1 AND 4 THEN 1
            WHEN MONTH(o.OrderDate) BETWEEN 5 AND 8 THEN 2
                                                    ELSE 3
       END                                  as ThirdOfYear  --2 way
      ,c.CustomerName as [имя заказчика]
FROM Sales.Orders o
JOIN Sales.OrderLines l ON l.OrderID = o.OrderID
JOIN Sales.Customers  c ON c.CustomerID = o.CustomerID
WHERE (l.UnitPrice > 100.00)
OR    (l.Quantity>20 and o.PickingCompletedWhen is not null)
ORDER BY [номер квартала заказа], [треть года], o.OrderDate
OFFSET(@pagenum - 1) * @pagesize ROWS
FETCH NEXT @pagesize ROWS ONLY;


/*-----------------------------------------------------------------------------------------------------------
4. Заказы поставщикам (Purchasing.Suppliers),
которые должны быть исполнены (ExpectedDeliveryDate) в январе 2013 года
с доставкой "Air Freight" или "Refrigerated Air Freight" (DeliveryMethodName)
и которые исполнены (IsOrderFinalized).
Вывести:
* способ доставки (DeliveryMethodName)
* дата доставки (ExpectedDeliveryDate)
* имя поставщика
* имя контактного лица принимавшего заказ (ContactPerson)
Таблицы: Purchasing.Suppliers, Purchasing.PurchaseOrders, Application.DeliveryMethods, Application.People. */

SELECT m.DeliveryMethodName as 'способ доставки', 
     o.ExpectedDeliveryDate as 'дата доставки', 
             s.SupplierName as 'имя поставщика',
                 p.FullName as 'имя принимавшего заказ контактного лица'
FROM Purchasing.Suppliers s
JOIN Purchasing.PurchaseOrders o ON o.SupplierID = s.SupplierID
JOIN Application.DeliveryMethods m ON m.DeliveryMethodID = o.DeliveryMethodID
JOIN Application.People p ON p.PersonID = o.ContactPersonID
WHERE o.ExpectedDeliveryDate between '2013-01-01' and '2013-01-31'
  AND o.IsOrderFinalized = 1
  AND (m.DeliveryMethodName = 'Air Freight' or m.DeliveryMethodName = 'Refrigerated Air Freight');


/*--------------------------------------------------------------------------------
5. Десять последних продаж (по дате продажи) с именем клиента и именем сотрудника,
который оформил заказ (SalespersonPerson).
Сделать без подзапросов.  */

-- поскольку в данной БД много продаж имеют одинаковую дату продажи, то
-- чтобы получить именно последние из них, иногда требуется включать в запросы дополнительные поля:

-- если нужны любые 10 последних по дате продажи
SELECT TOP 10
    o.OrderID      AS [заказ]
   ,o.OrderDate    AS [дата продажи]
   ,c.CustomerName AS [имя клиента]
   ,p.FullName     AS [ФИО оформившего заказ]
FROM Sales.Orders AS o
JOIN Sales.Customers    AS c ON c.CustomerID = o.CustomerID
JOIN Application.People AS p ON p.PersonID = o.SalespersonPersonID
ORDER BY o.OrderDate DESC;

-- если нужны последние по дате продажи, но не обязательно 10
SELECT TOP 10 WITH TIES
    o.OrderID      AS [заказ]
   ,o.OrderDate    AS [дата продажи]
   ,c.CustomerName AS [имя клиента]
   ,p.FullName     AS [ФИО оформившего заказ]
FROM Sales.Orders AS o
JOIN Sales.Customers    AS c ON c.CustomerID = o.CustomerID
JOIN Application.People AS p ON p.PersonID = o.SalespersonPersonID
ORDER BY o.OrderDate DESC;

-- если нужны именно 10 и именно последних созданных(по дате продажи и номеру заказа)
SELECT TOP 10 
    o.OrderID      AS [заказ]
   ,o.OrderDate    AS [дата продажи]
   ,c.CustomerName AS [имя клиента]
   ,p.FullName     AS [ФИО оформившего заказ]
FROM Sales.Orders AS o
JOIN Sales.Customers    AS c ON c.CustomerID = o.CustomerID
JOIN Application.People AS p ON p.PersonID = o.SalespersonPersonID
ORDER BY o.OrderDate DESC, o.OrderID DESC;

-- если нужны именно 10 и именно последних собранных из созданных(по дате продажи, дате сборки заказа, номеру заказа)
SELECT TOP 10
    o.OrderID              AS [заказ]
   ,o.OrderDate            AS [дата продажи]
   ,o.PickingCompletedWhen AS [дата завершения сборки заказа]
   ,c.CustomerName         AS [имя клиента]
   ,p.FullName             AS [ФИО оформившего заказ]
FROM Sales.Orders AS o
JOIN Sales.Customers    AS c ON c.CustomerID = o.CustomerID
JOIN Application.People AS p ON p.PersonID = o.SalespersonPersonID
ORDER BY o.OrderDate DESC, o.PickingCompletedWhen DESC, o.OrderID DESC;

-- если нужны любые 10 последних собранных(по дате продажи и дате сборки заказа)
SELECT TOP 10
    o.OrderID              AS [заказ]
   ,o.OrderDate            AS [дата продажи]
   ,o.PickingCompletedWhen AS [дата завершения сборки заказа]
   ,c.CustomerName         AS [имя клиента]
   ,p.FullName             AS [ФИО оформившего заказ]
FROM Sales.Orders AS o
JOIN Sales.Customers    AS c ON c.CustomerID = o.CustomerID
JOIN Application.People AS p ON p.PersonID = o.SalespersonPersonID
ORDER BY o.OrderDate DESC, o.PickingCompletedWhen DESC;

-- если нужны последние (по дате продажи и дате сборки заказа), но не обязательно 10
SELECT TOP 10 WITH TIES
    o.OrderID              AS [заказ]
   ,o.OrderDate            AS [дата продажи]
   ,o.PickingCompletedWhen AS [дата завершения сборки заказа]
   ,c.CustomerName         AS [имя клиента]
   ,p.FullName             AS [ФИО оформившего заказ]
FROM Sales.Orders AS o
JOIN Sales.Customers    AS c ON c.CustomerID = o.CustomerID
JOIN Application.People AS p ON p.PersonID = o.SalespersonPersonID
ORDER BY o.OrderDate DESC, o.PickingCompletedWhen DESC;

-- если нужные последние продажи по дате продажи (и этих дат должно быть 10), то
-- чтобы не использовать подзапрос, можно, например, использовать временную таблицу:
DROP TABLE IF EXISTS #t;

SELECT DISTINCT TOP (10)  OrderDate
INTO #t
    FROM Sales.Orders
    ORDER BY OrderDate DESC;

SELECT 
    o.OrderID              AS [заказ]
   ,o.OrderDate            AS [дата продажи]
   ,c.CustomerName         AS [имя клиента]
   ,p.FullName             AS [ФИО оформившего заказ]
FROM Sales.Orders AS o
JOIN #t AS t                 ON o.OrderDate = t.OrderDate
JOIN Sales.Customers    AS c ON c.CustomerID = o.CustomerID
JOIN Application.People AS p ON p.PersonID = o.SalespersonPersonID
ORDER BY o.OrderDate DESC;

DROP TABLE IF EXISTS #t;


/*--------------------------------------------------------------
6. Все ид и имена клиентов и их контактные телефоны,
которые покупали товар "Chocolate frogs 250g".
Имя товара смотреть в таблице Warehouse.StockItems.      */

SELECT DISTINCT c.CustomerID   AS [ид клиента]
              , c.CustomerName AS [имя клиента]
              , c.PhoneNumber  AS [контактный телефон]
FROM Warehouse.StockItems AS s
JOIN Sales.OrderLines     AS ol ON ol.StockItemID = s.StockItemID
JOIN Sales.Orders         AS o  ON o.OrderID = ol.OrderID
JOIN Sales.Customers      AS c  ON c.CustomerID = o.CustomerID
WHERE s.StockItemName = 'Chocolate frogs 250g'
ORDER BY c.CustomerID;
