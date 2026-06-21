/*
                              Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "03 - Агрегатные функции, GROUP BY, HAVING".
Задания выполняются с использованием базы данных WideWorldImporters.
-- ---------------------------------------------------------------------------
-- Задание - написать выборки для получения указанных ниже данных.
-- ---------------------------------------------------------------------------
*/
USE WideWorldImporters

/*-----------------------------------------------------------------------
1. Посчитать среднюю цену товара, общую сумму продажи по месяцам.
Вывести:
* Год продажи (например, 2015)
* Месяц продажи (например, 4)
* Средняя цена за месяц по всем товарам
* Общая сумма продаж за месяц
Продажи смотреть в таблице Sales.Invoices и связанных таблицах.    */

SELECT YEAR(i.InvoiceDate)             AS [Год продажи],
       MONTH(i.InvoiceDate)            AS [Месяц продажи],
       AVG(il.UnitPrice)               AS [Средняя цена за месяц],
       SUM(il.Quantity * il.UnitPrice) AS [Сумма всех продаж за месяц]
FROM Sales.Invoices     AS i
JOIN Sales.InvoiceLines AS il ON il.InvoiceID = i.InvoiceID
GROUP BY YEAR(i.InvoiceDate), MONTH(i.InvoiceDate)
ORDER BY [Год продажи], [Месяц продажи];

-- Опционально
-- Написать этот запрос так, чтобы если в каком-то месяце не было продаж,
-- то этот месяц также отображался бы в результатах, но там были нули:
DROP TABLE IF EXISTS #t;
DROP TABLE IF EXISTS #sales;

SELECT DISTINCT YEAR(i.InvoiceDate)   AS YearNumber,
                     m.Months         AS MonthNumber
INTO #t  -- календарь месяцев
FROM Sales.Invoices as i
CROSS JOIN (VALUES (1),(2),(3),(4),(5),(6),
                   (7),(8),(9),(10),(11),(12)) AS m(Months);

SELECT YEAR(i.InvoiceDate)             AS InvoiceYear,
       MONTH(i.InvoiceDate)            AS InvoiceMonth,
       AVG(il.UnitPrice)               AS PriceAvg,
       SUM(il.Quantity * il.UnitPrice) AS InvoiceSum
INTO #sales -- продажи
FROM Sales.Invoices     AS i
JOIN Sales.InvoiceLines AS il ON il.InvoiceID = i.InvoiceID
GROUP BY YEAR(i.InvoiceDate), MONTH(i.InvoiceDate);

SELECT t.YearNumber              AS [Год продажи],
       t.MonthNumber             AS [Месяц продажи],
       COALESCE(s.PriceAvg, 0)   AS [Средняя цена за месяц],
       COALESCE(s.InvoiceSum, 0) AS [Сумма всех продаж за месяц]
FROM          #t AS t
LEFT JOIN #sales AS s ON s.InvoiceYear = t.YearNumber
                     AND s.InvoiceMonth = t.MonthNumber
ORDER BY [Год продажи],[Месяц продажи];

DROP TABLE IF EXISTS #sales;
DROP TABLE IF EXISTS #t;


/*--------------------------------------------------------------------
2. Отобразить все месяцы, где общая сумма продаж превысила 4 600 000
Вывести:
* Год продажи (например, 2015)
* Месяц продажи (например, 4)
* Общая сумма продаж
Продажи смотреть в таблице Sales.Invoices и связанных таблицах.  */

SELECT YEAR(i.InvoiceDate)             AS [Год продажи],
       MONTH(i.InvoiceDate)            AS [Месяц продажи],
       SUM(il.Quantity * il.UnitPrice) AS [Общ.сумма продаж(>4600000)]
FROM Sales.Invoices     AS i
JOIN Sales.InvoiceLines AS il ON il.InvoiceID = i.InvoiceID
GROUP BY YEAR(i.InvoiceDate), MONTH(i.InvoiceDate)
HAVING SUM(il.Quantity * il.UnitPrice) > 4600000.00
ORDER BY [Год продажи], [Месяц продажи];


/*----------------------------------------------------------------------------------
3. Вывести сумму продаж, дату первой продажи и количество проданного по месяцам, 
по товарам, продажи которых менее 50 ед в месяц.
Группировка должна быть по году,  месяцу, товару.
Вывести:
* Год продажи
* Месяц продажи
* Наименование товара
* Сумма продаж
* Дата первой продажи
* Количество проданного
Продажи смотреть в таблице Sales.Invoices и связанных таблицах. */

SELECT YEAR(i.InvoiceDate)             AS [Год продажи],
       MONTH(i.InvoiceDate)            AS [Месяц продажи],
       si.StockItemName                AS [Наименование товара],
       SUM(il.Quantity * il.UnitPrice) AS [Сумма продаж],
       MIN(i.InvoiceDate)              AS [Дата первой продажи],
       SUM(il.Quantity)                AS [Количество проданного]
FROM Sales.Invoices       AS i
JOIN Sales.InvoiceLines   AS il ON il.InvoiceID = i.InvoiceID
JOIN Warehouse.StockItems AS si ON si.StockItemID = il.StockItemID
GROUP BY YEAR(i.InvoiceDate), MONTH(i.InvoiceDate), si.StockItemID, si.StockItemName
HAVING SUM(il.Quantity) < 50
ORDER BY [Год продажи],[Месяц продажи],[Наименование товара];

-- Опционально
-- Написать этот запрос так, чтобы если в каком-то месяце не было продаж,
-- то этот месяц также отображался бы в результатах, но там были нули:

        -- I вариант(нули будут в месяцах где совсем не было продаж)
DROP TABLE IF EXISTS #t;
DROP TABLE IF EXISTS #sales;

SELECT DISTINCT YEAR(i.InvoiceDate)   AS YearNumber,
                     m.Months         AS MonthNumber
INTO #t  -- календарь месяцев
FROM Sales.Invoices as i
CROSS JOIN (VALUES (1),(2),(3),(4),(5),(6),
                   (7),(8),(9),(10),(11),(12)) AS m(Months);

SELECT YEAR(i.InvoiceDate)             AS InvoiceYear,
       MONTH(i.InvoiceDate)            AS InvoiceMonth,
       si.StockItemName                AS ItemName,
       SUM(il.Quantity * il.UnitPrice) AS InvoiceSum,
       MIN(i.InvoiceDate)              AS InvoiceFirstDate,
       SUM(il.Quantity)                AS QuantitySum
INTO #sales  -- продажи
FROM Sales.Invoices       AS i
JOIN Sales.InvoiceLines   AS il ON il.InvoiceID = i.InvoiceID
JOIN Warehouse.StockItems AS si ON si.StockItemID = il.StockItemID
GROUP BY YEAR(i.InvoiceDate), MONTH(i.InvoiceDate), si.StockItemID, si.StockItemName

SELECT t.YearNumber              AS [Год продажи],
       t.MonthNumber             AS [Месяц продажи],
       ISNULL(s.ItemName,'-')    AS [Наименование товара],
       COALESCE(s.InvoiceSum, 0) AS [Сумма продаж],
       s.InvoiceFirstDate        AS [Дата первой продажи],
       ISNULL(s.QuantitySum,0)   AS [Количество проданного]
FROM          #t AS t
LEFT JOIN #sales AS s ON s.InvoiceYear = t.YearNumber
                     AND s.InvoiceMonth = t.MonthNumber
WHERE ISNULL(s.QuantitySum,0) < 50
ORDER BY [Год продажи],[Месяц продажи]

DROP TABLE IF EXISTS #t;
DROP TABLE IF EXISTS #sales;

        -- II вариант(нули будут в месяцах где не было продаж по какому-либо товару)
DROP TABLE IF EXISTS #t;
DROP TABLE IF EXISTS #sales;

SELECT DISTINCT YEAR(i.InvoiceDate)   AS YearNumber,
                     m.Months         AS MonthNumber,
                     si.StockItemID   AS ItemID,
                     si.StockItemName AS ItemName
INTO #t  -- таблица всех товаров
FROM Sales.Invoices as i
CROSS JOIN (VALUES (1),(2),(3),(4),(5),(6),
                   (7),(8),(9),(10),(11),(12)) AS m(Months)
CROSS JOIN Warehouse.StockItems AS si;

SELECT YEAR(i.InvoiceDate)             AS InvoiceYear,
       MONTH(i.InvoiceDate)            AS InvoiceMonth,
       il.StockItemID                  AS ItemID,
       SUM(il.Quantity * il.UnitPrice) AS InvoiceSum,
       MIN(i.InvoiceDate)              AS InvoiceFirstDate,
       SUM(il.Quantity)                AS QuantitySum
INTO #sales  -- таблица всех продаж
FROM Sales.Invoices       AS i
JOIN Sales.InvoiceLines   AS il ON il.InvoiceID = i.InvoiceID
GROUP BY YEAR(i.InvoiceDate), MONTH(i.InvoiceDate), il.StockItemID

SELECT t.YearNumber              AS [Год продажи],
       t.MonthNumber             AS [Месяц продажи],
       t.ItemName                AS [Наименование товара],
       COALESCE(s.InvoiceSum, 0) AS [Сумма продаж],
       s.InvoiceFirstDate        AS [Дата первой продажи],
       ISNULL(s.QuantitySum,0)   AS [Количество проданного]
FROM          #t AS t
LEFT JOIN #sales AS s ON s.InvoiceYear = t.YearNumber
                     AND s.InvoiceMonth = t.MonthNumber
                     AND s.ItemID = t.ItemID
WHERE ISNULL(s.QuantitySum,0) < 50 
ORDER BY [Год продажи],[Месяц продажи],[Количество проданного],[Сумма продаж],[Наименование товара];

DROP TABLE IF EXISTS #t;
DROP TABLE IF EXISTS #sales;