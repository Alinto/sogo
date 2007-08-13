--
-- (C) 2007 Inverse groupe conseil
--

CREATE TABLE SOGo_folder_info (
  c_folder_id      INTEGER PRIMARY KEY,
  c_path           VARCHAR(255)  NOT NULL, -- the full path to the folder
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

CREATE SEQUENCE SOGo_folder_info_seq;
CREATE OR REPLACE TRIGGER SOGo_folder_info_autonumber
BEFORE INSERT ON SOGo_folder_info FOR EACH ROW
BEGIN
    IF :new.c_folder_id IS NULL THEN
        SELECT SOGO_folder_info_seq.nextval INTO :new.c_folder_id FROM DUAL;
    END IF;
END;
/
