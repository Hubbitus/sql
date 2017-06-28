WITH interesting_options AS (
		SELECT -- inner select to preserve natural oerder as it organized by me in query. Hack (It is preserved when just select ... FROM VALUES, but breaks on JOIN).
				*, row_number() OVER() as rn
		FROM (VALUES
--		(E'### Resource Consumption - http://www.postgresql.org/docs/9.4/static/runtime-config-resource.html')
		(E'### Resource Consumption \n  ## Memory - http://www.postgresql.org/docs/9.4/static/runtime-config-resource.html')
		,('work_mem'), ('shared_buffers'), ('sort_mem'), ('maintenance_work_mem'), ('effective_cache_size')
		,('huge_pages')
		,(E'### Resource Consumption \n  ## Costs - http://www.postgresql.org/docs/9.4/static/runtime-config-resource.html')
		,('random_page_cost'), ('seq_page_cost'), ('cpu_tuple_cost'), ('cpu_index_tuple_cost'), ('cpu_operator_cost')
		,('default_statistics_target')
		,('effective_io_concurrency')
		,('max_connections')
		,(E'### Resource Consumption \n  ## Vacuum - http://www.postgresql.org/docs/9.4/static/runtime-config-resource.html')
		,('vacuum_cost_delay'), ('vacuum_cost_page_hit'), ('vacuum_cost_page_miss'), ('vacuum_cost_page_dirty'), ('vacuum_cost_limit')
		,(E'### Resource Consumption \n  ## Background Writer - http://www.postgresql.org/docs/9.4/static/runtime-config-resource.html')
		,('bgwriter_delay'), ('bgwriter_lru_maxpages'), ('bgwriter_lru_multiplier')
		,(E'### Resource Consumption \n  ## Asynchronous Behavior - http://www.postgresql.org/docs/9.4/static/runtime-config-resource.html')
		,(E'### Query Planning # http://www.postgresql.org/docs/9.4/static/runtime-config-query.html')
		,('enable_bitmapscan'), ('enable_hashagg'), ('enable_hashjoin'), ('enable_indexscan'), ('enable_indexonlyscan'), ('enable_material'), ('enable_mergejoin'), ('enable_nestloop'), ('enable_seqscan'), ('enable_sort'), ('enable_tidscan')
		,('constraint_exclusion')
		--
		,(E'### Write Ahead Log -- http://www.postgresql.org/docs/9.4/static/runtime-config-wal.html')
		,('fsync'), ('synchronous_commit'), ('full_page_writes') -- -> Off. Faster but unsafe
		,('wal_buffers'), ('wal_writer_delay'), ('commit_delay') /* ↑ if fsync = on */
		,('wal_level'), ('wal_keep_segments')
		,(E'### Write Ahead Log \n  ## Checkpoints \n  http://www.postgresql.org/docs/9.4/static/runtime-config-wal.html')
--		,('checkpoint_segments'), ('checkpoint_timeout'), ('checkpoint_completion_target'), ('checkpoint_warning')
-- checkpoint_segments from version 9.5 became min_wal_size and max_wal_size:
		,('min_wal_size'), ('max_wal_size'), ('checkpoint_completion_target'), ('checkpoint_warning')
		,(E'### Write Ahead Log \n  ## Archiving - https://www.postgresql.org/docs/9.4/static/runtime-config-wal.html#RUNTIME-CONFIG-WAL-ARCHIVING')
		,('archive_command'), ('archive_mode')
		--
		,(E'### Error Reporting and Logging \n  ##  Where To Log - http://www.postgresql.org/docs/9.4/static/runtime-config-logging.html')
		,('debug_print_parse'), ('debug_print_parse'), ('debug_print_rewritten'), ('debug_print_plan')
		,('debug_pretty_print'), ('log_checkpoints'), ('log_connections'), ('log_disconnections'), ('log_duration'), ('log_error_verbosity'), ('log_lock_waits'), ('log_statement'), ('log_temp_files')
		--
		,(E'### Run-time Statistics \n  ##  Query and Index Statistics Collector - http://www.postgresql.org/docs/9.4/static/runtime-config-statistics.html')
		,('track_activities'), ('track_counts'), ('track_io_timing'), ('track_functions'), ('track_activity_query_size'), ('update_process_title'), ('stats_temp_directory')
		,(E'### Run-time Statistics \n  ##  Statistics Monitoring - http://www.postgresql.org/docs/9.4/static/runtime-config-statistics.html')
		,('log_parser_stats'), ('log_planner_stats'), ('log_executor_stats'), ('log_statement_stats')
		--
		,(E'### Automatic Vacuuming - http://www.postgresql.org/docs/9.4/static/runtime-config-autovacuum.html')
		,('autovacuum')
		,('log_autovacuum_min_duration'), ('autovacuum_naptime'), ('autovacuum_vacuum_threshold'), ('autovacuum_analyze_threshold')
		--
		,(E'### Client Connection Defaults - http://www.postgresql.org/docs/9.4/static/runtime-config-client.html')
		,('statement_timeout'), ('lock_timeout'), ('temp_tablespaces'), ('default_tablespace')
		--
		,(E'### Preset Options (build or initdb time only) - https://www.postgresql.org/docs/current/static/runtime-config-preset.html')
		,('block_size'), ('data_checksums'), ('lc_collate'), ('wal_block_size'), ('wal_segment_size')
		) v (name)
)
SELECT
		o.name
		,CASE
				WHEN NOT position('###' IN o.name) > 0
						THEN current_setting(o.name)
				ELSE '---------------'
		END as cur_value_HR
		,s.setting as cur_value_raw, s.unit, s.min_val, s.max_val, s.boot_val, s.reset_val, s.category, s.enumvals, s.short_desc, s.extra_desc, s.context, s.vartype, s.source, s.sourcefile, s.sourceline
FROM interesting_options o
LEFT JOIN pg_settings s ON (s.name = o.name)
ORDER BY o.rn
