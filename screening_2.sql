-- phpMyAdmin SQL Dump
-- version 5.2.3
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: Aug 12, 2026 at 02:37 PM
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
-- Table structure for table `s`
--

CREATE TABLE `s` (
  `screening_id` int NOT NULL,
  `staff_id` int NOT NULL,
  `staff_name` varchar(1000) NOT NULL,
  `student_id` int NOT NULL,
  `student` varchar(100) NOT NULL,
  `age` double NOT NULL,
  `age_fine_motor` double NOT NULL,
  `age_gross_motor` double NOT NULL,
  `age_personal_social` double NOT NULL,
  `age_language` double NOT NULL,
  `status` varchar(100) NOT NULL,
  `screening_date` date NOT NULL,
  `date_created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `therapist_suggestion` longtext CHARACTER SET latin1 COLLATE latin1_swedish_ci NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Dumping data for table `s`
--

INSERT INTO `s` (`screening_id`, `student_id`, `student`, `status`, `screening_date`, `date_created`, `component_count`, `fail_count`, `no_count`, `first_component_id`, `last_component_id`) VALUES
(167, 5759, 'MUHAMMAD HARRAZ ZAFRAN BIN MOHD SHAHRIM', '', '2025-03-12', '2026-04-21 06:25:22', 28, 28, 0, 1598, 1625),
(165, 5759, 'MUHAMMAD HARRAZ ZAFRAN BIN MOHD SHAHRIM', '', '2025-03-12', '2026-04-21 06:25:22', 31, 31, 0, 1551, 1581),
(163, 5759, 'MUHAMMAD HARRAZ ZAFRAN BIN MOHD SHAHRIM', '', '2025-03-12', '2026-04-21 06:25:22', 25, 25, 0, 1515, 1539),
(444, 5805, 'NUR NUHA MIKAYLA BINTI AZIZI', 'Draft', '2026-02-27', '2026-04-21 06:25:22', 14, 4, 10, 7620, 7633),
(443, 5805, 'NUR NUHA MIKAYLA BINTI AZIZI', 'Draft', '2026-02-27', '2026-04-21 06:25:22', 14, 4, 10, 7606, 7619),
(442, 5805, 'NUR NUHA MIKAYLA BINTI AZIZI', 'Draft', '2026-02-27', '2026-04-21 06:25:22', 14, 4, 10, 7592, 7605),
(170, 5819, 'Aamily Dahlia', '', '2025-03-15', '2026-04-21 06:25:22', 7, 7, 0, 1644, 1650),
(169, 5819, 'Aamily Dahlia', '', '2025-03-15', '2026-04-21 06:25:22', 7, 7, 0, 1637, 1643),
(182, 5978, 'Shahrull Al-Hafiraz bin Shahrull Nizam ', 'Draft', '2025-04-08', '2026-04-21 06:25:22', 1, 1, 0, 1810, 1810),
(181, 5978, 'Shahrull Al-Hafiraz bin Shahrull Nizam ', 'Draft', '2025-04-08', '2026-04-21 06:25:22', 1, 1, 0, 1809, 1809),
(180, 5978, 'Shahrull Al-Hafiraz bin Shahrull Nizam ', 'Draft', '2025-04-08', '2026-04-21 06:25:22', 1, 1, 0, 1808, 1808),
(191, 6003, 'muhammad ryan arjuna', 'Draft', '2025-04-12', '2026-04-21 06:25:22', 7, 7, 0, 1965, 1971),
(190, 6003, 'muhammad ryan arjuna', 'Draft', '2025-04-12', '2026-04-21 06:25:22', 7, 7, 0, 1958, 1964),
(217, 6087, 'MUHAMMAD ARYAN MIKHAIL BIN MOHAMAD RIDZUAN', 'Draft', '2025-04-23', '2026-04-21 06:25:22', 18, 18, 0, 2470, 2487),
(216, 6087, 'MUHAMMAD ARYAN MIKHAIL BIN MOHAMAD RIDZUAN', 'Draft', '2025-04-23', '2026-04-21 06:25:22', 18, 18, 0, 2452, 2469),
(236, 6099, 'Muhammad Uwais Mateen bin Mohd Alif Akmal', 'Draft', '2025-05-06', '2026-04-21 06:25:22', 4, 4, 0, 2666, 2669),
(235, 6099, 'Muhammad Uwais Mateen bin Mohd Alif Akmal', 'Draft', '2025-05-06', '2026-04-21 06:25:22', 4, 4, 0, 2662, 2665),
(223, 6182, 'Nurzahra binti mohd firdaus', 'Submit', '2025-04-26', '2026-04-21 06:25:22', 0, NULL, NULL, NULL, NULL),
(224, 6182, 'Nurzahra binti mohd firdaus', 'Draft', '2025-04-26', '2026-04-21 06:25:22', 0, NULL, NULL, NULL, NULL),
(230, 6273, 'Ubaidillah Mustain b. Muhammad Bukhari', 'Draft', '2025-04-30', '2026-04-21 06:25:22', 0, NULL, NULL, NULL, NULL),
(231, 6273, 'Ubaidillah Mustain b. Muhammad Bukhari', 'Draft', '2025-04-30', '2026-04-21 06:25:22', 0, NULL, NULL, NULL, NULL),
(441, 6280, 'wan zharif aidan', 'Draft', '2026-02-27', '2026-04-21 06:25:22', 27, 17, 10, 7487, 7513),
(440, 6280, 'wan zharif aidan', 'Draft', '2026-02-27', '2026-04-21 06:25:22', 27, 17, 10, 7460, 7486),
(439, 6280, 'wan zharif aidan', 'Draft', '2026-02-27', '2026-04-21 06:25:22', 0, NULL, NULL, NULL, NULL),
(247, 6328, 'RAEF ZAFRAN BIN REDHUWAN', 'Submit', '2025-05-14', '2026-04-21 06:25:22', 33, 33, 0, 2889, 2921),
(248, 6328, 'RAEF ZAFRAN BIN REDHUWAN', 'Draft', '2025-05-14', '2026-04-21 06:25:22', 10, 10, 0, 2862, 2871),
(251, 6404, 'Muhamad Daniel Bin Muhamad Termizi', 'Draft', '2025-05-14', '2026-04-21 06:25:22', 9, 9, 0, 2930, 2938),
(250, 6404, 'Muhamad Daniel Bin Muhamad Termizi', 'Draft', '2025-05-14', '2026-04-21 06:25:22', 8, 8, 0, 2922, 2929),
(290, 7051, 'muhammad aidan eusoff bin muhammad afiq', 'Submit', '2025-07-12', '2026-04-21 06:25:22', 13, 13, 0, 3899, 3911),
(291, 7051, 'muhammad aidan eusoff bin muhammad afiq', 'Draft', '2025-07-12', '2026-04-21 06:25:22', 13, 13, 0, 3886, 3898),
(287, 7077, 'Fathi', 'Submit', '2025-07-11', '2026-04-21 06:25:22', 24, 24, 0, 3845, 3868),
(288, 7077, 'Fathi', 'Draft', '2025-07-11', '2026-04-21 06:25:22', 23, 23, 0, 3822, 3844),
(308, 7385, 'Kumaran', 'Draft', '2025-08-13', '2026-04-21 06:25:22', 45, 45, 0, 4290, 4334),
(307, 7385, 'Kumaran', 'Draft', '2025-08-13', '2026-04-21 06:25:22', 45, 45, 0, 4245, 4289),
(310, 7447, 'Subhan daniel', 'Submit', '2025-08-16', '2026-04-21 06:25:22', 5, 5, 0, 4363, 4367),
(311, 7447, 'Subhan daniel', 'Draft', '2025-08-16', '2026-04-21 06:25:22', 5, 5, 0, 4358, 4362),
(317, 7454, 'Dhia Mikhail', 'Submit', '2025-09-02', '2026-04-21 06:25:22', 15, 15, 0, 4570, 4584),
(318, 7454, 'Dhia Mikhail', 'Draft', '2025-09-02', '2026-04-21 06:25:22', 13, 13, 0, 4542, 4554),
(336, 8325, 'MUHAMMAD ZIYAD AQIL BIN MUHAMMAD AMINUDDIN', 'Submit', '2025-10-28', '2026-04-21 06:25:22', 15, 10, 0, 4891, 4905),
(337, 8325, 'MUHAMMAD ZIYAD AQIL BIN MUHAMMAD AMINUDDIN', 'Draft', '2025-10-28', '2026-04-21 06:25:22', 10, 10, 0, 4866, 4875),
(344, 8443, 'Puteri Aura Ufairah', 'Draft', '2025-11-05', '2026-04-21 06:25:22', 7, 7, 0, 5029, 5035),
(341, 8443, 'Puteri Aura Ufairah', 'Draft', '2025-11-05', '2026-04-21 06:25:22', 7, 7, 0, 4968, 4974),
(355, 8490, 'Afreen Rizqi Bin Ahmad Rozaiman', 'Submit', '2025-11-11', '2026-04-21 06:25:22', 5, 5, 0, 5389, 5393),
(356, 8490, 'Afreen Rizqi Bin Ahmad Rozaiman', 'Draft', '2025-11-11', '2026-04-21 06:25:22', 5, 5, 0, 5384, 5388),
(362, 8529, 'Muhammad Khalish Darwisy bin Mohd Suffian', 'Draft', '2025-11-13', '2026-04-21 06:25:22', 0, NULL, NULL, NULL, NULL),
(360, 8529, 'Muhammad Khalish Darwisy bin Mohd Suffian', 'Draft', '2025-11-13', '2026-04-21 06:25:22', 0, NULL, NULL, NULL, NULL),
(361, 8529, 'Muhammad Khalish Darwisy bin Mohd Suffian', 'Draft', '2025-11-13', '2026-04-21 06:25:22', 0, NULL, NULL, NULL, NULL),
(366, 8591, 'Nik Arya Qaseh Binti Nik Mohd Aiman', 'Submit', '2025-11-20', '2026-04-21 06:25:22', 9, 9, 0, 5545, 5553),
(367, 8591, 'Nik Arya Qaseh Binti Nik Mohd Aiman', 'Draft', '2025-11-20', '2026-04-21 06:25:22', 9, 9, 0, 5536, 5544),
(385, 8835, 'RAYQAL MATEEN BIN RAFIZAL ', 'Submit', '2025-12-18', '2026-04-21 06:25:22', 32, 32, 0, 5927, 5958),
(386, 8835, 'RAYQAL MATEEN BIN RAFIZAL ', 'Draft', '2025-12-18', '2026-04-21 06:25:22', 18, 18, 0, 5858, 5875),
(384, 8857, 'Muhammed Irfan Raees Bin Muhammed Imran ', 'Submit', '2025-12-23', '2026-04-21 06:25:22', 6, 6, 0, 5965, 5970),
(388, 8857, 'Muhammed Irfan Raees Bin Muhammed Imran ', 'Draft', '2025-12-23', '2026-04-21 06:25:22', 6, 6, 0, 5959, 5964),
(417, 9141, 'Amir Falique Bin Mohamad Amirul', 'Submit', '2026-01-23', '2026-04-21 06:25:22', 2, 2, 0, 6937, 6938),
(416, 9141, 'Amir Falique Bin Mohamad Amirul', 'Draft', '2026-01-23', '2026-04-21 06:25:22', 2, 2, 0, 6933, 6934),
(408, 9276, 'Raid Ramzi Bin Razman', 'Submit', '2026-01-21', '2026-04-21 06:25:22', 10, 10, 0, 6863, 6872),
(410, 9276, 'Raid Ramzi Bin Razman', 'Draft', '2026-01-21', '2026-04-21 06:25:22', 10, 10, 0, 6838, 6847),
(430, 9698, 'Muhammad Afif Bin Mohd Syahran', 'Draft', '2026-02-12', '2026-04-21 06:25:22', 0, NULL, NULL, NULL, NULL),
(431, 9698, 'Muhammad Afif Bin Mohd Syahran', 'Draft', '2026-02-12', '2026-04-21 06:25:22', 0, NULL, NULL, NULL, NULL),
(457, 10246, 'Muhammad Yusuf Adhwa Bin Mohamad Akmal', 'Submit', '2026-04-08', '2026-04-21 06:25:22', 3, 3, 0, 7840, 7842),
(459, 10246, 'Muhammad Yusuf Adhwa Bin Mohamad Akmal', 'Draft', '2026-04-08', '2026-04-21 06:25:22', 3, 3, 0, 7837, 7839),
(463, 10361, 'Muhammad Alif Khalid Bin Mohd Saiful Bahari', 'Draft', '2026-04-09', '2026-04-21 06:25:22', 11, 11, 0, 7872, 7882),
(461, 10361, 'Muhammad Alif Khalid Bin Mohd Saiful Bahari', 'Draft', '2026-04-09', '2026-04-21 06:25:22', 11, 11, 0, 7852, 7862),
(486, 10460, 'Ayden Shiraz Bin Muhammad Amshar', 'Submit', '2026-04-16', '2026-04-21 06:25:22', 9, 9, 0, 8166, 8174),
(487, 10460, 'Ayden Shiraz Bin Muhammad Amshar', 'Draft', '2026-04-16', '2026-04-21 06:25:22', 0, NULL, NULL, NULL, NULL),
(482, 10488, 'Jayden Aryan', 'Draft', '2026-04-15', '2026-04-21 06:25:22', 16, 16, 0, 8061, 8076),
(481, 10488, 'Jayden Aryan', 'Draft', '2026-04-15', '2026-04-21 06:25:22', 16, 16, 0, 8045, 8060),
(478, 10518, 'Armelleana Binti Mohd Hisyamuddin', 'Submit', '2026-04-15', '2026-04-21 06:25:22', 15, 15, 0, 8099, 8113),
(479, 10518, 'Armelleana Binti Mohd Hisyamuddin', 'Draft', '2026-04-15', '2026-04-21 06:25:22', 15, 15, 0, 8013, 8027),
(520, 10630, 'Kaashni Suriapryan', 'Submit', '2026-04-24', '2026-04-24 08:24:46', 3, 3, 0, 8469, 8471),
(521, 10630, 'Kaashni Suriapryan', 'Draft', '2026-04-24', '2026-04-24 09:06:05', 2, 2, 0, 8467, 8468),
(524, 10820, 'Muhammad Yusuf Bin Mohd Khairul Izzat', 'Draft', '2026-04-28', '2026-04-28 04:05:52', 2, 2, 0, 8494, 8495),
(523, 10820, 'Muhammad Yusuf Bin Mohd Khairul Izzat', 'Draft', '2026-04-28', '2026-04-28 04:05:48', 2, 2, 0, 8492, 8493),
(542, 10969, 'Lyodra Aurelia Josephine', 'Draft', '2026-05-08', '2026-05-08 07:44:41', 35, 31, 4, 8772, 8806),
(541, 10969, 'Lyodra Aurelia Josephine', 'Draft', '2026-05-08', '2026-05-08 07:43:47', 35, 31, 4, 8737, 8771),
(596, 11385, 'Muhammad Fakhri Bin Mohd Fakhrul Islam', 'Submit', '2026-06-26', '2026-06-26 09:12:15', 8, 4, 4, 10072, 10079),
(597, 11385, 'Muhammad Fakhri Bin Mohd Fakhrul Islam', 'Draft', '2026-06-26', '2026-06-26 09:15:41', 8, 4, 4, 10064, 10071),
(592, 11484, 'Mohamad Harith Mateen Bin Abdullah', 'Submit', '2026-06-25', '2026-06-25 01:50:13', 1, 1, 0, 10055, 10055),
(593, 11484, 'Mohamad Harith Mateen Bin Abdullah', 'Draft', '2026-06-25', '2026-06-25 01:50:36', 1, 1, 0, 10034, 10034),
(610, 11610, 'Izz Naufal Bin Izman', 'Draft', '2026-07-02', '2026-07-02 08:29:29', 2, 2, 0, 10399, 10400),
(608, 11610, 'Izz Naufal Bin Izman', 'Draft', '2026-07-02', '2026-07-02 04:52:26', 1, 1, 0, 10379, 10379),
(617, 11707, 'Aisy Haseef Bin Muhamad Aizuddin', 'Submit', '2026-07-08', '2026-07-08 07:24:25', 0, NULL, NULL, NULL, NULL),
(618, 11707, 'Aisy Haseef Bin Muhamad Aizuddin', 'Draft', '2026-07-08', '2026-07-08 07:55:13', 0, NULL, NULL, NULL, NULL),
(641, 11923, 'Muhammad Hadif Bin Muhammad Hafizhan', 'Draft', '2026-07-24', '2026-07-24 04:14:53', 2, 2, 0, 10545, 10546),
(640, 11923, 'Muhammad Hadif Bin Muhammad Hafizhan', 'Draft', '2026-07-24', '2026-07-24 04:14:09', 2, 2, 0, 10543, 10544);

--
-- Indexes for dumped tables
--

--
-- Indexes for table `s`
--
ALTER TABLE `s`
  ADD PRIMARY KEY (`screening_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `s`
--
ALTER TABLE `s`
  MODIFY `screening_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=671;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
