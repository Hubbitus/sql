IF OBJECT_ID('[dbo].[sql_benchmark_table]') IS NOT NULL
	DROP PROCEDURE dbo.sql_benchmark_table;
GO

IF OBJECT_ID('tempdb..#SqlBenchmarkTableResults') IS NOT NULL
	DROP TABLE #SqlBenchmarkTableResults;
GO

/* Create a table type */
IF TYPE_ID('[dbo].[SqlBenchmarkTableType]') IS NOT NULL
	DROP TYPE [dbo].[SqlBenchmarkTableType];
GO

CREATE TYPE SqlBenchmarkTableType AS TABLE (
	sql VARCHAR(MAX) NOT NULL -- SQL query to execute
	,sqlBefore VARCHAR(MAX) -- SQL query to execute BEFORE sql. F.e. for start transaction or provide settings.
	,sqlAfter VARCHAR(MAX) -- SQL query to execute AFTER sql. F.e. for commit/rollback transaction.
	,name VARCHAR(1024) -- (code)Name of iteration. Will be appeared in breaf results. If NULL combination of "sqlBefore + '; ' + sql + '; ' + sqlAfter" will be used
	,cnt INT -- Amount of execution. If Null - procedure @cnt parameter will be used as global
);
GO

/**
* Function to benchmark SQL.
* Inspired by dbo.sql_benchmark but more convenient to compare several queries with indepentent counter of execute
*
* Time of execution sqlBefore and sqlAfter excluded from measured times.
By default returned recordsed as short result:
	SELECT
		COALESCE(name, sqlBefore + '; ' + sql + '; ' + sqlAfter)
		,COUNT(*) as cnt
		,MIN(timeMs) as minTimeMs, dbo.format_interval(NULL, NULL, MIN(timeMs)) as minTimeStr
		,AVG(timeMs) as avgTimeMs, dbo.format_interval(NULL, NULL, AVG(timeMs)) as avgTimeStr
		,MAX(timeMs) as maxTimeMs, dbo.format_interval(NULL, NULL, MAX(timeMs)) as maxTimeStr
	FROM
		#SqlBenchmarkTableResults
	GROUP BY
		COALESCE(name, sqlBefore + '; ' + sql + '; ' + sqlAfter)
	ORDER BY
		avgTimeStr, minTimeStr, maxTimeStr;
*
* EXAMPLES:
* 1) simple usage:
DECLARE @sql AS SqlBenchmarkTableType;
 -- It is important for tested queries to do not return resultsets as it looks like a garbage
INSERT INTO @sql (sql) VALUES
	('DECLARE @var DATETIME2; SELECT @var = GETDATE()')
	,('DECLARE @var DATETIME2; SELECT @var = GETDATE() + 1')
EXEC sql_benchmark_table @sql, 3;
SELECT * FROM #SqlBenchmarkTableResults;

* 2) more advanced usage:
DECLARE @sql AS SqlBenchmarkTableType;
 -- It is important for tested queries to do not return resultsets as it looks like a garbage
INSERT INTO @sql (sqlBefore, sql, name, cnt) VALUES
	('DECLARE @var DATETIME2', 'WAITFOR DELAY ''00:00:01.123''; SELECT @var = GETDATE()', 'GETDATE() 3 times exec with delay', 3)
	,('DECLARE @var DATETIME2', 'SELECT @var = GETDATE() + 1', 'GETDATE() 5 times exec', 5)
-- IF you want access raw test results you may create temporary table for it in call scope. Otherwise it is created and automatically dropped in sp (http://stackoverflow.com/questions/17040710/how-to-access-the-temporary-table-created-inside-stored-procedure-vb6)
IF OBJECT_ID('tempdb..#SqlBenchmarkTableResults') IS NOT NULL DROP TABLE #SqlBenchmarkTableResults;
CREATE TABLE #SqlBenchmarkTableResults(sql VARCHAR(MAX), sqlBefore VARCHAR(MAX), sqlAfter VARCHAR(MAX), name VARCHAR(1024), cnt INT, i INT, timeMs INT);
EXEC sql_benchmark_table @sql, 3;
SELECT * FROM #SqlBenchmarkTableResults;
*
* @param sql SqlBenchmarkTableType READONLY
* @param commonCount INT = 10
*
* @uses log_message sp.
* @uses format_interval udf.
* @uses SqlBenchmarkTableType type.
* @uses #SqlBenchmarkTableResults temporary table (optionally create it in their scope).
*/
CREATE PROCEDURE dbo.sql_benchmark_table(@sql SqlBenchmarkTableType READONLY, @commonCount INT = 10)
AS
BEGIN
	DECLARE @dateStart DATETIME2 = GETDATE(), @dateEnd DATETIME2;
	DECLARE @i INT = 0, @cnt INT;
	DECLARE @timeMilliseconds INT;
	DECLARE @s VARCHAR(MAX), @sBefore VARCHAR(MAX), @sAfter VARCHAR(MAX), @name VARCHAR(MAX);

	DECLARE sql_c CURSOR FOR
		SELECT sql, sqlBefore, sqlAfter, name, cnt
		FROM @sql;

	IF OBJECT_ID('tempdb..#SqlBenchmarkTableResults') is not null
		TRUNCATE TABLE #SqlBenchmarkTableResults;

	OPEN sql_c
	FETCH NEXT FROM sql_c INTO @s, @sBefore, @sAfter, @name, @cnt;

	WHILE @@FETCH_STATUS = 0
	BEGIN
		WHILE @i < COALESCE(@cnt, @commonCount) BEGIN
			SET @sBefore = COALESCE(@sBefore, '');
			SET @sAfter = COALESCE(@sAfter, '');
			EXEC dbo.bench_exec @sql = @s, @timeMilliseconds = @timeMilliseconds OUTPUT, @sqlBefore = @sBefore, @sqlAfter = @sAfter;

			IF OBJECT_ID('tempdb..#SqlBenchmarkTableResults') IS NULL -- create
				SELECT @s as sql, @sBefore as sqlBefore, @sAfter as sqlAfter, @name as name, COALESCE(@cnt, @commonCount) as cnt, @i as i, @timeMilliseconds as timeMs
				INTO #SqlBenchmarkTableResults;
			ELSE -- add
				INSERT INTO #SqlBenchmarkTableResults (sql, sqlBefore, sqlAfter, name, cnt, i, timeMs) VALUES (@s, @sBefore, @sAfter, @name, COALESCE(@cnt, @commonCount), @i, @timeMilliseconds);

			SET @i = @i + 1;
		END
		FETCH NEXT FROM sql_c INTO @s, @sBefore, @sAfter, @name, @cnt;
		SET @i = 0;
	END

	CLOSE sql_c
	DEALLOCATE sql_c

	SELECT
		COALESCE(name, CASE WHEN sqlBefore IS NOT NULL THEN sqlBefore + '; ' ELSE '' END + sql + CASE WHEN sqlAfter IS NOT NULL THEN '; ' + sqlAfter ELSE '' END) as name
		,COUNT(*) as cnt
		,MIN(timeMs) as minTimeMs, dbo.format_interval(NULL, NULL, MIN(timeMs)) as minTimeStr
		,AVG(timeMs) as avgTimeMs, dbo.format_interval(NULL, NULL, AVG(timeMs)) as avgTimeStr
		,MAX(timeMs) as maxTimeMs, dbo.format_interval(NULL, NULL, MAX(timeMs)) as maxTimeStr
	FROM
		#SqlBenchmarkTableResults
	GROUP BY
		COALESCE(name, CASE WHEN sqlBefore IS NOT NULL THEN sqlBefore + '; ' ELSE '' END + sql + CASE WHEN sqlAfter IS NOT NULL THEN '; ' + sqlAfter ELSE '' END)
	ORDER BY
		avgTimeStr, minTimeStr, maxTimeStr;
	
	SET @dateEnd = GETDATE();
	EXEC dbo.log_message @dateStart = @dateStart, @dateEnd = @dateEnd, @textHead = 'Total execution time: ';
END