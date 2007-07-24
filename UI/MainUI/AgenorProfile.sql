--
-- (C) 2004-2005 SKYRIX Software AG
-- (C) 2006-2007 Inverse groupe conseil
--

CREATE TABLE SOGo_user_profile (
  c_uid      VARCHAR(255) NOT NULL PRIMARY KEY,
  c_defaults TEXT,
  c_settings TEXT
);
