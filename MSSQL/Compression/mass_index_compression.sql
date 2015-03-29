ALTER DATABASE ascug SET RECOVERY SIMPLE;

SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

DECLARE @dateStart DATETIME2 = GETDATE();
DECLARE @dateEnd DATETIME2;
DECLARE @sql VARCHAR(MAX);

SET @sql = 'Operation run time: ' + CONVERT(VARCHAR, @dateStart, 120);
EXEC dbo.log @msg = @sql

-- http://technet.microsoft.com/en-us/library/ms189858.aspx
DECLARE db_cursor CURSOR FOR
	-- http://www.chilledsql.com/welcome/tip_category_compression/tip_detail_compression_compressalltablesandindexes
	-- http://stackoverflow.com/questions/16988326/query-all-table-data-and-index-compression
	SELECT
		   'ALTER INDEX [' + i.[name] + '] ON [' + s.[name] + '].[' + o.[name] + '] REBUILD WITH (DATA_COMPRESSION=PAGE);'
	FROM
		sys.objects AS o WITH (NOLOCK)
		JOIN sys.indexes AS i WITH (NOLOCK) ON (o.[object_id] = i.[object_id])
		JOIN sys.schemas s WITH (NOLOCK) ON (o.[schema_id] = s.[schema_id])
		JOIN sys.dm_db_partition_stats AS ps WITH (NOLOCK) ON (i.[object_id] = ps.[object_id] AND ps.[index_id] = i.[index_id])
		JOIN sys.partitions AS p ON(p.object_id = i.object_id AND p.[index_id] = i.[index_id])
	WHERE
		o.type = 'U'
		AND i.[index_id] > 0
		AND p.data_compression_desc NOT IN('PAGE')
		--AND i.Name LIKE '%%'   -- filter by index name
		--AND o.Name LIKE '%%'   -- filter by table name
		--DB_NAME(OBJECTPROPERTY(o.object_id, 'ownerId')) = 'ascug'
	ORDER BY ps.[reserved_page_count]

OPEN db_cursor
FETCH NEXT FROM db_cursor INTO @sql;

SET @dateEnd = GETDATE();
EXEC dbo.log @msg = 'Select (initial) query', @datePrev = @dateStart, @dateLast = @dateEnd, @format = '[${cur_time}] ${msg}: spent ${date_diff_str} (ms: ${date_diff_milliseconds})'

WHILE @@FETCH_STATUS = 0
BEGIN
	EXEC dbo.log @msg = @sql;
	EXEC dbo.bench_exec @sql = @sql;

	FETCH NEXT FROM db_cursor INTO @sql;
END

CLOSE db_cursor
DEALLOCATE db_cursor

SET @dateEnd = GETDATE();
EXEC dbo.log @dateStart = @dateStart, @dateLast = @dateEnd, @msg = 'Total execution time', @format = '[${cur_time}] ${msg}: ${date_diff_start_str} (ms: ${date_diff_start_milliseconds})';
ALTER DATABASE ascug SET RECOVERY FULL;