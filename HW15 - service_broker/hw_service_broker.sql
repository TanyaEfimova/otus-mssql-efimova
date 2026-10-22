/*
                           Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "22 - Очереди в MS SQL Server, Service Broker".                                                             */

  USE WideWorldImporters;


/*-------------------------------------------------------------------------------------
Реализуйте очередь для БД WideWorldImporters:
Создайте очередь для формирования отчетов для клиентов по таблице Invoices. 
При вызове процедуры для создания отчета в очередь должна отправляться заявка.
При обработке очереди создавайте отчет 
    по количеству заказов (Orders) по клиенту за заданный период времени 
и складывайте готовый отчет в новую таблицу.
Проверьте, что вы корректно открываете и закрываете диалоги, и у нас они не копятся. */
---------------------------------------------------------------------------------------

-----------------------------ПОДГОТОВКА----------------------------------------------

-- создаём таблицу для отчётов
IF OBJECT_ID(N'Sales.tb_CustomersQtyOrdersReports',N'U') IS NULL
    CREATE TABLE Sales.tb_CustomersQtyOrdersReports
    (
       ReportID INT IDENTITY(1,1) NOT NULL,
       ReportXML XML NOT NULL,
       ReportDate DATETIME NOT NULL,
       CustomerID INT NOT NULL
    );
GO

-- включаем брокер
USE master;
ALTER DATABASE WideWorldImporters SET ENABLE_BROKER  WITH ROLLBACK IMMEDIATE; 

-- sb должен функционировать от имени sa
ALTER AUTHORIZATION ON DATABASE::WideWorldImporters TO [sa];

-- подключаемся к БД
USE WideWorldImporters;

-- создаём типы сообщений (оба будут xml)
CREATE MESSAGE TYPE [//WWI/ServiceBroker/RequestMessage]  VALIDATION=WELL_FORMED_XML;
CREATE MESSAGE TYPE [//WWI/ServiceBroker/ResponseMessage] VALIDATION=WELL_FORMED_XML;

-- определяем контракт(кто какие сообщения будет посылать)
CREATE CONTRACT [//WWI/ServiceBroker/Contract] 
(
   [//WWI/ServiceBroker/ResponseMessage] SENT BY TARGET
   ,[//WWI/ServiceBroker/RequestMessage] SENT BY INITIATOR
);

-- создаём очередь(почтовый ящик для сообщений от инициатора)
CREATE QUEUE TargetQueueWWI;
-- определяем сервис для обработки сообщений этой очереди
CREATE SERVICE [//WWI/ServiceBroker/TargetService] 
      ON QUEUE TargetQueueWWI ([//WWI/ServiceBroker/Contract]);

-- создаём очередь(почтовый ящик для ответных сообщений для инициатора)
CREATE QUEUE InitiatorQueueWWI;
-- определяем сервис для обработки сообщений этой очереди
CREATE SERVICE [//WWI/ServiceBroker/InitiatorService] 
      ON QUEUE InitiatorQueueWWI ([//WWI/ServiceBroker/Contract]);
--------------------------------------------------------------------------------------
            

------------------------ХРАНИМЫЕ ПРОЦЕДУРЫ--------------------------------------------------

-- создаём 1-ю ХП (отправляет заявку на отчёт, где указывает ID клиента и период)-----------
CREATE OR ALTER PROCEDURE Sales.usp_SendNewCustomerPeriod 
	@CustomerId INT, @FromDate DATE, @ToDate DATE
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @BeginDialogHandle UNIQUEIDENTIFIER,
            @RequestMessage    NVARCHAR(4000);
		
	BEGIN TRAN;
	    
		IF EXISTS(select 1 from  Sales.Invoices where CustomerID = @CustomerId)
        BEGIN

			SET @RequestMessage = 
			(
				SELECT 
				N'Требуется отчёт по данному клиенту за указанный период' 
						    AS [Message],
			    @CustomerId AS [CustomerID], 
			    @FromDate   AS [Period/From_this_date],
				@ToDate     AS [Period/To_this_date]
				FOR XML PATH('RequestMessage')
			); 
				
			BEGIN DIALOG CONVERSATION @BeginDialogHandle
			FROM SERVICE [//WWI/ServiceBroker/InitiatorService] 
			  TO SERVICE '//WWI/ServiceBroker/TargetService'
			ON CONTRACT [//WWI/ServiceBroker/Contract]
			WITH ENCRYPTION = OFF; 

			SEND ON CONVERSATION @BeginDialogHandle 
					MESSAGE TYPE [//WWI/ServiceBroker/RequestMessage](@RequestMessage);
		
		    SELECT @RequestMessage AS RequestMessage, @BeginDialogHandle AS DialogHandle;--тест
		END;
	
	COMMIT TRAN;
END;
GO

-- создаём 2-ю ХП (получает заявку, берёт из неё CustomerID и период,--------------------------
--                 строит по ним отчёт и отправляет в ответном соообщении)
CREATE OR ALTER PROCEDURE Sales.usp_GetNewCustomerPeriod
AS
BEGIN

	DECLARE @AnswerDialogHandle  UNIQUEIDENTIFIER,
			@ReceivedMessage     NVARCHAR(4000),
			@ReceivedMessageType SYSNAME,
			@ResponseMessage     NVARCHAR(4000),
			@CustomerId          INT,
			@FromDate            DATE,
			@ToDate              DATE,
			@ReceivedMessageXml  XML; 
	
	BEGIN TRAN; 

		RECEIVE TOP(1)
			@AnswerDialogHandle  = conversation_handle,
			@ReceivedMessage     = message_body,
			@ReceivedMessageType = message_type_name
		FROM dbo.TargetQueueWWI; 

		SET @ReceivedMessageXml = CAST(@ReceivedMessage AS XML);

		SELECT @CustomerId = R.m.value('(CustomerID)[1]','INT'),
		       @FromDate   = R.m.value('(Period/From_this_date)[1]','DATE'),
			   @ToDate     = R.m.value('(Period/To_this_date)[1]','DATE')
		FROM @ReceivedMessageXml.nodes('/RequestMessage') as R(m);

		IF @ReceivedMessageType = N'//WWI/ServiceBroker/RequestMessage' 
		BEGIN
			SET @ResponseMessage = 
			(
				SELECT 
				N'Отчёт о количестве заказов данного клиента за указанный период' 
									           AS [Message],
					i.CustomerID               AS CustomerID, 
					ISNULL(COUNT(o.OrderID),0) AS OrdersQuantity,
					@FromDate                  AS [Period/From_this_date],
					@ToDate                    AS [Period/To_this_date]
				FROM Sales.Invoices i
				LEFT JOIN Sales.Orders o ON i.CustomerID = o.CustomerID
										AND o.OrderDate >= @FromDate and o.OrderDate <= @ToDate
				WHERE i.CustomerID = @CustomerId
				GROUP BY i.CustomerID
				FOR XML PATH('ResponseMessage')
			); 
             
			SELECT @ResponseMessage AS ResponseMessage, @AnswerDialogHandle as DlgHandle;  -- тест
		
			SEND ON CONVERSATION @AnswerDialogHandle 
			        MESSAGE TYPE [//WWI/ServiceBroker/ResponseMessage](@ResponseMessage);

			END CONVERSATION @AnswerDialogHandle; 
		END 
		
	COMMIT TRAN;
END;
GO

-- создаём 3-ю ХП (получает сообщение-отчёт и сохраняет его в таблице)-----------------------
CREATE OR ALTER PROCEDURE Sales.usp_ConfirmCustomerPeriodReport
AS
BEGIN
	DECLARE @EndDialogHandle    UNIQUEIDENTIFIER,
			@ReceivedMessageXml XML,
			@CustomerId         INT
	
	BEGIN TRAN; 

		RECEIVE TOP(1)
			 @EndDialogHandle = conversation_handle,
			 @ReceivedMessageXml = CAST(message_body AS XML)
		FROM dbo.InitiatorQueueWWI;  
		 
		 select @ReceivedMessageXml as recMesXml, @EndDialogHandle as dlgHandle; -- тест

		SELECT @CustomerId = R.m.value('(CustomerID)[1]','INT') 
		FROM @ReceivedMessageXml.nodes('/ResponseMessage') as R(m);

		INSERT INTO Sales.tb_CustomersQtyOrdersReports(ReportXML,   ReportDate,    CustomerID) 
		     VALUES                         (@ReceivedMessageXml,   GETUTCDATE(), @CustomerId);
				
		END CONVERSATION @EndDialogHandle; 

	COMMIT TRAN; 
END;
GO
-----------------------------------------------------------------------------------------------


--------------------РУЧНОЙ ПОСЛЕДОВАТЕЛЬНЫЙ ЗАПУСК И МОНИТОРИНГ ВСЕГО ПРОЦЕССА-------------------------

-- проверяем таблицу отчётов
SELECT * FROM Sales.tb_CustomersQtyOrdersReports;

-- получаем список данных для входных параметров 1-ой ХП
--   (клиентов из таблицы Sales.Invoices)
SELECT 	
CustomerID       AS [CustomerID], 
MIN(InvoiceDate) AS [From_date],
MAX(InvoiceDate) AS [To_date]
FROM Sales.Invoices
GROUP BY CustomerID

-- выполняем 1-ю ХП
EXEC Sales.usp_SendNewCustomerPeriod @CustomerId = 902, @FromDate='2013-01-11', @ToDate = '2016-05-23';

-- проверяем очереди
SELECT CAST(message_body AS XML), * FROM dbo.TargetQueueWWI; --сообщение
SELECT CAST(message_body AS XML), * FROM dbo.InitiatorQueueWWI;  --пусто

-- выполняем 2-ю ХП
EXEC Sales.usp_GetNewCustomerPeriod;

-- проверяем очереди
SELECT CAST(message_body AS XML), * FROM dbo.TargetQueueWWI; --пусто
SELECT CAST(message_body AS XML), * FROM dbo.InitiatorQueueWWI;  --сообщение

-- проверяем таблицу отчётов для данного клиента
SELECT * FROM Sales.tb_CustomersQtyOrdersReports WHERE CustomerID = 902;     -- отчёта ещё нет

-- выполняем 3-ю ХП
EXEC Sales.usp_ConfirmCustomerPeriodReport;

-- проверяем таблицу отчётов
SELECT * FROM Sales.tb_CustomersQtyOrdersReports WHERE CustomerID = 902;     -- отчёт появился

-- проверяем очереди
SELECT CAST(message_body AS XML), * FROM dbo.TargetQueueWWI;  --пусто
SELECT CAST(message_body AS XML), * FROM dbo.InitiatorQueueWWI;   --пусто

-- проверяем список диалогов и их статусы
SELECT conversation_handle, is_initiator, s.name as 'local service', 
       far_service, sc.name 'contract', ce.state_desc
FROM sys.conversation_endpoints ce 
LEFT JOIN sys.services s ON ce.service_id = s.service_id
LEFT JOIN sys.service_contracts sc ON ce.service_contract_id = sc.service_contract_id
ORDER BY conversation_handle;
-------------------------------------------------------------------------------------------------------


----------------------АВТОМАТИЧЕСКАЯ ОБРАБОТКА ЧЕРЕЗ ПРОЦЕДУРЫ АКТИВАЦИИ-------------------------------------------

-- к очереди привязываем ХП-обработчик этой очереди
ALTER QUEUE TargetQueueWWI 
WITH ACTIVATION (
	STATUS = ON -- вкл
	, PROCEDURE_NAME = Sales.usp_GetNewCustomerPeriod -- 2-ю
	, MAX_QUEUE_READERS = 1 
	, EXECUTE AS OWNER 
	); 
GO

-- к очереди привязываем ХП-обработчик этой очереди
ALTER QUEUE InitiatorQueueWWI 
WITH ACTIVATION (
	STATUS = ON --  вкл
	, PROCEDURE_NAME = Sales.usp_ConfirmCustomerPeriodReport -- 3-ю
	, MAX_QUEUE_READERS = 1 
	, EXECUTE AS OWNER 
	); 
GO

-- получаем список данных для входных параметров 1-ой ХП
SELECT 	
CustomerID       AS [CustomerID], 
MIN(InvoiceDate) AS [From_date],
MAX(InvoiceDate) AS [To_date]
FROM Sales.Invoices
GROUP BY CustomerID

-- выполняем 1-ю ХП
EXEC Sales.usp_SendNewCustomerPeriod @CustomerId = 971, @FromDate='2013-01-01', @ToDate = '2016-05-13';

-- проверяем таблицу отчётов
SELECT * FROM Sales.tb_CustomersQtyOrdersReports 
WHERE CustomerID = 971;

-- проверяем очереди сообщений
SELECT CAST(message_body AS XML), * FROM dbo.TargetQueueWWI;  --пусто
SELECT CAST(message_body AS XML), * FROM dbo.InitiatorQueueWWI;   --пусто

-- проверяем список диалогов и их статусы
SELECT conversation_handle, is_initiator, s.name as 'local service', far_service, sc.name 'contract', ce.state_desc
FROM sys.conversation_endpoints ce 
LEFT JOIN sys.services s ON ce.service_id = s.service_id
LEFT JOIN sys.service_contracts sc ON ce.service_contract_id = sc.service_contract_id
ORDER BY conversation_handle;
-------------------------------------------------------------------------------------------------------------------


---------------------------ОЧИЩЕНИЕ----------------------------------------------------
-- (после того, как списки диалогов опустеют, удаляем всё ранее созданное, а именно):

-- таблицу отчётов
DROP TABLE Sales.tb_CustomersQtyOrdersReports;

-- сервисы
DROP SERVICE [//WWI/ServiceBroker/TargetService];
GO
DROP SERVICE [//WWI/ServiceBroker/InitiatorService];
GO

-- очереди
DROP QUEUE [dbo].[TargetQueueWWI];
GO 
DROP QUEUE [dbo].[InitiatorQueueWWI];
GO

-- контракт
DROP CONTRACT [//WWI/ServiceBroker/Contract];
GO

-- типы сообщений
DROP MESSAGE TYPE [//WWI/ServiceBroker/RequestMessage];
GO
DROP MESSAGE TYPE [//WWI/ServiceBroker/ResponseMessage];
GO

-- хранимые процедуры
DROP PROCEDURE IF EXISTS  Sales.usp_SendNewCustomerPeriod;
GO
DROP PROCEDURE IF EXISTS  Sales.usp_GetNewCustomerPeriod;
GO
DROP PROCEDURE IF EXISTS  Sales.usp_ConfirmCustomerPeriodReport;
GO

-- выключаем брокер
USE master;
ALTER DATABASE WideWorldImporters SET DISABLE_BROKER; 
GO
---------------------------------------------------------------------------------------