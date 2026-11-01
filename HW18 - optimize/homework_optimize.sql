/*
                              Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "Популярные Hint'ы и подсказки оптимизатору".
Задания выполняются с использованием базы данных WideWorldImporters.                                                      */
-- -------------------------------------------------------------------------------------------------------------------------
-- Оптимизируем запрос
-- Цель:
-- проанализировать и улучшить производительность запроса путем рефакторинга, пересмотра соединений и условий фильтрации.
-- --------------------------------------------------------------------------------------------------------------------------
                                       
USE WideWorldImporters;

------------------------------------------------------------------------------------------------------------------------------
-- Оптимизируйте запрос по БД WorldWideImporters.
-- Приложите текст запроса со статистиками по времени и операциям ввода вывода, опишите кратко ход рассуждений при оптимизации.
------------------------------------------------------------------------------------------------------------------------------

Select ord.CustomerID, det.StockItemID, SUM(det.UnitPrice), SUM(det.Quantity), COUNT(ord.OrderID)    
FROM Sales.Orders AS ord
    JOIN Sales.OrderLines AS det
        ON det.OrderID = ord.OrderID
    JOIN Sales.Invoices AS Inv 
        ON Inv.OrderID = ord.OrderID
    JOIN Sales.CustomerTransactions AS Trans
        ON Trans.InvoiceID = Inv.InvoiceID
    JOIN Warehouse.StockItemTransactions AS ItemTrans
        ON ItemTrans.StockItemID = det.StockItemID
WHERE Inv.BillToCustomerID != ord.CustomerID
    AND (Select SupplierId
         FROM Warehouse.StockItems AS It
         Where It.StockItemID = det.StockItemID) = 12
    AND (SELECT SUM(Total.UnitPrice*Total.Quantity)
        FROM Sales.OrderLines AS Total
            Join Sales.Orders AS ordTotal
                On ordTotal.OrderID = Total.OrderID
        WHERE ordTotal.CustomerID = Inv.CustomerID) > 250000
    AND DATEDIFF(dd, Inv.InvoiceDate, ord.OrderDate) = 0
GROUP BY ord.CustomerID, det.StockItemID
ORDER BY ord.CustomerID, det.StockItemID;

/*
JOIN Sales.CustomerTransactions и JOIN Warehouse.StockItemTransactions — их колонки не используются ни в SELECT, ни в WHERE. 
Но это INNER JOIN, значит:
они размножают строки (у одного счёта может быть несколько транзакций, у товара — десятки транзакций);
из-за размножения SUM(det.UnitPrice), SUM(det.Quantity), COUNT(ord.OrderID) завышены — результат исходного запроса просто некорректен;
они лишние по смыслу (если нужна была проверка существования — надо EXISTS).

Скалярный подзапрос (SELECT SupplierId FROM Warehouse.StockItems WHERE StockItemID = det.StockItemID) = 12 
— это коррелированный подзапрос, который выполняется на каждую строку. Нужно просто JOIN + фильтр It.SupplierID = 12.

Коррелированный подзапрос с SUM(UnitPrice*Quantity) > 250000 — пересчитывается на каждую строку внешнего запроса, 
хотя результат зависит только от Inv.CustomerID (т.е. от клиента). Нужно один раз посчитать в CTE и соединить.

DATEDIFF(dd, Inv.InvoiceDate, ord.OrderDate) = 0 —  DATEDIFF по колонке мешает использовать индекс по OrderDate/InvoiceDate. 
В WideWorldImporters обе колонки — тип date, значит эквивалентно Inv.InvoiceDate = ord.OrderDate. 

Нет хватает индексов под соединения/фильтры                                                                                   */


--1	Убраны CustomerTransactions и StockItemTransactions	Не влияют на SELECT/WHERE, только плодят строки → искажают агрегаты и тормозят
--2	Скалярный подзапрос SupplierId → JOIN Warehouse.StockItems	Один раз соединяем по индексу PK, вместо подзапроса на каждую строку
--3	Коррелированный SUM(...) > 250000 → CTE CustomerTotals	Считаем один раз на клиента, а не на каждую строку; HAVING фильтрует сразу
--4	DATEDIFF(dd, Inv.InvoiceDate, ord.OrderDate) = 0 → Inv.InvoiceDate = ord.OrderDate	Стало SARGable → индекс по датам работает
--5 Созданы недостающие индексы:

-- Ускоряет JOIN Invoice → Order и фильтр по датам
    CREATE INDEX IX_Invoices_OrderID
    ON Sales.Invoices (OrderID)
    INCLUDE (CustomerID, BillToCustomerID, InvoiceDate);

-- Ускоряет агрегаты по строкам заказов
    CREATE INDEX IX_OrderLines_OrderID
    ON Sales.OrderLines (OrderID)
    INCLUDE (StockItemID, UnitPrice, Quantity);

-- Ускоряет фильтр по поставщику (StockItems маленькая, но не помешает)
   CREATE INDEX IX_StockItems_SupplierID
    ON Warehouse.StockItems (SupplierID)
   INCLUDE (StockItemID);

-- Для CTE CustomerTotal
   CREATE INDEX IX_Orders_CustomerID
    ON Sales.Orders (CustomerID)
   INCLUDE (OrderID, OrderDate);

-- более оптимальный запрос:-------------------------------------------------------------------------                   

;WITH CustomerTotals AS
(
    SELECT
        o.CustomerID,
        SUM(ol.UnitPrice * ol.Quantity) AS TotalPurchase
    FROM Sales.Orders AS o
    JOIN Sales.OrderLines AS ol ON ol.OrderID = o.OrderID
    GROUP BY o.CustomerID
    HAVING SUM(ol.UnitPrice * ol.Quantity) > 250000
)
SELECT
    ord.CustomerID,
    det.StockItemID,
    SUM(det.UnitPrice)  AS SumUnitPrice,
    SUM(det.Quantity)   AS SumQuantity,
    COUNT(ord.OrderID)  AS OrderCount
FROM Sales.Orders AS ord
JOIN Sales.OrderLines  AS det ON det.OrderID = ord.OrderID
JOIN Sales.Invoices    AS Inv ON Inv.OrderID = ord.OrderID
JOIN Warehouse.StockItems AS It ON It.StockItemID = det.StockItemID
JOIN CustomerTotals    AS ct  ON ct.CustomerID = Inv.CustomerID
WHERE Inv.BillToCustomerID <> ord.CustomerID
  AND It.SupplierID = 12
  AND ord.OrderDate = Inv.InvoiceDate         
GROUP BY ord.CustomerID, det.StockItemID
ORDER BY ord.CustomerID, det.StockItemID;

--query1 Время ЦП = 1000 мс, затраченное время = 1116 мс              файл before_optimization.rpt
--      "Orders": Сканирований 2,     логических операций чтения 883
--    "Invoices": Сканирований 15856, логических операций чтения 82365

--query2 Время ЦП = 110 мс, затраченное время = 179 мс.               файл after_optimization.rpt
--      "Orders": Сканирований 2, логических операций чтения 326
--    "Invoices": Сканирований 1, логических операций чтения 226

