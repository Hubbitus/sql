/**
* JSON analogue of query_to_xml function
* @link By http://blog.sql-workbench.eu/post/query-to-json/ (<= https://stackoverflow.com/questions/49281340/why-postgresql-need-script-for-execute-and-not-need-script-for-query-to-xml)
**/
create or replace function public.query_to_jsonb(p_query text, p_include_nulls boolean default false)
  returns jsonb
as
$$
declare
  l_sql text;
  l_result jsonb;
begin
  l_sql := 'select jsonb_agg(';
  if p_include_nulls then
    l_sql := l_sql || 'jsonb_strip_nulls(';
  end if;
  l_sql := l_sql || 'to_jsonb(t)';
  if p_include_nulls then
    l_sql := l_sql || ')';
  end if;
  l_sql := l_sql || ') from (' || p_query || ') t';
  execute l_sql
    into l_result;
  return l_result;
end;
$$
language plpgsql;
