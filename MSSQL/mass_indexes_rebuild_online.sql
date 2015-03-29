ALTER DATABASE ascug SET RECOVERY SIMPLE;

DECLARE @startDate DATETIME = GETDATE();
DECLARE @endDate DATETIME;
DECLARE @sql VARCHAR(MAX);

SET @sql = 'Operation run time: ' + CONVERT(VARCHAR, @startDate, 120);
-- http://stackoverflow.com/questions/306945/how-do-i-flush-the-print-buffer-in-tsql
RAISERROR(@sql, 0, 1) WITH NOWAIT;

-- http://technet.microsoft.com/en-us/library/ms189858.aspx
DECLARE db_cursor CURSOR FOR
	SELECT
		-- a.index_id,
		b.name as indexName, OBJECT_NAME(b.object_id) as tableName, avg_fragmentation_in_percent
	FROM sys.dm_db_index_physical_stats (DB_ID(N'ascug'), NULL, NULL, NULL, NULL) AS a
	    JOIN sys.indexes AS b ON a.object_id = b.object_id AND a.index_id = b.index_id
	WHERE avg_fragmentation_in_percent > 30 AND a.index_id > 0 AND b.name NOT IN('pk_attachment', 'pk_act_contract', 'pk_attachment_data')
	ORDER BY avg_fragmentation_in_percent DESC;
DECLARE @indexName VARCHAR(128);
DECLARE @tableName VARCHAR(128);
DECLARE @avgFragmentationInPercent FLOAT;

OPEN db_cursor
FETCH NEXT FROM db_cursor INTO @indexName, @tableName, @avgFragmentationInPercent;

SET @endDate = GETDATE();
-- Date diff http://stackoverflow.com/questions/13577898/sql-time-difference-between-two-dates-result-in-hhmmss
SET @sql = 'Analyze query took: ' + CONVERT(VARCHAR(5),DateDiff(s, @startDate, @endDate)/3600)+':'+CONVERT(VARCHAR(5),DateDiff(s, @startDate, @endDate)%3600/60)+':'+CONVERT(VARCHAR(5),(DateDiff(s, @startDate, @endDate)%60));
RAISERROR(@sql, 0, 1) WITH NOWAIT;

WHILE @@FETCH_STATUS = 0
BEGIN
	SET @sql = 'Rebuilding index [' +  @indexName + '] on table [' + @tableName + '] which have fragmentation: ' + LTRIM(STR(@avgFragmentationInPercent)) + '%%';
	RAISERROR(@sql, 0, 1) WITH NOWAIT;

	SET @startDate = GETDATE();
	SET @sql = 'ALTER INDEX ' + @indexName + ' ON ' + @tableName + ' REBUILD WITH (ONLINE = ON)';
	EXEC(@sql);
	SET @endDate = GETDATE();

	SET @sql = '  operation took: ' + CONVERT(VARCHAR(5),DateDiff(s, @startDate, @endDate)/3600)+':'+CONVERT(VARCHAR(5),DateDiff(s, @startDate, @endDate)%3600/60)+':'+CONVERT(VARCHAR(5),(DateDiff(s, @startDate, @endDate)%60))
	-- http://stackoverflow.com/questions/306945/how-do-i-flush-the-print-buffer-in-tsql
	RAISERROR(@sql, 0, 1) WITH NOWAIT;

	FETCH NEXT FROM db_cursor INTO @indexName, @tableName, @avgFragmentationInPercent;
END

CLOSE db_cursor
DEALLOCATE db_cursor

ALTER DATABASE ascug SET RECOVERY FULL;