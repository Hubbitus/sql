IF OBJECT_ID('[dbo].[batch_delete]') IS NOT NULL
	DROP PROCEDURE dbo.batch_delete;
GO

/**
* Perform delete by @batch rows at once and then sleep 1 millisecond to release locks and do nt lock tables long time. Also perform exceccive logging including estimated time to finish.
* BE CARAEFULL it is intended to commit any bach separately to lock as less resources as possible! So you may got errors on partial of data in non-transaction way!!!
*
* Example of useage:
* EXEC dbo.batch_delete N'DELETE FROM arc_exps_h WHERE channel_id IN( SELECT channel_id FROM channel WHERE orig_id LIKE ''DELETED_%'')', 1000;
*
* @param deleteSql	String with delete code. Something LIKE: 'DELETE FROM arc_expc_h'. MUST start from 'DELETE ' and NOT 'DELETE TOP (111) '!
* @param step		Banch size. Delete will be performed by this pack.
*
* @uses log sp.
*/
CREATE PROCEDURE dbo.batch_delete(@deleteSql NVARCHAR(MAX), @batch INT = 10000)
AS
BEGIN
	--	LEVEL SERIALIZABLE loop delete by 10000 records (10 steps) - wins by benchmarking
	SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
	BEGIN TRANSACTION
	DECLARE @i INT = 1, @total INT;
	DECLARE @timeEstimateDiffMilliseconds INT, @timeMilliseconds INT, @timeMillisecondsPrev INT = 0; -- 2 times to estimate end time
	DECLARE @dateStart DATETIME2 = GETDATE();
	DECLARE @datePrev DATETIME2;
	DECLARE @sql NVARCHAR(MAX), @sqlDel VARCHAR(MAX) = 'DELETE TOP(' + CAST(@batch as VARCHAR(100)) + ') ' + RIGHT(@deleteSql, LEN(@deleteSql) - LEN('DELETE ') - 1);

--	SELECT @total = COUNT(*) FROM arc_exps_h WHERE channel_id IN(SELECT channel_id FROM channel WHERE orig_id LIKE 'DELETED_%');
	SET @sql = 'SELECT @total = COUNT(*) ' + RIGHT(@deleteSql, LEN(@deleteSql) - LEN('DELETE ') - 1);
	EXEC sp_executesql @sql, N'@total INT OUTPUT', @total OUTPUT;

	SET @sql = 'Operation run time: ' + CONVERT(VARCHAR, @dateStart, 121) + '; Rows to delete: ' + CAST(@total as VARCHAR(100)) + ' by ' + CAST(@batch as VARCHAR(100)) + ' at step';
	RAISERROR(@sql, 0, 1) WITH NOWAIT;
	  
	-- We can't rely on @@ROWCOUNT because use dinamic SQL
	WHILE (@i * @batch < @total) BEGIN
	--	DELETE TOP(@batch) FROM arc_exps_h WHERE channel_id IN(SELECT channel_id FROM channel WHERE orig_id LIKE 'DELETED_%')
		EXEC dbo.bench_exec @sql = @sqlDel, @timeMilliseconds = @timeMilliseconds OUTPUT;
		IF (0 = @timeMillisecondsPrev) SET @timeMillisecondsPrev = @timeMilliseconds; -- begin

		SET @timeEstimateDiffMilliseconds = (CEILING(CAST(@total as float)/@batch) - @i) * ((@timeMilliseconds + @timeMillisecondsPrev) / 2);
		SET @sql = 'step:' + CAST(@i as VARCHAR) + '/from:' + CAST(CEILING(CAST(@total as float)/@batch) AS VARCHAR) + '/done:' + CAST(ROUND(CAST(@i as float) / CEILING(CAST(@total as float)/@batch) * 100, 2) as VARCHAR) + '%) Deleted ' + CAST(@i * @batch as VARCHAR) + '/' + CAST(@total as VARCHAR);
		EXEC dbo.log @msg = @sql, @format = '[${cur_time}, spent: ${date_diff_str}, spent from start: ${date_diff_start_str}, estimate end (by 2 last operations) in: ${date_diff_estimate_str}] ${msg}', @dateStart = @dateStart, @timeLastDiffMillisecondsIn = @timeMilliseconds, @timeEstimateDiffMillisecondsIn = @timeEstimateDiffMilliseconds;
		SET @i = @i + 1;
		SET @timeMillisecondsPrev = @timeMilliseconds;
		WAITFOR DELAY '00:00:00.001';
	END

	EXEC dbo.log @msg = 'End full execution.', @format = '[${cur_time}, spent from start: ${date_diff_start_str}] ${msg}', @dateStart = @dateStart;
	-- For check!
	SELECT @total = COUNT(*) FROM arc_exps_h WHERE channel_id IN(SELECT channel_id FROM channel WHERE orig_id LIKE 'DELETED_%');
	SET @datePrev = GETDATE();
	ROLLBACK

	EXEC dbo.log @msg = 'End full execution. Also ROLLBACK done', @format = '[${cur_time}, spent: ${date_diff_str}, spent from start: ${date_diff_start_str}] ${msg}', @datePrev = @datePrev, @dateStart = @dateStart;
END