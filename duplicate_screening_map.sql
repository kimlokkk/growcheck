-- phpMyAdmin SQL Dump
-- version 5.2.3
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: Aug 12, 2026 at 02:43 PM
-- Server version: 8.0.46-cll-lve
-- PHP Version: 8.4.24

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `zharfanc_appkizzukids`
--

-- --------------------------------------------------------

--
-- Table structure for table `duplicate_screening_map`
--

CREATE TABLE `duplicate_screening_map` (
  `duplicate_id` int NOT NULL DEFAULT '0',
  `keep_id` bigint DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `duplicate_screening_map`
--

INSERT INTO `duplicate_screening_map` (`duplicate_id`, `keep_id`) VALUES
(443, 444),
(442, 444),
(181, 182),
(180, 182),
(190, 191),
(216, 217),
(235, 236),
(230, 231),
(440, 441),
(439, 441),
(250, 251),
(307, 308),
(341, 344),
(361, 362),
(360, 362),
(430, 431),
(461, 463),
(481, 482),
(523, 524),
(541, 542),
(608, 610),
(640, 641);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
