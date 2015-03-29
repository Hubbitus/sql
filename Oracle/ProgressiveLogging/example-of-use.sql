DECLARE
	CURSOR c_from IS
SELECT
	Old.ORIG_ID as oldOrigId, Old.cons_id as oldId, New.orig_Id as newOrigId, New.cons_id as newId
FROM consumer Old
	JOIN consumer New ON (old.SUB_UNID = new.ORIG_ID AND old.CONS_ID != new.CONS_ID)
WHERE ROWNUM <= 10000
;

BEGIN

	FOR ind IN c_from LOOP -- Cycle with long operations

	DBMS_OUTPUT.PUT_LINE(ind.oldOrigId || ':' || ind.oldId || ':' || ind.newOrigId || ':' || ind.newId); -- That output will be available only AFTER all execution
	tmp_log(ind.oldOrigId || ':' || ind.oldId || ':' || ind.newOrigId || ':' || ind.newId); -- That log you may see in table directly as it arrived. Look at select.sql and select.watch.sql examples.

	UPDATE ADD_ARC_EXPS_H SET CONS_ID = ind.oldId WHERE CONS_ID = ind.newId;
	UPDATE ARC_EXPS_D SET CONS_ID = ind.oldId WHERE CONS_ID = ind.newId;
	UPDATE ARC_EXPS_H SET CONS_ID = ind.oldId WHERE CONS_ID = ind.newId;
	UPDATE CC_SCHEMA SET CONS_ID = ind.oldId WHERE CONS_ID = ind.newId;
	UPDATE CC_STRUCT SET CONS_ID = ind.oldId WHERE CONS_ID = ind.newId;
	UPDATE CHANNEL_STRUCT SET CONS_ID = ind.oldId WHERE CONS_ID = ind.newId;
	UPDATE CONTRACT SET CONS_ID = ind.oldId WHERE CONS_ID = ind.newId;
	UPDATE CUR_EQUIP_STATUS SET CONS_ID = ind.oldId WHERE CONS_ID = ind.newId;
	UPDATE POINT_CONNECT SET CONS_ID = ind.oldId WHERE CONS_ID = ind.newId;
	UPDATE DISP_LIMIT SET CONS_ID = ind.oldId WHERE CONS_ID = ind.newId;
	UPDATE META_CONSUMER SET CONS_ID = ind.oldId WHERE CONS_ID = ind.newId;
	UPDATE ACT_CONSUMPTION SET CONS_ID = ind.oldId WHERE CONS_ID = ind.newId;
	UPDATE ACT_CONSUMP_OBJ SET CONS_ID = ind.oldId WHERE CONS_ID = ind.newId;
	UPDATE GAS_CONS_OBJECT SET CONS_ID = ind.oldId WHERE CONS_ID = ind.newId;

	UPDATE CL_ACCOUNT SET CONS_ID = ind.oldId WHERE CONS_ID = ind.newId;
	UPDATE CONSUMP_RESTRICT SET CONS_ID = ind.oldId WHERE CONS_ID = ind.newId;
	UPDATE CONS_OUT SET CONS_ID = ind.oldId WHERE CONS_ID = ind.newId;
	UPDATE CONS_TO_LTG SET CONS_ID = ind.oldId WHERE CONS_ID = ind.newId;
	UPDATE CONS_TYPE_PARAM SET CONS_ID = ind.oldId WHERE CONS_ID = ind.newId;
	UPDATE EXCEL_MAPPING_SDU SET CONS_ID = ind.oldId WHERE CONS_ID = ind.newId;
	UPDATE HEAD_CONNECTION SET CONS_ID = ind.oldId WHERE CONS_ID = ind.newId;
	UPDATE INDEPEND_SUPPLY SET CONS_ID = ind.oldId WHERE CONS_ID = ind.newId;
	UPDATE PRC_OVER_LESS SET CONS_ID = ind.oldId WHERE CONS_ID = ind.newId;
	UPDATE PRG2MRG_CONSUMER SET CONS_ID = ind.oldId WHERE CONS_ID = ind.newId;
	UPDATE PRIORITY SET CONS_ID = ind.oldId WHERE CONS_ID = ind.newId;
	UPDATE REQ_YEAR_LIMIT SET CONS_ID = ind.oldId WHERE CONS_ID = ind.newId;
	UPDATE SDU_GAS_CC SET CONS_ID = ind.oldId WHERE CONS_ID = ind.newId;
	UPDATE SDU_GAS_CONS SET CONS_ID = ind.oldId WHERE CONS_ID = ind.newId;
	UPDATE SUPPLY_LICENCE SET CONS_ID = ind.oldId WHERE CONS_ID = ind.newId;
	UPDATE TECHNICAL_CONDITIONS_JOIN SET CONS_ID = ind.oldId WHERE CONS_ID = ind.newId;

	DELETE consumer WHERE cons_id = ind.newId;
	UPDATE consumer SET ORIG_ID = SUB_UNID WHERE CONS_ID = ind.oldId;

	COMMIT;

	END LOOP;

COMMIT;

END;
/
