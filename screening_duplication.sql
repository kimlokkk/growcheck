-- phpMyAdmin SQL Dump
-- version 5.2.3
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: Aug 12, 2026 at 02:21 PM
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
-- Table structure for table `screening`
--

CREATE TABLE `screening` (
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
-- Dumping data for table `screening`
--

INSERT INTO `screening` (`screening_id`, `staff_id`, `staff_name`, `student_id`, `student`, `age`, `age_fine_motor`, `age_gross_motor`, `age_personal_social`, `age_language`, `status`, `screening_date`, `date_created`, `therapist_suggestion`) VALUES
(163, 5, 'Mazwa Izzati Binti Mazuki', 5759, 'MUHAMMAD HARRAZ ZAFRAN BIN MOHD SHAHRIM', 44, 0, 0, 0, 0, '', '2025-03-12', '2026-04-21 06:25:22', 'Screening has been done'),
(165, 5, 'Mazwa Izzati Binti Mazuki', 5759, 'MUHAMMAD HARRAZ ZAFRAN BIN MOHD SHAHRIM', 44, 22, 0, 20, 18.8, '', '2025-03-12', '2026-04-21 06:25:22', 'Screening has been done'),
(167, 5, 'Mazwa Izzati Binti Mazuki', 5759, 'MUHAMMAD HARRAZ ZAFRAN BIN MOHD SHAHRIM', 44, 22, 19, 20, 18.8, '', '2025-03-12', '2026-04-21 06:25:22', 'Screening has been done'),
(442, 126, 'Rohaini binti Hamidun', 5805, 'NUR NUHA MIKAYLA BINTI AZIZI', 26, 26, 13, 17, 0, 'Draft', '2026-02-27', '2026-04-21 06:25:22', ''),
(443, 126, 'Rohaini binti Hamidun', 5805, 'NUR NUHA MIKAYLA BINTI AZIZI', 26, 26, 13, 17, 0, 'Draft', '2026-02-27', '2026-04-21 06:25:22', ''),
(444, 126, 'Rohaini binti Hamidun', 5805, 'NUR NUHA MIKAYLA BINTI AZIZI', 26, 26, 13, 17, 0, 'Draft', '2026-02-27', '2026-04-21 06:25:22', ''),
(169, 195, 'Nor Shafiqah Binti Mohammed ', 5819, 'Aamily Dahlia', 38, 38, 33, 27, 20.9, '', '2025-03-15', '2026-04-21 06:25:22', 'Screening has been done'),
(170, 195, 'Nor Shafiqah Binti Mohammed ', 5819, 'Aamily Dahlia', 38, 38, 33, 27, 20.9, '', '2025-03-15', '2026-04-21 06:25:22', 'Screening has been done'),
(180, 126, 'Rohaini binti Hamidun', 5978, 'Shahrull Al-Hafiraz bin Shahrull Nizam ', 77, 77, 77, 77, 60, 'Draft', '2025-04-08', '2026-04-21 06:25:22', 'Child have impression of ADHD. Therapist advise for diagnosis after 3-6 months after attending OT.'),
(181, 126, 'Rohaini binti Hamidun', 5978, 'Shahrull Al-Hafiraz bin Shahrull Nizam ', 77, 77, 77, 77, 60, 'Draft', '2025-04-08', '2026-04-21 06:25:22', 'Child have impression of ADHD. Therapist advise for diagnosis after 3-6 months after attending OT.'),
(182, 126, 'Rohaini binti Hamidun', 5978, 'Shahrull Al-Hafiraz bin Shahrull Nizam ', 77, 77, 77, 77, 60, 'Draft', '2025-04-08', '2026-04-21 06:25:22', 'Child have impression of ADHD. Therapist advise for diagnosis after 3-6 months after attending OT.'),
(190, 5, 'Mazwa Izzati Binti Mazuki', 6003, 'muhammad ryan arjuna', 43, 33, 26, 16, 43, 'Draft', '2025-04-12', '2026-04-21 06:25:22', ''),
(191, 5, 'Mazwa Izzati Binti Mazuki', 6003, 'muhammad ryan arjuna', 43, 33, 26, 16, 43, 'Draft', '2025-04-12', '2026-04-21 06:25:22', ''),
(216, 186, 'Nur Amirah Hanani Binti Rafaai', 6087, 'MUHAMMAD ARYAN MIKHAIL BIN MOHAMAD RIDZUAN', 41, 33, 41, 27, 15.8, 'Draft', '2025-04-23', '2026-04-21 06:25:22', 'Occupational therapy '),
(217, 186, 'Nur Amirah Hanani Binti Rafaai', 6087, 'MUHAMMAD ARYAN MIKHAIL BIN MOHAMAD RIDZUAN', 41, 33, 41, 27, 15.8, 'Draft', '2025-04-23', '2026-04-21 06:25:22', 'Occupational therapy '),
(235, 126, 'Rohaini binti Hamidun', 6099, 'Muhammad Uwais Mateen bin Mohd Alif Akmal', 29, 29, 29, 20, 25, 'Draft', '2025-05-06', '2026-04-21 06:25:22', ''),
(236, 126, 'Rohaini binti Hamidun', 6099, 'Muhammad Uwais Mateen bin Mohd Alif Akmal', 29, 29, 0, 20, 25, 'Draft', '2025-05-06', '2026-04-21 06:25:22', ''),
(223, 5, 'Mazwa Izzati Binti Mazuki', 6182, 'Nurzahra binti mohd firdaus', 31, 31, 31, 31, 31, 'Submit', '2025-04-26', '2026-04-21 06:25:22', 'st'),
(224, 5, 'Mazwa Izzati Binti Mazuki', 6182, 'Nurzahra binti mohd firdaus', 31, 31, 31, 31, 31, 'Draft', '2025-04-26', '2026-04-21 06:25:22', 'st'),
(228, 189, 'Nurul Hafisya binti Mohammad Khir', 6232, 'Aisy bin mohd ilyas', 56, 56, 56, 56, 56, 'Submit', '2026-04-22', '2026-04-21 06:25:22', 'TRIAL EIP'),
(229, 189, 'Nurul Hafisya binti Mohammad Khir', 6232, 'Aisy bin mohd ilyas', 56, 44, 56, 27, 25, 'Draft', '2025-04-29', '2026-04-21 06:25:22', 'TRIAL EIP'),
(230, 189, 'Nurul Hafisya binti Mohammad Khir', 6273, 'Ubaidillah Mustain b. Muhammad Bukhari', 83, 83, 83, 83, 83, 'Draft', '2025-04-30', '2026-04-21 06:25:22', 'OT'),
(231, 189, 'Nurul Hafisya binti Mohammad Khir', 6273, 'Ubaidillah Mustain b. Muhammad Bukhari', 83, 83, 83, 83, 83, 'Draft', '2025-04-30', '2026-04-21 06:25:22', 'OT'),
(439, 126, 'Rohaini binti Hamidun', 6280, 'wan zharif aidan', 75, 75, 75, 75, 75, 'Draft', '2026-02-27', '2026-04-21 06:25:22', ''),
(440, 126, 'Rohaini binti Hamidun', 6280, 'wan zharif aidan', 75, 48, 42, 48, 75, 'Draft', '2026-02-27', '2026-04-21 06:25:22', 'personal social ada perubahan (pass,fail,no) lepas 1st time buat, tapi lepas ada correction, system tetap baca data yg lama (45month) tpi component dalam fail, no ada perubahan'),
(441, 126, 'Rohaini binti Hamidun', 6280, 'wan zharif aidan', 75, 48, 42, 48, 75, 'Draft', '2026-02-27', '2026-04-21 06:25:22', 'personal social ada perubahan (pass,fail,no) lepas 1st time buat, tapi lepas ada correction, system tetap baca data yg lama (45month) tpi component dalam fail, no ada perubahan'),
(247, 195, 'Nor Shafiqah Binti Mohammed ', 6328, 'RAEF ZAFRAN BIN REDHUWAN', 44, 24, 19, 27, 8.3, 'Submit', '2025-05-14', '2026-04-21 06:25:22', ''),
(248, 195, 'Nor Shafiqah Binti Mohammed ', 6328, 'RAEF ZAFRAN BIN REDHUWAN', 44, 24, 19, 27, 0, 'Draft', '2025-05-14', '2026-04-21 06:25:22', ''),
(250, 189, 'Nurul Hafisya binti Mohammad Khir', 6404, 'Muhamad Daniel Bin Muhamad Termizi', 75, 75, 75, 0, 32, 'Draft', '2025-05-14', '2026-04-21 06:25:22', 'ST'),
(251, 189, 'Nurul Hafisya binti Mohammad Khir', 6404, 'Muhamad Daniel Bin Muhamad Termizi', 75, 75, 75, 50, 32, 'Draft', '2025-05-14', '2026-04-21 06:25:22', 'ST'),
(290, 186, 'Nur Amirah Hanani Binti Rafaai', 7051, 'muhammad aidan eusoff bin muhammad afiq', 38, 32, 19, 26, 20.9, 'Submit', '2025-07-12', '2026-04-21 06:25:22', 'Occupational Therapist'),
(291, 186, 'Nur Amirah Hanani Binti Rafaai', 7051, 'muhammad aidan eusoff bin muhammad afiq', 38, 32, 19, 26, 20.9, 'Draft', '2025-07-12', '2026-04-21 06:25:22', 'Occupational Therapist'),
(287, 186, 'Nur Amirah Hanani Binti Rafaai', 7077, 'Fathi', 33, 17.1, 18, 19, 11, 'Submit', '2025-07-11', '2026-04-21 06:25:22', 'Occupational Therapy'),
(288, 186, 'Nur Amirah Hanani Binti Rafaai', 7077, 'Fathi', 33, 17.1, 18, 19, 11, 'Draft', '2025-07-11', '2026-04-21 06:25:22', 'Occupational Therapy'),
(301, 189, 'Nurul Hafisya binti Mohammad Khir', 7284, 'Fattah uwais', 39, 39, 39, 39, 39, 'Submit', '2026-05-25', '2026-04-21 06:25:22', ''),
(302, 189, 'Nurul Hafisya binti Mohammad Khir', 7284, 'Fattah uwais', 29, 29, 24, 29, 29, 'Draft', '2025-07-30', '2026-04-21 06:25:22', ''),
(307, 188, 'Puteri ‘Aisyah Binti Abd Ghaffar', 7385, 'Kumaran', 84, 24, 19, 50, 15.8, 'Draft', '2025-08-13', '2026-04-21 06:25:22', 'OT 1 to 1 session'),
(308, 188, 'Puteri ‘Aisyah Binti Abd Ghaffar', 7385, 'Kumaran', 84, 24, 19, 50, 15.8, 'Draft', '2025-08-13', '2026-04-21 06:25:22', 'OT 1 to 1 session'),
(310, 186, 'Nur Amirah Hanani Binti Rafaai', 7447, 'Subhan daniel', 45, 45, 45, 33, 39, 'Submit', '2025-08-16', '2026-04-21 06:25:22', 'ST'),
(311, 186, 'Nur Amirah Hanani Binti Rafaai', 7447, 'Subhan daniel', 45, 45, 45, 33, 39, 'Draft', '2025-08-16', '2026-04-21 06:25:22', 'ST'),
(317, 5, 'Mazwa Izzati Binti Mazuki', 7454, 'Dhia Mikhail', 36, 22, 26, 27, 18.8, 'Submit', '2025-09-02', '2026-04-21 06:25:22', 'child shows of movement sensitivity. further observation is needed. suggestion OT'),
(318, 5, 'Mazwa Izzati Binti Mazuki', 7454, 'Dhia Mikhail', 36, 22, 21, 27, 18.8, 'Draft', '2025-09-02', '2026-04-21 06:25:22', 'OT'),
(336, 5, 'Mazwa Izzati Binti Mazuki', 8325, 'MUHAMMAD ZIYAD AQIL BIN MUHAMMAD AMINUDDIN', 49, 22, 46, 26, 39, 'Submit', '2025-10-28', '2026-04-21 06:25:22', 'refer OT'),
(337, 5, 'Mazwa Izzati Binti Mazuki', 8325, 'MUHAMMAD ZIYAD AQIL BIN MUHAMMAD AMINUDDIN', 49, 22, 46, 26, 39, 'Draft', '2025-10-28', '2026-04-21 06:25:22', 'refer OT'),
(341, 186, 'Nur Amirah Hanani Binti Rafaai', 8443, 'Puteri Aura Ufairah', 20, 20, 20, 20, 6, 'Draft', '2025-11-05', '2026-04-21 06:25:22', 'PG'),
(344, 186, 'Nur Amirah Hanani Binti Rafaai', 8443, 'Puteri Aura Ufairah', 20, 20, 20, 20, 6, 'Draft', '2025-11-05', '2026-04-21 06:25:22', 'PG'),
(351, 189, 'Nurul Hafisya binti Mohammad Khir', 8487, 'YESHUA SURENTHIRAN ', 41, 12.4, 11, 12, 18.8, 'Submit', '2025-11-08', '2026-04-21 06:25:22', 'OT'),
(352, 189, 'Nurul Hafisya binti Mohammad Khir', 8487, 'YESHUA SURENTHIRAN ', 41, 12.4, 11, 12, 18.8, 'Draft', '2025-11-06', '2026-04-21 06:25:22', 'OT'),
(355, 189, 'Nurul Hafisya binti Mohammad Khir', 8490, 'Afreen Rizqi Bin Ahmad Rozaiman', 39, 39, 39, 33, 30, 'Submit', '2025-11-11', '2026-04-21 06:25:22', 'OT for social skills,sensory function'),
(356, 189, 'Nurul Hafisya binti Mohammad Khir', 8490, 'Afreen Rizqi Bin Ahmad Rozaiman', 39, 39, 39, 33, 30, 'Draft', '2025-11-11', '2026-04-21 06:25:22', 'OT for social skills,sensory function'),
(360, 126, 'Rohaini binti Hamidun', 8529, 'Muhammad Khalish Darwisy bin Mohd Suffian', 70, 70, 0, 70, 0, 'Draft', '2025-11-13', '2026-04-21 06:25:22', ''),
(361, 126, 'Rohaini binti Hamidun', 8529, 'Muhammad Khalish Darwisy bin Mohd Suffian', 70, 70, 0, 70, 0, 'Draft', '2025-11-13', '2026-04-21 06:25:22', ''),
(362, 126, 'Rohaini binti Hamidun', 8529, 'Muhammad Khalish Darwisy bin Mohd Suffian', 70, 70, 0, 70, 0, 'Draft', '2025-11-13', '2026-04-21 06:25:22', ''),
(366, 189, 'Nurul Hafisya binti Mohammad Khir', 8591, 'Nik Arya Qaseh Binti Nik Mohd Aiman', 71, 71, 71, 50, 39, 'Submit', '2025-11-20', '2026-04-21 06:25:22', 'speech therapist'),
(367, 189, 'Nurul Hafisya binti Mohammad Khir', 8591, 'Nik Arya Qaseh Binti Nik Mohd Aiman', 71, 71, 71, 50, 39, 'Draft', '2025-11-20', '2026-04-21 06:25:22', 'speech therapist'),
(393, 126, 'Rohaini binti Hamidun', 8725, 'Nurfiqa aryana binti hariyanto', 56, 56, 56, 56, 50, 'Submit', '2025-12-27', '2026-04-21 06:25:22', '1) Poor attention span. Less than 1 min attend to FM, GM, toys & learning\n2) Sensory function: tactile, auditory, visual hypersensitive \n3) GM: fair postural control on unbalance surface (eg: gymball)\n4) Hearing test and earnwax cleaning. C have unintelligible speech despite good communication and interaction skill (eg: ask qeaustion, story telling, commenting, requesting)\n5) Behavior modification: to encourage self-control\n6) Poor school readiness skill'),
(394, 126, 'Rohaini binti Hamidun', 8725, 'Nurfiqa aryana binti hariyanto', 56, 56, 46, 56, 50, 'Draft', '2025-12-26', '2026-04-21 06:25:22', '1) Poor attention span. Less than 1 min attend to FM, GM, toys & learning\n2) Sensory function: tactile, auditory, visual hypersensitive \n3) GM: fair postural control on unbalance surface (eg: gymball)\n4) Hearing test and earnwax cleaning. C have unintelligible speech despite good communication and interaction skill (eg: ask qeaustion, story telling, commenting, requesting)\n5) Behavior modification: to encourage self-control\n6) Poor school readiness skill'),
(380, 189, 'Nurul Hafisya binti Mohammad Khir', 8730, 'Zaffyn Irsyad Bin Rasyid', 35, 17.1, 18, 19, 18.8, 'Submit', '2026-05-25', '2026-04-21 06:25:22', ''),
(381, 189, 'Nurul Hafisya binti Mohammad Khir', 8730, 'Zaffyn Irsyad Bin Rasyid', 30, 17.1, 19, 19, 14.6, 'Draft', '2025-12-09', '2026-04-21 06:25:22', ''),
(385, 189, 'Nurul Hafisya binti Mohammad Khir', 8835, 'RAYQAL MATEEN BIN RAFIZAL ', 32, 22, 24, 6, 5.6, 'Submit', '2025-12-18', '2026-04-21 06:25:22', 'OT'),
(386, 189, 'Nurul Hafisya binti Mohammad Khir', 8835, 'RAYQAL MATEEN BIN RAFIZAL ', 32, 22, 32, 6, 5.6, 'Draft', '2025-12-18', '2026-04-21 06:25:22', 'OT'),
(384, 5, 'Mazwa Izzati Binti Mazuki', 8857, 'Muhammed Irfan Raees Bin Muhammed Imran ', 72, 72, 46, 72, 50, 'Submit', '2025-12-23', '2026-04-21 06:25:22', 'only came for therapist provide report for school'),
(388, 5, 'Mazwa Izzati Binti Mazuki', 8857, 'Muhammed Irfan Raees Bin Muhammed Imran ', 72, 72, 46, 72, 50, 'Draft', '2025-12-23', '2026-04-21 06:25:22', 'only came for therapist provide report for school'),
(416, 189, 'Nurul Hafisya binti Mohammad Khir', 9141, 'Amir Falique Bin Mohamad Amirul', 22, 17.1, 22, 19, 22, 'Draft', '2026-01-23', '2026-04-21 06:25:22', 'No issues, monitor at home but parents request for playgroup for social exposure '),
(417, 189, 'Nurul Hafisya binti Mohammad Khir', 9141, 'Amir Falique Bin Mohamad Amirul', 22, 17.1, 22, 19, 22, 'Submit', '2026-01-23', '2026-04-21 06:25:22', 'No issues, monitor at home but parents request for playgroup for social exposure '),
(408, 5, 'Mazwa Izzati Binti Mazuki', 9276, 'Raid Ramzi Bin Razman', 31, 12.4, 31, 20, 18.8, 'Submit', '2026-01-21', '2026-04-21 06:25:22', 'OT'),
(410, 5, 'Mazwa Izzati Binti Mazuki', 9276, 'Raid Ramzi Bin Razman', 31, 12.4, 31, 20, 18.8, 'Draft', '2026-01-21', '2026-04-21 06:25:22', 'OT'),
(427, 189, 'Nurul Hafisya binti Mohammad Khir', 9513, 'Zaheen Musa Bin Zhafran Safwan', 33, 17.1, 33, 27, 5.6, 'Submit', '2026-02-07', '2026-04-21 06:25:22', ''),
(428, 189, 'Nurul Hafisya binti Mohammad Khir', 9513, 'Zaheen Musa Bin Zhafran Safwan', 33, 32, 33, 27, 5.6, 'Draft', '2026-02-03', '2026-04-21 06:25:22', ''),
(430, 188, 'Puteri ‘Aisyah Binti Abd Ghaffar', 9698, 'Muhammad Afif Bin Mohd Syahran', 67, 67, 67, 67, 67, 'Draft', '2026-02-12', '2026-04-21 06:25:22', 'ot 1-to-1 session.'),
(431, 188, 'Puteri ‘Aisyah Binti Abd Ghaffar', 9698, 'Muhammad Afif Bin Mohd Syahran', 67, 67, 67, 67, 67, 'Draft', '2026-02-12', '2026-04-21 06:25:22', 'ot 1-to-1 session.'),
(446, 189, 'Nurul Hafisya binti Mohammad Khir', 9932, 'Wan Muhammad Nuh Anaqi Bin Wan Khairul Anuar', 80, 80, 80, 80, 80, 'Submit', '2026-03-26', '2026-04-21 06:25:22', 'OT:aim for sensory, focus attention,preverbal skills'),
(447, 189, 'Nurul Hafisya binti Mohammad Khir', 9932, 'Wan Muhammad Nuh Anaqi Bin Wan Khairul Anuar', 79, 79, 79, 79, 39, 'Draft', '2026-02-28', '2026-04-21 06:25:22', 'OT:aim for sensory, focus attention,preverbal skills'),
(457, 186, 'Nur Amirah Hanani Binti Rafaai', 10246, 'Muhammad Yusuf Adhwa Bin Mohamad Akmal', 15, 15, 15, 15, 8.3, 'Submit', '2026-04-08', '2026-04-21 06:25:22', 'language stimulation - imitation sound, word'),
(459, 186, 'Nur Amirah Hanani Binti Rafaai', 10246, 'Muhammad Yusuf Adhwa Bin Mohamad Akmal', 15, 15, 15, 15, 8.3, 'Draft', '2026-04-08', '2026-04-21 06:25:22', 'language stimulation - imitation sound, word'),
(461, 195, 'Nor Shafiqah Binti Mohammed ', 10361, 'Muhammad Alif Khalid Bin Mohd Saiful Bahari', 31, 31, 31, 20, 8.3, 'Draft', '2026-04-09', '2026-04-21 06:25:22', 'refer to ot 1-to-1 session.'),
(463, 195, 'Nor Shafiqah Binti Mohammed ', 10361, 'Muhammad Alif Khalid Bin Mohd Saiful Bahari', 31, 31, 31, 20, 8.3, 'Draft', '2026-04-09', '2026-04-21 06:25:22', ''),
(472, 189, 'Nurul Hafisya binti Mohammad Khir', 10406, 'Habeel Ezrique Bin Huzairi', 32, 17.1, 19, 15, 32, 'Submit', '2026-05-25', '2026-04-21 06:25:22', 'OT'),
(473, 189, 'Nurul Hafisya binti Mohammad Khir', 10406, 'Habeel Ezrique Bin Huzairi', 30, 17.1, 19, 15, 11, 'Draft', '2026-04-14', '2026-04-21 06:25:22', 'OT'),
(486, 5, 'Mazwa Izzati Binti Mazuki', 10460, 'Ayden Shiraz Bin Muhammad Amshar', 26, 26, 26, 19, 18.8, 'Submit', '2026-04-16', '2026-04-21 06:25:22', ''),
(487, 5, 'Mazwa Izzati Binti Mazuki', 10460, 'Ayden Shiraz Bin Muhammad Amshar', 26, 26, 26, 19, 18.8, 'Draft', '2026-04-16', '2026-04-21 06:25:22', 'monitor at home.. if no improvement or unable to combine 2 words within 6 months then, follow up back with kizzu for speech screening. Preverbal overall established'),
(480, 189, 'Nurul Hafisya binti Mohammad Khir', 10488, 'Jayden Aryan', 34, 17.1, 19, 26, 18.8, 'Submit', '2026-05-25', '2026-04-21 06:25:22', 'OT'),
(481, 189, 'Nurul Hafisya binti Mohammad Khir', 10488, 'Jayden Aryan', 33, 17.1, 19, 27, 18.8, 'Draft', '2026-04-15', '2026-04-21 06:25:22', 'OT'),
(482, 189, 'Nurul Hafisya binti Mohammad Khir', 10488, 'Jayden Aryan', 33, 17.1, 19, 27, 18.8, 'Draft', '2026-04-15', '2026-04-21 06:25:22', 'OT'),
(478, 195, 'Nor Shafiqah Binti Mohammed ', 10518, 'Armelleana Binti Mohd Hisyamuddin', 19, 19, 9, 12, 8.3, 'Submit', '2026-04-15', '2026-04-21 06:25:22', ''),
(479, 195, 'Nor Shafiqah Binti Mohammed ', 10518, 'Armelleana Binti Mohd Hisyamuddin', 19, 19, 9, 12, 8.3, 'Draft', '2026-04-15', '2026-04-21 06:25:22', ''),
(520, 195, 'Nor Shafiqah Binti Mohammed ', 10630, 'Kaashni Suriapryan', 34, 24, 34, 27, 34, 'Submit', '2026-04-24', '2026-04-24 08:24:46', 'refer to st.'),
(521, 195, 'Nor Shafiqah Binti Mohammed ', 10630, 'Kaashni Suriapryan', 34, 32, 34, 27, 34, 'Draft', '2026-04-24', '2026-04-24 09:06:05', ''),
(523, 189, 'Nurul Hafisya binti Mohammad Khir', 10820, 'Muhammad Yusuf Bin Mohd Khairul Izzat', 14, 14, 13, 0, 14, 'Draft', '2026-04-28', '2026-04-28 04:05:48', 'monitor at home'),
(524, 189, 'Nurul Hafisya binti Mohammad Khir', 10820, 'Muhammad Yusuf Bin Mohd Khairul Izzat', 14, 14, 13, 14, 14, 'Draft', '2026-04-28', '2026-04-28 04:05:52', 'monitor at home'),
(545, 5, 'Mazwa Izzati Binti Mazuki', 10929, 'Muhammad Amsyar Ardhani', 42, 42, 42, 27, 32, 'Submit', '2026-05-23', '2026-05-09 02:34:50', 'OT'),
(547, 5, 'Mazwa Izzati Binti Mazuki', 10929, 'Muhammad Amsyar Ardhani', 42, 42, 42, 27, 32, 'Draft', '2026-05-09', '2026-05-09 02:48:26', 'OT'),
(538, 186, 'Nur Amirah Hanani Binti Rafaai', 10937, 'Nur Aulia Mikayla Binti Muhammad Alif Mustaqim', 32, 22, 32, 26, 30, 'Submit', '2026-05-12', '2026-05-07 08:29:10', 'OT to improve attention span.'),
(539, 186, 'Nur Amirah Hanani Binti Rafaai', 10937, 'Nur Aulia Mikayla Binti Muhammad Alif Mustaqim', 32, 22, 32, 26, 30, 'Draft', '2026-05-08', '2026-05-08 03:33:07', 'OT to improve attention span.'),
(540, 186, 'Nur Amirah Hanani Binti Rafaai', 10969, 'Lyodra Aurelia Josephine', 46, 32, 18, 26, 8.3, 'Submit', '2026-05-12', '2026-05-08 05:21:16', 'OT for preverbal skills and sensory regulation'),
(541, 186, 'Nur Amirah Hanani Binti Rafaai', 10969, 'Lyodra Aurelia Josephine', 46, 32, 18, 26, 8.3, 'Draft', '2026-05-08', '2026-05-08 07:43:47', ''),
(542, 186, 'Nur Amirah Hanani Binti Rafaai', 10969, 'Lyodra Aurelia Josephine', 46, 32, 18, 26, 8.3, 'Draft', '2026-05-08', '2026-05-08 07:44:41', ''),
(577, 126, 'Rohaini binti Hamidun', 11348, 'Muhammad Ayyash Syafiq Bin Mohd Sharil', 42, 32, 42, 26, 30, 'Submit', '2026-06-20', '2026-06-16 09:37:53', ''),
(578, 126, 'Rohaini binti Hamidun', 11348, 'Muhammad Ayyash Syafiq Bin Mohd Sharil', 42, 32, 42, 0, 30, 'Draft', '2026-06-16', '2026-06-16 09:38:05', ''),
(596, 126, 'Rohaini binti Hamidun', 11385, 'Muhammad Fakhri Bin Mohd Fakhrul Islam', 36, 36, 26, 27, 25, 'Submit', '2026-06-26', '2026-06-26 09:12:15', ''),
(597, 126, 'Rohaini binti Hamidun', 11385, 'Muhammad Fakhri Bin Mohd Fakhrul Islam', 36, 0, 26, 27, 25, 'Draft', '2026-06-26', '2026-06-26 09:15:41', ''),
(590, 186, 'Nur Amirah Hanani Binti Rafaai', 11468, 'Muhammad Hadif Durrani Bin Helmy Nizam', 53, 39, 46, 50, 30, 'Submit', '2026-06-25', '2026-06-24 09:55:19', 'OT'),
(591, 186, 'Nur Amirah Hanani Binti Rafaai', 11468, 'Muhammad Hadif Durrani Bin Helmy Nizam', 53, 39, 46, 50, 30, 'Draft', '2026-06-24', '2026-06-24 10:04:54', 'OT'),
(592, 195, 'Nor Shafiqah Binti Mohammed ', 11484, 'Mohamad Harith Mateen Bin Abdullah', 24, 24, 24, 24, 22.6, 'Submit', '2026-06-25', '2026-06-25 01:50:13', 'refer to ST.'),
(593, 195, 'Nor Shafiqah Binti Mohammed ', 11484, 'Mohamad Harith Mateen Bin Abdullah', 24, 24, 24, 24, 22.6, 'Draft', '2026-06-25', '2026-06-25 01:50:36', 'refer to ST.'),
(608, 188, 'Puteri ‘Aisyah Binti Abd Ghaffar', 11610, 'Izz Naufal Bin Izman', 60, 60, 60, 60, 50, 'Draft', '2026-07-02', '2026-07-02 04:52:26', 'Refer to Speech Therapy & Playgroup'),
(610, 188, 'Puteri ‘Aisyah Binti Abd Ghaffar', 11610, 'Izz Naufal Bin Izman', 60, 60, 60, 60, 50, 'Draft', '2026-07-02', '2026-07-02 08:29:29', ''),
(617, 189, 'Nurul Hafisya binti Mohammad Khir', 11707, 'Aisy Haseef Bin Muhamad Aizuddin', 69, 69, 69, 69, 69, 'Submit', '2026-07-08', '2026-07-08 07:24:25', 'OT- focus attention in big room'),
(618, 189, 'Nurul Hafisya binti Mohammad Khir', 11707, 'Aisy Haseef Bin Muhamad Aizuddin', 69, 69, 69, 69, 69, 'Draft', '2026-07-08', '2026-07-08 07:55:13', 'OT- focus attention in big room'),
(647, 189, 'Nurul Hafisya binti Mohammad Khir', 11869, 'Muhammad Yusof Bin Nasrul Izwan', 57, 39, 46, 50, 32, 'Submit', '2026-07-30', '2026-07-29 05:19:52', 'Occupational therapy'),
(648, 189, 'Nurul Hafisya binti Mohammad Khir', 11869, 'Muhammad Yusof Bin Nasrul Izwan', 57, 39, 46, 50, 32, 'Draft', '2026-07-29', '2026-07-29 05:25:05', 'Occupational therapy'),
(639, 189, 'Nurul Hafisya binti Mohammad Khir', 11923, 'Muhammad Hadif Bin Muhammad Hafizhan', 74, 74, 74, 74, 74, 'Submit', '2026-07-25', '2026-07-24 03:52:59', 'OT- monitor on learning skills and social skills'),
(640, 189, 'Nurul Hafisya binti Mohammad Khir', 11923, 'Muhammad Hadif Bin Muhammad Hafizhan', 74, 74, 74, 74, 50, 'Draft', '2026-07-24', '2026-07-24 04:14:09', 'OT- monitor on learning skills and social skills'),
(641, 189, 'Nurul Hafisya binti Mohammad Khir', 11923, 'Muhammad Hadif Bin Muhammad Hafizhan', 74, 74, 74, 74, 50, 'Draft', '2026-07-24', '2026-07-24 04:14:53', 'OT- monitor on learning skills and social skills');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `screening`
--
ALTER TABLE `screening`
  ADD PRIMARY KEY (`screening_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `screening`
--
ALTER TABLE `screening`
  MODIFY `screening_id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=671;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
