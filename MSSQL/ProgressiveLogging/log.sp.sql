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