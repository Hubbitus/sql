--- Example calculate frequency histogram on postgres.
--- By
--- https://stackoverflow.com/questions/58844982/generate-date-histogram-over-table/58848954#58848954
--- https://dbfiddle.uk/?rdbms=postgres_12&fiddle=604ba5261f1524559504e15a649b7edc (<- https://stackoverflow.com/questions/49860696/how-to-bin-timestamp-data-into-buckets-of-n-minutes-in-postgres/49861242#49861242)
--- My modified variant: https://dbfiddle.uk/?rdbms=postgres_12&fiddle=827faf11fa6ac99f0a56142933404b22
--- And this all scriptin also available at https://dbfiddle.uk/?rdbms=postgres_12&fiddle=c29d7c8df3fa60494b77ce54710092ed


DROP TABLE test1;

CREATE TABLE test1 (id serial PRIMARY KEY, d date);

INSERT INTO test1 (d) VALUES
    ('2019-01-01'), ('2020-01-01'), ('2020-01-03'), ('2020-02-01'), ('2020-03-01')
   ,('2020-06-01'), ('2020-08-01'), ('2020-08-10'), ('2021-01-01'), ('2021-01-01')
   ,('2021-08-01'), ('2021-09-10'), ('2021-09-20'), ('2021-10-01'), ('2021-11-01')
   ,('2021-12-10'), ('2021-12-20')
;

SELECT *
FROM test1

-- 1) Variant with numeric date conversion (potentially slow)
WITH buckets AS (
    SELECT
        d
        ,extract(epoch FROM d)
        ,width_bucket(
            extract(epoch FROM d)
            ,(SELECT MIN(extract(epoch FROM d)) FROM test1)
            ,(SELECT MAX(extract(epoch FROM d)) FROM test1)
            ,5
        ) as bucket
    FROM test1
)
SELECT
    bucket
    ,COUNT(d) as cnt
    , REPEAT('=', COUNT(d)::int)
FROM buckets
GROUP BY bucket
ORDER BY cnt DESC

-- 2.1) Variant with date ranges (faster). Plain list of buckets (see aggregation the next)
WITH ranges AS (
    SELECT ARRAY(
        SELECT generate_series(
            MIN(d),
            MAX(d), 
            '1 month'
        )
        FROM test1
    )::date[] as range
)
, buckets AS (
    SELECT
        d
        ,width_bucket(d, (SELECT range FROM ranges)) as bucket
    FROM test1
)
SELECT b.*, daterange(range[bucket], range[bucket + 1], '[)')
FROM buckets b, ranges

-- 2.2) Grouping by backet, calc count
WITH ranges AS (
    SELECT ARRAY(
        SELECT generate_series(
            MIN(d),
            MAX(d), 
            '6 months'
        )
        FROM test1
    )::date[] as range
)
, buckets AS (
    SELECT
        d
        ,width_bucket(d, (SELECT range FROM ranges)) as bucket
        ,(SELECT COUNT(*) FROM test1) as total_count
    FROM test1
)
SELECT
    bucket, COUNT(*) cnt, total_count
    ,daterange(range[bucket], range[bucket + 1], '[)') -- optional range for easy reading
    ,REPEAT('■', COUNT(*)::int) as bar_absolute -- 'Bar graph'
    ,COUNT(*)::float * 100 / total_count as "%"
    ,REPEAT('■', (COUNT(*)::float * 100 / total_count)::int) as "bar_%" -- 'Bar graph'. To enhance: percentage count by total_count
FROM buckets b, ranges
GROUP BY bucket, range, total_count
-- ORDER BY cnt DESC
ORDER BY bucket

------------------------------------------------------------------------------
-- 2.3) Generic variant. Extract target table into SRS CTE, for easy re-use --
------------------------------------------------------------------------------
WITH src AS NOT MATERIALIZED (
    SELECT d as d FROM test1
), ranges AS (
    SELECT ARRAY(
        SELECT generate_series(
            MIN(d),
            MAX(d), 
            '6 months'
        )
        FROM src
    )::date[] as range
)
, buckets AS (
    SELECT
        d
        ,width_bucket(d, (SELECT range FROM ranges)) as bucket
        ,(SELECT COUNT(*) FROM src) as total_count
    FROM src
)
SELECT
    bucket, COUNT(*) cnt, total_count
    ,daterange(range[bucket], range[bucket + 1], '[)') -- optional range for easy reading
    ,REPEAT('■', COUNT(*)::int) as bar_absolute -- 'Bar graph'
    ,COUNT(*)::float * 100 / total_count as "%"
    ,REPEAT('■', (COUNT(*)::float * 100 / total_count)::int) as "bar_%" -- 'Bar graph'. To enhance: percentage count by total_count
FROM buckets b, ranges
GROUP BY bucket, range, total_count
-- ORDER BY cnt DESC
ORDER BY bucket
------
-- Result will be like:
-- bucket|cnt|total_count|daterange              |bar_absolute|%                 |bar_%                                    |
-- ------+---+-----------+-----------------------+------------+------------------+-----------------------------------------+
--      1|  1|         17|[2019-01-01,2019-07-01)|■           | 5.882352941176471|■■■■■■                                   |
--      3|  5|         17|[2020-01-01,2020-07-01)|■■■■■       | 29.41176470588235|■■■■■■■■■■■■■■■■■■■■■■■■■■■■■            |
--      4|  2|         17|[2020-07-01,2021-01-01)|■■          |11.764705882352942|■■■■■■■■■■■■                             |
--      5|  2|         17|[2021-01-01,2021-07-01)|■■          |11.764705882352942|■■■■■■■■■■■■                             |
--      6|  7|         17|[2021-07-01,)          |■■■■■■■     |  41.1764705882353|■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■|
