WITH RECURSIVE tables_tree AS ( -- See https://stackoverflow.com/questions/30592826/postgres-approximate-number-of-rows-in-partitioned-tables/68958004#68958004
    SELECT oid AS oid, oid as parent_oid
    FROM pg_class i
--  WHERE i.inhparent = 'epm_pbi.dim_employee_history$events'::regclass
UNION ALL
    SELECT i.inhrelid AS oid, t.parent_oid
    FROM pg_inherits i
    JOIN tables_tree t ON i.inhparent = t.oid
), table_total_size AS (
    SELECT sum(tbl.reltuples) as estimated_table_rows_sum, t.parent_oid
    FROM tables_tree t
        JOIN pg_class tbl ON t.oid = tbl.oid
    GROUP BY t.parent_oid
)
SELECT *, parent_oid::regclass as base_table
FROM table_total_size
