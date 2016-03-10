--
-- (C) 2004-2005 SKYRIX Software AG
-- (C) 2006-2007 Inverse inc.
--

CREATE TABLE @{tableName} (
	c_folder_id INTEGER NOT NULL,
	c_object VARCHAR(255) NOT NULL,
  	c_uid VARCHAR(255) NOT NULL,
  	c_role VARCHAR(80) NOT NULL
);

CREATE INDEX @{tableName}_c_folder_id_idx ON @{tableName}(c_folder_id);
CREATE INDEX @{tableName}_c_uid_idx ON @{tableName}(c_uid);
