CREATE USER IF NOT EXISTS 'sogobuild'@'%' IDENTIFIED BY 'sogo123';
GRANT ALL PRIVILEGES ON * . * TO 'sogobuild'@'%';

FLUSH PRIVILEGES;

CREATE DATABASE IF NOT EXISTS sogo;
USE sogo;
-- INSERT INTO 
CREATE DATABASE IF NOT EXISTS sogo_integration_tests_auth;
USE sogo_integration_tests_auth;
-- MySQL dump 10.16  Distrib 10.1.48-MariaDB, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: sogo_integration_tests_auth
-- ------------------------------------------------------
-- Server version	10.1.48-MariaDB-0+deb9u2

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `sogoauth`
--

DROP TABLE IF EXISTS `sogoauth`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `sogoauth` (
  `c_uid` varchar(255) NOT NULL,
  `c_name` varchar(255) NOT NULL,
  `c_password` varchar(255) DEFAULT NULL,
  `c_cn` varchar(255) DEFAULT NULL,
  `mail` varchar(255) DEFAULT NULL,
  `kind` varchar(255) DEFAULT NULL,
  `multiplebookings` int(11) DEFAULT NULL,
  PRIMARY KEY (`c_uid`),
  UNIQUE KEY `c_name` (`c_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `sogoauth`
--

LOCK TABLES `sogoauth` WRITE;
/*!40000 ALTER TABLE `sogoauth` DISABLE KEYS */;
INSERT INTO `sogoauth` VALUES ('res','res','sogo','Resource no overbook','res@example.org','location',1),('res-nolimit','res-nolimit','sogo','Resource can overbook','res-nolimit@example.org','location',0),('sogo-tests-super','sogo-tests-super','sogo','sogo test super','sogo-tests-super@example.org',NULL,NULL),('sogo-tests1','sogo-tests1','sogo','sogo One','sogo-tests1@example.org',NULL,NULL),('sogo-tests2','sogo-tests2','sogo','sogo Two','sogo-tests2@example.org',NULL,NULL),('sogo-tests3','sogo-tests3','sogo','sogo Three','sogo-tests3@example.org',NULL,NULL);
/*!40000 ALTER TABLE `sogoauth` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2023-02-22  4:15:31
