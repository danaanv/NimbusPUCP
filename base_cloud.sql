-- MySQL dump 10.13  Distrib 8.0.42, for macos15 (x86_64)
--
-- Host: localhost    Database: infraestructura_cloud
-- ------------------------------------------------------
-- Server version	9.3.0

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `imagenes_vm`
--

DROP TABLE IF EXISTS `imagenes_vm`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `imagenes_vm` (
  `id` int NOT NULL AUTO_INCREMENT,
  `nombre` varchar(100) NOT NULL,
  `descripcion` text,
  `url_descarga` text,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `imagenes_vm`
--

LOCK TABLES `imagenes_vm` WRITE;
/*!40000 ALTER TABLE `imagenes_vm` DISABLE KEYS */;
/*!40000 ALTER TABLE `imagenes_vm` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `maquinas_virtuales`
--

DROP TABLE IF EXISTS `maquinas_virtuales`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `maquinas_virtuales` (
  `id` int NOT NULL AUTO_INCREMENT,
  `id_topologia` int DEFAULT NULL,
  `nombre` varchar(100) DEFAULT NULL,
  `imagen_id` int DEFAULT NULL,
  `estado` enum('pendiente','creada','activa','error') DEFAULT 'pendiente',
  `nodo_asignado` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `id_topologia` (`id_topologia`),
  KEY `imagen_id` (`imagen_id`),
  CONSTRAINT `maquinas_virtuales_ibfk_1` FOREIGN KEY (`id_topologia`) REFERENCES `topologias` (`id`),
  CONSTRAINT `maquinas_virtuales_ibfk_2` FOREIGN KEY (`imagen_id`) REFERENCES `imagenes_vm` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `maquinas_virtuales`
--

LOCK TABLES `maquinas_virtuales` WRITE;
/*!40000 ALTER TABLE `maquinas_virtuales` DISABLE KEYS */;
/*!40000 ALTER TABLE `maquinas_virtuales` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `monitoreo`
--

DROP TABLE IF EXISTS `monitoreo`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `monitoreo` (
  `id` int NOT NULL AUTO_INCREMENT,
  `id_vm` int DEFAULT NULL,
  `uso_cpu` float DEFAULT NULL,
  `uso_memoria` float DEFAULT NULL,
  `timestamp` datetime DEFAULT CURRENT_TIMESTAMP,
  `nodo_sugerido` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `id_vm` (`id_vm`),
  CONSTRAINT `monitoreo_ibfk_1` FOREIGN KEY (`id_vm`) REFERENCES `maquinas_virtuales` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `monitoreo`
--

LOCK TABLES `monitoreo` WRITE;
/*!40000 ALTER TABLE `monitoreo` DISABLE KEYS */;
/*!40000 ALTER TABLE `monitoreo` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `red_seguridad`
--

DROP TABLE IF EXISTS `red_seguridad`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `red_seguridad` (
  `id` int NOT NULL AUTO_INCREMENT,
  `id_vm` int DEFAULT NULL,
  `ip` varchar(45) DEFAULT NULL,
  `vlan_id` int DEFAULT NULL,
  `firewall_rules` json DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `id_vm` (`id_vm`),
  CONSTRAINT `red_seguridad_ibfk_1` FOREIGN KEY (`id_vm`) REFERENCES `maquinas_virtuales` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `red_seguridad`
--

LOCK TABLES `red_seguridad` WRITE;
/*!40000 ALTER TABLE `red_seguridad` DISABLE KEYS */;
/*!40000 ALTER TABLE `red_seguridad` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `slices`
--

DROP TABLE IF EXISTS `slices`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `slices` (
  `id` int NOT NULL AUTO_INCREMENT,
  `nombre` varchar(100) NOT NULL,
  `descripcion` text,
  `creado_por` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `creado_por` (`creado_por`),
  CONSTRAINT `slices_ibfk_1` FOREIGN KEY (`creado_por`) REFERENCES `usuarios` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `slices`
--

LOCK TABLES `slices` WRITE;
/*!40000 ALTER TABLE `slices` DISABLE KEYS */;
/*!40000 ALTER TABLE `slices` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `topologias`
--

DROP TABLE IF EXISTS `topologias`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `topologias` (
  `id` int NOT NULL AUTO_INCREMENT,
  `id_slice` int DEFAULT NULL,
  `nombre` varchar(100) DEFAULT NULL,
  `definicion_json` json DEFAULT NULL,
  `creado_por` int DEFAULT NULL,
  `fecha_creacion` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `id_slice` (`id_slice`),
  KEY `creado_por` (`creado_por`),
  CONSTRAINT `topologias_ibfk_1` FOREIGN KEY (`id_slice`) REFERENCES `slices` (`id`),
  CONSTRAINT `topologias_ibfk_2` FOREIGN KEY (`creado_por`) REFERENCES `usuarios` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `topologias`
--

LOCK TABLES `topologias` WRITE;
/*!40000 ALTER TABLE `topologias` DISABLE KEYS */;
/*!40000 ALTER TABLE `topologias` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `usuarios`
--

DROP TABLE IF EXISTS `usuarios`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `usuarios` (
  `id` int NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL,
  `password` varchar(255) NOT NULL,
  `rol` enum('superadmin','user') NOT NULL,
  `nombre` varchar(100) DEFAULT NULL,
  `correo` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `usuarios`
--

LOCK TABLES `usuarios` WRITE;
/*!40000 ALTER TABLE `usuarios` DISABLE KEYS */;
INSERT INTO `usuarios` VALUES (1,'superadmin1','$2b$12$kDKF0Wp/2qrbwRiNqqq/FOFslyahqU3pTP3j9V1JClk2vYf0e7uau','superadmin','Administrador Principal','superadmin@example.com'),(2,'superadmin2','$2b$12$cs1m9JRSTT/9UDJamGpdaOGe1lx71vbuEmjPlpyOg1Epzh6iApQc.','superadmin','Gerente de Sistemas','admin@empresa.com'),(3,'usuario1','$2b$12$VY3Myw7KUg3TPjedYFRH/.Klv2PptKAlJS3sS9Gwo1QcbQ3h9KyGG','user','Juan Pérez','juan.perez@mail.com'),(4,'usuario2','$2b$12$4.k9LyaHk33WtRWNz./54uw88L9jmyst3vKLvgng40MJQEZOSaKf2','user','María García','maria.garcia@correo.com'),(5,'usuario3','$2b$12$aQOTiWjRwFwP0KR2UCkUMuLMfcAUJ8zVR83E8TbzRbfvz6iRzRwyS','user','Carlos López','c.lopez@dominio.org');
/*!40000 ALTER TABLE `usuarios` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2025-05-13 19:34:31
