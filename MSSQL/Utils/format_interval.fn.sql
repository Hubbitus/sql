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
