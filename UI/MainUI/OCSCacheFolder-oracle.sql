--
-- (C) 2018 Inverse inc.
--

CREATE TABLE @{tableName} (
  	c_uid VARCHAR(255) NOT NULL,
        c_path VARCHAR(255) NOT NULL,
        c_parent_path VARCHAR(255),
        c_type SMALLINT NOT NULL,
        c_creationdate INT NOT NULL,
        c_lastmodified INT NOT NULL,
        c_version INT NOT NULL DEFAULT 0,
        c_deleted SMALLINT NOT NULL DEFAULT 0,
        c_content CLOB,
        CONSTRAINT @{tableName}_pkey PRIMARY KEY (c_uid, c_path)
);
