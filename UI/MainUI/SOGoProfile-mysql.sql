--
-- (C) 2004-2005 SKYRIX Software AG
-- (C) 2006-2007 Inverse inc.
-- (C) 2023 Alinto
--

CREATE TABLE @{tableName} (
  c_uid      VARCHAR(255) NOT NULL PRIMARY KEY,
  c_defaults MEDIUMTEXT,
  c_settings TEXT
);
