SELECT COUNT(*)
FROM epm_staf.m_weekly_workload

SELECT COUNT(*), _head$, _latest$
FROM epm_staf.m_weekly_workload
GROUP BY _head$, _latest$

VACUUM VERBOSE ANALYSE epm_staf.m_proposals

SELECT COUNT(*)
FROM epm_staf.m_positions
WHERE position_id IS NULL

--? TEST
ALTER TABLE epm_staf.m_positions
	ALTER COLUMN position_id SET NOT NULL
;

-- Revert
ALTER TABLE epm_staf.m_positions
	ALTER COLUMN position_id DROP NOT NULL
;

-- By https://stackoverflow.com/questions/24997131/pairwise-array-sum-aggregate-function/24997565#24997565
CREATE TABLE tbl (arr int []);

INSERT INTO tbl VALUES
  ('{1,2,3}'::int[])
 ,('{9,12,13}')
 ,('{1,1,1, 33}')
 ,('{NULL,NULL}')
 ,(NULL);


SELECT ARRAY (
   SELECT sum(elem)
   FROM  tbl t, unnest(t.arr) WITH ORDINALITY x(elem, rn)
   GROUP BY rn
   ORDER BY rn
);

SELECT sum(elem)
FROM  tbl t, unnest(t.arr) WITH ORDINALITY x(elem, rn)
GROUP BY rn
ORDER BY rn


SELECT elem, rn
FROM  tbl t, unnest(t.arr) WITH ORDINALITY x(elem, rn)
ORDER BY rn;