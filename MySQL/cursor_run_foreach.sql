DROP PROCEDURE IF EXISTS _tmp_run;
/

/*
http://dev.mysql.com/doc/refman/5.6/en/cursors.html
Unfortunately MySQL does not allow direct anounimouse block execution - http://forums.mysql.com/read.php?20,574906, co procedure required
*/
CREATE PROCEDURE _tmp_run()
BEGIN
	DECLARE done INT DEFAULT 0;
	DECLARE a VARCHAR(160);
	DECLARE b INT;
	DECLARE cur1
		CURSOR FOR
			SELECT TABLE_NAME, TABLE_ROWS
			FROM INFORMATION_SCHEMA.TABLES
			WHERE
				TABLE_SCHEMA = 'ru_bir_ru'
				AND TABLE_NAME LIKE 'hh_%';
	DECLARE
		CONTINUE HANDLER FOR 
			SQLSTATE '02000'
			SET done = 1;

	OPEN cur1;

	REPEAT
		FETCH cur1 INTO a, b;
		IF NOT done THEN
			SELECT a as 'a=', b as 'b=';

			-- Dinamyc SQL http://stackoverflow.com/questions/190776/how-to-have-dynamic-sql-in-mysql-stored-procedure
			SET @s = CONCAT('DROP TABLE ', a);
			PREPARE stmt FROM @s;
			EXECUTE stmt;
			DEALLOCATE PREPARE stmt;

		END IF;

	UNTIL
		done
	END REPEAT;

	CLOSE cur1;
END;
/

CALL _tmp_run;
/

DROP PROCEDURE _tmp_run;