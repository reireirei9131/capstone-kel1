\dt
SELECT version, description, success FROM flyway_schema_history ORDER BY installed_rank;
SELECT a.id AS attempt, a.tenant_id, a.user_id, a.submitted_at, r.score
  FROM attempt a JOIN result r ON r.attempt_id=a.id ORDER BY a.id;
SELECT tenant_id, attempt_id, question_id, chosen_option FROM answer ORDER BY attempt_id, question_id;
SELECT tenant_id, COUNT(*) AS jumlah_answer FROM answer GROUP BY tenant_id;
