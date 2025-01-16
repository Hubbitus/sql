/**
* Please look at db-fiddle live example: https://www.db-fiddle.com/f/cpzd67PzMMQyqcJs9z2D6K/2
**/

CREATE USER u_a;
CREATE USER u_b;
CREATE ROLE r_c LOGIN;
CREATE ROLE r_d LOGIN;
CREATE ROLE r_e LOGIN;
CREATE ROLE r_f LOGIN;

GRANT r_c TO u_a;
GRANT r_d TO r_c;
GRANT r_e TO r_c;
GRANT r_f TO r_d;

CREATE TABLE t1 (id int);
CREATE TABLE t2 (id int);

GRANT SELECT on t1 TO u_a;
GRANT SELECT on t1 TO u_b;
GRANT SELECT on t2 TO r_c;

/**
* Access hierarchy.
* Provides information about users access, including recursive grants by roles.
**/
WITH RECURSIVE r AS (
	SELECT member::regrole::text as member, roleid::regrole AS role, member::regrole || ' ➫ ' || roleid::regrole AS path
	FROM pg_auth_members AS m
	WHERE roleid > 16384 -- system roles
	UNION -- pg_auth_members misses users, which ar not members of any role! So, we add them from pg_authid
	SELECT rolname, null, ''
	FROM pg_authid
	WHERE
		oid NOT IN (SELECT member FROM pg_auth_members)
		AND oid > 16384 -- system roles
	UNION ALL
	SELECT r.member::regrole::text, m.roleid::regrole, r.path || ' ➫ ' || m.roleid::regrole
	FROM pg_auth_members AS m
		JOIN r ON m.member = r.role
)
, roles AS (
	SELECT member, role, path
	FROM r
	-- WHERE member::text = 'bi_readonly_user' -- specific user if needed
	ORDER BY member::text, role::text
)
SELECT grantee, path, table_catalog, table_schema, table_name, privilege_type
FROM
	information_schema.role_table_grants as g
	JOIN roles as r ON (g.grantee::text = r.member::text OR g.grantee::text = r.role::text)
;

/**
* Roles hierarchy.
* Based on https://www.cybertec-postgresql.com/en/postgresql-get-member-roles-and-permissions/
* Meantime selecting initially from pg_auth_members misses users, which ar not members of any role!
* So, modified to also add pg_authid
**/
WITH RECURSIVE r AS (
	SELECT member::regrole::text as member, roleid::regrole AS role, member::regrole || ' ➫ ' || roleid::regrole AS path
	FROM pg_auth_members AS m
	WHERE roleid > 16384 -- system roles
	UNION -- pg_auth_members misses users, which ar not members of any role! Som we add them from pg_authid
	SELECT rolname, null, ''
	FROM pg_authid
	WHERE
		oid NOT IN (SELECT member FROM pg_auth_members)
		AND oid > 16384 -- system roles
	UNION ALL
	SELECT r.member::regrole::text, m.roleid::regrole, r.path || ' ➫ ' || m.roleid::regrole
	FROM pg_auth_members AS m
		JOIN r ON m.member = r.role
)
SELECT member, role, path
FROM r
ORDER BY member, role
;
