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
	SET XACT_ABORT ON;
	DBCC TRACEON(1204, -1);

	-- LEVEL SERIALIZABLE loop delete by 10000 records (10 steps) - wins by benchmarking
	SET TRANSACTION ISOLATION LEVEL SERIALIZABLE

	DECLARE @i INT = 1, @total INT;
	DECLARE @timeEstimateDiffMilliseconds INT, @timeMilliseconds INT, @timeMillisecondsPrev INT = 0; -- 2 times to estimate end time
	DECLARE @dateStart DATETIME2 = GETDATE();
	DECLARE @datePrev DATETIME2;
	DECLARE @sql NVARCHAR(MAX), @msg NVARCHAR(MAX), @sqlDel VARCHAR(MAX) = 'DELETE TOP(' + CAST(@batch as VARCHAR(100)) + ') ' + RIGHT(@deleteSql, LEN(@deleteSql) - LEN('DELETE ') - 1);

--	SELECT @total = COUNT(*) FROM arc_exps_h WHERE channel_id IN(SELECT channel_id FROM channel WHERE orig_id LIKE 'DELETED_%');
	SET @sql = 'SELECT @total = COUNT(*) ' + RIGHT(@deleteSql, LEN(@deleteSql) - LEN('DELETE ') - 1);
	EXEC sp_executesql @sql, N'@total INT OUTPUT', @total OUTPUT;

	SET @msg = 'Operation run time: ' + CONVERT(VARCHAR, @dateStart, 121) + '; Rows to delete: ' + CAST(@total as VARCHAR(100)) + ' by ' + CAST(@batch as VARCHAR(100)) + ' at step';
	RAISERROR(@msg, 0, 1) WITH NOWAIT;

	-- We can't rely on @@ROWCOUNT because use dinamic SQL
	WHILE (@i * @batch < @total) BEGIN
	--	DELETE TOP(@batch) FROM arc_exps_h WHERE channel_id IN(SELECT channel_id FROM channel WHERE orig_id LIKE 'DELETED_%')
		BEGIN TRY
			BEGIN TRANSACTION
				EXEC dbo.bench_exec @sql = @sqlDel, @timeMilliseconds = @timeMilliseconds OUTPUT;
				IF (0 = @timeMillisecondsPrev) SET @timeMillisecondsPrev = @timeMilliseconds; -- begin

				SET @timeEstimateDiffMilliseconds = (CEILING(CAST(@total as float)/@batch) - @i) * ((@timeMilliseconds + @timeMillisecondsPrev) / 2);
				SET @msg = 'step:' + CAST(@i as VARCHAR) + '/from:' + CAST(CEILING(CAST(@total as float)/@batch) AS VARCHAR) + '/done:' + CAST(ROUND(CAST(@i as float) / CEILING(CAST(@total as float)/@batch) * 100, 2) as VARCHAR) + '%) Deleted ' + CAST(@i * @batch as VARCHAR) + '/' + CAST(@total as VARCHAR);
				EXEC dbo.log @msg = @msg, @format = '[${cur_time}, spent: ${date_diff_str}, spent from start: ${date_diff_start_str}, estimate end (by 2 last operations) in: ${date_diff_estimate_str}] ${msg}', @dateStart = @dateStart, @timeLastDiffMillisecondsIn = @timeMilliseconds, @timeEstimateDiffMillisecondsIn = @timeEstimateDiffMilliseconds;
				SET @i = @i + 1;
				SET @timeMillisecondsPrev = @timeMilliseconds;
			COMMIT;
		END TRY
		BEGIN CATCH
			SET @msg = 'ERROR happened! ErrorNumber: ' + CAST(ERROR_NUMBER() as VARCHAR(1000)) + '; ErrorSeverity: ' + CAST(ERROR_SEVERITY() as VARCHAR(1000)) + 'ErrorState: ' + CAST(ERROR_STATE() as VARCHAR(1000)) + '; ErrorProcedure: ' + ERROR_PROCEDURE() + '; ErrorLine: ' + CAST(ERROR_LINE() as VARCHAR(1000)) + '; ErrorMessage: ' + CAST(ERROR_MESSAGE() as VARCHAR(1000)) + ';';
			EXEC dbo.log @msg = @msg;
		END CATCH

		WAITFOR DELAY '00:00:00.001';
	END

	EXEC dbo.log @msg = 'End full execution.', @format = '[${cur_time}, spent from start: ${date_diff_start_str}] ${msg}', @dateStart = @dateStart;
END