-- Some examples to work with JSON(B) structures to produce paths and compare objects diff on traverse tree
-- See also interactive fiddle: https://dbfiddle.uk/?rdbms=postgres_12&fiddle=76a90eebba7e5f4a9e2e61d6204c1b2a 

DROP TABLE table2

CREATE table table1 (
    id serial,
    txt text,
    number int,
    object jsonb
);

INSERT INTO table1 (txt, number, object) VALUES
    ('one', 1, '{"name": "name_one", "number": 1, "inner_array": [{"code": "one_one", "number": 11}, {"code": "one_one1", "number": 111}]}'),
    ('two', 2, '{"name": "name_two", "number": 2, "inner_array": [{"code": "two_one", "number": 22}, {"code": "two_one1", "number": 222}, {"code": "two_one2", "number": 2222}]}'),
    ('three', 3, '{"name": "name_three", "number": 3, "inner_array": [{"code": "three_one", "three_number": 33}, {"code": "three_one1", "number": 333}]}')

CREATE TABLE table2 AS SELECT * FROM table1

UPDATE table2
SET
    txt = 'first test_change'
WHERE id = 1;

UPDATE table2
SET
    txt = 'some_test_change' -- simple scalar field
    ,number = 77
    ,object = jsonb_set(
        object || jsonb '{"name": "name two changed"}' -- Set value inside JSON field
        ,'{inner_array, 1, code}' -- And even in JSON array on any path!!!
        ,'"code changed"'
    )
WHERE id = 2;

UPDATE table2
SET
    txt = 'text change for id=3'
    ,object = object || jsonb '{"name": "name three changed"}'
WHERE id = 3;

INSERT INTO table2 (id, txt, number, object) VALUES
    (4, 'foure', 4, '{"name": "name_four", "number": 4}');

/**
* 1) Most generic variant: Compare any objects structure (tables) allow omit some rows, result in single JSON object:
*    on 1st level of diff (do not nest into JSON fields to see what exact differ)
* Most suitable for the normalized fields without (or small) JSON fields.
* For the excessive usage of JSON see variant 2 with comparing inner JSONPathes in objects
**/
WITH data_diff AS (
    SELECT
        one.id
        ,(-- Can't create function on prod. Inlining jsonb_diff_val(...)
            SELECT
                json_object_agg(COALESCE(old.key, new.key), json_build_object('old', old.value, 'new', new.value))
            FROM jsonb_each(row_to_json(two)::jsonb /*val1*/) old
                FULL OUTER JOIN jsonb_each(row_to_json(one)::jsonb /*val2*/) new ON new.key = old.key
            WHERE
                new.value IS DISTINCT FROM old.value
        )::jsonb - 'id' - '_bt$' - '_tt$' - '_id$' - '_dt$' - '_it$' - '_ccl$' - '_head$' - '_latest$' - '_ctxid' - '_otxid' - 'entity' -- Fields where we have no interest see differenses (skipped)
        as data_diff
    FROM table1 one
        JOIN table2 two ON (two.id = one.id) -- Main condition JOIN to obtain pair for comparison (one, two tables may be SQL CTE). Other script part must not be changed in most situations!
        -- Optional other conditions: WHERE one._head$ AND one._latest$ AND two._head$ AND two._latest$
)
SELECT
    *
FROM data_diff
WHERE data_diff != '{}'::jsonb

/*
Results will look like:
2   {"txt": {"new": "two", "old": "some_test_change"}, "number": {"new": 2, "old": 77}, "object": {"new": {"name": "name_two", "number": 2, "inner_array": [{"code": "two_one", "number": 22}, {"code": "two_one1", "number": 222}, {"code": "two_one2", "number": 2222}]}, "old": {"name": "name two changed", "number": 2, "inner_array": [{"code": "two_one", "number": 22}, {"code": "code changed", "number": 222}, {"code": "two_one2", "number": 2222}]}}}

data_diff field formatted:
{
  "txt": {
    "new": "two",
    "old": "some_test_change"
  },
  "number": {
    "new": 2,
    "old": 77
  },
  "object": {
    "new": {
      "name": "name_two",
      "number": 2,
      "inner_array": [
        {
          "code": "two_one",
          "number": 22
        },
        {
          "code": "two_one1",
          "number": 222
        },
        {
          "code": "two_one2",
          "number": 2222
        }
      ]
    },
    "old": {
      "name": "name two changed",
      "number": 2,
      "inner_array": [
        {
          "code": "two_one",
          "number": 22
        },
        {
          "code": "code changed",
          "number": 222
        },
        {
          "code": "two_one2",
          "number": 2222
        }
      ]
    }
  }
}
*/

/**
* 1.1) Variant with LATERAL join.
* Shorter, potentially faster.
**/
SELECT
    one.id
    ,data_diff
FROM table1 one
    JOIN table2 two ON (two.id = one.id) -- Main condition JOIN to obtain pair for comparison (one, two tables may be SQL CTE). Other script part must not be changed in most situations!
    JOIN LATERAL (
        -- Can't create function on prod. Inlining jsonb_diff_val(...)
        SELECT
            jsonb_object_agg(COALESCE(old.key, new.key), json_build_object('old', old.value, 'new', new.value)) as data_diff
        FROM jsonb_each(row_to_json(two)::jsonb /*val1*/ - '_bt$' - '_tt$' /* Fields where we have no interest see differenses (skipped) */) old
            FULL OUTER JOIN jsonb_each(row_to_json(one)::jsonb /*val2*/ - '_bt$' - '_tt$' /* Fields where we have no interest see differenses (skipped) */ ) new ON new.key = old.key
        WHERE
            new.value IS DISTINCT FROM old.value
    ) as data_diff ON true
WHERE data_diff IS NOT NULL
-- Optional other conditions: AND one._head$ AND one._latest$ AND two._head$ AND two._latest$

/* Preparation of demo-data
CREATE TABLE epm_ddo_custom.tmp__cdm_v2__project AS
SELECT *
FROM cdm_v2.project

UPDATE epm_ddo_custom.tmp__cdm_v2__project
SET
    _ccl$ = 'some_test_change' -- simple scalar field
    ,project_record = jsonb_set(
        project_record || jsonb '{"end_date": 1648684800001}' -- Set value inside JSON field
        ,'{managers, 1, role_name}' -- And even in JSON array on any path!!!
        ,'"custom role"'
    )
WHERE id = 'e14ad16b-9355-45a5-94b6-f10149e471eb'
*/

-- 2) 2nd variant: deep diff JSON objects and show changed JSON-fields in the separate rows 
-- Heavily inspired by https://stackoverflow.com/questions/30132568/collect-recursive-json-keys-in-postgres answers, but gather idea and combine several provided solutions
-- See my answer there: https://stackoverflow.com/questions/30132568/collect-recursive-json-keys-in-postgres/67761539#67761539
WITH one AS (
    SELECT * FROM table1 -- !!! Replace that, assume there is id field to match second table
), two AS (
    SELECT * FROM table2 -- !!! Replace that
), json_pathes_expand AS (
    SELECT
        one.id
        ,one_json_pathes.key   as change_path
        ,one_json_pathes.value as one_value
        ,two_json_pathes.value as two_value
    FROM table1 as one
        JOIN table2 as two ON (two.id = one.id)
        JOIN LATERAL (-- Can't create function on prod. Inlining
            WITH RECURSIVE _tree (key, value, type) AS (
                SELECT null as key, row_to_json(one)::jsonb as value, null
                UNION ALL
                (
                    WITH typed_values AS (
                        SELECT key, jsonb_typeof(value) as typeof, value FROM _tree
                    )
                    SELECT CONCAT(tv.key, '.', v.key), v.value, jsonb_typeof(v.value)
                    FROM typed_values as tv, LATERAL jsonb_each(value) v
                    WHERE typeof = 'object'
                        UNION ALL
                    SELECT CONCAT(tv.key, '[', n-1, ']'), element.val, jsonb_typeof(element.val)
                    FROM typed_values as tv, LATERAL jsonb_array_elements(value) WITH ORDINALITY as element (val, n)
                    WHERE typeof = 'array'
                )
            )
            SELECT DISTINCT one.id, key, value #>> '{}' as value, type
            FROM _tree
            WHERE key IS NOT NULL
        ) as one_json_pathes ON true
       JOIN LATERAL (
            WITH RECURSIVE _tree (key, value, type) AS (
                SELECT null as key, row_to_json(two)::jsonb as value, null
                UNION ALL
                (
                    WITH typed_values AS (
                        SELECT key, jsonb_typeof(value) as typeof, value FROM _tree
                    )
                    SELECT CONCAT(tv.key, '.', v.key), v.value, jsonb_typeof(v.value)
                    FROM typed_values as tv, LATERAL jsonb_each(value) v
                    WHERE typeof = 'object'
                        UNION ALL
                    SELECT CONCAT(tv.key, '[', n-1, ']'), element.val, jsonb_typeof(element.val)
                    FROM typed_values as tv, LATERAL jsonb_array_elements(value) WITH ORDINALITY as element (val, n)
                    WHERE typeof = 'array'
                )
            )
            SELECT DISTINCT two.id, key, value #>> '{}' as value, type
            FROM _tree
            WHERE key IS NOT NULL
        ) as two_json_pathes ON (one_json_pathes.id = two_json_pathes.id AND one_json_pathes.key = two_json_pathes.key)
    WHERE
        one_json_pathes.key NOT IN ( -- Meta fields where we not interested in diff
            '._bt$', '._tt$'
        )
        -- Other conditions are optional: one._head$ AND one._latest$ AND two._head$ AND two._latest$
)
SELECT
    *
FROM json_pathes_expand jp
WHERE one_value != two_value
ORDER BY id, change_path

-- Expected output:
id|change_path                |one_value                                                                                                                                                       |two_value                                                                                                                                                                   |
--+---------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
 2|.number                    |2                                                                                                                                                               |77                                                                                                                                                                          |
 2|.object                    |{"name": "name_two", "number": 2, "inner_array": [{"code": "two_one", "number": 22}, {"code": "two_one1", "number": 222}, {"code": "two_one2", "number": 2222}]}|{"name": "name two changed", "number": 2, "inner_array": [{"code": "two_one", "number": 22}, {"code": "code changed", "number": 222}, {"code": "two_one2", "number": 2222}]}|
 2|.object.inner_array        |[{"code": "two_one", "number": 22}, {"code": "two_one1", "number": 222}, {"code": "two_one2", "number": 2222}]                                                  |[{"code": "two_one", "number": 22}, {"code": "code changed", "number": 222}, {"code": "two_one2", "number": 2222}]                                                          |
 2|.object.inner_array[1]     |{"code": "two_one1", "number": 222}                                                                                                                             |{"code": "code changed", "number": 222}                                                                                                                                     |
 2|.object.inner_array[1].code|two_one1                                                                                                                                                        |code changed                                                                                                                                                                |
 2|.object.name               |name_two                                                                                                                                                        |name two changed                                                                                                                                                            |
 2|.txt                       |two                                                                                                                                                             |some_test_change                                                                                                                                                            |


/**
* 2.1) 2nd variant OPTIMIZED (limit differs rows): deep diff JSON objects and show changed JSON-fields in the separate rows
* Also in tis version implemented show differencies for not matched keys (absent records in one or two) 
* Heavily inspired by https://stackoverflow.com/questions/30132568/collect-recursive-json-keys-in-postgres answers, but gather idea and combine several provided solutions
* See my answer there: https://stackoverflow.com/questions/30132568/collect-recursive-json-keys-in-postgres/67761539#67761539
**/
WITH one AS (
    SELECT * FROM table1 -- !!! Replace that, assume there is id field to match second table
), two AS (
    SELECT * FROM table2 -- !!! Replace that
), join_diffs AS (
    SELECT
        /* Fields where we have no interest see differenses (skipped). 4 times! */
        row_to_json(one)::jsonb /*val1*/ - '_bt$' - '_tt$' #- '{entity, created_when}' #- '{entity, updated_when}' as one
       ,row_to_json(two)::jsonb /*val1*/ - '_bt$' - '_tt$' #- '{entity, created_when}' #- '{entity, updated_when}' as two
    FROM one
        FULL OUTER JOIN two ON (one.id = two.id)
    WHERE -- Can be extracted to the functon for the readability
        row_to_json(one)::jsonb /*val1*/ - '_bt$' - '_tt$' #- '{entity, created_when}' #- '{entity, updated_when}'
        IS DISTINCT FROM
        row_to_json(two)::jsonb /*val1*/ - '_bt$' - '_tt$' #- '{entity, created_when}' #- '{entity, updated_when}'
), top_n_diffs AS ( -- Have no worth compare diffs fort thousants of rows!
    SELECT one, two
    FROM join_diffs
    WHERE one IS NOT NULL AND two IS NOT NULL -- Other have no worth compare by fields
    LIMIT 100 -- Limit diff rows for deep compare
)
--SELECT id FROM top_n_diffs GROUP BY id HAVING COUNT(*) > 1  -- ASSERTION! Must be empty! If not, check one/two queries uniquity by id (have you forgotten add `AND _head$` conditions on temporal data?)
--SELECT * FROM top_n_diffs
--SELECT (SELECT COUNT(*) FROM one) as rows_in_one, (SELECT COUNT(*) FROM two) as rows_in_two, COUNT(*) as differed_rows FROM top_n_diffs -- For count make sure you swith off limit in top_n_diffs CTE
, json_pathes_expand AS (
    SELECT DISTINCT
        one->>'id' as id
        ,one_json_pathes.key   as change_path
        ,one_json_pathes.value as one_value
        ,two_json_pathes.value as two_value
    FROM top_n_diffs
        JOIN LATERAL (-- Can't create function on prod. Inlining
            WITH RECURSIVE _tree (key, value, type) AS (
                SELECT null as key, one as value, null
                UNION ALL
                (
                    WITH typed_values AS (
                        SELECT key, jsonb_typeof(value) as typeof, value FROM _tree
                    )
                    SELECT CONCAT(tv.key, '.', v.key), v.value, jsonb_typeof(v.value)
                    FROM typed_values as tv, LATERAL jsonb_each(value) v
                    WHERE typeof = 'object'
                        UNION ALL
                    SELECT CONCAT(tv.key, '[', n-1, ']'), element.val, jsonb_typeof(element.val)
                    FROM typed_values as tv, LATERAL jsonb_array_elements(value) WITH ORDINALITY as element (val, n)
                    WHERE typeof = 'array'
                )
            )
            SELECT DISTINCT one->>'id' as id, key, value #>> '{}' as value, type
            FROM _tree
            WHERE key IS NOT NULL
        ) as one_json_pathes ON true
        JOIN LATERAL (
            WITH RECURSIVE _tree (key, value, type) AS (
                SELECT null as key, two as value, null
                UNION ALL
                (
                    WITH typed_values AS (
                        SELECT key, jsonb_typeof(value) as typeof, value FROM _tree
                    )
                    SELECT CONCAT(tv.key, '.', v.key), v.value, jsonb_typeof(v.value)
                    FROM typed_values as tv, LATERAL jsonb_each(value) v
                    WHERE typeof = 'object'
                        UNION ALL
                    SELECT CONCAT(tv.key, '[', n-1, ']'), element.val, jsonb_typeof(element.val)
                    FROM typed_values as tv, LATERAL jsonb_array_elements(value) WITH ORDINALITY as element (val, n)
                    WHERE typeof = 'array'
                )
            )
            SELECT DISTINCT two->>'id' as id, key, value #>> '{}' as value, type
            FROM _tree
            WHERE key IS NOT NULL
        ) as two_json_pathes ON (one_json_pathes.id = two_json_pathes.id AND one_json_pathes.key = two_json_pathes.key)
        -- Other conditions are optional: WHERE one._head$ AND one._latest$ AND two._head$ AND two._latest$
)
SELECT
    *
FROM json_pathes_expand jp
WHERE one_value != two_value
    UNION ALL
SELECT
    COALESCE (one->>'id', two->>'id') as id
    ,CASE
        WHEN one IS NULL THEN '<one row missing>'
        WHEN two IS NULL THEN '<two row missing>'
    END as change_path
    ,one::text
    ,two::text
FROM join_diffs
WHERE one IS NULL OR two IS NULL
ORDER BY id, change_path

