SELECT 'tenant' AS tabel, count(*) AS baris, md5(coalesce(string_agg(id||name, ',' ORDER BY id),'')) AS checksum FROM tenant
UNION ALL SELECT 'exam', count(*), md5(coalesce(string_agg(id::text||tenant_id||title||duration_min::text, ',' ORDER BY id),'')) FROM exam
UNION ALL SELECT 'question', count(*), md5(coalesce(string_agg(id::text||tenant_id||exam_id::text||body||correct_option, ',' ORDER BY id),'')) FROM question
UNION ALL SELECT 'attempt', count(*), md5(coalesce(string_agg(id::text||tenant_id||exam_id::text||user_id||coalesce(submitted_at::text,'-'), ',' ORDER BY id),'')) FROM attempt
UNION ALL SELECT 'answer', count(*), md5(coalesce(string_agg(id::text||tenant_id||attempt_id::text||question_id::text||coalesce(chosen_option,'-'), ',' ORDER BY id),'')) FROM answer
UNION ALL SELECT 'result', count(*), md5(coalesce(string_agg(id::text||tenant_id||attempt_id::text||score::text, ',' ORDER BY id),'')) FROM result
UNION ALL SELECT 'flyway_schema_history', count(*), md5(coalesce(string_agg(version||description||success::text, ',' ORDER BY installed_rank),'')) FROM flyway_schema_history;
