--
-- (C) 2007 Inverse groupe conseil
--

CREATE TABLE SOGo_user_profile (
  c_uid      VARCHAR(255) NOT NULL PRIMARY KEY,
  c_defaults CLOB,
  c_settings CLOB
);
