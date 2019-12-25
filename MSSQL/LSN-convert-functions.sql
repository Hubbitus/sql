/*
 * Function for convert LSN binary values as it returned from sys.fn_cdc_get_max_lsn() or stored in CDC changes tables.
 *
 * It will convert from binary or bigint form and return string like '0000001e:00000038:0001'
 *
 * Reverse function by information from https://sqlsoldier.net/wp/sqlserver/day11of31daysofdisasterconvertinglsnformats
 *
 * Examples of usage:
 * 1)
 * SELECT dbo.__tmp_td_cdc_binary_decode_to_string([__$start_lsn])
 * FROM RdcModel_QA.cdc.dbo_Entity_cdc_CT
 * ORDER BY createdDateTime DESC
 *
 * 2) SELECT dbo.__tmp_td_cdc_binary_decode_to_string(sys.fn_cdc_get_max_lsn())
 * 3) SELECT dbo.__tmp_td_cdc_binary_decode_to_string(30000000005600001) -- returns: 0000001e:00000038:0001
 */
CREATE OR ALTER FUNCTION dbo.__tmp_td_cdc_binary_decode_to_string(@lsn VARBINARY(10))
RETURNS VARCHAR(max) AS
	BEGIN
		-- Fill by \0 at left
		SET @lsn = CONVERT(varbinary, REPLICATE(char(0), 10 - LEN(@lsn))) + @lsn
		DECLARE @lsn_s varchar(max) = CONVERT(varchar, CONVERT(bigint, SUBSTRING(@lsn, 1, 2), 1)) + CONVERT(varchar, CONVERT(bigint, SUBSTRING(@lsn, 3, 8), 1))
		SET @lsn_s = RIGHT(REPLICATE('0', 25) + @lsn_s, 25) -- Make it 25 symbols long, to always just take substrings
		/*
		* 1) In first place of text-based LSN (e.g. '0000001e:00000038:0001') may be 8 digits in HEX base
		* 2) '0xffffffff' is max value
		* 3) That is 4294967295 in DEC-base, it is 10 symbols long
		* 4) So, max length of string in DEC is 10 + 10 + 5 = 25 symbols!
		*/
		DECLARE @l1 varchar(max) = SUBSTRING(@lsn_s,  1, 10)
		DECLARE @l2 varchar(max) = SUBSTRING(@lsn_s, 11, 10)
		DECLARE @l3 varchar(max) = SUBSTRING(@lsn_s, 21,  5)
		RETURN lower(
			RIGHT(CONVERT(varchar(max), CONVERT(varbinary, CONVERT(bigint, @l1)), 1), 8) + ':' +
			RIGHT(CONVERT(varchar(max), CONVERT(varbinary, CONVERT(bigint, @l2)), 1), 8) + ':' +
			RIGHT(CONVERT(varchar(max), CONVERT(varbinary, CONVERT(bigint, @l3)), 1), 5)
			)
	END
;

/**
 * By https://solutioncenter.apexsql.com/analyzing-and-reading-change-data-capture-cdc-records/
 * Function to convert from string like '0000001e:00000038:0001' which come from Debezium logs into binary
 * form present in CDC tables and returned from sys.fn_cdc_get_max_lsn() function
 *
 * Example of usage:
 * SELECT dbo.__tmp_td_cdc_string_decode_to_binary('0000001e:00000038:0001') -- Returns: 30000000005600001
 *
 * @returns DECIMAL representation string. For binary form see dbo.__tmp_td_cdc_string_decode_to_binary_BINARY function
 */
CREATE OR ALTER FUNCTION dbo.__tmp_td_cdc_string_decode_to_binary_DECSTRING(@lsn VARCHAR(23))
RETURNS VARCHAR(MAX) AS
	BEGIN
		-- Split LSN into segments at colon
		DECLARE @LSN1 varchar(11) = LEFT(@LSN, 8)
		DECLARE @LSN2 varchar(10) = SUBSTRING(@LSN, 10, 8)
		/*
		DECLARE @LSN3 varchar(5)  = RIGHT(@LSN, 5)
		There are values like '0000001e:00000038:0001' and '000a4444:fdae4f71:13361'
		See my comment: https://stackoverflow.com/questions/20801344/what-format-should-the-start-and-end-lsn-parameters-be-to-sys-fn-dblog/20807856#comment105138864_20807856
		Use split.
		*/
		DECLARE @LSN3 varchar(5) = SUBSTRING(@LSN, CHARINDEX(':', @LSN, 10) + 1, 100)
		-- Convert to binary style 1 -> int
		SET @LSN1 = CAST(CONVERT(VARBINARY, '0x' + RIGHT(REPLICATE('0', 8) + @LSN1, 8), 1) AS bigint)
		SET @LSN2 = CAST(CONVERT(VARBINARY, '0x' + RIGHT(REPLICATE('0', 8) + @LSN2, 8), 1) AS bigint)
		SET @LSN3 = CAST(CONVERT(VARBINARY, '0x' + RIGHT(REPLICATE('0', 8) + @LSN3, 8), 1) AS bigint)
		-- Add padded 0's to 2nd and 3rd string
		DECLARE @res_decimal_string VARCHAR(max) = CAST(@LSN1 as varchar(10)) +
				CAST(RIGHT(REPLICATE('0', 10) + @LSN2, 10) as varchar(10)) +
				CAST(RIGHT(REPLICATE('0',  5) + @LSN3,  5) as varchar(5 ))
		RETURN @res_decimal_string
	END
;


CREATE OR ALTER FUNCTION dbo.__tmp_td_cdc_string_decode_to_binary_HEXSTRING(@lsn VARCHAR(23))
RETURNS VARCHAR(MAX) AS
	BEGIN
		-- Split LSN into segments at colon
		DECLARE @LSN1 varchar(11) = LEFT(@LSN, 8)
		DECLARE @LSN2 varchar(10) = SUBSTRING(@LSN, 10, 8)
		/*
		DECLARE @LSN3 varchar(5)  = RIGHT(@LSN, 5)
		There are values like '0000001e:00000038:0001' and '000a4444:fdae4f71:13361'
		See my comment: https://stackoverflow.com/questions/20801344/what-format-should-the-start-and-end-lsn-parameters-be-to-sys-fn-dblog/20807856#comment105138864_20807856
		Use split.
		*/
		DECLARE @LSN3 varchar(5) = SUBSTRING(@LSN, CHARINDEX(':', @LSN, 10) + 1, 100)
		DECLARE @res_hex_string VARCHAR(max) = '0x' + RIGHT(REPLICATE('0', 8) + @LSN1, 8) +
			RIGHT(REPLICATE('0', 8) + @LSN2, 8) +
			RIGHT(REPLICATE('0', 8) + @LSN3, 8)
		RETURN @res_hex_string
	END
;



/**
 * Complimentary to dbo.__tmp_td_cdc_binary_decode_to_string function for reverse conversion!
 *
 * See https://solutioncenter.apexsql.com/analyzing-and-reading-change-data-capture-cdc-records/
 *
 * Example (must return 'CORRECT' in `CheckConversion` column):
 * --DECLARE @lsn varbinary(16) = CONVERT(varbinary, CONVERT(bigint, 30000000005600001)) -- First cast to bigint is mandatory!
 * DECLARE @lsn VARBINARY(100) = sys.fn_cdc_get_max_lsn()
 * SELECT
 *	@lsn as orig_lsn_bin
 *	--, dbo.__tmp_td_cdc_string_decode_to_binary_BINARY('0000001e:00000038:0001'),
 *	,dbo.__tmp_td_cdc_binary_decode_to_string(@lsn) as string
 *	,dbo.__tmp_td_cdc_string_decode_to_binary_BINARY(
 *		dbo.__tmp_td_cdc_binary_decode_to_string(@lsn)
 *	) as bin2str_and_revert
 *	,CASE WHEN dbo.__tmp_td_cdc_string_decode_to_binary_BINARY(
 *		dbo.__tmp_td_cdc_binary_decode_to_string(@lsn)
 *	) = @lsn THEN 'CORRECT' ELSE 'Error' END as CheckConversion
 *	,DATALENGTH(@lsn) as lsn_len
 *	,DATALENGTH(
 *		dbo.__tmp_td_cdc_string_decode_to_binary_BINARY(
 *			dbo.__tmp_td_cdc_binary_decode_to_string(@lsn)
 *		)
 *	) as reverse_convert_len
 *	,CONVERT(varchar, @lsn, 1) as lsn_hex
 *	,CONVERT(
 *		varchar
 *		,dbo.__tmp_td_cdc_string_decode_to_binary_BINARY(
 *			dbo.__tmp_td_cdc_binary_decode_to_string(@lsn)
 *		)
 *		,1
 *	) as reverse_convert_hex
 *
 * LSN hex value '0x0043275D010200440020' still fails to convert. There even first 19 digit symbols owerflow bigint. @TODO I do not known how to deal with it now
 */
CREATE OR ALTER FUNCTION dbo.__tmp_td_cdc_string_decode_to_binary_BINARY(@lsn VARCHAR(23))
RETURNS VARBINARY(10) AS
	BEGIN
		DECLARE @res_decimal_string VARCHAR(max) = dbo.__tmp_td_cdc_string_decode_to_binary_DECSTRING(@lsn)
		SET @res_decimal_string = RIGHT(REPLICATE('0', 38) + @res_decimal_string, 38) -- 19 * 2
--		RETURN CONVERT(VARBINARY(8), CONVERT(bigint, @res_decimal_string), 1) -- Work for single bigint in string!
		DECLARE @res VARBINARY(10)
		DECLARE @bigint1 bigint = CONVERT(bigint, SUBSTRING(@res_decimal_string, 1, 19)) -- 19 is maximum digits in bigint
		DECLARE @bigint2 bigint = CONVERT(bigint, SUBSTRING(@res_decimal_string, 20, 19))
		IF (@bigint1 > 0)
			SET @res = CONVERT(VARBINARY(2), @bigint1, 1) + CONVERT(VARBINARY(8), @bigint2, 1)
		ELSE
			SET @res = CONVERT(VARBINARY(8), @bigint2, 1)
		RETURN @res
	END
;

/**
 * Comliant function for test dbo.__tmp_td_cdc_binary_decode_to_string/dbo.__tmp_td_cdc_string_decode_to_binary_BINARY pair.
 * It return string 'CORRECT' if forward and backward convertion return same value as original, and 'Error' otherwise
 *
 * Example: SELECT dbo.__tmp_td_cdc_decode_check(sys.fn_cdc_get_max_lsn()) must return 'CORRECT'
 */
CREATE OR ALTER FUNCTION dbo.__tmp_td_cdc_decode_check(@lsn VARBINARY(10))
RETURNS VARCHAR(max) AS
	BEGIN
		RETURN CASE WHEN  dbo.__tmp_td_cdc_string_decode_to_binary_BINARY(dbo.__tmp_td_cdc_binary_decode_to_string(@lsn)) = @lsn THEN 'CORRECT' ELSE 'Error' END
	END
;

