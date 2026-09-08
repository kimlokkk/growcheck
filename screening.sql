-- phpMyAdmin SQL Dump
-- version 5.2.3
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: Aug 12, 2026 at 02:41 PM
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

INSERT INTO `s` (`student_id`, `student`, `staff_id`, `screening_date`, `screening_count`, `screening_ids`) VALUES
(5759, 'MUHAMMAD HARRAZ ZAFRAN BIN MOHD SHAHRIM', 5, '2025-03-12', 3, '163:,165:,167:'),
(5805, 'NUR NUHA MIKAYLA BINTI AZIZI', 126, '2026-02-27', 3, '442:Draft,443:Draft,444:Draft'),
(5978, 'Shahrull Al-Hafiraz bin Shahrull Nizam ', 126, '2025-04-08', 3, '180:Draft,181:Draft,182:Draft'),
(6280, 'wan zharif aidan', 126, '2026-02-27', 3, '439:Draft,440:Draft,441:Draft'),
(8529, 'Muhammad Khalish Darwisy bin Mohd Suffian', 126, '2025-11-13', 3, '360:Draft,361:Draft,362:Draft'),
(5819, 'Aamily Dahlia', 195, '2025-03-15', 2, '169:,170:'),
(6003, 'muhammad ryan arjuna', 5, '2025-04-12', 2, '190:Draft,191:Draft'),
(6087, 'MUHAMMAD ARYAN MIKHAIL BIN MOHAMAD RIDZUAN', 186, '2025-04-23', 2, '216:Draft,217:Draft'),
(6099, 'Muhammad Uwais Mateen bin Mohd Alif Akmal', 126, '2025-05-06', 2, '235:Draft,236:Draft'),
(6182, 'Nurzahra binti mohd firdaus', 5, '2025-04-26', 2, '223:Submit,224:Draft'),
(6273, 'Ubaidillah Mustain b. Muhammad Bukhari', 189, '2025-04-30', 2, '230:Draft,231:Draft'),
(6328, 'RAEF ZAFRAN BIN REDHUWAN', 195, '2025-05-14', 2, '247:Submit,248:Draft'),
(6404, 'Muhamad Daniel Bin Muhamad Termizi', 189, '2025-05-14', 2, '250:Draft,251:Draft'),
(7051, 'muhammad aidan eusoff bin muhammad afiq', 186, '2025-07-12', 2, '290:Submit,291:Draft'),
(7077, 'Fathi', 186, '2025-07-11', 2, '287:Submit,288:Draft'),
(7385, 'Kumaran', 188, '2025-08-13', 2, '307:Draft,308:Draft'),
(7447, 'Subhan daniel', 186, '2025-08-16', 2, '310:Submit,311:Draft'),
(7454, 'Dhia Mikhail', 5, '2025-09-02', 2, '317:Submit,318:Draft'),
(8325, 'MUHAMMAD ZIYAD AQIL BIN MUHAMMAD AMINUDDIN', 5, '2025-10-28', 2, '336:Submit,337:Draft'),
(8443, 'Puteri Aura Ufairah', 186, '2025-11-05', 2, '341:Draft,344:Draft'),
(8490, 'Afreen Rizqi Bin Ahmad Rozaiman', 189, '2025-11-11', 2, '355:Submit,356:Draft'),
(8591, 'Nik Arya Qaseh Binti Nik Mohd Aiman', 189, '2025-11-20', 2, '366:Submit,367:Draft'),
(8835, 'RAYQAL MATEEN BIN RAFIZAL ', 189, '2025-12-18', 2, '385:Submit,386:Draft'),
(8857, 'Muhammed Irfan Raees Bin Muhammed Imran ', 5, '2025-12-23', 2, '384:Submit,388:Draft'),
(9141, 'Amir Falique Bin Mohamad Amirul', 189, '2026-01-23', 2, '416:Draft,417:Submit'),
(9276, 'Raid Ramzi Bin Razman', 5, '2026-01-21', 2, '408:Submit,410:Draft'),
(9698, 'Muhammad Afif Bin Mohd Syahran', 188, '2026-02-12', 2, '430:Draft,431:Draft'),
(10246, 'Muhammad Yusuf Adhwa Bin Mohamad Akmal', 186, '2026-04-08', 2, '457:Submit,459:Draft'),
(10361, 'Muhammad Alif Khalid Bin Mohd Saiful Bahari', 195, '2026-04-09', 2, '461:Draft,463:Draft'),
(10460, 'Ayden Shiraz Bin Muhammad Amshar', 5, '2026-04-16', 2, '486:Submit,487:Draft'),
(10488, 'Jayden Aryan', 189, '2026-04-15', 2, '481:Draft,482:Draft'),
(10518, 'Armelleana Binti Mohd Hisyamuddin', 195, '2026-04-15', 2, '478:Submit,479:Draft'),
(10630, 'Kaashni Suriapryan', 195, '2026-04-24', 2, '520:Submit,521:Draft'),
(10820, 'Muhammad Yusuf Bin Mohd Khairul Izzat', 189, '2026-04-28', 2, '523:Draft,524:Draft'),
(10969, 'Lyodra Aurelia Josephine', 186, '2026-05-08', 2, '541:Draft,542:Draft'),
(11385, 'Muhammad Fakhri Bin Mohd Fakhrul Islam', 126, '2026-06-26', 2, '596:Submit,597:Draft'),
(11484, 'Mohamad Harith Mateen Bin Abdullah', 195, '2026-06-25', 2, '592:Submit,593:Draft'),
(11610, 'Izz Naufal Bin Izman', 188, '2026-07-02', 2, '608:Draft,610:Draft'),
(11707, 'Aisy Haseef Bin Muhamad Aizuddin', 189, '2026-07-08', 2, '617:Submit,618:Draft'),
(11923, 'Muhammad Hadif Bin Muhammad Hafizhan', 189, '2026-07-24', 2, '640:Draft,641:Draft');

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
