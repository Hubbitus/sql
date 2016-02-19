-- https://community.oracle.com/thread/2406371
CREATE OR REPLACE PROCEDURE myproc(p_cv OUT SYS_REFCURSOR, p_num OUT string) AS
    BEGIN
      OPEN p_cv FOR SELECT 'Hello Oracle' sayhello FROM DUAL ;
      p_num := '77';
    END;
    /

DROP PROCEDURE myproc
/

declare
--	lvar1 string(300);
	lvar1 varchar(300);
	lvar2 sys_refcursor;
begin
	myproc(lvar2,lvar1);
	dbms_output.put_line(lvar1);//use
end;
