/*
                                     Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "15 - Операторы DDL".
Используем DDL. Создание таблиц и представлений для своего проекта.                                                              */
-- --------------------------------------------------------------------------------------------------------------------------------
-- Задание - реализовать физическую модель данных, создав основные таблицы проекта с ключами, индексами и ограничениями целостности
-- --------------------------------------------------------------------------------------------------------------------------------

/*---------------------------------------------------------------------------------------------------------------------------------
1. Создать базу данных.                                                                                                          */

CREATE DATABASE [MyBookForCook]
 ON  PRIMARY 
( 
	NAME = N'MyBookForCook', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL16.SQL2022\MSSQL\DATA\MyBookForCook.mdf', 
	SIZE = 8192KB , MAXSIZE = 9GB, FILEGROWTH = 65536KB 
)
 LOG ON 
( 
	NAME = N'MyBookForCook_log', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL16.SQL2022\MSSQL\DATA\MyBookForCook_log.ldf',
	SIZE = 8192KB , MAXSIZE = 20GB , FILEGROWTH = 65536KB 
);
GO


USE [MyBookForCook];

/*---------------------------------------------------------------------------------------------------------------
2. Создать таблицы для своего проекта                                                                          */

CREATE TABLE [dbo].[IngredientCategories]  -- категории ингредиентов(овощи,фрукты...)
(
	[IngredientCategoryId] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](100) NOT NULL
);
GO

CREATE TABLE [dbo].[Ingredients]  -- ингредиенты(баклажан,ананас...)
(
	[IngredientId] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](200) NOT NULL,
	[IngredientCategoryId] [int] NOT NULL
);
GO

CREATE TABLE [dbo].[RecipeCategories]  -- категории рецептов(десерты,напитки...)
(
	[RecipeCategoryId] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](100) NOT NULL
);
GO

CREATE TABLE [dbo].[Recipes]   -- рецепты(медовик,лимонад...)
(
	[RecipeId] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](200) NOT NULL,
	[RecipeCategoryId] [int] NOT NULL
);
GO

CREATE TABLE [dbo].[Units]    -- единицы измерения ингредиентов(кг,шт)
(
	[UnitId] [int] IDENTITY(1,1) NOT NULL,
	[ShortName] [nvarchar](5) NOT NULL,
	[FullName] [nvarchar](50) NOT NULL
);
GO

CREATE TABLE [dbo].[RecipeIngredients]  -- состав рецепта(1 кг баклажанов, 2 ананаса...)
(
	[RecipeIngredientId] [int] IDENTITY(1,1) NOT NULL,
	[RecipeId] [int] NOT NULL,
	[IngredientId] [int] NOT NULL,
	[UnitId] [int] NULL,
	[Quantity] [decimal](10, 3) NULL,
	[Comment] [nvarchar](200) NULL
);
GO

CREATE TABLE [dbo].[Actions]  -- действия(порезать, положить...)
(
	[ActionId] [int] IDENTITY(1,1) NOT NULL,
	[Description] [nvarchar](800) NOT NULL
);
GO

CREATE TABLE [dbo].[RecipeSteps] -- шаги приготовления(1-порезать кубиком, 2-положить на разогретую сковороду...)
(
	[RecipeStepId] [int] IDENTITY(1,1) NOT NULL,
	[RecipeId] [int] NOT NULL,
	[StepNumber] [int] NOT NULL,
	[StepDescription] [nvarchar](max) NOT NULL,
	[ActionId] [int] NOT NULL
);
GO

CREATE TABLE [dbo].[RecipeStepIngredients] -- ингредиенты в шагах
(
	[RecipeStepId] [int] NOT NULL,
	[RecipeIngredientId] [int] NOT NULL
);
GO

CREATE TABLE [dbo].[CookingLogs] -- история приготовлений
(
	[CookingId] [int] IDENTITY(1,1) NOT NULL,
	[RecipeId] [int] NOT NULL,
	[CookingDate] [datetime2](7) NOT NULL
);
GO

CREATE TABLE [dbo].[SearchSets]   -- поисковые наборы
(
	[SearchSetId] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](100) NOT NULL
);
GO

CREATE TABLE [dbo].[SearchSetItems]  -- наборы ингредиентов(для поиска подходящего рецепта)
(
	[SearchSetItemId] [int] IDENTITY(1,1) NOT NULL,
	[SearchSetId] [int] NOT NULL,
	[IngredientId] [int] NOT NULL
);
GO


/*----------------------------------------------------------------------------------------------
3. Создать первичные и внешние ключи для всех созданных таблиц.                               */

ALTER TABLE [IngredientCategories] ADD CONSTRAINT [PK_IngredientCategories] 
PRIMARY KEY (IngredientCategoryId);

ALTER TABLE [Ingredients] ADD CONSTRAINT [PK_Ingredients] 
PRIMARY KEY (IngredientId);
GO
ALTER TABLE [Ingredients] ADD CONSTRAINT [FK_Ingredients_IngredientCategoryId] 
FOREIGN KEY (IngredientCategoryId)
REFERENCES [IngredientCategories](IngredientCategoryId);

ALTER TABLE [RecipeCategories] ADD CONSTRAINT [PK_RecipeCategories] 
PRIMARY KEY (RecipeCategoryId);

ALTER TABLE [Recipes] ADD CONSTRAINT [PK_Recipes] 
PRIMARY KEY (RecipeId);
GO
ALTER TABLE [Recipes] ADD CONSTRAINT [FK_Recipes_RecipeCategoryId] 
FOREIGN KEY (RecipeCategoryId)
REFERENCES [RecipeCategories](RecipeCategoryId);

ALTER TABLE [Units] ADD CONSTRAINT [PK_Units] 
PRIMARY KEY (UnitId);

ALTER TABLE [RecipeIngredients] ADD CONSTRAINT [PK_RecipeIngredients] 
PRIMARY KEY (RecipeIngredientId);
GO
ALTER TABLE [RecipeIngredients] ADD CONSTRAINT [FK_RecipeIngredients_IngredientId]
FOREIGN KEY (IngredientId)
REFERENCES [Ingredients](IngredientId)
ON UPDATE CASCADE
ON DELETE CASCADE;
GO
ALTER TABLE [RecipeIngredients] ADD CONSTRAINT [FK_RecipeIngredients_RecipeId] 
FOREIGN KEY (RecipeId)
REFERENCES [Recipes](RecipeId)
ON UPDATE CASCADE
ON DELETE CASCADE;
GO
ALTER TABLE [RecipeIngredients] ADD CONSTRAINT [FK_RecipeIngredients_UnitId] 
FOREIGN KEY (UnitId)
REFERENCES [Units](UnitId)
ON UPDATE CASCADE
ON DELETE CASCADE;

ALTER TABLE [Actions] ADD CONSTRAINT [PK_Actions] 
PRIMARY KEY (ActionId);

ALTER TABLE [RecipeSteps] ADD CONSTRAINT [PK_RecipeSteps] 
PRIMARY KEY (RecipeStepId);
GO
ALTER TABLE [RecipeSteps] ADD CONSTRAINT [FK_RecipeSteps_RecipeId] 
FOREIGN KEY (RecipeId)
REFERENCES [Recipes](RecipeId)
ON UPDATE CASCADE
ON DELETE CASCADE;
GO
ALTER TABLE [RecipeSteps] ADD CONSTRAINT [FK_RecipeSteps_ActionId] 
FOREIGN KEY (ActionId)
REFERENCES [Actions](ActionId)
ON UPDATE CASCADE
ON DELETE CASCADE;

ALTER TABLE [RecipeStepIngredients] ADD CONSTRAINT [PK_RecipeStepIngredients] 
PRIMARY KEY (RecipeStepId, RecipeIngredientId);
GO
ALTER TABLE [RecipeStepIngredients] ADD CONSTRAINT [FK_RecipeStepIngredients_RecipeIngredientId]
FOREIGN KEY (RecipeIngredientId)
REFERENCES [RecipeIngredients](RecipeIngredientId);
GO
ALTER TABLE [RecipeStepIngredients] ADD CONSTRAINT [FK_RecipeStepIngredients_RecipeStepId] 
FOREIGN KEY (RecipeStepId)
REFERENCES [RecipeSteps](RecipeStepId)
ON UPDATE CASCADE
ON DELETE CASCADE;

ALTER TABLE [CookingLogs] ADD CONSTRAINT [PK_CookingLogs] 
PRIMARY KEY (CookingId);
GO
ALTER TABLE [CookingLogs] ADD CONSTRAINT [FK_CookingLogs_RecipeId] 
FOREIGN KEY (RecipeId)
REFERENCES [Recipes](RecipeId);

ALTER TABLE [SearchSets] ADD CONSTRAINT [PK_SearchSets] 
PRIMARY KEY (SearchSetId);

ALTER TABLE [SearchSetItems] ADD CONSTRAINT [PK_SearchSetItems] 
PRIMARY KEY (SearchSetItemId);
GO
ALTER TABLE [SearchSetItems] ADD CONSTRAINT [FK_SearchSetItems_IngredientId] 
FOREIGN KEY (IngredientId)
REFERENCES [Ingredients](IngredientId)
ON UPDATE CASCADE
ON DELETE CASCADE;
GO
ALTER TABLE [SearchSetItems] ADD CONSTRAINT [FK_SearchSetItems_SearchSetId] 
FOREIGN KEY (SearchSetId)
REFERENCES [SearchSets] (SearchSetId)
ON UPDATE CASCADE
ON DELETE CASCADE;

 
/*-----------------------------------------------------------------------------------------------------------------------
4. Создать 1-2 индекса на таблицы.                                                                                     */

CREATE UNIQUE NONCLUSTERED INDEX [UK_IngredientCategories_Name] ON [IngredientCategories]([Name]);

CREATE NONCLUSTERED INDEX [IX_Ingredients_IngredientCategoryId] ON [Ingredients]([IngredientCategoryId]);

CREATE UNIQUE NONCLUSTERED INDEX [UK_RecipeCategories_Name] ON [RecipeCategories]([Name]);

CREATE NONCLUSTERED INDEX [IX_Recipes_RecipeCategoryId] ON [Recipes]([RecipeCategoryId]);
CREATE NONCLUSTERED INDEX [IX_Recipes_Name] ON [Recipes]([Name]);

CREATE NONCLUSTERED INDEX [IX_Units_FullName] ON [Units]([FullName]);

CREATE NONCLUSTERED INDEX [IX_RecipeIngredients_IngredientId] ON [RecipeIngredients]([IngredientId]);
CREATE NONCLUSTERED INDEX [IX_RecipeIngredients_RecipeId] ON [RecipeIngredients]([RecipeId]);
CREATE NONCLUSTERED INDEX [IX_RecipeIngredients_UnitId] ON [RecipeIngredients]([UnitId]);

CREATE UNIQUE NONCLUSTERED INDEX [UK_Actions_Description] ON [Actions]([Description]);

CREATE NONCLUSTERED INDEX [IX_RecipeSteps_RecipeId] ON [RecipeSteps]([RecipeId]);
CREATE NONCLUSTERED INDEX [IX_RecipeSteps_ActionId] ON [RecipeSteps]([ActionId]);

CREATE NONCLUSTERED INDEX [IX_RecipeStepIngredients_RecipeStepId] ON [RecipeStepIngredients]([RecipeStepId]);
CREATE NONCLUSTERED INDEX [IX_RecipeStepIngredients_RecipeIngredientId] ON [RecipeStepIngredients]([RecipeIngredientId]);

CREATE NONCLUSTERED INDEX [IX_CookingLogs_RecipeId] ON [CookingLogs]([RecipeId]);
CREATE NONCLUSTERED INDEX [IX_CookingLogs_CookingDate] ON [CookingLogs]([CookingDate]);

CREATE NONCLUSTERED INDEX [IX_SearchSets_Name] ON [SearchSets]([Name]);

CREATE NONCLUSTERED INDEX [IX_SearchSetItems_SearchSetId] ON [SearchSetItems]([SearchSetId]);
CREATE NONCLUSTERED INDEX [IX_SearchSetItems_IngredientId] ON [SearchSetItems]([IngredientId]);


/*-------------------------------------------------------------------------------------------------------------------------
5. Наложить по одному ограничению в каждой таблице на ввод данных.                                                       */

ALTER TABLE [IngredientCategories] ADD CONSTRAINT [CK_IngredientCategories_Name_Valid]
CHECK 
(
    LEN(TRIM([Name])) >= 0                    -- не должно быть пустым или состоять из пробелов
    AND [Name] = TRIM([Name])                 -- без ведущих/концевых пробелов
);

ALTER TABLE [Ingredients] ADD CONSTRAINT [UK_Ingredients_Name] UNIQUE ([Name]);

ALTER TABLE [RecipeCategories] ADD CONSTRAINT [CK_RecipeCategories_Name_Valid]
CHECK 
(
    LEN(TRIM([Name])) >= 0                    -- не должно быть пустым или состоять из пробелов
    AND [Name] = TRIM([Name])                 -- без ведущих/концевых пробелов
);

ALTER TABLE [Recipes] ADD CONSTRAINT [CK_Recipes_Name_Valid]
CHECK 
(
    LEN(TRIM([Name])) >= 0                    -- не должно быть пустым или состоять из пробелов
    AND [Name] = TRIM([Name])                 -- без ведущих/концевых пробелов
);

ALTER TABLE [Units] ADD CONSTRAINT [UK_Units_ShortName] UNIQUE ([ShortName]);

ALTER TABLE [RecipeIngredients] ADD CONSTRAINT [CK_RecipeIngredients_Quantity_Valid]
CHECK 
(
    ISNULL([Quantity],0) >= 0                 -- не должно отрицательным
);

ALTER TABLE [Actions] ADD CONSTRAINT [CK_Actions_Description_Valid]
CHECK 
(
    LEN(TRIM([Description])) >= 0             -- не должно быть пустым или состоять из пробелов
    AND [Description] = TRIM([Description])   -- без ведущих/концевых пробелов
);


ALTER TABLE [RecipeSteps] ADD CONSTRAINT [UK_RecipeSteps] UNIQUE ([RecipeId],[StepNumber]);

ALTER TABLE [RecipeStepIngredients] ADD CONSTRAINT [UK_RecipeStepIngredients] UNIQUE ([RecipeStepId],[RecipeIngredientId]);

ALTER TABLE [CookingLogs] ADD CONSTRAINT [DF_CookingLogs_CookingDate] DEFAULT (SYSDATETIME()) FOR [CookingDate];

ALTER TABLE [SearchSets] ADD CONSTRAINT [CK_SearchSets_Name_Valid]
CHECK 
(
    LEN(TRIM([Name])) >= 0                    -- не должно быть пустым или состоять из пробелов
    AND [Name] = TRIM([Name])                 -- без ведущих/концевых пробелов
);


ALTER TABLE [SearchSetItems] ADD CONSTRAINT [UK_SearchSetItems] UNIQUE ([SearchSetId],[IngredientId]);
-----------------------------------------------------------------------------------------------------------------------------------