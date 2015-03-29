USE [msdb]
GO

DELETE FROM backupfile
GO
DELETE FROM backupfilegroup
GO
DELETE FROM restorefile
GO
DELETE FROM restorefilegroup
GO
DELETE FROM restorehistory
GO
DELETE FROM backupset
GO

USE [msdb]
GO

/****** Object:  Job [Full]    Script Date: 08/28/2013 12:21:02 ******/
BEGIN TRANSACTION

DECLARE @ReturnCode INT

SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 08/28/2013 12:21:02 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
DECLARE @name varchar(1000)
SET @name = ((cast((SELECT SERVERPROPERTY('MachineName')) as varchar(1000)))+'\ant')
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Full',
		@enabled=1,
		@notify_level_eventlog=0,
		@notify_level_email=0,
		@notify_level_netsend=0,
		@notify_level_page=0,
		@delete_level=0,
		@description=N'Описание недоступно.',
		@category_name=N'Database Maintenance',
		@owner_login_name=@name, @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [ascug]    Script Date: 08/28/2013 12:21:03 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'ascug',
		@step_id=1,
		@cmdexec_success_code=0,
		@on_success_action=3,
		@on_success_step_id=0,
		@on_fail_action=3,
		@on_fail_step_id=0,
		@retry_attempts=0,
		@retry_interval=0,
		@os_run_priority=0, @subsystem=N'TSQL',
		@command=N'DECLARE @path varchar(1000)

SET @path = ''D:\imus\backup\arhiv\Full.BAK''

BACKUP DATABASE [ASCUG]
	TO  DISK = @path
		WITH
			NOFORMAT,
			INIT,
			COMPRESSION',
		@database_name=N'ascug',
		@flags=4
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [master]    Script Date: 08/28/2013 12:21:03 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'master',
		@step_id=2,
		@cmdexec_success_code=0,
		@on_success_action=3,
		@on_success_step_id=0,
		@on_fail_action=3,
		@on_fail_step_id=0,
		@retry_attempts=0,
		@retry_interval=0,
		@os_run_priority=0, @subsystem=N'TSQL',
		@command=N'DECLARE @path varchar(1000)

SET @path = ''D:\imus\backup\arhiv\master.BAK''

BACKUP DATABASE [MASTER]
	TO  DISK = @path
		WITH
			NOFORMAT,
			INIT,
			COMPRESSION',
		@database_name=N'master',
		@flags=4
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [model]    Script Date: 08/28/2013 12:21:03 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'model',
		@step_id=3,
		@cmdexec_success_code=0,
		@on_success_action=3,
		@on_success_step_id=0,
		@on_fail_action=3,
		@on_fail_step_id=0,
		@retry_attempts=0,
		@retry_interval=0,
		@os_run_priority=0, @subsystem=N'TSQL',
		@command=N'DECLARE @path varchar(1000)

SET @path = ''D:\imus\backup\arhiv\model.BAK''

BACKUP DATABASE [MODEL]
	TO  DISK = @path
		WITH
			NOFORMAT,
			INIT,
			COMPRESSION',
		@database_name=N'model',
		@flags=4
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [msdb]    Script Date: 08/28/2013 12:21:03 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'msdb',
		@step_id=4,
		@cmdexec_success_code=0,
		@on_success_action=1,
		@on_success_step_id=0,
		@on_fail_action=2,
		@on_fail_step_id=0,
		@retry_attempts=0,
		@retry_interval=0,
		@os_run_priority=0, @subsystem=N'TSQL',
		@command=N'DECLARE @path varchar(1000)

SET @path = ''D:\imus\backup\arhiv\msdb.BAK''

BACKUP DATABASE [MSDB]
	TO  DISK = @path
		WITH
			NOFORMAT,
			INIT,
			COMPRESSION',
		@database_name=N'msdb',
		@flags=4
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Holiday',
		@enabled=1,
		@freq_type=8,
		@freq_interval=1,
		@freq_subday_type=1,
		@freq_subday_interval=0,
		@freq_relative_interval=0,
		@freq_recurrence_factor=1,
		@active_start_date=20130826,
		@active_end_date=99991231,
		@active_start_time=0,
		@active_end_time=235959,
		@schedule_uid=N'21df73e3-32e9-4cb9-b82f-64d0ee7c93ba'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO

USE [msdb]
GO

/****** Object:  Job [Diff]    Script Date: 08/28/2013 12:21:12 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 08/28/2013 12:21:12 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
DECLARE @name varchar(1000)
SET @name = ((cast((SELECT SERVERPROPERTY('MachineName')) as varchar(1000)))+'\ant')
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Diff',
		@enabled=1,
		@notify_level_eventlog=0,
		@notify_level_email=0,
		@notify_level_netsend=0,
		@notify_level_page=0,
		@delete_level=0,
		@description=N'Описание недоступно.',
		@category_name=N'Database Maintenance',
		@owner_login_name=@name, @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Diff]    Script Date: 08/28/2013 12:21:12 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Diff',
		@step_id=1,
		@cmdexec_success_code=0,
		@on_success_action=1,
		@on_success_step_id=0,
		@on_fail_action=2,
		@on_fail_step_id=0,
		@retry_attempts=0,
		@retry_interval=0,
		@os_run_priority=0, @subsystem=N'TSQL',
		@command=N'DECLARE @path varchar(1000)

SET DATEFIRST 1

SET @path = ''D:\imus\backup\arhiv\Diff_'' + (select cast(datepart(dw,getdate()) as VARCHAR)) + ''.BAK''


BACKUP DATABASE [ASCUG]
	TO  DISK = @path
		WITH
			NOFORMAT,
			INIT,
			COMPRESSION,
			DIFFERENTIAL',
		@database_name=N'ascug',
		@flags=4
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Daily',
		@enabled=1,
		@freq_type=8,
		@freq_interval=126,
		@freq_subday_type=1,
		@freq_subday_interval=4,
		@freq_relative_interval=0,
		@freq_recurrence_factor=1,
		@active_start_date=20130826,
		@active_end_date=99991231,
		@active_start_time=0,
		@active_end_time=235959,
		@schedule_uid=N'0d37d5d1-f34a-4ced-bafd-563166c54783'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO

USE [msdb]
GO

/****** Object:  Job [Inc]    Script Date: 08/28/2013 12:21:23 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 08/28/2013 12:21:23 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
DECLARE @name varchar(1000)
SET @name = ((cast((SELECT SERVERPROPERTY('MachineName')) as varchar(1000)))+'\ant')
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Inc',
		@enabled=1,
		@notify_level_eventlog=0,
		@notify_level_email=0,
		@notify_level_netsend=0,
		@notify_level_page=0,
		@delete_level=0,
		@description=N'Описание недоступно.',
		@category_name=N'Database Maintenance',
		@owner_login_name=@name, @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [inc]    Script Date: 08/28/2013 12:21:24 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'inc',
		@step_id=1,
		@cmdexec_success_code=0,
		@on_success_action=1,
		@on_success_step_id=0,
		@on_fail_action=2,
		@on_fail_step_id=0,
		@retry_attempts=0,
		@retry_interval=0,
		@os_run_priority=0, @subsystem=N'TSQL',
		@command=N'DECLARE @path varchar(1000)

SET @path = ''D:\imus\backup\arhiv\Inc_'' + (select cast(datepart(hh,getdate()) as VARCHAR)) + ''.BAK''


BACKUP LOG [ASCUG]
	TO  DISK = @path
		WITH
			NOFORMAT,
			INIT,
			COMPRESSION',
		@database_name=N'ascug',
		@flags=4
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Daily',
		@enabled=1,
		@freq_type=4,
		@freq_interval=1,
		@freq_subday_type=8,
		@freq_subday_interval=1,
		@freq_relative_interval=0,
		@freq_recurrence_factor=0,
		@active_start_date=20130827,
		@active_end_date=99991231,
		@active_start_time=10000,
		@active_end_time=235959,
		@schedule_uid=N'9df5a083-6f36-42bb-9108-ca677cc91aab'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO

USE [msdb]
GO

/****** Object:  Job [Stat]    Script Date: 08/07/2013 18:55:35 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 08/07/2013 18:55:35 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
DECLARE @name varchar(1000)
SET @name = ((cast((SELECT SERVERPROPERTY('MachineName')) as varchar(1000)))+'\ant')
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Stat',
		@enabled=1,
		@notify_level_eventlog=0,
		@notify_level_email=0,
		@notify_level_netsend=0,
		@notify_level_page=0,
		@delete_level=0,
		@description=N'Описание недоступно.',
		@category_name=N'Database Maintenance',
		@owner_login_name=@name, @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Stat]    Script Date: 08/07/2013 18:55:36 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Stat',
		@step_id=1,
		@cmdexec_success_code=0,
		@on_success_action=1,
		@on_success_step_id=0,
		@on_fail_action=2,
		@on_fail_step_id=0,
		@retry_attempts=0,
		@retry_interval=0,
		@os_run_priority=0, @subsystem=N'TSQL',
		@command=N'EXEC sp_updatestats',
		@database_name=N'ascug',
		@flags=4
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Hourly',
		@enabled=1,
		@freq_type=4,
		@freq_interval=1,
		@freq_subday_type=8,
		@freq_subday_interval=2,
		@freq_relative_interval=0,
		@freq_recurrence_factor=0,
		@active_start_date=20130827,
		@active_end_date=99991231,
		@active_start_time=0,
		@active_end_time=235959,
		@schedule_uid=N'464e12f7-52fb-46f5-a403-f570804b31fd'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO

USE [msdb]
GO

/****** Object:  Job [Stat_Resample]    Script Date: 08/29/2013 17:26:52 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 08/29/2013 17:26:52 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
DECLARE @name varchar(1000)
SET @name = ((cast((SELECT SERVERPROPERTY('MachineName')) as varchar(1000)))+'\ant')
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Stat_Resample',
		@enabled=1,
		@notify_level_eventlog=0,
		@notify_level_email=0,
		@notify_level_netsend=0,
		@notify_level_page=0,
		@delete_level=0,
		@description=N'Описание недоступно.',
		@category_name=N'Database Maintenance',
		@owner_login_name=@name, @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Stat]    Script Date: 08/29/2013 17:26:53 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Stat_resample',
		@step_id=1,
		@cmdexec_success_code=0,
		@on_success_action=1,
		@on_success_step_id=0,
		@on_fail_action=2,
		@on_fail_step_id=0,
		@retry_attempts=0,
		@retry_interval=0,
		@os_run_priority=0, @subsystem=N'TSQL',
		@command=N'EXEC sp_updatestats @resample = ''resample'' ',
		@database_name=N'ascug',
		@flags=4
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Daily',
		@enabled=1,
		@freq_type=4,
		@freq_interval=1,
		@freq_subday_type=1,
		@freq_subday_interval=2,
		@freq_relative_interval=0,
		@freq_recurrence_factor=0,
		@active_start_date=20130827,
		@active_end_date=99991231,
		@active_start_time=20000,
		@active_end_time=235959,
		@schedule_uid=N'1c00a7fe-1697-4042-a369-c319fa48a422'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO