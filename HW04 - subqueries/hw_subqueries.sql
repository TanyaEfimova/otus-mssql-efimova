/*
                               Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "04 - Подзапросы, CTE, временные таблицы".
Задания выполняются с использованием базы данных WideWorldImporters.
-- -----------------------------------------------------------------------------------------
-- Задание - написать выборки для получения указанных ниже данных.
-- Для всех заданий, где возможно, сделайте два варианта запросов:
--  1) через вложенный запрос
--  2) через WITH (для производных таблиц)
-- -----------------------------------------------------------------------------------------
*/
USE WideWorldImporters;

/*-----------------------------------------------------------------------------------------
1. Выберите сотрудников (Application.People), которые являются продажниками (IsSalesPerson), 
и не сделали ни одной продажи 04 июля 2015 года. 
Вывести ИД сотрудника и его полное имя. 
Продажи смотреть в таблице Sales.Invoices.                  */

-- 1 --
SELECT PersonID AS [ИД сотрудника],
       FullName AS [Полное имя]
FROM Application.People
WHERE IsSalesperson = 1 
AND NOT EXISTS (SELECT 1 FROM Sales.Invoices 
                WHERE InvoiceDate = '2015-07-04' 
				  AND SalespersonPersonID = People.PersonID
			   );

-- 2 --
WITH cte_sales AS
(
    select distinct SalespersonPersonID
    from Sales.Invoices
    where InvoiceDate = '2015-07-04'
)
SELECT p.PersonID AS [ИД сотрудника],
       p.FullName AS [Полное имя]
FROM Application.People AS p
LEFT JOIN     cte_sales AS s ON p.PersonID = s.SalespersonPersonID
WHERE p.IsSalesperson = 1
  AND s.SalespersonPersonID IS NULL;


/*------------------------------------------------------------------------------------
2. Выберите товары с минимальной ценой (подзапросом). Сделайте два варианта подзапроса. 
Вывести: ИД товара, наименование товара, цена. */

-- 1 --
SELECT StockItemID AS [ИД товара], 
     StockItemName AS [наименование товара], 
         UnitPrice AS [цена]
FROM Warehouse.StockItems
WHERE UnitPrice = (select min(UnitPrice) from Warehouse.StockItems);

-- 2 --
SELECT StockItemID AS [ИД товара], 
     StockItemName AS [наименование товара], 
         UnitPrice AS [цена]
FROM Warehouse.StockItems
WHERE UnitPrice <= ALL(select UnitPrice from Warehouse.StockItems);

-- 3 --
WITH cte_prices AS 
(
	select min(UnitPrice) as MinUnitPrice from Warehouse.StockItems
)
SELECT si.StockItemID AS [ИД товара], si.StockItemName AS [наименование товара], si.UnitPrice AS [цена]
FROM Warehouse.StockItems AS si
          JOIN cte_prices AS pr ON si.UnitPrice = pr.MinUnitPrice;


/*-----------------------------------------------------------------------------------------
3. Выберите информацию по клиентам, которые перевели компании пять максимальных платежей 
из Sales.CustomerTransactions. 
Представьте несколько способов (в том числе с CTE).   */

------- если под "максимальным" подразумевается размер каждой ОТДЕЛЬНОЙ транзакции(платежа):
-- 1 --
SELECT CustomerID   AS [Идентификатор клиента],
       CustomerName AS [Имя клиента]
FROM Sales.Customers
WHERE CustomerID IN
(
    select top (5) CustomerID
    from Sales.CustomerTransactions
    order by TransactionAmount desc
);

-- 2 --
SELECT c.CustomerID        AS [Идентификатор клиента],
       c.CustomerName      AS [Имя клиента],
       t.TransactionAmount AS [Размер платежа]
FROM
(
    select top (5) CustomerID, TransactionAmount
    from Sales.CustomerTransactions
    order by TransactionAmount desc
)                 AS t 
JOIN Sales.Customers c ON c.CustomerID = t.CustomerID
ORDER BY [Размер платежа] DESC;

-- 3 --
SELECT customers.CustomerID      AS [Идентификатор клиента], 
       customers.CustomerName    AS [Имя клиента], 
       amounts.TransactionAmount AS [Размер платежа]
FROM Sales.Customers 
AS customers JOIN 
                 (
                   select top (5) CustomerID, TransactionAmount
                   from Sales.CustomerTransactions
                   order by TransactionAmount desc
                 ) 
AS amounts ON customers.CustomerID = amounts.CustomerID
ORDER BY [Размер платежа] DESC;

-- 4 --
WITH cte_amounts AS
(
   select top (5) CustomerID, TransactionAmount
   from Sales.CustomerTransactions
   order by TransactionAmount desc
)
SELECT c.CustomerID        AS [Идентификатор клиента], 
       c.CustomerName      AS [Имя клиента], 
       a.TransactionAmount AS [Размер платежа]
FROM Sales.Customers AS c
    JOIN cte_amounts AS a ON c.CustomerID = a.CustomerID
ORDER BY [Размер платежа] DESC;

-- 5 --
DROP TABLE IF EXISTS #t;

SELECT TOP (5) CustomerID, TransactionAmount
INTO #t
FROM Sales.CustomerTransactions
ORDER BY TransactionAmount DESC;

SELECT c.CustomerID        AS [Идентификатор клиента], 
       c.CustomerName      AS [Имя клиента], 
       t.TransactionAmount AS [Размер платежа]
FROM Sales.Customers AS c
             JOIN #t AS t ON c.CustomerID = t.CustomerID
ORDER BY [Размер платежа] DESC;

DROP TABLE IF EXISTS #t;

------- если под "максимальным" подразумевается СУММАРНЫЙ платеж от каждой компании:
-- 1 --
SELECT CustomerID   AS [Идентификатор клиента],
       CustomerName AS [Имя клиента]
FROM Sales.Customers
WHERE CustomerID IN
(
    select top (5) CustomerID
    from Sales.CustomerTransactions
    group by CustomerID
    order by sum(TransactionAmount) desc
);

-- 2 --
SELECT c.CustomerID   AS [Идентификатор клиента],
       c.CustomerName AS [Имя клиента],
       t.TotalAmount  AS [Сумма платежей]
FROM
(
    select top (5) CustomerID,
                   sum(TransactionAmount) as TotalAmount
    from Sales.CustomerTransactions
    group by CustomerID
    order by TotalAmount desc
) AS t JOIN Sales.Customers c
  ON c.CustomerID = t.CustomerID
ORDER BY 3 DESC;

-- 3 --
SELECT c.CustomerID   AS [Идентификатор клиента],
       c.CustomerName AS [Имя клиента],
    (
        SELECT SUM(ct.TransactionAmount)
        FROM Sales.CustomerTransactions ct
        WHERE ct.CustomerID = c.CustomerID
    )                 AS [Сумма платежей]
FROM Sales.Customers c
WHERE c.CustomerID IN
(
    select top (5) CustomerID
    from Sales.CustomerTransactions
    group by CustomerID
    order by sum(TransactionAmount) desc
)
ORDER BY [Сумма платежей] DESC;

-- 4 --
WITH cte_transactions AS
(
    select CustomerID,
       sum(TransactionAmount) as TotalAmount
    from Sales.CustomerTransactions
    group by CustomerID
)
SELECT TOP (5) c.CustomerID   AS [Идентификатор клиента],
               c.CustomerName AS [Имя клиента],
               t.TotalAmount  AS [Сумма платежей]
FROM cte_transactions t
JOIN  Sales.Customers c
  ON   c.CustomerID = t.CustomerID
ORDER BY 3 DESC;

-- 5 --
WITH cte_trans AS
(
    select CustomerID,
       sum(TransactionAmount) as TotalAmount
    from Sales.CustomerTransactions
    group by CustomerID
),
cte_top AS
(
    select top (5) CustomerID, TotalAmount
    from cte_trans
    order by TotalAmount desc
)
SELECT
    c.CustomerID   AS [Идентификатор клиента],
    c.CustomerName AS [Имя клиента],
    t.TotalAmount  AS [Сумма платежей]
FROM         cte_top t
JOIN Sales.Customers c
    ON c.CustomerID = t.CustomerID
ORDER BY 3 DESC;


/*---------------------------------------------------------------------
4. Выберите города (ид и название), в которые были доставлены товары, 
входящие в тройку самых дорогих товаров, а также имя сотрудника, 
который осуществлял упаковку заказов (PackedByPersonID).          */

-- 1 --
SELECT DISTINCT ci.CityID   AS [ИД города]
               ,ci.CityName AS [Название города]
               , p.FullName AS [Заказ упакован]
FROM Sales.InvoiceLines il
JOIN Sales.Invoices     i  ON i.InvoiceID = il.InvoiceID
JOIN Sales.Customers    c  ON c.CustomerID = i.CustomerID
JOIN Application.People p  ON p.PersonID = i.PackedByPersonID
JOIN Application.Cities ci ON ci.CityID = c.DeliveryCityID
WHERE il.StockItemID IN
(
    select top (3) with ties StockItemID
    from Warehouse.StockItems
    order by UnitPrice desc
)   
ORDER BY ci.CityName, p.FullName;

-- 2 --
WITH cte_items AS
(
    select top (3) with ties StockItemID
    from Warehouse.StockItems
    order by UnitPrice desc
)
SELECT DISTINCT ci.CityID   AS [ИД города]
               ,ci.CityName AS [Название города]
               , p.FullName AS [Заказ упакован]
FROM Sales.InvoiceLines il
JOIN cte_items          it ON il.StockItemID = it.StockItemID
JOIN Sales.Invoices     i  ON i.InvoiceID = il.InvoiceID
JOIN Sales.Customers    c  ON c.CustomerID = i.CustomerID
JOIN Application.People p  ON p.PersonID = i.PackedByPersonID
JOIN Application.Cities ci ON ci.CityID = c.DeliveryCityID
ORDER BY ci.CityName, p.FullName;


--------------------------------------------------------------------------------------------
-- Опциональное задание
-- -----------------------------------------------------------------------------------------
-- Можно двигаться как в сторону улучшения читабельности запроса, 
-- так и в сторону упрощения плана\ускорения. 
-- Сравнить производительность запросов можно через SET STATISTICS IO, TIME ON. 
-- Если знакомы с планами запросов, то используйте их (тогда к решению также приложите планы). 
-- Напишите ваши рассуждения по поводу оптимизации. 
/*-------------------------------------------------------------------------------------------
5. Объясните, что делает и оптимизируйте запрос:                                           */
SELECT 
	Invoices.InvoiceID, 
	Invoices.InvoiceDate,
	(SELECT People.FullName
		FROM Application.People
		WHERE People.PersonID = Invoices.SalespersonPersonID
	) AS SalesPersonName,
	SalesTotals.TotalSumm AS TotalSummByInvoice, 
	(SELECT SUM(OrderLines.PickedQuantity*OrderLines.UnitPrice)
		FROM Sales.OrderLines
		WHERE OrderLines.OrderId = (SELECT Orders.OrderId 
			FROM Sales.Orders
			WHERE Orders.PickingCompletedWhen IS NOT NULL	
				AND Orders.OrderId = Invoices.OrderId)	
	) AS TotalSummForPickedItems
FROM Sales.Invoices 
	JOIN
	(SELECT InvoiceId, SUM(Quantity*UnitPrice) AS TotalSumm
	FROM Sales.InvoiceLines
	GROUP BY InvoiceId
	HAVING SUM(Quantity*UnitPrice) > 27000) AS SalesTotals
		ON Invoices.InvoiceID = SalesTotals.InvoiceID
ORDER BY TotalSumm DESC;

/* Этот запрос выводит информацию по счетам (Sales.Invoices), 
у которых общая стоимость товаров в счёте больше 27000 (начиная вывод с наибольшей стоимости).

Возвращаются следующие данные:
InvoiceID — номер счёта;
InvoiceDate — дата счёта;
SalesPersonName — имя продавца;
TotalSummByInvoice — общая сумма счёта;
TotalSummForPickedItems — стоимость отобранных (picked) товаров  в заказе, указанного в счёте, 
                          если он(заказ) уже полностью собран (PickingCompletedWhen IS NOT NULL).

Исходя из плана -      файл query_task5_firstPlan(no-optimized).sqlplan
и времени выполнения - файл query_task5_firstTime(no-optimized).rpt
374 мс ЦП, 461 мс общее, 
основная проблема этого запроса — это коррелированные подзапросы в SELECT, особенно вычисление столбца TotalSummForPickedItems.
Запрос для каждой строки из Invoices выполняет отдельный поиск в таблицах Orders и OrderLines, а также агрегацию суммы. 
Это приводит к многократному сканированию одних и тех же таблиц (что видно по высоким показателям логических чтений LOB). */


-- РЕШЕНИЕ:                                                                                                                         
/*    Для максимальной оптимизации нужно переписать запрос так, 
чтобы все агрегации и подзапросы выполнялись однократно для всего набора данных, 
а затем происходило их соединение (JOIN). 
Мой способ это сделать — через обобщенные табличные выражения (CTE) и операторы JOIN / LEFT JOIN.
Также я бы рекомендовала создать/изменить 2 некластеризованных индекса: 
  на таблице Sales.Invoices по полю OrderId с включением InvoiceID,InvoiceDate,SalespersonPersonID
и на таблице Sales.Orders   по полю PickingCompletedWhen с включением OrderId.                                             */

CREATE NONCLUSTERED INDEX [FK_Sales_Invoices_OrderID] ON [Sales].[Invoices] ([OrderId])
INCLUDE ([InvoiceID], [InvoiceDate], [SalespersonPersonID])
WITH (DROP_EXISTING = ON);   -- пересоздание существующего (с добавлением полей в Include)

CREATE NONCLUSTERED INDEX [IX_Orders_PickingCompletedWhen] ON [Sales].[Orders] ([PickingCompletedWhen]) 
INCLUDE ([OrderId]);

;WITH 
cte_invoiceTotals AS 
(
    select 
        InvoiceId, 
        sum(Quantity * UnitPrice) as TotalSumm
    from Sales.InvoiceLines
    group by InvoiceId
    having sum(Quantity * UnitPrice) > 27000
),
cte_pickedOrderTotals AS 
(
    select 
        o.OrderId, 
        sum(ol.PickedQuantity * ol.UnitPrice) as TotalSummForPickedItems
    from Sales.Orders o
    join Sales.OrderLines ol on o.OrderId = ol.OrderId
    where o.PickingCompletedWhen is not null
    group by o.OrderId
)
SELECT 
    i.InvoiceID, 
    i.InvoiceDate,
    p.FullName AS SalesPersonName,
    it.TotalSumm AS TotalSummByInvoice, 
    pt.TotalSummForPickedItems
FROM          Sales.Invoices i
INNER JOIN cte_invoiceTotals it ON i.InvoiceID = it.InvoiceID
LEFT JOIN Application.People p ON i.SalespersonPersonID = p.PersonID
LEFT JOIN cte_pickedOrderTotals pt ON i.OrderId = pt.OrderId
ORDER BY it.TotalSumm DESC;

/*
Исходя из плана -      файл query_task5_lastPlan(optimized).sqlplan
и времени выполнения - файл query_task5_lastTime(optimized).rpt
172 мс ЦП, 201 мс общее,
замечаем такие улучшения: 
- время ЦП сократилось в ~2.2 раза, общее время в ~2.3 раза.
- число сканирований и логических чтений значительно снизилось
    OrderLines:  сканирований 2 (было 22), логических чтений 345 (было 508)
    InvoiceLines:сканирований 2 (было 22), логических чтений 341 (было 502)
    Orders:      сканирований 1 (было 12), логических чтений 164 (было 725).
    Invoices:    сканирований 1 (было 12), логических чтений 192 (было 11994)
    People:      сканирований 1 (было 12), логических чтений 11  (было 28).
*/