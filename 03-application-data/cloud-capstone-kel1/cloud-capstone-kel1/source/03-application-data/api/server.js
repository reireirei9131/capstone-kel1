// Evidence 03 - API ujian daring multi-tenant (Express + PostgreSQL + Keycloak)
// Konfigurasi lewat environment variable; default cocok dengan paket infrastruktur kelas.
const express = require('express');
const { Pool } = require('pg');
const { createRemoteJWKSet, jwtVerify } = require('jose');

const ISSUER = process.env.OIDC_ISSUER || 'http://127.0.0.1:8081/realms/capstone';
const JWKS = createRemoteJWKSet(new URL(`${ISSUER}/protocol/openid-connect/certs`));
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: +(process.env.DB_PORT || 5432),
  user: process.env.DB_USER || 'capstone',
  password: process.env.DB_PASSWORD || 'capstone',
  database: process.env.DB_NAME || 'capstone',
});

const app = express();
app.use(express.json());

app.get('/health', (req, res) => res.json({ status: 'ok' }));

// Autentikasi: verifikasi JWT, ambil tenant dari klaim "groups" dan role dari realm_access
app.use(async (req, res, next) => {
  try {
    const token = (req.headers.authorization || '').replace(/^Bearer /, '');
    const { payload } = await jwtVerify(token, JWKS, { issuer: ISSUER });
    const tenant = (payload.groups || []).map(g => g.replace(/^\//, ''))
                     .find(g => g.startsWith('tenant-'));
    if (!tenant) return res.status(403).json({ error: 'no tenant group in token' });
    req.user = { id: payload.sub, username: payload.preferred_username, tenant,
                 roles: payload.realm_access?.roles || [] };
    next();
  } catch (e) {
    res.status(401).json({ error: 'invalid token' });
  }
});

const need = (...roles) => (req, res, next) =>
  roles.some(r => req.user.roles.includes(r))
    ? next() : res.status(403).json({ error: 'forbidden', required: roles });

// 1. Peserta mulai ujian (hanya ujian milik tenant sendiri)
app.post('/exams/:id/start', need('user'), async (req, res) => {
  const ex = await pool.query('SELECT id FROM exam WHERE id=$1 AND tenant_id=$2',
    [req.params.id, req.user.tenant]);
  if (!ex.rowCount) return res.status(404).json({ error: 'exam not found' });
  const r = await pool.query(
    'INSERT INTO attempt(tenant_id,exam_id,user_id) VALUES($1,$2,$3) RETURNING *',
    [req.user.tenant, req.params.id, req.user.id]);
  res.json(r.rows[0]);
});

// 2. Autosave jawaban (upsert); hanya pemilik attempt, tenant sama, belum submit
app.put('/attempts/:id/answers', need('user'), async (req, res) => {
  const { question_id, chosen_option } = req.body;
  const r = await pool.query(
    `INSERT INTO answer(tenant_id,attempt_id,question_id,chosen_option)
     SELECT $1,a.id,q.id,$4 FROM attempt a
       JOIN question q ON q.exam_id=a.exam_id AND q.id=$3 AND q.tenant_id=$1
      WHERE a.id=$2 AND a.tenant_id=$1 AND a.user_id=$5 AND a.submitted_at IS NULL
     ON CONFLICT (attempt_id,question_id)
     DO UPDATE SET chosen_option=EXCLUDED.chosen_option, saved_at=now()
     RETURNING *`,
    [req.user.tenant, req.params.id, question_id, chosen_option, req.user.id]);
  if (!r.rowCount) return res.status(404).json({ error: 'attempt/question not found or closed' });
  res.json(r.rows[0]);
});

// 3. Submit + hitung skor dalam satu transaksi
app.post('/attempts/:id/submit', need('user'), async (req, res) => {
  const c = await pool.connect();
  try {
    await c.query('BEGIN');
    const a = await c.query(
      `UPDATE attempt SET submitted_at=now()
        WHERE id=$1 AND tenant_id=$2 AND user_id=$3 AND submitted_at IS NULL
        RETURNING exam_id`,
      [req.params.id, req.user.tenant, req.user.id]);
    if (!a.rowCount) { await c.query('ROLLBACK'); return res.status(404).json({ error: 'attempt not found or already submitted' }); }
    const s = await c.query(
      `SELECT COALESCE(100.0 * SUM((an.chosen_option=q.correct_option)::int)
              / NULLIF((SELECT COUNT(*) FROM question WHERE exam_id=$2),0), 0) AS score
         FROM answer an JOIN question q ON q.id=an.question_id
        WHERE an.attempt_id=$1`, [req.params.id, a.rows[0].exam_id]);
    const r = await c.query(
      'INSERT INTO result(tenant_id,attempt_id,score) VALUES($1,$2,$3) RETURNING *',
      [req.user.tenant, req.params.id, s.rows[0].score]);
    await c.query('COMMIT');
    res.json(r.rows[0]);
  } catch (e) {
    await c.query('ROLLBACK');
    res.status(500).json({ error: e.message });
  } finally { c.release(); }
});

// 4. Laporan nilai: Examiner/Admin/Auditor, hanya data tenant sendiri
app.get('/reports', need('operator', 'admin', 'auditor'), async (req, res) => {
  const r = await pool.query(
    `SELECT a.id AS attempt_id, a.user_id, e.title, r.score, a.submitted_at
       FROM attempt a JOIN exam e ON e.id=a.exam_id
       JOIN result r ON r.attempt_id=a.id
      WHERE a.tenant_id=$1 ORDER BY a.id`, [req.user.tenant]);
  res.json({ tenant: req.user.tenant, count: r.rowCount, rows: r.rows });
});

app.listen(3000, () => console.log('API on :3000, issuer', ISSUER));
