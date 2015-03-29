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