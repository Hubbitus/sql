/**
* See for the details: https://stackoverflow.com/questions/30132568/collect-recursive-json-keys-in-postgres/67761539#67761539
* Based on @Simon's answer (https://stackoverflow.com/questions/30132568/collect-recursive-json-keys-in-postgres/46761197#46761197) which is great,
* but for my similar case building JSON objects diff, I want to have keys path like in JSONpath form, and not only last name, including array indexes and also values.
*
* So, on example {"A":[[[{"C":"B"}, {"D":"E"}]]],"X":"Y", "F": {"G": "H"}} I need not only keys X, D, G, C, F, A, but values on each path like .A[0][0][0].C = 'B'.
*
* There are also some minor enhancements like:
* - Providing data type of value
* - Provide value itself, without extra quotes
*
* Live DBFfiddle: https://www.db-fiddle.com/f/4Rvsd7cFLvjBTZbvBtT81E/1
*/
WITH RECURSIVE _tree (key, value, type) AS (
    SELECT
        NULL as key
        ,'{"A":[[[{"C":"B"}, {"D":"E"}]]],"X":"Y", "F": {"G": "H"}}'::jsonb as value
        ,'object'
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
SELECT DISTINCT key, value #>> '{}' as value, type
FROM _tree
WHERE key IS NOT NULL
ORDER BY key
