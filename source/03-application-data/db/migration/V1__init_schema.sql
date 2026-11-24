-- Evidence 03: skema aplikasi ujian daring multi-tenant
CREATE TABLE tenant (
  id   VARCHAR(50)  PRIMARY KEY,
  name VARCHAR(100) NOT NULL
);

CREATE TABLE exam (
  id           SERIAL PRIMARY KEY,
  tenant_id    VARCHAR(50)  NOT NULL REFERENCES tenant(id),
  title        VARCHAR(200) NOT NULL,
  duration_min INT          NOT NULL
);

CREATE TABLE question (
  id             SERIAL PRIMARY KEY,
  tenant_id      VARCHAR(50) NOT NULL REFERENCES tenant(id),
  exam_id        INT         NOT NULL REFERENCES exam(id),
  body           TEXT        NOT NULL,
  correct_option CHAR(1)     NOT NULL
);

CREATE TABLE attempt (
  id           SERIAL PRIMARY KEY,
  tenant_id    VARCHAR(50)  NOT NULL REFERENCES tenant(id),
  exam_id      INT          NOT NULL REFERENCES exam(id),
  user_id      VARCHAR(100) NOT NULL,
  started_at   TIMESTAMP    NOT NULL DEFAULT now(),
  submitted_at TIMESTAMP
);

CREATE TABLE answer (
  id            SERIAL PRIMARY KEY,
  tenant_id     VARCHAR(50) NOT NULL REFERENCES tenant(id),
  attempt_id    INT         NOT NULL REFERENCES attempt(id),
  question_id   INT         NOT NULL REFERENCES question(id),
  chosen_option CHAR(1),
  saved_at      TIMESTAMP   NOT NULL DEFAULT now(),
  CONSTRAINT uq_answer UNIQUE (attempt_id, question_id)
);

CREATE TABLE result (
  id         SERIAL PRIMARY KEY,
  tenant_id  VARCHAR(50)   NOT NULL REFERENCES tenant(id),
  attempt_id INT           NOT NULL UNIQUE REFERENCES attempt(id),
  score      NUMERIC(5,2)  NOT NULL,
  created_at TIMESTAMP     NOT NULL DEFAULT now()
);

CREATE INDEX idx_exam_tenant     ON exam(tenant_id);
CREATE INDEX idx_question_tenant ON question(tenant_id);
CREATE INDEX idx_attempt_tenant  ON attempt(tenant_id);
CREATE INDEX idx_answer_tenant   ON answer(tenant_id);
CREATE INDEX idx_result_tenant   ON result(tenant_id);
