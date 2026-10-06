/*
                              Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "06 - Оконные функции".
Задания выполняются с использованием базы данных WideWorldImporters.                                               */
-- ---------------------------------------------------------------------------
-- Задание - написать выборки для получения указанных ниже данных.
-- Опционально можете для каждого запроса без оконных функций 
--             сделать вариант запросов с оконными функциями 
--           и сравнить их производительность. 
-- ---------------------------------------------------------------------------

USE WideWorldImporters;

/*-------------------------------------------------------------------------------------------
1. Сделать расчет суммы продаж нарастающим итогом по месяцам с 2015 года 
(в рамках одного месяца он будет одинаковый, нарастать будет в течение времени выборки).
Выведите: id продажи, название клиента, дату продажи, сумму продажи, сумму нарастающим итогом

Пример:
-------------+----------------------------
Дата продажи | Нарастающий итог по месяцу
-------------+----------------------------
 2015-01-29  | 4801725.31
 2015-01-30	 | 4801725.31
 2015-01-31	 | 4801725.31
 2015-02-01	 | 9626342.98
 2015-02-02	 | 9626342.98
 2015-02-03	 | 9626342.98
Продажи можно взять из таблицы Invoices.
Нарастающий итог должен быть без оконной функции.                                    */

DROP TABLE IF EXISTS #MonthlyData;

SELECT i.InvoiceID,
       c.CustomerName,
       i.InvoiceDate,
       100 * YEAR(i.InvoiceDate) + MONTH(i.InvoiceDate) AS MonthNumber,
       t.TransactionAmount
INTO #MonthlyData  -- временная таблица с данными за месяц
FROM Sales.Invoices             i
JOIN Sales.CustomerTransactions t ON t.InvoiceID  = i.InvoiceID
JOIN Sales.Customers            c ON c.CustomerID = i.CustomerID
WHERE i.InvoiceDate >= '2015-01-01';

DROP TABLE IF EXISTS #MonthTotals;

SELECT MonthNumber, SUM(TransactionAmount) AS MonthlyTotal
INTO #MonthTotals --временная таблица с суммами за месяц
FROM #MonthlyData
GROUP BY MonthNumber;

SELECT md.InvoiceID         AS [Id продажи],
       md.CustomerName      AS [Название клиента],
       md.InvoiceDate       AS [Дата продажи],
       md.TransactionAmount AS [Сумма продажи],
       (
		select sum(MonthlyTotal) 
		from #MonthTotals 
		where MonthNumber <= md.MonthNumber
	   )                    AS [Нарастающий итог по месяцу]
FROM #MonthlyData md
ORDER BY [Дата продажи],[Id продажи];

DROP TABLE IF EXISTS #MonthTotals;
DROP TABLE IF EXISTS #MonthlyData;

/*-----------------------------------------------------------------------------------------
2. Сделайте расчет суммы нарастающим итогом в предыдущем запросе с помощью оконной функции.
   Сравните производительность запросов 1 и 2 с помощью set statistics time, io on    */

SELECT InvoiceID         AS [Id продажи],
       CustomerName      AS [Название клиента],
       InvoiceDate       AS [Дата продажи],
       TransactionAmount AS [Сумма продажи],
   SUM(TransactionAmount) OVER (ORDER BY MonthNumber) AS [Нарастающий итог по месяцу]
FROM 
(
	select i.InvoiceID,		   
			i.InvoiceDate,
			100 * year(i.InvoiceDate) + month(i.InvoiceDate) as MonthNumber,
			t.TransactionAmount,
			c.CustomerName
	from Sales.Invoices i
	JOIN Sales.CustomerTransactions t on t.InvoiceID = i.InvoiceID
	JOIN Sales.Customers c            on c.CustomerID = i.CustomerID
	where i.InvoiceDate >= '2015-01-01'
) AS MonthlyData
ORDER BY [Дата продажи],[Id продажи];

-- query 1: CPU time = 4311 ms,  elapsed time = 1953 ms, logical reads 33293  (файл task1_without_windowFunc.rpt)
-- query 2: CPU time = 922 ms,   elapsed time = 2058 ms, logical reads 68286  (файл task2_with_windowFunc.rpt)

-- в запросе с временными таблицами сначала подготавливаются/фильтруются/группируются данные, прежде чем вычислять нарастающий итог,
-- а оконная функция СРАЗУ же приступает к вычислению нарастающего итога, 
-- беря сразу все строки и делая одну большую операцию сортировки + один проход агрегации (в отличие от многошаговости первого запроса),
-- и это ей даёт преимущество в процессорном времени (922 вместо 4311), 
-- и несильно сказывается на общем времени выполнения(2058 вместо 1953), несмотря на 2х-кратное увеличение количества чтений(68286 вместо 33293).


/*----------------------------------------------------------------------------------
3. Вывести список 2х самых популярных продуктов (по количеству проданных) 
в каждом месяце за 2016 год (по 2 самых популярных продукта в каждом месяце). */

--1----- если считать популярность по количеству проданных единиц продукта:
------------------ query 1 (без ОФ) ---------------------------------------
;WITH cte_sales AS 
(
    select month(i.InvoiceDate) as SaleMonth,
                si.StockItemName,
            sum(il.Quantity)    as TotalQty
    from Sales.InvoiceLines   il
    join Sales.Invoices        i on il.InvoiceID   = i.InvoiceID
    join Warehouse.StockItems si on il.StockItemID = si.StockItemID
    where i.InvoiceDate >= '2016-01-01' and i.InvoiceDate < '2017-01-01'
    group by month(i.InvoiceDate), si.StockItemName           
),
cte_counts AS 
(
    select s1.SaleMonth,
           s1.StockItemName,
           s1.TotalQty,
    count(s2.StockItemName) as BetterCount  -- сколько продуктов, у которых продано больше
    from      cte_sales s1
    left join cte_sales s2 on s1.SaleMonth = s2.SaleMonth 
                          and s2.TotalQty  > s1.TotalQty
    group by s1.SaleMonth, s1.StockItemName, s1.TotalQty 
)
SELECT SaleMonth  AS [Месяц],
    StockItemName AS [Продукт],
    TotalQty      AS [Проданное кол-во за месяц]
FROM cte_counts
WHERE BetterCount < 2  -- если таких меньше 2, значит мы в топ-2
ORDER BY [Месяц], [Проданное кол-во за месяц] DESC;

------------------ query 2 (с ОКОННОЙ) ------------------------------------
;WITH cte_sales AS 
(
    select month(i.InvoiceDate) as SaleMonth,
                si.StockItemName,
            sum(il.Quantity)    as TotalQty
    from Sales.InvoiceLines   il
    join Sales.Invoices        i on il.InvoiceID   = i.InvoiceID
    join Warehouse.StockItems si on il.StockItemID = si.StockItemID
    where i.InvoiceDate >= '2016-01-01' and i.InvoiceDate < '2017-01-01'
    group by month(i.InvoiceDate), si.StockItemName           
),
cte_ranking AS -- присваиваем ранги продуктам (в рамках каждого месяца)
(                 
    select SaleMonth as     [Месяц],
           StockItemName as [Продукт],
           TotalQty as      [Проданное кол-во за месяц],
           row_number() over(partition by SaleMonth order by TotalQty desc) as [Ранг]
    from cte_sales
)
SELECT [Месяц],[Продукт],[Проданное кол-во за месяц]
FROM cte_ranking
WHERE [Ранг] <= 2  -- для топ-2 берём с рангом 1 и 2
ORDER BY 1, 3 DESC;

-- query 1: CPU time = 704 ms,  elapsed time = 6725 ms, logical reads 58:      (файл task3_1_query1_without_windowFunc.rpt)
          --InvoiceLines - scan count 4, lob logical reads 504, segment reads 2
		  --Invoices -     scan count 2,     logical reads 46
		  --StockItems -   scan count 2,     logical reads 12

-- query 2: CPU time = 94 ms,   elapsed time = 106 ms,  logical reads 29:      (файл task3_1_query2_with_windowFunc.rpt)
          --InvoiceLines - scan count 2, lob logical reads 342, segment reads 1
		  --Invoices -     scan count 1,     logical reads 23
		  --StockItems -   scan count 1,     logical reads 6

-- исходя из данных показателей, замечаем такие улучшения: 
-- время ЦП сократилось в ~7.5 раз, общее время в ~63.4 раза,
-- число сканирований и логических чтений снизилось в ~2 раза,
-- по которым мы видим явное преимущество использования оконной функции

--2----- если считать популярность по количеству проданных раз продукта:
------------------ query 1 (без ОФ) ------------------------------------
;WITH cte_sales AS 
(
    select month(i.InvoiceDate)         as SaleMonth,
                                        si.StockItemName,
           count(distinct il.InvoiceID) as SalesCount   
    from Sales.InvoiceLines   il
    join Sales.Invoices        i on il.InvoiceID   = i.InvoiceID
    join Warehouse.StockItems si on il.StockItemID = si.StockItemID
    where i.InvoiceDate >= '2016-01-01' and i.InvoiceDate < '2017-01-01'
    group by month(i.InvoiceDate), si.StockItemName           
),
cte_counts AS 
(
    select s1.SaleMonth,
           s1.StockItemName,
           s1.SalesCount,
    count(s2.StockItemName) as BetterCount  -- сколько продуктов продано больше раз
    from      cte_sales s1
    left join cte_sales s2 on s1.SaleMonth  = s2.SaleMonth 
                          and s2.SalesCount > s1.SalesCount
    group by s1.SaleMonth, s1.StockItemName, s1.SalesCount 
)
SELECT SaleMonth  AS [Месяц],
    StockItemName AS [Продукт],
    SalesCount    AS [Кол-во продаж за месяц]
FROM cte_counts
WHERE BetterCount < 2  -- если таких меньше 2, значит мы в топ-2
ORDER BY [Месяц], [Кол-во продаж за месяц] DESC;

------------------ query 2 (с ОКОННОЙ) ------------------------------------
;WITH cte_sales AS 
(
    select month(i.InvoiceDate)         as SaleMonth,
                                        si.StockItemName,
           count(distinct il.InvoiceID) as SalesCount
    from Sales.InvoiceLines   il
    join Sales.Invoices        i on il.InvoiceID   = i.InvoiceID
    join Warehouse.StockItems si on il.StockItemID = si.StockItemID
    where i.InvoiceDate >= '2016-01-01' and i.InvoiceDate < '2017-01-01'
    group by month(i.InvoiceDate), si.StockItemName           
),
cte_ranking AS -- присваиваем ранги продуктам (в рамках каждого месяца)
(                 
    select SaleMonth as     [Месяц],
           StockItemName as [Продукт],
           SalesCount as    [Кол-во продаж за месяц],
           row_number() over(partition by SaleMonth order by SalesCount desc) as [Ранг]
    from cte_sales
)
SELECT [Месяц],[Продукт],[Кол-во продаж за месяц]
FROM cte_ranking
WHERE [Ранг] <= 2  -- для топ-2 берём с рангом 1 и 2
ORDER BY 1, 3 DESC;

-- query 1: CPU time = 828 ms,  elapsed time = 899 ms, logical reads 58:       (файл task3_2_query1_without_windowFunc.rpt)
          --InvoiceLines - scan count 4, lob logical reads 489, segment reads 2
		  --Invoices -     scan count 2,     logical reads 46
		  --StockItems -   scan count 2,     logical reads 12

-- query 2: CPU time = 156 ms,  elapsed time = 162 ms, logical reads 29:       (файл task3_2_query2_with_windowFunc.rpt)
          --InvoiceLines - scan count 2, lob logical reads 157, segment reads 1
		  --Invoices -     scan count 1,     logical reads 23
		  --StockItems -   scan count 1,     logical reads 6

-- исходя из данных показателей, замечаем такие улучшения: 
-- время ЦП и общее время сократилось в ~5.3-5.5 раз,
-- число сканирований и логических чтений снизилось, примерно, в 2 раза,
-- т.о. использование оконной функции выигрывает.


/*----------------------------------------------------------------------------------------------------------------------------
4. Функции одним запросом.
Посчитайте по таблице товаров (в вывод также должен попасть ид товара, название, брэнд и цена):
* пронумеруйте записи по названию товара, так чтобы при изменении первой буквы алфавита нумерация начиналась заново,
* посчитайте общее количество товаров и выведите полем в этом же запросе,
* посчитайте общее количество товаров в зависимости от первой буквы названия товара,
* отобразите следующий id товара исходя из того, что порядок отображения товаров по имени,
* предыдущий ид товара с тем же порядком отображения (по имени),
* названия товара 2 строки назад, в случае если предыдущей строки нет, то нужно вывести "No items"
* сформируйте 30 групп товаров по полю вес товара на 1 шт.
Для этой задачи НЕ нужно писать аналог без аналитических функций.  */

SELECT StockItemID                                   AS [Ид товара],
       StockItemName                                 AS [Название товара],
       Brand                                         AS [Бренд],
       UnitPrice                                     AS [Цена],
  ROW_NUMBER() OVER(PARTITION BY LEFT(StockItemName,1) 
                        ORDER BY StockItemName)      AS [Порядковый номер],       -- нумерация внутри первой буквы названия
  COUNT(*) OVER()                                    AS [Общее кол-во],           -- общее количество товаров
  COUNT(*) OVER(PARTITION BY LEFT(StockItemName, 1)) AS [Кол-во на эту букву],    -- количество товаров с той же первой буквой
  LEAD(StockItemID) OVER(ORDER BY StockItemName)     AS [Следующий Ид товара],    -- следующий ID по алфавиту
  LAG (StockItemID) OVER(ORDER BY StockItemName)     AS [Предыдущий Ид товара],   -- предыдущий ID по алфавиту
  LAG (StockItemName,2,'No items') OVER(ORDER BY StockItemName) AS [Товар ранее], -- название на 2 строки назад
  NTILE(30) OVER(ORDER BY TypicalWeightPerUnit)      AS [Номер группы]            -- 30 групп по весу товара
FROM Warehouse.StockItems
ORDER BY StockItemName;


/*-----------------------------------------------------------------------------------------------------------
5. По каждому сотруднику выведите последнего клиента, которому сотрудник что-то продал.
   В результатах должны быть ид и фамилия сотрудника, ид и название клиента, дата продажи, сумма сделки.  */

------------------ query 1 (без ОФ) ---------------------------------------
;WITH cte_sales AS 
(
    select i.SalespersonPersonID,
           i.CustomerID,
           i.InvoiceDate,
           i.InvoiceID,
        sum(il.Quantity * il.UnitPrice) as DealAmount
    from Sales.Invoices i
    join Sales.InvoiceLines il on i.InvoiceID = il.InvoiceID
    group by i.SalespersonPersonID, i.CustomerID, i.InvoiceDate, i.InvoiceID
)
SELECT p.PersonID     AS [Ид сотрудника],
       p.FullName     AS [Фамилия сотрудника],
       c.CustomerID   AS [Ид клиента],
       c.CustomerName AS [Название клиента],
       s.InvoiceDate  AS [Дата продажи],
       s.DealAmount   AS [Сумма сделки]
FROM          cte_sales s
JOIN Application.People p ON s.SalespersonPersonID = p.PersonID
JOIN    Sales.Customers c ON s.CustomerID = c.CustomerID
WHERE NOT EXISTS 
(
    -- ищем строку "более позднюю" для того же сотрудника
    select 1
    from cte_sales
    where SalespersonPersonID = s.SalespersonPersonID
      and (InvoiceDate > s.InvoiceDate  or  (InvoiceDate = s.InvoiceDate and InvoiceID > s.InvoiceID) )
)
ORDER BY p.PersonID;

------------------ query 2 (с ОКОННОЙ) ------------------------------------
;WITH cte_sales AS 
(
    select i.SalespersonPersonID,
           i.CustomerID,
           i.InvoiceDate,
           i.InvoiceID,
      sum(il.Quantity * il.UnitPrice)                             as DealAmount,
      row_number() over(partition by i.SalespersonPersonID 
	               order by i.InvoiceDate desc, i.InvoiceID desc) as RowNumber
    from     Sales.Invoices i
    join Sales.InvoiceLines il on i.InvoiceID = il.InvoiceID
    group by i.SalespersonPersonID, i.CustomerID, i.InvoiceDate, i.InvoiceID
)
SELECT p.PersonID     AS [Ид сотрудника],
       p.FullName     AS [Фамилия сотрудника],
       c.CustomerID   AS [Ид клиента],
       c.CustomerName AS [Название клиента],
       s.InvoiceDate  AS [Дата продажи],
       s.DealAmount   AS [Сумма сделки]
FROM cte_sales s
JOIN Application.People p ON s.SalespersonPersonID = p.PersonID
JOIN    Sales.Customers c ON s.CustomerID = c.CustomerID
WHERE s.RowNumber = 1
ORDER BY p.PersonID;

-- query 1:-- CPU time = 16843 ms, elapsed time = 16896 ms     (файл task5_query1_without_windowFunc.rpt)
           -- InvoiceLines - scan count 4, segment reads 2
		   -- Invoices     - scan count 2, logical reads 22800
		  
-- query 2:-- CPU time = 594 ms,   elapsed time = 930 ms       (файл task5_query2_with_windowFunc.rpt)
           -- InvoiceLines - scan count 2, segment reads 1
		   -- Invoices     - scan count 1, logical reads 11400
		  
-- исходя из данных показателей, замечаем такие улучшения: 
-- время ЦП сократилось в ~28 раз, общее время в ~18 раз,
-- число сканирований и логических чтений снизилось в 2 раза,
-- что является несомненным плюсом использования оконной функции


/*---------------------------------------------------------------------------------------
6. Выберите по каждому клиенту два самых дорогих товара, которые он покупал.
В результатах должно быть ид клиента, его название, ид товара, цена, дата покупки.*/

------------------ query 1 (без ОФ) ---------------------------------------
DROP TABLE IF EXISTS #Sales;

SELECT  il.InvoiceLineID,
        il.StockItemID,
		il.UnitPrice,
         i.InvoiceDate,
		 c.CustomerID,
	     c.CustomerName
INTO #Sales
FROM Sales.InvoiceLines il
JOIN Sales.Invoices      i ON il.InvoiceID = i.InvoiceID
JOIN Sales.Customers     c ON i.CustomerID = c.CustomerID;

SELECT s1.CustomerID   AS [Ид клиента],
       s1.CustomerName AS [Название клиента],
       s1.StockItemID  AS [Ид товара],
       s1.UnitPrice    AS [Цена],
       s1.InvoiceDate  AS [Дата покупки]
FROM #Sales s1
WHERE 
(
    select count(*)
    from #Sales s2
    where s2.CustomerID = s1.CustomerID
     and (s2.UnitPrice > s1.UnitPrice or (s2.UnitPrice = s1.UnitPrice and s2.InvoiceLineID < s1.InvoiceLineID))
) < 2
ORDER BY s1.CustomerID, s1.UnitPrice DESC, s1.InvoiceLineID;

DROP TABLE IF EXISTS #Sales;

------------------ query 2 (с ОКОННОЙ) ------------------------------------
;WITH cte_sales AS 
(
    select il.InvoiceLineID,
	       il.StockItemID,
		   il.UnitPrice,
            i.InvoiceDate,
		    c.CustomerID,
	        c.CustomerName,
			row_number() over(partition by c.CustomerID order by il.UnitPrice desc, il.InvoiceLineID) as RowNumber
    from Sales.InvoiceLines   il
    join Sales.Invoices        i on il.InvoiceID  = i.InvoiceID
    join Sales.Customers       c on i.CustomerID = c.CustomerID
)
SELECT CustomerID   AS [Ид клиента],
       CustomerName AS [Название клиента],
       StockItemID  AS [Ид товара],
	   UnitPrice    AS [Цена],
       InvoiceDate  AS [Дата покупки]
FROM cte_sales
WHERE RowNumber <= 2  
ORDER BY CustomerID, UnitPrice DESC, InvoiceLineID;

-- query 1:     CPU time = 144718 ms,  elapsed time = 17908 ms                  (файл task6_query1_without_windowFunc.rpt)
          --InvoiceLines - scan count 2,  lob logical reads 341, segment reads 1
		  --Invoices     - scan count 1,      logical reads 156
		  --Customers    - scan count 1,      logical reads 40
		  --#Temporary   - scan count 228279, logical reads 2186015
-- query 1
--(with index): CPU time = 113811 ms,  elapsed time = 11793 ms                  (файл task6_query1(indexed)_without_windowFunc.rpt)
          --InvoiceLines - scan count 2,  lob logical reads 341, segment reads 1
		  --Invoices     - scan count 1,      logical reads 156
		  --Customers    - scan count 1,      logical reads 40
		  --#Temporary   - scan count 228291, logical reads 1841627

-- query 2:     CPU time = 813 ms,     elapsed time = 1104 ms                   (файл task6_query2_with_windowFunc.rpt)
          --InvoiceLines - scan count 2,  lob logical reads 341, segment reads 1
		  --Invoices     - scan count 1,      logical reads 156
		  --Customers    - scan count 1,      logical reads 40

-- исходя из данных показателей, замечаем такие улучшения при использовании ОФ: 
-- время ЦП сократилось в ~178 раз, а общее время в ~16 раз
-- число сканирований и логических чтений таблиц БД не изменилось,
-- но засчёт того, что не требуются сканирования и чтения временной таблицы - их общее число колоссально снизилось,
-- даже создание кластерного индекса на полях(CustomerID, UnitPrice DESC, InvoiceLineID) временной таблицы
-- не дало такого же преимущества и оптимальности.

