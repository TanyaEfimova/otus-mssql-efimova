/*
                                     Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "Индексы".                                                                                           */
----------------------------------------------------------------------------------------------------------------
-- Думаем какие запросы у вас будут в базе и добавляем для них индексы. Проверяем, что они используются в запросе.
-----------------------------------------------------------------------------------------------------------------
USE MyBookForCook;

-- Все 12 таблиц проекта уже содержат Кластерные индексы(по 1 на таблицу),
--                                    созданные автоматически при создании Primary Key,
-- привожу примеры их использования в запросах:-------------------------------------------------------------------

SELECT [Name] FROM dbo.IngredientCategories                       -- Clustered Index Seek[PK_IngredientCategories]
WHERE IngredientCategoryId = 15;                                  

SELECT * FROM dbo.Ingredients WHERE IngredientId = 7;             -- Clustered Index Seek[PK_Ingredients]  

SELECT * FROM dbo.RecipeCategories ORDER BY RecipeCategoryId;     -- Clustered Index Scan[PK_RecipeCategories]

SELECT * FROM dbo.Recipes WHERE [Name] LIKE 'Б%';                 -- Clustered Index Scan[PK_Recipes] 

SELECT ShortName, FullName FROM dbo.Units ORDER BY ShortName;     -- Clustered Key Lookup[PK_Units]   

SELECT Quantity, UnitID 
FROM dbo.RecipeIngredients                                        -- Clustered Key Lookup[PK_RecipeIngredients] 
WHERE RecipeId = 10 AND IngredientId = 217;                       

SELECT a.[Description], rs.RecipeStepId, rs.StepDescription
FROM dbo.Actions a                                                -- Clustered Index Seek[PK_Actions]
LEFT JOIN dbo.RecipeSteps rs ON  a.ActionId = rs.ActionId         -- Clustered Index Scan[PK_RecipeSteps]
WHERE rs.RecipeId = 12;

SELECT * FROM dbo.RecipeStepIngredients WHERE RecipeStepId = 75;  -- Clustered Index Seek[PK_RecipeStepIngredients]

SELECT * FROM dbo.CookingLogs                                     -- Clustered Index Scan[PK_CookingLogs]
WHERE CookingDate BETWEEN '2024-01-01' AND '2024-03-01';           

SELECT ssi.IngredientId, ss.[Name]                          
FROM dbo.SearchSetItems ssi                                       -- Clustered Index Seek[PK_SearchSetItems]
JOIN dbo.SearchSets ss  ON ssi.SearchSetId = ss.SearchSetId       -- Clustered Index Seek[PK_SearchSets]
WHERE ssi.SearchSetItemId = 1;



-- Создадим некластерные индексы на поля с Foreign Key с примерами их использования:-------------------------------

CREATE NONCLUSTERED INDEX [IX_Ingredients_IngredientCategoryId] ON [Ingredients]([IngredientCategoryId]);
go
SELECT IngredientId
FROM dbo.Ingredients                                -- NonClustered Index Seek[IX_Ingredients_IngredientCategoryId]
WHERE IngredientCategoryId = 13;  


CREATE NONCLUSTERED INDEX [IX_Recipes_RecipeCategoryId] ON [Recipes]([RecipeCategoryId]);
go
SELECT RecipeId  
FROM dbo.Recipes                                    -- NonClustered Index Seek[IX_Recipes_RecipeCategoryId]
WHERE RecipeCategoryId = 2;  -- Супы


CREATE NONCLUSTERED INDEX [IX_RecipeIngredients_IngredientId] ON [RecipeIngredients]([IngredientId]);
go
SELECT RecipeIngredientId
FROM dbo.RecipeIngredients                          -- NonClustered Index Seek[IX_RecipeIngredients_IngredientId]
WHERE IngredientId = 95;  -- мука пшеничная


CREATE NONCLUSTERED INDEX [IX_RecipeIngredients_RecipeId] ON [RecipeIngredients]([RecipeId]);
go
SELECT RecipeIngredientId  
FROM dbo.RecipeIngredients                           -- NonClustered Index Seek[IX_RecipeIngredients_RecipeId]
WHERE RecipeId = 1;


CREATE NONCLUSTERED INDEX [IX_RecipeIngredients_UnitId] ON [RecipeIngredients]([UnitId]);
go
SELECT COUNT(*) FROM dbo.RecipeIngredients WHERE UnitId = 1;   -- NonClustered Index Seek[IX_RecipeIngredients_UnitId]


CREATE NONCLUSTERED INDEX [IX_RecipeSteps_ActionId] ON [RecipeSteps]([ActionId]);
go
SELECT RecipeStepId
FROM dbo.RecipeSteps                                   -- NonClustered Index Seek[IX_RecipeSteps_ActionId]
WHERE ActionId = 20;  -- Нарезать
                                     

CREATE NONCLUSTERED INDEX [IX_RecipeStepIngredients_RecipeIngredientId] ON [RecipeStepIngredients]([RecipeIngredientId]);
go
SELECT RecipeStepId
FROM dbo.RecipeStepIngredients                        -- NonClustered Index Seek[IX_RecipeStepIngredients_RecipeIngredientID]
WHERE RecipeIngredientId = 3;    


CREATE NONCLUSTERED INDEX [IX_CookingLogs_RecipeId] ON [CookingLogs]([RecipeId]);
go
SELECT COUNT(*)
FROM dbo.CookingLogs                                 -- NonClustered Index Seek[IX_CookingLogs_RecipeId]
WHERE RecipeId = 1;                       


CREATE NONCLUSTERED INDEX [IX_SearchSetItems_IngredientId] ON [SearchSetItems]([IngredientId]);
go
SELECT SearchSetItemId  
FROM dbo.SearchSetItems                            -- NonClustered Index Seek[IX_SearchSetItems_IngredientId]
WHERE IngredientId = 108;  -- яйцо куриное


-- Все уникальные Некластерные индексы созданы автоматически при добавлении соответствующих CONSTRAINT,
-- рассмотрим примеры их использования:----------------------------------------------------------------------------------------------

SELECT 1 FROM dbo.IngredientCategories WHERE [Name] = N'Овощи сырые/свежие';  -- NonClustered Index Seek[UK_IngredientCategories_Name]

SELECT IngredientId FROM dbo.Ingredients WHERE [Name] = N'мука пшеничная';    -- NonClustered Index Seek[UK_Ingredients_Name]

SELECT * FROM dbo.RecipeCategories WHERE [Name] = N'Десерты';                 -- NonClustered Index Seek[UK_RecipeCategories_Name]

SELECT FullName FROM dbo.Units WHERE ShortName = N'ч.л.';                     -- NonClustered Index Seek[UK_Units_ShortName]

SELECT 1 FROM dbo.Actions WHERE [Description] = N'Нарезать';                  -- NonClustered Index Seek[UK_Actions_Description]

SELECT StepNumber, StepDescription
FROM dbo.RecipeSteps WHERE RecipeId = 1  ORDER BY StepNumber;                 -- NonClustered Index Seek[UK_RecipeSteps]

SELECT IngredientId FROM dbo.SearchSetItems WHERE SearchSetId = 1;            -- NonClustered Index Seek[UK_SearchSetItems]


-- И создадим недостающие индексы с примерами их использования----------------------------------------------------------------------------

CREATE INDEX [IX_Units_FullName] ON dbo.Units(FullName);
go
SELECT UnitId FROM dbo.Units WHERE FullName = N'стакан';                         -- NonClustered Index Seek[IX_Units_FullName]


CREATE INDEX IX_Recipes_Name ON dbo.Recipes([Name]);
go
SELECT RecipeID, [Name]
FROM dbo.Recipes                                                                 -- NonClustered Index Scan[IX_Recipes_Name]
WHERE [Name] LIKE N'%суп%';                                                   


CREATE INDEX IX_RecipeIngredients_Quantity ON dbo.RecipeIngredients(Quantity);
go
SELECT COUNT(*) FROM dbo.RecipeIngredients WHERE UnitId = 3 and Quantity = 300;  -- NonClustered Index Seek[IX_RecipeIngredients_Quantity]


CREATE INDEX IX_SearchSets_Name ON dbo.SearchSets([Name]);
go
SELECT SearchSetId, [Name] FROM dbo.SearchSets WHERE Name = N'Завтрак';          -- NonClustered Index Seek[IX_SearchSets_Name]


CREATE INDEX IX_CookingLogs_CookingDate ON dbo.CookingLogs(CookingDate);
go
SELECT COUNT(RecipeId)
FROM dbo.CookingLogs                                                             -- NonClustered Index Seek[IX_CookingLogs_CookingDate]
WHERE CookingDate >= '2024-01-01' AND CookingDate < '2025-01-01';         


CREATE INDEX IX_RecipeSteps_StepDescription ON dbo.RecipeSteps(StepDescription);
go
SELECT RecipeId
FROM dbo.RecipeSteps                                                             -- NonClustered Index Seek[IX_RecipeSteps_StepDescription]
WHERE StepDescription = N'Дать постоять 2 дня';                
-------------------------------------------------------------------------------------------------------------------------------------------

