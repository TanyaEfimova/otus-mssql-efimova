/*
                              Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "Динамический SQL".
Задания выполняются с использованием базы данных WideWorldImporters.                                               */
-- ---------------------------------------------------------------------------
-- Задание - написать выборки для получения указанных ниже данных.
-- ---------------------------------------------------------------------------

USE WideWorldImporters;

/*-------------------------------------------------------------------------------------------------
Это задание из занятия "Операторы CROSS APPLY, PIVOT, UNPIVOT."
Нужно для него написать динамический PIVOT, отображающий результаты по всем клиентам.
Имя клиента указывать полностью из поля CustomerName.
Требуется написать запрос, который в результате своего выполнения 
формирует сводку по количеству покупок в разрезе клиентов и месяцев.
В строках должны быть месяцы (дата начала месяца), в столбцах - клиенты.
Дата должна иметь формат dd.mm.yyyy, например, 25.12.2019.

Пример, как должны выглядеть результаты:
-------------+--------------------+--------------------+----------------+----------------------
InvoiceMonth | Aakriti Byrraju    | Abel Spirlea       | Abel Tatarescu | ... (другие клиенты)
-------------+--------------------+--------------------+----------------+----------------------
01.01.2013   |      3             |        1           |      4         | ...
01.02.2013   |      7             |        3           |      4         | ...
-------------+--------------------+--------------------+----------------+----------------------  */


-- 1 --------------- с помощью инструкции EXEC --------------------------------------------------

-- отладка запроса
SELECT *
FROM
(
	SELECT FORMAT(DATETRUNC(month, i.InvoiceDate),'dd.MM.yyyy')        
	    AS InvoiceMonth, 
	     c.CustomerName,
	     i.InvoiceID
	FROM Sales.Customers c
	JOIN Sales.Invoices  i ON i.CustomerID = c.CustomerID
) AS src
PIVOT
(
	COUNT(InvoiceID)
	FOR CustomerName IN ([Tailspin Toys (Head Office)],[Tailspin Toys (Sylvanite, MT)])
) AS pvt
ORDER BY CAST(InvoiceMonth AS DATE);


-- определение переменных
DECLARE @Columns NVARCHAR(MAX), 
		@Query NVARCHAR(MAX),
		@AreAllCustomers INT = 1; -- если нужны цифры по всем имеющимся клиентам
--		                       0; -- если нужны цифры по всем тем клиентам, которые что-либо покупали

-- занесение списка имён столбцов в переменную @Columns
IF @AreAllCustomers = 1
	SELECT @Columns = STRING_AGG(CAST(QUOTENAME(CustomerName) AS NVARCHAR(MAX)), ',')
	FROM Sales.Customers;  
	
IF @AreAllCustomers = 0
	SELECT @Columns = STRING_AGG(CAST(QUOTENAME(CustomerName) AS NVARCHAR(MAX)), ',')
	FROM (select distinct c.CustomerName 
		  from Sales.Customers c  
		  join Sales.Invoices  i on i.CustomerID = c.CustomerID) AS CN;  
                       
-- проверка корректности списка столбцов
SELECT CAST(@Columns AS XML) as Cln;

-- проверка целесобразности запроса(если список пуст)
IF @Columns IS NULL OR @Columns = N''
	BEGIN
		PRINT N'Имена столбцов не найдены!';
		RETURN;
	END;

-- занесение запроса в переменную
SET @Query = N'
SELECT *
FROM
(
	SELECT FORMAT(DATETRUNC(month, i.InvoiceDate),''dd.MM.yyyy'')        
	    AS InvoiceMonth, 
	     c.CustomerName,
	     i.InvoiceID
	FROM Sales.Customers c
	JOIN Sales.Invoices  i ON i.CustomerID = c.CustomerID
) AS src
PIVOT
(
	COUNT(InvoiceID)
	FOR CustomerName IN (' + @Columns + N')
) AS pvt
ORDER BY CAST(InvoiceMonth AS DATE);';

-- вывод на экран запроса(для проверки)
PRINT @Query;

-- выполнение запроса
EXEC(@Query);

-- 2 --------------- с помощью процедуры sp_executesql ------------------------------------------

-- определяем переменные
DECLARE @QuerySQL NVARCHAR(MAX),
		@ColumnsList NVARCHAR(MAX),
		@FirstId INT, @LastId INT;

-- если нужны определённые клиенты
SET @QuerySQL = N'
SELECT @Fields = STRING_AGG(CAST(QUOTENAME(CustomerName) AS NVARCHAR(MAX)), N'','')
FROM Sales.Customers
WHERE CustomerID >= @From AND CustomerID <= @To;'

-- то определяем значения фильтра(например,как в прошлом ДЗ)
SET @FirstId = 2;
SET @LastId  = 6;

-- передаём все нужные параметры в ХП и выполняем, получая список столбцов
EXEC sp_executesql @QuerySQL, N'@From int, @To int, @Fields nvarchar(max) output',
                   @From   = @FirstId,
				   @To     = @LastId,
				   @Fields = @ColumnsList OUTPUT;

-- проверка списка на пустоту
IF @ColumnsList IS NULL OR @ColumnsList = N''
	BEGIN
		PRINT N'Имена столбцов не найдены!';
		RETURN;
	END;

-- вывод на экран получившегося списка
PRINT @ColumnsList;

-- если нужен диапазон дат...
SET @QuerySQL = N'
SELECT FORMAT(StartMonth,''dd.MM.yyyy'') 
       AS InvoiceMonth, ' + @ColumnsList + N' 
FROM
(
	SELECT DATETRUNC(month, i.InvoiceDate)  
	    AS StartMonth, 
	     c.CustomerName,
	     i.InvoiceID
	FROM Sales.Customers c
	JOIN Sales.Invoices  i ON i.CustomerID = c.CustomerID
	WHERE i.InvoiceDate >= @start AND i.InvoiceDate <= @finish
) AS src
PIVOT
(
	COUNT(InvoiceID)
	FOR CustomerName IN (' + @ColumnsList + N')
) AS pvt
ORDER BY StartMonth;';

-- то определяем значения фильтра
DECLARE @FirstDate DATE, @LastDate DATE;
SET @FirstDate = '2015-01-01';
SET @LastDate  = '2015-12-31';

-- вывод на экран текста запроса
PRINT @QuerySQL;

-- передаём все нужные параметры в ХП и выполняем итоговый запрос
EXEC sp_executesql @QuerySQL, N'@start date, @finish date',
                   @start  = @FirstDate,
				   @finish = @LastDate;