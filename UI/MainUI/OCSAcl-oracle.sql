--
-- (C) 2018 Inverse inc.
--

CREATE TABLE @{tableName} (
	c_folder_id INTEGER NOT NULL,
	c_object VARCHAR(255) NOT NULL,
  	c_uid VARCHAR(255) NOT NULL,
  	c_role VARCHAR(80) NOT NULL
);

CREATE INDEX @{tableName}_c_folder_id_idx ON @{tableName}(c_folder_id);
CREATE INDEX @{tableName}_c_uid_idx ON @{tableName}(c_uid);
