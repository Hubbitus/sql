IF OBJECT_ID('[dbo].[bench_exec]') IS NOT NULL
	DROP PROCEDURE dbo.bench_exec;
GO

/**
* Execute given in string SQL code and immediantly print time spent results. Optionally return it in milliseconds and human readable format.
*
* Examples of usage:
* 1) Basic usage:
  DECLARE @sql VARCHAR(MAX) = 'WAITFOR DELAY ''00:00.123'''
  EXEC dbo.bench_exec @sql = @sql
* output:
* Execution of [WAITFOR DELAY '00:00.123'] took: 00:00:00.123
* 2) Advanced usage with all options:
  DECLARE @timeMilliseconds INT, @timeVarchar VARCHAR(12);
  DECLARE @sqlBefore VARCHAR(MAX) = 'WAITFOR DELAY ''00:00:02'''; -- Wait 2 second before
  DECLARE @sqlAfter VARCHAR(MAX) = 'WAITFOR DELAY ''00:00:03'''; -- Wait 3 second, after
  DECLARE @sql VARCHAR(MAX) = 'WAITFOR DELAY ''00:00:01.123''' -- Main code
  EXEC dbo.bench_exec @sql = @sql, @sqlBefore = @sqlBefore, @sqlAfter = @sqlAfter, @timeMilliseconds = @timeMilliseconds OUTPUT, @timeVarchar = @timeVarchar OUTPUT;
  SELECT 'SQL [(' + @sqlBefore + ')' + @sql + ' (' + @sqlAfter + ')] executed in ' + @timeVarchar + ' (' + CAST(@timeMilliseconds as VARCHAR(100)) + ' milliseconds)';
* Result should be:
* in text console:
* Execution of [WAITFOR DELAY '00:00:02'; SET @dateStart = GETDATE(); WAITFOR DELAY '00:00:01.123'; SET @dateEnd = GETDATE(); WAITFOR DELAY '00:00:03'] took: 00:00:01.127
* in sql select result:
* SQL [(WAITFOR DELAY '00:00:02')WAITFOR DELAY '00:00:01.123' (WAITFOR DELAY '00:00:03')] executed in 00:00:01.127 (1127 milliseconds)
* Note about some error in milliseconds calculation and also what @sqlBefore and @sqlAfter time actually excluded!
*
* @param sql VARCHAR(MAX)					Main SQL code to execute.
* @param timeMilliseconds INT=0	OUTPUT		Optional output parameter of milliseconds actual execution of (@sql).
* @param timeVarchar VARCHAR(12)='' OUTPUT	Optional output parameter of human readable representation time spent to @sql esecution like 00:00:00.123.
* @param sqlBefore VARCHAR(MAX)=''			Optional SQL code to execute before @sql. Do not accounted in time. Typically for bunch of SET and BEGIN transaction statements.
* @param sqlAfter VARCHAR(MAX)=''			Optional SQL code to execute after @sql. Do not accounted in time. Typically for bunch of SET and COMMIT/ROLLBACK statements.
*
* @uses log_message
*/
CREATE PROCEDURE dbo.bench_exec(@sql NVARCHAR(MAX), @timeMilliseconds INT = 0 OUTPUT, @timeVarchar VARCHAR(12) = '' OUTPUT, @sqlBefore NVARCHAR(MAX) = '', @sqlAfter NVARCHAR(MAX) = '')
AS
BEGIN
	DECLARE @dateStart DATETIME2;
	DECLARE @dateEnd DATETIME2;
	DECLARE @_sql NVARCHAR(MAX)

	SET @_sql = @sqlBefore + '; SET @dateStart = GETDATE(); ' + @sql + '; SET @dateEnd = GETDATE(); ' + @sqlAfter;
	EXEC sp_executesql @_sql, N'@dateStart DATETIME2 OUTPUT, @dateEnd DATETIME2 OUTPUT', @dateStart OUTPUT, @dateEnd OUTPUT; -- EXEC can't bind variables

	SET @sql = 'Execution of [' + @sql + '] took: ';
	EXEC dbo.log_message @dateStart = @dateStart, @dateEnd = @dateEnd, @textHead = @sql, @timeMilliseconds = @timeMilliseconds OUTPUT, @timeVarchar = @timeVarchar OUTPUT;
END
