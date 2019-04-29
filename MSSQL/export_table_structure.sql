-- See https://stackoverflow.com/questions/21547/in-sql-server-how-do-i-generate-a-create-table-statement-for-a-given-table/18619504#18619504
-- You could try in is sqlfiddle: http://sqlfiddle.com/#!6/e3b66/3/0
SELECT
        obj.name
        ,'CREATE TABLE [' + obj.name + '] (' + LEFT(cols.list, LEN(cols.list) - 1 ) + ')'
        + ISNULL(' ' + refs.list, '')
    FROM sysobjects obj
    CROSS APPLY (
        SELECT
            CHAR(10)
            + ' [' + column_name + '] '
            + data_type
            + CASE data_type
                WHEN 'sql_variant' THEN ''
                WHEN 'text' THEN ''
                WHEN 'ntext' THEN ''
                WHEN 'xml' THEN ''
                WHEN 'decimal' THEN '(' + CAST(numeric_precision as VARCHAR) + ', ' + CAST(numeric_scale as VARCHAR) + ')'
                ELSE COALESCE('(' + CASE WHEN character_maximum_length = -1 THEN 'MAX' ELSE CAST(character_maximum_length as VARCHAR) END + ')', '')
            END
            + ' '
            + case when exists ( -- Identity skip
            select id from syscolumns
            where object_name(id) = obj.name
            and name = column_name
            and columnproperty(id,name,'IsIdentity') = 1
            ) then
            'IDENTITY(' +
            cast(ident_seed(obj.name) as varchar) + ',' +
            cast(ident_incr(obj.name) as varchar) + ')'
            else ''
            end + ' '
            + CASE WHEN IS_NULLABLE = 'No' THEN 'NOT ' ELSE '' END
            + 'NULL'
            + CASE WHEN information_schema.columns.column_default IS NOT NULL THEN ' DEFAULT ' + information_schema.columns.column_default ELSE '' END
            + ','
        FROM
            INFORMATION_SCHEMA.COLUMNS
        WHERE table_name = obj.name
        ORDER BY ordinal_position
        FOR XML PATH('')
    ) cols (list)
    CROSS APPLY(
        SELECT
            CHAR(10) + 'ALTER TABLE ' + obj.name + '_noident_temp ADD ' + LEFT(alt, LEN(alt)-1)
        FROM(
            SELECT
                CHAR(10)
                + ' CONSTRAINT ' + tc.constraint_name
                + ' ' + tc.constraint_type + ' (' + LEFT(c.list, LEN(c.list)-1) + ')'
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
                    -- // http://stackoverflow.com/questions/3907879/sql-server-howto-get-foreign-key-reference-from-information-schema
                    SELECT
                        '  REFERENCES [' + kcu1.constraint_schema + '].' + '[' + kcu2.table_name + ']' + '(' + kcu2.column_name + '), '
                    FROM information_schema.referential_constraints as rc
                        JOIN information_schema.key_column_usage as kcu1 ON (kcu1.constraint_catalog = rc.constraint_catalog AND kcu1.constraint_schema = rc.constraint_schema AND kcu1.constraint_name = rc.constraint_name)
                        JOIN information_schema.key_column_usage as kcu2 ON (kcu2.constraint_catalog = rc.unique_constraint_catalog AND kcu2.constraint_schema = rc.unique_constraint_schema AND kcu2.constraint_name = rc.unique_constraint_name AND kcu2.ordinal_position = KCU1.ordinal_position)
                    WHERE
                        kcu1.constraint_catalog = tc.constraint_catalog AND kcu1.constraint_schema = tc.constraint_schema AND kcu1.constraint_name = tc.constraint_name
                ) r (list)
            WHERE tc.table_name = obj.name
            FOR XML PATH('')
        ) a (alt)
    ) refs (list)
    WHERE
        xtype = 'U'
    AND name NOT IN ('dtproperties')
    AND obj.name = 'your_table_name'
