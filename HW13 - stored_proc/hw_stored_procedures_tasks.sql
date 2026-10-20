/*
                                     Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "Хранимые процедуры, функции, триггеры, курсоры".
Задания выполняются с использованием базы данных WideWorldImporters.                                                             */
----------------------------------------------------------------------------------------------
-- Во всех заданиях написать хранимую процедуру/функцию и продемонстрировать ее использование.
----------------------------------------------------------------------------------------------

USE WideWorldImporters;

/*------------------------------------------------------------------------
1) Написать функцию, возвращающую Клиента с наибольшей суммой покупки.  */
--------------------------------------------------------------------------

--1 --если нужна функция, возвращающая только ID клиента, то 
--создадим скалярную функцию:
CREATE OR ALTER FUNCTION Sales.fn_MaxPurchaseCustomerID
()
RETURNS int
AS
BEGIN
	-- Declare the return variable here
	DECLARE @CustomerId int;

	-- Add the T-SQL statements to compute the return value here
	SELECT TOP (1) @CustomerId = c.CustomerID
	FROM Sales.Customers     AS c
	JOIN Sales.Invoices      AS i ON i.CustomerID = c.CustomerID
	JOIN Sales.InvoiceLines AS il ON il.InvoiceID = i.InvoiceID
	GROUP BY c.CustomerID
	ORDER BY SUM(il.ExtendedPrice) DESC; -- ExtendedPrice= UnitPrice*Quantity+TaxAmount

	-- Return the result of the function
	RETURN @CustomerId;
END;
GO

-- так можем её вызвать:
SELECT Sales.fn_MaxPurchaseCustomerID() AS TopCustomerID; 
GO


--2 --если нужна функция, возвращающая и клиента, и его сумму покупки,
--тогда создадим inline табличную функцию:
CREATE OR ALTER FUNCTION Sales.fn_CustomerWithMaxPurchaseTotal
()
RETURNS TABLE 
AS
RETURN 
(
	-- Add the SELECT statement with parameter references here
	SELECT TOP (1) WITH TIES c.CustomerID,
                             c.CustomerName,
	 SUM(il.ExtendedPrice)  AS MaxPurchaseTotal -- ExtendedPrice = цена*количество+налог
	FROM Sales.Customers    AS c
	JOIN Sales.Invoices     AS i  ON i.CustomerID = c.CustomerID
	JOIN Sales.InvoiceLines AS il ON il.InvoiceID = i.InvoiceID
	GROUP BY c.CustomerID, c.CustomerName
	ORDER BY MaxPurchaseTotal DESC
);
GO

-- так можем её вызвать:
SELECT *
FROM Sales.fn_CustomerWithMaxPurchaseTotal(); 
GO



/*--------------------------------------------------------------------------------------------------------
2) Написать хранимую процедуру с входящим параметром СustomerID, выводящую сумму покупки по этому клиенту.
Использовать таблицы : Sales.Customers, Sales.Invoices, Sales.InvoiceLines                              */
----------------------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE Sales.usp_PurchaseCustomer
	@CustomerID INT,
	@PurchaseSum DECIMAL(18,2) OUTPUT    -- итоговая сумма всех покупок
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SET @PurchaseSum = 0;

	IF NOT EXISTS
	(
		select 1
		from Sales.Customers
		where CustomerID = @CustomerID
	)
	 THROW 50000, 'Customer was not found.', 1; 

    -- Insert statements for procedure here
	SELECT @PurchaseSum = ISNULL(SUM(il.ExtendedPrice), 0)
	FROM Sales.Invoices      AS i 
	JOIN Sales.InvoiceLines  AS il ON il.InvoiceID = i.InvoiceID
	WHERE i.CustomerID = @CustomerID;
END;
GO

-- так можем её вызвать:
DECLARE @TotalSum DECIMAL(18,2);
EXEC Sales.usp_PurchaseCustomer
	@CustomerID = 996,     -- передаём идентификатор клиента      
	@PurchaseSum = @TotalSum OUTPUT;
SELECT @TotalSum AS total; -- получаем сумму покупок этого клиента
-- и так:
EXEC Sales.usp_PurchaseCustomer
	@CustomerID = 0, -- если передадим несуществующий идентификатор,
	@PurchaseSum = @TotalSum OUTPUT; -- получим сообщение об ошибке
	SELECT @TotalSum


/*------------------------------------------------------------------------------------------------------------
3) Создать одинаковую функцию и хранимую процедуру, посмотреть в чем разница в производительности и почему. */
--------------------------------------------------------------------------------------------------------------
CREATE OR ALTER FUNCTION Sales.fn_CustomerWithMaxOrderTotal     -- inline табличная функция 
()
RETURNS TABLE 
AS
RETURN 
(
	-- Add the SELECT statement with parameter references here
	SELECT TOP (10) WITH TIES         c.CustomerID,
                                      c.CustomerName,
	 SUM(ol.UnitPrice * ol.Quantity) AS MaxOrderTotal 
	FROM Sales.Customers    AS c
	JOIN Sales.Orders     AS o  ON o.CustomerID = c.CustomerID
	JOIN Sales.OrderLines AS ol ON ol.OrderID = o.OrderID
	GROUP BY c.CustomerID, c.CustomerName
	ORDER BY MaxOrderTotal DESC
);
GO


CREATE OR ALTER PROCEDURE Sales.usp_CustomerWithMaxOrderTotal   -- хранимая процедура

AS
BEGIN 
    SET NOCOUNT ON;

	-- Add the SELECT statement with parameter references here
	SELECT TOP (10) WITH TIES         c.CustomerID,
                                      c.CustomerName,
	 SUM(ol.UnitPrice * ol.Quantity) AS MaxOrderTotal
	FROM Sales.Customers    AS c
	JOIN Sales.Orders     AS o  ON o.CustomerID = c.CustomerID
	JOIN Sales.OrderLines AS ol ON ol.OrderID = o.OrderID
	GROUP BY c.CustomerID, c.CustomerName
	ORDER BY MaxOrderTotal DESC
END;
GO

-- вызываем функцию
SELECT * FROM Sales.fn_CustomerWithMaxOrderTotal(); 

-- вызываем процедуру
EXEC Sales.usp_CustomerWithMaxOrderTotal; 

--и сравниваем время выполнения:
--TVF: CPU time = 156 ms,  elapsed time = 157 ms  - файл task3_inlineTVF.rpt
--USP: CPU time = 219 ms,  elapsed time = 237 ms  - файл task3_storedProc.rpt
/*
Inline-функция — это «прозрачный» объект. 
Когда пишем SELECT * FROM dbo.MyFunction() WHERE ..., 
то SQL Server буквально подставляет тело функции в запрос. 
В результате он может использовать все доступные индексы, 
статистику и фильтры внешнего запроса, 
чтобы построить один общий, максимально эффективный план выполнения.

Хранимая процедура — это «изолированный» объект. 
Она компилируется и кэшируется отдельно. 
Когда выполняем EXEC dbo.MyProcedure, 
то SQL Server выполняет её по собственному плану, 
не зная, как результат процедуры будет использоваться снаружи. 
При вызове извне она воспринимается как «чёрный ящик», 
эта изоляция может привести к менее оптимальному плану.

Даже на 10 полученных записях уже заметно отставание по времени ХП от ТФ,
а при увеличении количества записей (ТОР 100...ТОР 500) 
-- разница по времени будет увеличиваться.                             */



/*--------------------------------------------------------------------------------------------------------------------
4) Создайте табличную функцию и покажите как ее можно вызвать для каждой строки result set'а без использования цикла. */
----------------------------------------------------------------------------------------------------------------------
CREATE OR ALTER FUNCTION Sales.fn_OrdersCustomer
(
	@CustomerID INT 
)
RETURNS TABLE  -- 2 последних заказа клиента
AS
RETURN
(
    -- Add the SELECT statement with parameter references here
    SELECT TOP(2) *
    FROM Sales.Orders
    WHERE CustomerID = @CustomerID	
    ORDER BY OrderDate DESC, OrderID DESC
);
GO

-- I способ вызова для каждой строки/каждого клиента (APPLY) --
SELECT c.CustomerID,
       c.CustomerName,
       f.OrderID,
       f.OrderDate
FROM Sales.Customers AS c
OUTER APPLY Sales.fn_OrdersCustomer(c.CustomerID) AS f
ORDER BY c.CustomerID, f.OrderDate DESC;  
GO

-- II способ вызова для каждой строки/каждого клиента (CURSOR) --
CREATE TABLE #CustomerLastTwoOrders
(
    CustomerID     INT,      
    CustomerName   NVARCHAR(100),
	OrderID        INT,
	OrderDate      DATE          
);

DECLARE @CustomerID INT,
        @CustomerName NVARCHAR(100);

DECLARE CustomerCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT CustomerID, CustomerName
    FROM Sales.Customers
    ORDER BY CustomerID;

OPEN CustomerCursor;

FETCH NEXT FROM CustomerCursor 
INTO @CustomerID, @CustomerName;

WHILE @@FETCH_STATUS = 0
BEGIN
    INSERT INTO #CustomerLastTwoOrders (CustomerID, CustomerName, OrderID, OrderDate)
    SELECT @CustomerID, @CustomerName, fn.OrderID, fn.OrderDate
    FROM Sales.fn_OrdersCustomer(@CustomerID) fn;

    FETCH NEXT FROM CustomerCursor 
	INTO @CustomerID, @CustomerName;
END;

CLOSE CustomerCursor;
DEALLOCATE CustomerCursor;

SELECT *                    -- получаем тот же результат
FROM #CustomerLastTwoOrders
ORDER BY CustomerID, OrderDate DESC;

DROP TABLE #CustomerLastTwoOrders;



/*----------------------------------------------------------------------------------------------------------
5) Опционально. Во всех процедурах укажите какой уровень изоляции транзакций вы бы использовали и почему. */
------------------------------------------------------------------------------------------------------------
/*
В текущей учебной ситуации -
READ UNCOMMITTED (или WITH (NOLOCK)) — самый быстрый для чистого чтения, 
и в моей ситуации он безопасен, потому что «грязных чтений» физически не может быть( писать в базу больше некому).

А в рабочей многопользовательской среде
я бы использовала SNAPSHOT (или READ COMMITTED SNAPSHOT, если в базе включён READ_COMMITTED_SNAPSHOT ON).

Почему:
- Обе Процедуры только читают данные из трёх таблиц и считают агрегат. Запись не выполняется.
- Нужен согласованный срез данных: если во время выполнения кто-то добавляет или меняет счета/заказы, сумма не должна «прыгать» между строками.
- SNAPSHOT даёт чтение на момент начала транзакции/оператора и не ставит shared-блокировки на Invoices/InvoiceLines/Orders/OrderLines, то есть не блокирует OLTP-нагрузку.
- READ UNCOMMITTED / NOLOCK использовать не стоит — возможны грязные чтения и неверная сумма.
- SERIALIZABLE здесь избыточен: он бы взял range-блокировки и сильнее мешал бы работе.
- Если база не настроена для snapshot-изоляции, для такого простого чтения достаточно дефолтного READ COMMITTED. 
- Но для отчётной процедуры SNAPSHOT предпочтительнее, особенной для финансовой.