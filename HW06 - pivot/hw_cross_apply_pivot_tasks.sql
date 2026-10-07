/*
                                Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "Операторы CROSS APPLY, PIVOT, UNPIVOT".
Задания выполняются с использованием базы данных WideWorldImporters.                                                   */
-- ---------------------------------------------------------------------------
-- Задание - написать выборки для получения указанных ниже данных.
-- ---------------------------------------------------------------------------

USE WideWorldImporters;

/*--------------------------------------------------------------------------------------------------
1. Требуется написать запрос, который в результате своего выполнения 
формирует сводку по количеству покупок в разрезе клиентов и месяцев.
В строках должны быть месяцы (дата начала месяца), в столбцах - клиенты.
Клиентов взять с ID 2-6, это все подразделение Tailspin Toys.
Имя клиента нужно поменять так чтобы осталось только уточнение.
Например, исходное значение "Tailspin Toys (Gasport, NY)" - вы выводите только "Gasport, NY".
Дата должна иметь формат dd.mm.yyyy, например, 25.12.2019.

Пример, как должны выглядеть результаты:
-------------+--------------------+--------------------+-------------+--------------+------------
InvoiceMonth | Peeples Valley, AZ | Medicine Lodge, KS | Gasport, NY | Sylvanite, MT | Jessie, ND
-------------+--------------------+--------------------+-------------+--------------+------------
01.01.2013   |      3             |        1           |      4      |      2        |     2
01.02.2013   |      7             |        3           |      4      |      2        |     1
-------------+--------------------+--------------------+-------------+--------------+------------ */

SELECT FORMAT(MonthStart,'dd.MM.yyyy') 
 AS InvoiceMonth,
   [Peeples Valley, AZ],
   [Medicine Lodge, KS],
   [Gasport, NY],
   [Sylvanite, MT],
   [Jessie, ND]
FROM
(
	SELECT DATETRUNC(month, i.InvoiceDate)                             AS MonthStart, 
	       TRIM('()'FROM REPLACE(c.CustomerName,'Tailspin Toys ', '')) AS CustomerName,
	                                                                    i.InvoiceID
	FROM Sales.Customers c
	JOIN Sales.Invoices  i
	ON i.CustomerID = c.CustomerID
	WHERE c.CustomerID BETWEEN 2 AND 6
) AS src
PIVOT
(
	COUNT(InvoiceID)
	FOR CustomerName IN ([Peeples Valley, AZ],[Medicine Lodge, KS],[Gasport, NY],[Sylvanite, MT],[Jessie, ND])
) AS pvt
ORDER BY MonthStart;


/*-----------------------------------------------------------
2. Для всех клиентов с именем, в котором есть "Tailspin Toys"
вывести все адреса, которые есть в таблице, в одной колонке.

Пример результата:
----------------------------+--------------------
CustomerName                | AddressLine
----------------------------+--------------------
Tailspin Toys (Head Office) | Shop 38
Tailspin Toys (Head Office) | 1877 Mittal Road
Tailspin Toys (Head Office) | PO Box 8975
Tailspin Toys (Head Office) | Ribeiroville
----------------------------+--------------------          */

SELECT CustomerName, AddressLine  
FROM Sales.Customers
UNPIVOT
(
    AddressLine FOR TypeAddress IN (DeliveryAddressLine1, DeliveryAddressLine2, PostalAddressLine1, PostalAddressLine2)
) AS unpvt

WHERE CustomerName LIKE '%Tailspin Toys%';


/*-----------------------------------------------------------------------------------------
3. В таблице стран (Application.Countries) есть поля с цифровым кодом страны и с буквенным.
Сделайте выборку ИД страны, названия и ее кода так, 
чтобы в поле с кодом был либо цифровой либо буквенный код.

Пример результата:
--------------------------------
CountryId | CountryName | Code
----------+-------------+-------
1         | Afghanistan | AFG
1         | Afghanistan | 4
3         | Albania     | ALB
3         | Albania     | 8
----------+-------------+-------    */

SELECT CountryID, 
       CountryName, 
	   Code
FROM
(
	SELECT CountryID, 
		   CountryName, 
	  CAST(IsoAlpha3Code  AS NVARCHAR(10)) AS LetterCode,
	  CAST(IsoNumericCode AS NVARCHAR(10)) AS NumericCode
	FROM Application.Countries
) AS src
UNPIVOT
( 
    Code FOR TypeCode IN (LetterCode, NumericCode)
) AS unpvt
ORDER BY CountryID;


/*-----------------------------------------------------------------------------------
4. Выберите по каждому клиенту два самых дорогих товара, которые он покупал.
В результатах должно быть ид клиента, его название, ид товара, цена, дата покупки. */

-- 1 --если требуется найти дорогие по ПРАЙСОВОЙ цене товары:
SELECT c.CustomerID   AS [Ид клиента],
       c.CustomerName AS [Название клиента],
       t.StockItemID  AS [Ид товара],
       t.UnitPrice    AS [Цена],
       t.OrderDate    AS [Дата покупки]
FROM Sales.Customers 
  AS c
CROSS APPLY    
(
    SELECT TOP (2) si.StockItemID,
                   si.UnitPrice,
                    o.OrderDate
    FROM Sales.Orders         AS o
    JOIN Sales.OrderLines     AS ol  ON ol.OrderID = o.OrderID
    JOIN Warehouse.StockItems AS si  ON si.StockItemID = ol.StockItemID
    WHERE o.CustomerID = c.CustomerID
    ORDER BY si.UnitPrice DESC
) AS t
ORDER BY c.CustomerID;

-- 2 --если требуется найти дорогие по ПРОДАЖНОЙ(может отличаться от прайса) цене товары:
SELECT c.CustomerID   AS [Ид клиента],
       c.CustomerName AS [Название клиента],
       t.StockItemID  AS [Ид товара],
       t.UnitPrice    AS [Цена],
       t.OrderDate    AS [Дата покупки]
FROM Sales.Customers 
  AS c
CROSS APPLY
(
    SELECT TOP (2) ol.StockItemID,
                   ol.UnitPrice,
                    o.OrderDate
    FROM Sales.Orders     AS o
    JOIN Sales.OrderLines AS ol ON ol.OrderID = o.OrderID
    WHERE o.CustomerID = c.CustomerID
    ORDER BY ol.UnitPrice DESC
) AS t
ORDER BY c.CustomerID;

