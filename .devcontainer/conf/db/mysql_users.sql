CREATE TABLE `sogo_users` (
    `c_uid` varchar(255) COLLATE utf8_bin NOT NULL,
    `c_name` varchar(255) COLLATE utf8_bin NOT NULL,
    `c_password` varchar(255) COLLATE utf8_bin NOT NULL,
    `c_cn` varchar(255) COLLATE utf8_bin NOT NULL,
    `mail` varchar(255) COLLATE utf8_bin NOT NULL
    
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

INSERT INTO `sogo_users` VALUES ('sogo', 'sogo', '{MD5}dfbb885c6e4743f30025399a97c65ab0', 'Sogo', 'sogo@example.org');
INSERT INTO `sogo_users` VALUES ('cyrus', 'cyrus', '{MD5}dfbb885c6e4743f30025399a97c65ab0', 'cyrus', 'cyrus@example.org');
INSERT INTO `sogo_users` VALUES ('sogo-tests1', 'sogo-tests1', '{MD5}dfbb885c6e4743f30025399a97c65ab0', 'Dude', 'sogo-tests1@example.org');
INSERT INTO `sogo_users` VALUES ('sogo-tests2', 'sogo-tests2', '{MD5}dfbb885c6e4743f30025399a97c65ab0', 'Hewill', 'sogo-tests2@example.org');
INSERT INTO `sogo_users` VALUES ('sogo-tests3', 'sogo-tests3', '{MD5}dfbb885c6e4743f30025399a97c65ab0', 'Ithas', 'sogo-tests3@example.org');
INSERT INTO `sogo_users` VALUES ('sogo-tests-super', 'sogo-tests-super', '{MD5}dfbb885c6e4743f30025399a97c65ab0', 'John Doe', 'sogo-tests-super@example.org');
INSERT INTO `sogo_users` VALUES ('res', 'res', '{MD5}dfbb885c6e4743f30025399a97c65ab0', 'resource No Overbook', 'res@example.org');
INSERT INTO `sogo_users` VALUES ('res-nolimit', 'res-nolimit', '{MD5}dfbb885c6e4743f30025399a97c65ab0', 'resource No Overbook', 'res-nolimit@example.org');

