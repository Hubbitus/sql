/**
* Understandint postgres types and meta-information about they
* https://www.postgresql.org/docs/13/catalog-pg-type.html
* "Type names cannot begin with the underscore character ("_") and can only be 15 characters long. This is because Postgres silently creates an array type for each base type with a name consisting of the base type's name prepended with an underscore." (https://www.postgresql.org/docs/6.4/sql-createtype.htm)
**/
SELECT DISTINCT
    pg_catalog.format_type(a.atttypid, a.atttypmod) AS data_type
    ,pg_catalog.format_type(a.atttypid, NULL) AS data_type_NOmod
    ,a.atttypid, a.atttypmod
    ,t.typname
    ,t.typtype
    ,t.oid
    ,t.typarray
    ,t.typelem
    ,pg_catalog.obj_description ( t.oid, 'pg_type' ) AS type_description -- https://www.postgresql.org/docs/13/functions-info.html
    ,'a>' -- !!! Comment this out to see distinct types!
    ,ns.nspname || '.' || c.relname || '.' || a.attname AS fqn_column_name
    ,'t>'
    ,t.*
FROM
    pg_catalog.pg_attribute a
    JOIN pg_catalog.pg_class c ON (c.oid = a.attrelid)
    JOIN pg_catalog.pg_namespace ns ON (ns.oid = c.relnamespace)
    JOIN pg_catalog.pg_type t ON (t.oid = a.atttypid)
WHERE
    t.typtype NOT IN ('c')
--        AND t.typname LIKE '%oid'
--            AND t.typname LIKE '%char%'
    AND ns.nspname || '.' || c.relname || '.' || a.attname /*AS fqn_column_name*/ IN (
        'epm_emisblackbook.dim_employee_period.is_time_reporting_required'
    )
ORDER BY t.typname
;

SELECT pg_typeof(is_time_reporting_required), pg_typeof(is_time_reporting_required)::oid
FROM epm_emisblackbook.dim_employee_period
LIMIT 1

/**
* Find differencies between pg_catalog.<columns> information and information_schema!
* There are some significant differencies:
* 1) System columns (oid, etc.) are not included [in information_schema.columns]. See https://www.postgresql.org/docs/13/infoschema-columns.html
* 2) information_schema.columns: That does not include columns for the materialized views!!! See https://stackoverflow.com/questions/31119260/column-names-and-data-types-for-materialized-views-in-postgresql
* 3) information_schema.columns: "Only those tables and views are shown that the current user has access to (by way of being the owner or having some privilege)" See https://www.postgresql.org/docs/13/infoschema-tables.html
* 4) information_schema.tables also does not contain information is that table of table partition (pg_class.relispartition)!
**/ 
WITH pg_fields AS (
    SELECT
        ns.nspname as schema_name,
        c.relname as table_name,
        a.attname AS column_name,
        pg_catalog.format_type(a.atttypid, a.atttypmod) AS data_type,
        pg_catalog.format_type(a.atttypid, NULL) AS data_type_generic,
        c.relkind,
        CASE relkind WHEN 'r' THEN 'table' WHEN 'v' THEN 'view' WHEN 'm' THEN 'materialized view' WHEN 'S' THEN 'sequence' WHEN 'f' THEN 'foreign table' WHEN 'p' THEN 'partitioned table' END as rel_type
        ,t.typname
        ,has_table_privilege(format('%I.%I', ns.nspname, c.relname)::regtype::text, 'select') as has_table_privilege
    FROM
        pg_catalog.pg_attribute a
        JOIN pg_catalog.pg_class c ON (c.oid = a.attrelid)
        JOIN pg_catalog.pg_namespace ns ON (ns.oid = c.relnamespace)
        -- JOIN pg_catalog.pg_type t ON (t.typelem = a.atttypid) -- ??? https://stackoverflow.com/questions/31119260/column-names-and-data-types-for-materialized-views-in-postgresql/33064815#33064815
        LEFT JOIN pg_catalog.pg_type t ON (t.oid = a.atttypid)
    WHERE
        NOT a.attisdropped
        AND NOT a.attname ~* '_.+\$$'
--        AND NOT c.relispartition -- !!
        AND a.attname || ':' || pg_catalog.format_type(a.atttypid, a.atttypmod) NOT IN ( -- System columns (oid, etc.) are not included [in information_schema.columns]. See https://www.postgresql.org/docs/13/infoschema-columns.html
            'ctid:tid'
            ,'cmax:cid'
            ,'cmin:cid'
            ,'tableoid:oid'
            ,'xmax:xid'
            ,'xmin:xid'
        )
        -- The view columns contains information about all table columns (or view columns) in the database [in information_schema.columns]. See https://www.postgresql.org/docs/13/infoschema-columns.html
        AND relkind IN ( -- See https://www.postgresql.org/docs/13/catalog-pg-class.html.
        -- Only ordinal, partitioned, foreign tables, and materialized views:
          'r', 'm', 'f', 'p'
        )
), inf_schema_fields AS ( -- That does not include columns for the materialized views!!! See https://stackoverflow.com/questions/31119260/column-names-and-data-types-for-materialized-views-in-postgresql
    -- "Only those tables and views are shown that the current user has access to (by way of being the owner or having some privilege)" See https://www.postgresql.org/docs/13/infoschema-tables.html
    SELECT
        c.table_schema as schema_name, c.table_name, c.column_name, c.udt_name as data_type
    FROM information_schema.columns c
        JOIN information_schema.tables t ON (t.table_catalog = c.table_catalog AND t.table_schema = c.table_schema AND t.table_name = c.table_name)
    WHERE
        t.table_type IN ('BASE TABLE', 'FOREIGN')
        AND NOT c.column_name ~* '_.+\$$'
)
SELECT
    pg.*, '<pg| |inf>' as "pg/inf", inf.*
FROM pg_fields pg
    FULL OUTER JOIN inf_schema_fields inf ON (pg.schema_name = inf.schema_name AND pg.table_name = inf.table_name AND pg.column_name = inf.column_name)
WHERE
    has_table_privilege
    AND rel_type != 'materialized view'
    AND (
        pg.schema_name IS NULL
        OR
        inf.schema_name IS NULL
    )
;


-- We can't just use information_schema.columns because that does not contain materialized views columns, can't allow easily filter out partisions... See details in "Types,attributes,columns.sql"
CREATE VIEW epm_ddo_custom.all_tables_columns AS
    SELECT
        ns.nspname as schema_name,
        c.relname as table_name,
        a.attname AS column_name,
        pg_catalog.format_type(a.atttypid, a.atttypmod) AS data_type,
        pg_catalog.format_type(a.atttypid, NULL) AS data_type_generic,
        c.relkind,
        CASE relkind WHEN 'r' THEN 'table' WHEN 'v' THEN 'view' WHEN 'm' THEN 'materialized view' WHEN 'S' THEN 'sequence' WHEN 'f' THEN 'foreign table' WHEN 'p' THEN 'partitioned table' END as rel_type
        ,t.typname
        ,has_table_privilege(format('%I.%I', ns.nspname, c.relname)::regtype::text, 'select') as has_select_privilege
    FROM
        pg_catalog.pg_attribute      a
        JOIN pg_catalog.pg_class     c  ON (c.oid  = a.attrelid)
        JOIN pg_catalog.pg_namespace ns ON (ns.oid = c.relnamespace)
        LEFT JOIN pg_catalog.pg_type t  ON (t.oid  = a.atttypid)
    WHERE
        NOT a.attisdropped
--        AND NOT a.attname ~* '_.+\$$'
--        AND NOT c.relispartition -- !!
        AND a.attname || ':' || pg_catalog.format_type(a.atttypid, a.atttypmod) NOT IN ( -- System columns (oid, etc.) are not included [in information_schema.columns]. See https://www.postgresql.org/docs/13/infoschema-columns.html
            'ctid:tid'
            ,'cmax:cid'
            ,'cmin:cid'
            ,'tableoid:oid'
            ,'xmax:xid'
            ,'xmin:xid'
        )
        -- The view columns contains information about all table columns (or view columns) in the database [in information_schema.columns]. See https://www.postgresql.org/docs/13/infoschema-columns.html
        AND relkind IN ( -- See https://www.postgresql.org/docs/13/catalog-pg-class.html.
        -- Only ordinal, partitioned, foreign tables, and materialized views:
          'r', 'm', 'f', 'p'
        )
;

SELECT *
FROM epm_ddo_custom.all_tables_columns


SELECT DISTINCT data_type, data_type_generic, typname
FROM epm_ddo_custom.all_tables_columns
