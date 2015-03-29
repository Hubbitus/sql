IF (OBJECT_ID('dbo.sp_drop_table_identity') IS NOT NULL)
	DROP PROCEDURE dbo.sp_drop_table_identity;
GO

CREATE PROCEDURE dbo.sp_drop_table_identity @tableName VARCHAR(256) AS
BEGIN
	set xact_abort on;

	DECLARE @sql VARCHAR (4096);
	DECLARE @sqlTableConstraints VARCHAR (4096);
	DECLARE @tmpTableName VARCHAR(256) = @tableName + '_noident_temp';

	BEGIN TRANSACTION

	-- 1) Create temporary table with edentical structure except identity
	-- Idea borrowed from http://stackoverflow.com/questions/21547/in-sql-server-how-do-i-generate-a-create-table-statement-for-a-given-table
	-- modified to ommit Identity and honor all constraints, not primary key only!
	SELECT
		@sql = 'CREATE TABLE [' + so.name + '_noident_temp] (' + o.list + ')'
		+ CHAR(10) + ' WITH (DATA_COMPRESSION = ' + (SELECT p.data_compression_desc FROM sys.partitions AS p JOIN sys.tables AS t ON (t.object_id = p.object_id) WHERE p.index_id in (0,1) AND t.name = so.name) + ')'
		+ ' ' + j.list
	FROM sysobjects so
	CROSS APPLY (
		SELECT
			' [' + column_name + '] '
			+ data_type
			+ CASE data_type
				WHEN 'sql_variant' THEN ''
				WHEN 'text' THEN ''
				WHEN 'ntext' THEN ''
				WHEN 'xml' THEN ''
				WHEN 'decimal' THEN '(' + CAST(numeric_precision as VARCHAR) + ', ' + CAST(numeric_scale as VARCHAR) + ')'
				WHEN 'numeric' THEN '(' + CAST(numeric_precision as VARCHAR) + ', ' + CAST(numeric_scale as VARCHAR) + ')'
				ELSE COALESCE('(' + CASE WHEN character_maximum_length = -1 THEN 'MAX' ELSE CAST(character_maximum_length as VARCHAR) END + ')', '')
			END
			+ ' '
			/* + case when exists ( -- Identity skip
			select id from syscolumns
			where object_name(id)=so.name
			and name=column_name
			and columnproperty(id,name,'IsIdentity') = 1
			) then
			'IDENTITY(' +
			cast(ident_seed(so.name) as varchar) + ',' +
			cast(ident_incr(so.name) as varchar) + ')'
			else ''
			end + ' ' */
			+ CASE WHEN IS_NULLABLE = 'No' THEN 'NOT ' ELSE '' END
			+ 'NULL'
			+ CASE WHEN information_schema.columns.column_default IS NOT NULL THEN ' DEFAULT ' + information_schema.columns.column_default ELSE '' END
			+ ','
		FROM
			INFORMATION_SCHEMA.COLUMNS
		WHERE table_name = so.name
		ORDER BY ordinal_position
		FOR XML PATH('')
	) o (list)
	CROSS APPLY(
		SELECT
			CHAR(10) + 'ALTER TABLE ' + @tableName + '_noident_temp ADD ' + LEFT(alt, LEN(alt)-1)
		FROM(
			SELECT
				CHAR(10)
				+ ' CONSTRAINT ' + tc.constraint_name  + '_noident_temp ' + tc.constraint_type + ' (' + LEFT(c.list, LEN(c.list)-1) + ')'
				+ COALESCE(CHAR(10) + r.list, ', ')
			FROM
				information_schema.table_constraints tc
				CROSS APPLY(
					SELECT
						'[' + kcu.column_name + '], '
					FROM
						information_schema.key_column_usage kcu
					WHERE
						kcu.constraint_name = tc.constraint_name
					ORDER BY
						kcu.ordinal_position
					FOR XML PATH('')
				) c (list)
				OUTER APPLY(
					-- http://stackoverflow.com/questions/3907879/sql-server-howto-get-foreign-key-reference-from-information-schema
					SELECT
						'  REFERENCES [' + kcu1.constraint_schema + '].' + '[' + kcu2.table_name + ']' + '([' + kcu2.column_name + ']) '
						+ CHAR(10)
						+ '    ON DELETE ' + rc.delete_rule
						+ CHAR(10)
						+ '    ON UPDATE ' + rc.update_rule + ', '
					FROM information_schema.referential_constraints as rc
						JOIN information_schema.key_column_usage as kcu1 ON (kcu1.constraint_catalog = rc.constraint_catalog AND kcu1.constraint_schema = rc.constraint_schema AND kcu1.constraint_name = rc.constraint_name)
						JOIN information_schema.key_column_usage as kcu2 ON (kcu2.constraint_catalog = rc.unique_constraint_catalog AND kcu2.constraint_schema = rc.unique_constraint_schema AND kcu2.constraint_name = rc.unique_constraint_name AND kcu2.ordinal_position = KCU1.ordinal_position)
					WHERE
						kcu1.constraint_catalog = tc.constraint_catalog AND kcu1.constraint_schema = tc.constraint_schema AND kcu1.constraint_name = tc.constraint_name
				) r (list)
			WHERE tc.table_name = @tableName
			FOR XML PATH('')
		) a (alt)
	) j (list)
	WHERE
		xtype = 'U'
	AND name NOT IN ('dtproperties')
	AND so.name = @tableName

	--SELECT @sql as '1) @sql';
	print '1) @sql: ' + COALESCE(@sql, '<null>');
	EXECUTE(@sql);

	-- 2) Obtain current back references on our table from others to reenable it later
	-- http://stackoverflow.com/questions/3907879/sql-server-howto-get-foreign-key-reference-from-information-schema
	SELECT
		@sqlTableConstraints = (
			SELECT
				'ALTER TABLE [' + kcu1.constraint_schema + '].' + '[' + kcu1.table_name + ']'
				+ ' ADD CONSTRAINT ' + kcu1.constraint_name + '_noident_temp FOREIGN KEY ([' + kcu1.column_name + '])'
				+ CHAR(10)
				+ '  REFERENCES ['  + kcu2.table_schema + '].[' + kcu2.table_name + ']([' + kcu2.column_name + '])'
				+ CHAR(10)
				+ '    ON DELETE ' + rc.delete_rule
				+ CHAR(10)
				+ '    ON UPDATE ' + rc.update_rule + ' '
			FROM information_schema.referential_constraints as rc
				JOIN information_schema.key_column_usage as kcu1 ON (kcu1.constraint_catalog = rc.constraint_catalog AND kcu1.constraint_schema = rc.constraint_schema AND kcu1.constraint_name = rc.constraint_name)
				JOIN information_schema.key_column_usage as kcu2 ON (kcu2.constraint_catalog = rc.unique_constraint_catalog AND kcu2.constraint_schema = rc.unique_constraint_schema AND kcu2.constraint_name = rc.unique_constraint_name AND kcu2.ordinal_position = KCU1.ordinal_position)
			WHERE
				kcu2.table_name = @tableName
			FOR XML PATH('')
		);
	--SELECT @sqlTableConstraints as '8) @sqlTableConstraints';
	print '2(8)) @sqlTableConstraints: ' + COALESCE(@sqlTableConstraints, '<null>');
	-- Execute at end

	-- 3) Drop outer references for switch (structure must be identical: http://msdn.microsoft.com/en-gb/library/ms191160.aspx) and rename table
	SELECT
		@sql = (
			SELECT
				' ALTER TABLE [' + kcu1.constraint_schema + '].' + '[' + kcu1.table_name + '] DROP CONSTRAINT ' + kcu1.constraint_name
			FROM information_schema.referential_constraints as rc
				JOIN information_schema.key_column_usage as kcu1 ON (kcu1.constraint_catalog = rc.constraint_catalog AND kcu1.constraint_schema = rc.constraint_schema AND kcu1.constraint_name = rc.constraint_name)
				JOIN information_schema.key_column_usage as kcu2 ON (kcu2.constraint_catalog = rc.unique_constraint_catalog AND kcu2.constraint_schema = rc.unique_constraint_schema AND kcu2.constraint_name = rc.unique_constraint_name AND kcu2.ordinal_position = KCU1.ordinal_position)
			WHERE
				kcu2.table_name = @tableName
			FOR XML PATH('')
		);
	--SELECT @sql as '3) @sql'
	print '3) @sql: ' + COALESCE(@sql, '<null>');
	EXECUTE (@sql);

	-- 4) Switch partition
	-- http://www.calsql.com/2012/05/removing-identity-property-taking-more.html
	SET @sql = 'ALTER TABLE ' + @tableName + ' switch partition 1 to ' + @tmpTableName;
	--SELECT @sql as '4) @sql';
	print '4) @sql: ' + COALESCE(@sql, '<null>');
	EXECUTE(@sql);

	-- 5) Rename real old table to bak
	SET @sql = 'EXEC sp_rename ' + @tableName + ', ' + @tableName + '_bak';
	--SELECT @sql as '5) @sql';
	print '5) @sql: ' + COALESCE(@sql, '<null>');
	EXECUTE(@sql);

	-- 6) Rename temp table to real
	SET @sql = 'EXEC sp_rename ' + @tmpTableName + ', ' + @tableName;
	--SELECT @sql as '6) @sql';
	print '6) @sql: ' + COALESCE(@sql, '<null>');
	EXECUTE(@sql);

	-- 7) Drop bak table
	SET @sql = 'DROP TABLE ' + @tableName + '_bak';
	--SELECT @sql as '7) @sql';
	print '7) @sql: ' + COALESCE(@sql, '<null>');
	EXECUTE(@sql);

	-- 8) Create again dropped early constraints
	--SELECT @sqlTableConstraints as '8) @sqlTableConstraints';
	print '8) @sqlTableConstraints: ' + COALESCE(@sqlTableConstraints, '<null>');
	EXECUTE(@sqlTableConstraints);

	-- 9) Rename constraints back without _noident_temp suffix
	DECLARE db_cursor CURSOR FOR
		SELECT DISTINCT
			'sp_rename ''' + CONSTRAINT_NAME + ''', ''' + REPLACE(CONSTRAINT_NAME, '_noident_temp', '') + ''' '
		FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
		WHERE
			CONSTRAINT_NAME LIKE '%_noident_temp';
	OPEN db_cursor;
	FETCH NEXT FROM db_cursor INTO @sql;
	WHILE @@FETCH_STATUS = 0
		BEGIN
			--SELECT @sql as '9) @sql';
			print '9) @sql: ' +  + COALESCE(@sql, '<null>');
			EXECUTE (@sql);
			FETCH NEXT FROM db_cursor INTO @sql;
		END
	CLOSE db_cursor;
	DEALLOCATE db_cursor;

	-- It still may fail if there references from objects with WITH CHECKOPTION
	-- it may be recreated - http://stackoverflow.com/questions/1540988/sql-2005-force-table-rename-that-has-dependencies
	COMMIT
END

GO