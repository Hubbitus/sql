USE [msdb]
GO

/****** Object:  Job [INDEXES_STATS_REBUILD]    Script Date: 05/28/2014 18:03:59 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]]    Script Date: 05/28/2014 18:04:00 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @name varchar(1000)
SET @name = ((cast((SELECT SERVERPROPERTY('MachineName')) as varchar(1000)))+'\ant')

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'INDEXES_STATS_REBUILD',
		@enabled=1,
		@notify_level_eventlog=0,
		@notify_level_email=0,
		@notify_level_netsend=0,
		@notify_level_page=0,
		@delete_level=0,
		@description=N'Комплексный пересчёт всех индексов и стетистики с ресемплингом (2 шаг)',
		@category_name=N'[Uncategorized (Local)]',
		@owner_login_name=@name, @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [INDEXES_REBUILD]    Script Date: 05/28/2014 18:04:00 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'INDEXES_REBUILD',
		@step_id=1,
		@cmdexec_success_code=0,
		@on_success_action=3,
		@on_success_step_id=0,
		@on_fail_action=2,
		@on_fail_step_id=0,
		@retry_attempts=0,
		@retry_interval=0,
		@os_run_priority=0, @subsystem=N'TSQL',
		@command=N'USE ascug;

-- ALTER DATABASE ascug SET RECOVERY SIMPLE;

SET QUOTED_IDENTIFIER ON;

SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

DECLARE @dateStart DATETIME = GETDATE();
DECLARE @dateEnd DATETIME;
DECLARE @sql VARCHAR(MAX);

SET @sql = ''Operation run time: '' + CONVERT(VARCHAR, @dateStart, 120);
-- http://stackoverflow.com/questions/306945/how-do-i-flush-the-print-buffer-in-tsql
RAISERROR(@sql, 0, 1) WITH NOWAIT;

-- http://technet.microsoft.com/en-us/library/ms189858.aspx
DECLARE db_cursor CURSOR FOR
WITH st AS (
	SELECT DISTINCT
--		ind.index_id,
		OBJECT_NAME(stat.object_id) as tableName
		,ind.name as indexName
		,stat.avg_fragmentation_in_percent
--		,''|||'' as [|||], *
	FROM
		sys.dm_db_index_physical_stats (DB_ID(N''ascug''), NULL, NULL, NULL, NULL) AS stat
	    JOIN sys.indexes AS ind ON (stat.object_id = ind.object_id AND stat.index_id = ind.index_id)
	WHERE
		stat.index_id > 0 AND stat.object_id NOT IN (SELECT object_id FROM sys.indexes WHERE alloc_unit_type_desc IN (''LOB_DATA'') OR is_disabled = 1)
		AND stat.avg_fragmentation_in_percent > 30
)
SELECT st.tableName, ''Indexes on table ['' + st.tableName + ''] will be rebuild. Indexes fragmentation: '' + LEFT(stringify.indexes_frag, LEN(stringify.indexes_frag) - 1) as log
FROM
	st
	CROSS APPLY(
		SELECT
			indexName + '':'' + CAST(sti.avg_fragmentation_in_percent AS VARCHAR(MAX))+ ''%; ''
		FROM st as sti -- Inner
		WHERE sti.tableName = st.tableName
		FOR XML PATH('''')
	) stringify (indexes_frag)
GROUP BY tableName, stringify.indexes_frag; -- Aggregate to rebuild ALL indexes on table at once

DECLARE @tableName VARCHAR(128);
DECLARE @indLog VARCHAR(1024);

OPEN db_cursor
FETCH NEXT FROM db_cursor INTO @tableName, @indLog;

SET @dateEnd = GETDATE();
EXEC dbo.log_message @dateStart = @dateStart, @dateEnd = @dateEnd, @textHead = ''Select (initial) query took: '';

WHILE @@FETCH_STATUS = 0
BEGIN
	SET @sql = REPLACE(@indLog, ''%'', ''%%'');
	RAISERROR(@sql, 0, 1) WITH NOWAIT;

	SET @sql = ''ALTER INDEX ALL ON '' + @tableName + '' REBUILD WITH (ONLINE = OFF)'';
	EXEC dbo.bench_exec @sql = @sql;

	FETCH NEXT FROM db_cursor INTO @tableName, @indLog;
END

CLOSE db_cursor
DEALLOCATE db_cursor

SET @dateEnd = GETDATE();
EXEC dbo.log_message @dateStart = @dateStart, @dateEnd = @dateEnd, @textHead = ''Total execution time: '';

-- ALTER DATABASE ascug SET RECOVERY FULL;',
		@database_name=N'ascug',
		@flags=4
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [STATS_RESAMPLE]    Script Date: 05/28/2014 18:04:00 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'STATS_RESAMPLE',
		@step_id=2,
		@cmdexec_success_code=0,
		@on_success_action=1,
		@on_success_step_id=0,
		@on_fail_action=2,
		@on_fail_step_id=0,
		@retry_attempts=0,
		@retry_interval=0,
		@os_run_priority=0, @subsystem=N'TSQL',
		@command=N'USE ascug;

EXEC sp_updatestats @resample = ''resample'' ',
		@database_name=N'ascug',
		@flags=4
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Daily at 2:0',
		@enabled=1,
		@freq_type=4,
		@freq_interval=1,
		@freq_subday_type=1,
		@freq_subday_interval=0,
		@freq_relative_interval=0,
		@freq_recurrence_factor=0,
		@active_start_date=20140527,
		@active_end_date=99991231,
		@active_start_time=20000,
		@active_end_time=235959,
		@schedule_uid=N'128c967d-da81-4627-b7ea-74e27e240c52'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO
