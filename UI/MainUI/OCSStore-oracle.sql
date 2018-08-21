--
-- (C) 2004-2005 SKYRIX Software AG
-- (C) 2006-2007 Inverse inc.
--

CREATE TABLE @{tableName} (
	c_folder_id INT NOT NULL,
	c_name VARCHAR (255),
	c_content CLOB NOT NULL,
	c_creationdate INT NOT NULL,
	c_lastmodified INT NOT NULL,
	c_version INT NOT NULL,
	c_deleted INT NULL,
	CONSTRAINT @{tableName}_pkey PRIMARY KEY (c_folder_id, c_name)
);
