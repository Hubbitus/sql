-- file [./Utils/format_interval.fn.sql]
IF OBJECT_ID('[dbo].[format_interval]') IS NOT NULL
	DROP FUNCTION dbo.format_interval;
GO

/**
* Function to format date intervals into human readable format like "01:23:45.123".
* Unfortunately MSSQL does not allow function overloading to provide 2 functions with different arguments like:
* 1) CREATE FUNCTION dbo.format_interval(@dateStart DATETIME2, @dateEnd DATETIME2)
* 2) CREATE FUNCTION dbo.format_interval(@diffMilliseconds INT)
* So, arguments checked on runtime and behave appropriately.
* In first form only @dateStart parameter required, second, if NULL will be assumed AS GETDATE().
* In second form dates must be NULL, and only @diffMilliseconds considerated.
*
* Example of usage:
* 1) SELECT dbo.format_interval(GETDATE(), GETDATE() + 1, NULL) as IntervalStr
* Result: 24:00:00.000
* 2) SELECT dbo.format_interval(NULL, NULL, 12345678) as IntervalStr
* Result: 03:25:45.678
*/
CREATE FUNCTION dbo.format_interval(@dateStart DATETIME2 = NULL, @dateEnd DATETIME2 = NULL, @diffMilliseconds INT = NULL)
RETURNS CHAR(12)
AS
BEGIN
	DECLARE @sub INT;

	IF (@dateStart IS NULL) BEGIN
		IF (@diffMilliseconds IS NULL) BEGIN
			RETURN 'You must provide not null @dateStart or @diffMilliseconds parameters of format_interval()';
		END

		SET @sub = @diffMilliseconds;
	END
	ELSE
		IF (@dateEnd IS NULL) BEGIN
			SET @sub = DateDiff(MILLISECOND, @dateStart, GETDATE());
		END
		ELSE
			SET @sub = DateDiff(MILLISECOND, @dateStart, @dateEnd);


	-- Padding solution from: http://stackoverflow.com/questions/121864/most-efficient-t-sql-way-to-pad-a-varchar-on-the-left-to-a-certain-length
	RETURN RIGHT('0' + CAST(@sub / 3600000 as VARCHAR)/*hours*/, 2) + ':' + RIGHT('0' + CAST(@sub / 1000 / 60 % 60 as VARCHAR), 2)/*minutes*/ + ':' + RIGHT('0' + CAST(@sub / 1000 % 60 as VARCHAR), 2) /*seconds*/ + '.' + RIGHT('00' + CAST(@sub % 1000 as VARCHAR), 3) /*milliseconds*/;
END

GO

-- /file [./Utils/format_interval.fn.sql]
-- file [./ProgressiveLogging/log_message.sp.sql]
-- Can't be FUNCTION bacause RAISERROR used
IF OBJECT_ID('[dbo].[log_message]') IS NOT NULL
	DROP PROCEDURE dbo.log_message;
GO

/**
* example usage:
 DECLARE @dateStart DATETIME = GETDATE() - 1;
 EXEC dbo.log_message @dateStart = @dateStart, @textHead = 'Operation took: '
* output:
* Operation took: 24:0:0.123
*
* @deprecated since log.sp introduced
*/
CREATE PROCEDURE dbo.log_message(@dateStart DATETIME2, @dateEnd DATETIME2 = null, @textHead VARCHAR(1024) = '', @textTrail VARCHAR(1024) = '', @timeMilliseconds INT = 0 OUTPUT, @timeVarchar VARCHAR(12) = '' OUTPUT)
-- Datetime2 is more accurate than datetime: http://stackoverflow.com/questions/1334143/sql-server-datetime2-vs-datetime
AS
BEGIN
	IF (@dateEnd IS NULL)
		SET @dateEnd = GETDATE()

	DECLARE @sql VARCHAR(MAX);
	SET @timeMilliseconds = DATEDIFF(MILLISECOND, @dateStart, @dateEnd);
	SET @timeVarchar = dbo.format_interval(NULL, NULL, @timeMilliseconds);
	SET @sql = REPLACE(@textHead + @timeVarchar + @textTrail, '%', '%%'); -- % has special meaning for RAISERROR
	-- http://stackoverflow.com/questions/306945/how-do-i-flush-the-print-buffer-in-tsql
	RAISERROR(@sql, 0, 1) WITH NOWAIT;
END
GO

-- /file [./ProgressiveLogging/log_message.sp.sql]
-- file [./ProgressiveLogging/log.sp.sql]
-- Can't be FUNCTION bacause RAISERROR used
IF OBJECT_ID('[dbo].[log]') IS NOT NULL
	DROP PROCEDURE dbo.log;
GO

/**
* Common method to log runtime messages interactively.
* Unfortunately TSQL have no classes to incapsulate some data in it, so all parameters like dates must be handled in outer code.
* But provided format string to substitute parameters which are:
* ${cur_time}							- Will be substituted by value of CONVERT(VARCHAR, GETDATE(), 121)
* ${date_diff_str}						- If provides @datePrev and @dateLast will be substituted by human readable range spent time like '01:02:03.456'. (Value optionally may be returned in output parameter @timeLastDiffStr).
* ${date_diff_milliseconds}				- Similar to _str, but diff in milliseconds. (Value optionally may be returned in output parameter @timeLastDiffMilliseconds)
* ${date_diff_start_str}				- If provided @dateStart and @dateLast will be substituted by its diff in human readable format like '01:02:03.456'. (Value optionally may be returned in output parameter @timeStartDiffStr).
* ${date_diff_start_milliseconds}		- Similar to _str, but diff in milliseconds. (Value optionally may be returned in output parameter @timeStartDiffMilliseconds)
* ${date_diff_estimate_str}				- 
* ${date_diff_estimate_milliseconds}	- Both available only if @timeEstimateDiffMillisecondsIn provided.
* 
* ${msg}
*
* @param msg NVARCHAR(MAX)
* @param format NVARCHAR(MAX) = '[${cur_time}] ${msg}'
* @param dateStart DATETIME2 = null						- See ${date_diff_start_*} description before.
* @param datePrev DATETIME2 = null						- See ${date_diff_*} description before.
* @param dateLast DATETIME2 = null						- See ${date_diff_*} description before.
* @param timeEstimateDiffMillisecondsIn INT = 0			- Estimated end time in milliseconds. If provided in @format became available ${date_diff_estimate_milliseconds} and ${date_diff_estimate_str}
* @param timeLastDiffMillisecondsIn INT = 0
* @param timeLastDiffMilliseconds INT = 0 OUTPUT		- Will be equals @timeLastDiffMilliseconds (primary for pass some ranges, f.e. from bench_exec) if it is not NULL OR DATEDIFF(MILLISECOND, @datePrev, @dateLast)
* @param timeLastDiffStr VARCHAR(12) = '' OUTPUT		- See ${date_diff_*} description before.
* @param timeStartDiffMilliseconds INT = 0 OUTPUT		- See ${date_diff_start_*} description before.
* @param timeStartDiffStr VARCHAR(12) = '' OUTPUT		- See ${date_diff_start_*} description before.
*
* Examples of usage:
* 1) Basic usage
* EXEC dbo.log @msg = 'Just message to log', @format = '${msg}'
* output:
* Just message to log
* 2) Message in default format with current date:
* EXEC dbo.log @msg = 'Message to log with timestamp'
* output:
* [2014-06-10 19:53:05.660] Message to log with timestamp
* 3) Demonstrate all parameters:
DECLARE @dateStart DATETIME2 = GETDATE() - 2, @datePrev DATETIME2 = GETDATE() - 1, @dateLast DATETIME2 = GETDATE();
EXEC dbo.log @msg = 'Excesive rich log message', @format = '[${cur_time}; spent ${date_diff_str}(ms: ${date_diff_milliseconds}); spent from start ${date_diff_start_str}(ms: ${date_diff_start_milliseconds})] ${msg}', @dateStart = @dateStart, @datePrev = @datePrev, @dateLast = @dateLast
* output:
* [2014-06-10 19:57:56.643; spent 24:00:00.000(ms: 86400000); spent from start 48:00:00.000(ms: 172800000)] Excesive rich log message
*/
CREATE PROCEDURE dbo.log(@msg NVARCHAR(MAX), @format NVARCHAR(MAX) = '[${cur_time}] ${msg}', @dateStart DATETIME2 = null, @datePrev DATETIME2 = null, @dateLast DATETIME2 = null, @timeEstimateDiffMillisecondsIn INT = 0, @timeLastDiffMillisecondsIn INT = null, @timeLastDiffMilliseconds INT = 0 OUTPUT, @timeLastDiffStr VARCHAR(12) = '' OUTPUT, @timeStartDiffMilliseconds INT = 0 OUTPUT, @timeStartDiffStr VARCHAR(12) = '' OUTPUT)
-- Datetime2 is more accurate than datetime: http://stackoverflow.com/questions/1334143/sql-server-datetime2-vs-datetime
AS
BEGIN
	IF (@dateLast IS NULL)
		SET @dateLast = GETDATE()

	DECLARE @txt NVARCHAR(MAX);
	SET @timeLastDiffMilliseconds = CASE WHEN @timeLastDiffMillisecondsIn IS NOT NULL THEN @timeLastDiffMillisecondsIn ELSE DATEDIFF(MILLISECOND, @datePrev, @dateLast) END;
	SET @timeLastDiffStr = CASE WHEN @timeLastDiffMilliseconds IS NOT NULL THEN dbo.format_interval(NULL, NULL, @timeLastDiffMilliseconds) ELSE '' END;
	SET @timeStartDiffMilliseconds = DATEDIFF(MILLISECOND, @dateStart, @dateLast);
	SET @timeStartDiffStr = CASE WHEN @timeStartDiffMilliseconds IS NOT NULL THEN dbo.format_interval(NULL, NULL, @timeStartDiffMilliseconds) ELSE '' END;
	SET @txt =
		REPLACE(
			REPLACE(
				REPLACE(
					REPLACE(
						REPLACE(
							REPLACE(
								REPLACE(
									REPLACE(
										REPLACE(
											@format
											,'${msg}'
											,@msg
										)
										,'${cur_time}'
										,CONVERT(VARCHAR, GETDATE(), 121)
									)
									,'${date_diff_str}'
									,@timeLastDiffStr
								)
								,'${date_diff_milliseconds}'
								,CASE WHEN @timeLastDiffMilliseconds IS NOT NULL THEN @timeLastDiffMilliseconds ELSE '' END
							)
							,'${date_diff_start_str}'
							,@timeStartDiffStr
						)
						,'${date_diff_start_milliseconds}'
						,CASE WHEN @timeStartDiffMilliseconds IS NOT NULL THEN @timeStartDiffMilliseconds ELSE '' END
					)
					,'${date_diff_estimate_str}'
					,dbo.format_interval(NULL, NULL, @timeEstimateDiffMillisecondsIn)
				)
				,'${date_diff_estimate_milliseconds}'
				,@timeEstimateDiffMillisecondsIn
			)
			,'%'
			,'%%' -- % has special meaning for RAISERROR
		);
	-- http://stackoverflow.com/questions/306945/how-do-i-flush-the-print-buffer-in-tsql
	RAISERROR(@txt, 0, 1) WITH NOWAIT;
END
GO

-- /file [./ProgressiveLogging/log.sp.sql]
-- file [./Benchmarking/bench_exec.sp.sql]
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

GO

-- /file [./Benchmarking/bench_exec.sp.sql]

GO

