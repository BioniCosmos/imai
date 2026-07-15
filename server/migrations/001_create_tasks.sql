CREATE TABLE IF NOT EXISTS tasks (
    id          UUID PRIMARY KEY,
    state       VARCHAR(32) NOT NULL DEFAULT 'created',

    -- Diving-Fish credentials
    df_username VARCHAR(255) NOT NULL,
    df_password VARCHAR(255) NOT NULL,
    difficulties INTEGER[] NOT NULL DEFAULT '{0,1,2,3,4}',

    -- OAuth parameters for task association
    oauth_state VARCHAR(512),
    oauth_r     VARCHAR(512),

    -- OAuth authorization code
    oauth_code  VARCHAR(512),

    -- Upload results
    results     JSONB,

    -- Error message (if failed)
    error_message TEXT,

    -- Timestamps
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tasks_state ON tasks(state);
CREATE INDEX IF NOT EXISTS idx_tasks_oauth ON tasks(oauth_state, oauth_r);
