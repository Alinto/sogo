--
-- (C) 2004-2005 SKYRIX Software AG
-- (C) 2006-2007 Inverse groupe conseil
--

CREATE TABLE @{tableName} (
  c_folder_id      SERIAL,
  c_path           VARCHAR(255)  PRIMARY KEY, -- the full path to the folder
  c_path1          VARCHAR(255)  NOT NULL, -- parts (for fast queries)
  c_path2          VARCHAR(255)  NULL,     -- parts (for fast queries)
  c_path3          VARCHAR(255)  NULL,     -- parts (for fast queries)
  c_path4          VARCHAR(255)  NULL,     -- parts (for fast queries)
  c_foldername     VARCHAR(255)  NOT NULL, -- last path component
  c_location       VARCHAR(2048) NOT NULL, -- URL to folder
  c_quick_location VARCHAR(2048) NULL,     -- URL to quicktable of folder
  c_acl_location   VARCHAR(2048) NULL,     -- URL to quicktable of folder
  c_folder_type    VARCHAR(255)  NOT NULL  -- the folder type ...
);
