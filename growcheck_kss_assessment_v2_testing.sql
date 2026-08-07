-- ============================================================
-- GrowCheck KSS Assessment Module - V2 TESTING RESET
-- Target: MySQL 8.x / MariaDB (InnoDB, utf8mb4)
--
-- IMPORTANT:
-- 1) TESTING ONLY: this script DROPS existing KSS module views/tables.
-- 2) It does NOT touch existing GrowCheck student/teacher tables.
-- 3) teacher_id / student_id are stored as IDs from the existing
--    GrowCheck system, but no FK is added because the existing table
--    names/PK definitions are not confirmed yet.
-- ============================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
-- Drop views first
-- ----------------------------
DROP VIEW IF EXISTS v_kss_tp_frequency;
DROP VIEW IF EXISTS v_kss_latest_sk_results;
DROP VIEW IF EXISTS v_kss_class_active_student_count;

-- ----------------------------
-- Drop tables in dependency order
-- ----------------------------
DROP TABLE IF EXISTS kss_pbd_report_items;
DROP TABLE IF EXISTS kss_pbd_reports;
DROP TABLE IF EXISTS kss_sk_results;
DROP TABLE IF EXISTS kss_sp_observations;
DROP TABLE IF EXISTS kss_sk_assessment_cycles;
DROP TABLE IF EXISTS kss_class_students;
DROP TABLE IF EXISTS kss_classes;
DROP TABLE IF EXISTS kss_performance_standards;
DROP TABLE IF EXISTS kss_learning_standards;
DROP TABLE IF EXISTS kss_content_standards;
DROP TABLE IF EXISTS kss_domains;
DROP TABLE IF EXISTS kss_curriculum_subjects;
DROP TABLE IF EXISTS kss_subjects;
DROP TABLE IF EXISTS kss_curriculum_versions;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- 1. DSKP / CURRICULUM MASTER
-- ============================================================

CREATE TABLE kss_curriculum_versions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    code VARCHAR(50) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_kss_curriculum_versions_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE kss_subjects (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    code VARCHAR(30) NOT NULL,
    name VARCHAR(150) NOT NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_kss_subjects_code (code),
    UNIQUE KEY uq_kss_subjects_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- One row = one subject for one school year level in one curriculum version.
-- Example: KSSRPK 2017 + Bahasa Melayu + Tahun 1.
CREATE TABLE kss_curriculum_subjects (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    curriculum_version_id BIGINT UNSIGNED NOT NULL,
    subject_id BIGINT UNSIGNED NOT NULL,
    year_level TINYINT UNSIGNED NOT NULL,
    display_name VARCHAR(200) NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_kss_curriculum_subject (
        curriculum_version_id,
        subject_id,
        year_level
    ),
    KEY idx_kss_curriculum_subject_year (year_level),
    CONSTRAINT fk_kss_curriculum_subject_version
        FOREIGN KEY (curriculum_version_id)
        REFERENCES kss_curriculum_versions(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_kss_curriculum_subject_subject
        FOREIGN KEY (subject_id)
        REFERENCES kss_subjects(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- DSKP domain / bidang.
-- Example: 1.0 Kemahiran Mendengar dan Bertutur.
CREATE TABLE kss_domains (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    curriculum_subject_id BIGINT UNSIGNED NOT NULL,
    code VARCHAR(30) NOT NULL,
    title TEXT NOT NULL,
    sort_order INT UNSIGNED NOT NULL DEFAULT 0,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_kss_domain_code (curriculum_subject_id, code),
    KEY idx_kss_domains_subject (curriculum_subject_id),
    CONSTRAINT fk_kss_domains_curriculum_subject
        FOREIGN KEY (curriculum_subject_id)
        REFERENCES kss_curriculum_subjects(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Standard Kandungan (SK)
-- This is the level that receives TP1-TP6 from the teacher.
CREATE TABLE kss_content_standards (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    domain_id BIGINT UNSIGNED NOT NULL,
    code VARCHAR(30) NOT NULL,
    statement TEXT NOT NULL,
    teacher_reference TEXT NULL,
    sort_order INT UNSIGNED NOT NULL DEFAULT 0,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_kss_content_standard_code (domain_id, code),
    KEY idx_kss_content_standards_domain (domain_id),
    CONSTRAINT fk_kss_content_standards_domain
        FOREIGN KEY (domain_id)
        REFERENCES kss_domains(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Standard Pembelajaran (SP)
-- Teacher writes observation/ulasan here; SP itself does NOT receive TP.
-- interpretation is nullable because some DSKP entries may only have the
-- official SP statement without a separate tafsiran.
CREATE TABLE kss_learning_standards (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    content_standard_id BIGINT UNSIGNED NOT NULL,
    code VARCHAR(30) NOT NULL,
    statement TEXT NOT NULL,
    interpretation TEXT NULL,
    sort_order INT UNSIGNED NOT NULL DEFAULT 0,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_kss_learning_standard_code (content_standard_id, code),
    KEY idx_kss_learning_standards_sk (content_standard_id),
    CONSTRAINT fk_kss_learning_standards_sk
        FOREIGN KEY (content_standard_id)
        REFERENCES kss_content_standards(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Official TP descriptor / tafsiran used when teacher finalizes an SK.
-- One SK can have TP1...TP6 descriptors.
CREATE TABLE kss_performance_standards (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    content_standard_id BIGINT UNSIGNED NOT NULL,
    tp_level TINYINT UNSIGNED NOT NULL,
    interpretation TEXT NOT NULL,
    sort_order INT UNSIGNED NOT NULL DEFAULT 0,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_kss_performance_standard_tp (content_standard_id, tp_level),
    KEY idx_kss_performance_standards_sk (content_standard_id),
    CONSTRAINT fk_kss_performance_standards_sk
        FOREIGN KEY (content_standard_id)
        REFERENCES kss_content_standards(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 2. TEACHER-CREATED KSS CLASSES
-- ============================================================

-- Teacher may create multiple KSS assessment classes.
-- curriculum_subject_id fixes BOTH Tahun + Subject for the class.
-- Default maximum is 8 based on the current KSS operating rule.
CREATE TABLE kss_classes (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    teacher_id BIGINT UNSIGNED NOT NULL,
    class_name VARCHAR(150) NOT NULL,
    curriculum_subject_id BIGINT UNSIGNED NOT NULL,
    academic_year SMALLINT UNSIGNED NOT NULL,
    max_students SMALLINT UNSIGNED NOT NULL DEFAULT 8,
    status ENUM('ACTIVE','ARCHIVED') NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_kss_teacher_class_name (
        teacher_id,
        academic_year,
        curriculum_subject_id,
        class_name
    ),
    KEY idx_kss_classes_teacher (teacher_id, status),
    KEY idx_kss_classes_curriculum_subject (curriculum_subject_id),
    CONSTRAINT fk_kss_classes_curriculum_subject
        FOREIGN KEY (curriculum_subject_id)
        REFERENCES kss_curriculum_subjects(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Existing GrowCheck students are enrolled into a KSS class.
-- Removing a student is a soft remove; assessment history remains intact.
CREATE TABLE kss_class_students (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    class_id BIGINT UNSIGNED NOT NULL,
    student_id BIGINT UNSIGNED NOT NULL,
    status ENUM('ACTIVE','REMOVED') NOT NULL DEFAULT 'ACTIVE',
    joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    removed_at DATETIME NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_kss_class_student (class_id, student_id),
    KEY idx_kss_class_students_class_status (class_id, status),
    KEY idx_kss_class_students_student (student_id),
    CONSTRAINT fk_kss_class_students_class
        FOREIGN KEY (class_id)
        REFERENCES kss_classes(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 3. SK ASSESSMENT CYCLE / REVISION
-- ============================================================

-- One cycle = one round of assessment for one SK in one class.
-- Example:
--   Attempt 1 = INITIAL
--   Attempt 2 = REVISION
--
-- A cycle can contain observations made on different lesson dates.
-- Reassessment creates a NEW cycle; previous cycles are not overwritten.
CREATE TABLE kss_sk_assessment_cycles (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    class_id BIGINT UNSIGNED NOT NULL,
    content_standard_id BIGINT UNSIGNED NOT NULL,
    attempt_no INT UNSIGNED NOT NULL DEFAULT 1,
    cycle_type ENUM('INITIAL','REVISION') NOT NULL DEFAULT 'INITIAL',
    status ENUM('IN_PROGRESS','COMPLETED','CANCELLED') NOT NULL DEFAULT 'IN_PROGRESS',
    started_by_teacher_id BIGINT UNSIGNED NOT NULL,
    started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_kss_sk_cycle_attempt (
        class_id,
        content_standard_id,
        attempt_no
    ),
    KEY idx_kss_sk_cycles_class (class_id, status),
    KEY idx_kss_sk_cycles_sk (content_standard_id),
    CONSTRAINT fk_kss_sk_cycles_class
        FOREIGN KEY (class_id)
        REFERENCES kss_classes(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_kss_sk_cycles_content_standard
        FOREIGN KEY (content_standard_id)
        REFERENCES kss_content_standards(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Teacher's free-text observation / ulasan for one student and one SP.
-- Row existence means the SP has been assessed/recorded for that cycle.
-- App should require meaningful observation_text before considering it done.
CREATE TABLE kss_sp_observations (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    assessment_cycle_id BIGINT UNSIGNED NOT NULL,
    student_id BIGINT UNSIGNED NOT NULL,
    learning_standard_id BIGINT UNSIGNED NOT NULL,
    observation_text LONGTEXT NOT NULL,
    observed_by_teacher_id BIGINT UNSIGNED NOT NULL,
    observed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_kss_sp_observation (
        assessment_cycle_id,
        student_id,
        learning_standard_id
    ),
    KEY idx_kss_sp_observations_student (student_id),
    KEY idx_kss_sp_observations_sp (learning_standard_id),
    CONSTRAINT fk_kss_sp_observations_cycle
        FOREIGN KEY (assessment_cycle_id)
        REFERENCES kss_sk_assessment_cycles(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_kss_sp_observations_learning_standard
        FOREIGN KEY (learning_standard_id)
        REFERENCES kss_learning_standards(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Final teacher judgement for one student's SK in one assessment cycle.
-- TP is assigned HERE, not to SP.
-- tp_interpretation_snapshot preserves the descriptor used at that time.
CREATE TABLE kss_sk_results (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    assessment_cycle_id BIGINT UNSIGNED NOT NULL,
    student_id BIGINT UNSIGNED NOT NULL,
    performance_standard_id BIGINT UNSIGNED NULL,
    tp_level TINYINT UNSIGNED NOT NULL,
    tp_interpretation_snapshot LONGTEXT NOT NULL,
    teacher_summary LONGTEXT NULL,
    status ENUM('FINALIZED','VOID') NOT NULL DEFAULT 'FINALIZED',
    finalized_by_teacher_id BIGINT UNSIGNED NOT NULL,
    finalized_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    voided_at DATETIME NULL,
    void_reason TEXT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_kss_sk_result_student_cycle (
        assessment_cycle_id,
        student_id
    ),
    KEY idx_kss_sk_results_student (student_id, status),
    KEY idx_kss_sk_results_tp (tp_level),
    CONSTRAINT fk_kss_sk_results_cycle
        FOREIGN KEY (assessment_cycle_id)
        REFERENCES kss_sk_assessment_cycles(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_kss_sk_results_performance_standard
        FOREIGN KEY (performance_standard_id)
        REFERENCES kss_performance_standards(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 4. OVERALL PBD / REPORT SNAPSHOT
-- ============================================================

-- Overall subject result based on the latest finalized TP for each SK.
-- MODE = clear highest frequency.
-- PROFESSIONAL_JUDGEMENT = tie or other approved teacher judgement.
CREATE TABLE kss_pbd_reports (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    class_id BIGINT UNSIGNED NOT NULL,
    student_id BIGINT UNSIGNED NOT NULL,
    academic_year SMALLINT UNSIGNED NOT NULL,
    reporting_period ENUM('SEM1','SEM2','FINAL','OTHER') NOT NULL,
    recommended_tp TINYINT UNSIGNED NULL,
    final_tp TINYINT UNSIGNED NULL,
    calculation_method ENUM('MODE','PROFESSIONAL_JUDGEMENT') NULL,
    has_mode_tie TINYINT(1) NOT NULL DEFAULT 0,
    professional_judgement_note LONGTEXT NULL,
    status ENUM('DRAFT','FINALIZED') NOT NULL DEFAULT 'DRAFT',
    confirmed_by_teacher_id BIGINT UNSIGNED NULL,
    finalized_at DATETIME NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_kss_pbd_report (
        class_id,
        student_id,
        academic_year,
        reporting_period
    ),
    KEY idx_kss_pbd_reports_student (student_id),
    KEY idx_kss_pbd_reports_class_period (class_id, reporting_period),
    CONSTRAINT fk_kss_pbd_reports_class
        FOREIGN KEY (class_id)
        REFERENCES kss_classes(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Snapshot of the exact SK results used when a PBD report is generated.
-- This prevents an old Sem 1 report from changing after later reassessment.
CREATE TABLE kss_pbd_report_items (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    report_id BIGINT UNSIGNED NOT NULL,
    content_standard_id BIGINT UNSIGNED NOT NULL,
    source_sk_result_id BIGINT UNSIGNED NOT NULL,
    sk_code_snapshot VARCHAR(30) NOT NULL,
    sk_statement_snapshot LONGTEXT NOT NULL,
    tp_level TINYINT UNSIGNED NOT NULL,
    tp_interpretation_snapshot LONGTEXT NOT NULL,
    source_finalized_at DATETIME NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_kss_pbd_report_sk (report_id, content_standard_id),
    KEY idx_kss_pbd_report_items_result (source_sk_result_id),
    CONSTRAINT fk_kss_pbd_report_items_report
        FOREIGN KEY (report_id)
        REFERENCES kss_pbd_reports(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_kss_pbd_report_items_sk
        FOREIGN KEY (content_standard_id)
        REFERENCES kss_content_standards(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_kss_pbd_report_items_result
        FOREIGN KEY (source_sk_result_id)
        REFERENCES kss_sk_results(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 5. HELPER VIEWS
-- ============================================================

CREATE VIEW v_kss_class_active_student_count AS
SELECT
    c.id AS class_id,
    COUNT(cs.id) AS active_student_count
FROM kss_classes c
LEFT JOIN kss_class_students cs
    ON cs.class_id = c.id
   AND cs.status = 'ACTIVE'
GROUP BY c.id;

-- Latest FINALIZED SK result for each student + class + SK.
-- If a revision exists, the revision becomes current while the old result remains.
CREATE VIEW v_kss_latest_sk_results AS
SELECT
    r.id AS sk_result_id,
    cyc.id AS assessment_cycle_id,
    cyc.class_id,
    r.student_id,
    cyc.content_standard_id,
    cs.code AS sk_code,
    cs.statement AS sk_statement,
    cyc.attempt_no,
    cyc.cycle_type,
    r.tp_level,
    r.tp_interpretation_snapshot,
    r.teacher_summary,
    r.finalized_by_teacher_id,
    r.finalized_at
FROM kss_sk_results r
INNER JOIN kss_sk_assessment_cycles cyc
    ON cyc.id = r.assessment_cycle_id
INNER JOIN kss_content_standards cs
    ON cs.id = cyc.content_standard_id
WHERE r.status = 'FINALIZED'
  AND NOT EXISTS (
      SELECT 1
      FROM kss_sk_results r2
      INNER JOIN kss_sk_assessment_cycles cyc2
          ON cyc2.id = r2.assessment_cycle_id
      WHERE r2.status = 'FINALIZED'
        AND r2.student_id = r.student_id
        AND cyc2.class_id = cyc.class_id
        AND cyc2.content_standard_id = cyc.content_standard_id
        AND (
            r2.finalized_at > r.finalized_at
            OR (
                r2.finalized_at = r.finalized_at
                AND r2.id > r.id
            )
        )
  );

-- Frequency / mode source.
-- Example output: TP3=2, TP4=3, TP5=1 for a student in a class.
CREATE VIEW v_kss_tp_frequency AS
SELECT
    class_id,
    student_id,
    tp_level,
    COUNT(*) AS tp_frequency
FROM v_kss_latest_sk_results
GROUP BY class_id, student_id, tp_level;

-- ============================================================
-- 6. STARTER MASTER DATA
-- ============================================================
-- Only curriculum/subject scaffolding is seeded here.
-- Full SK/SP/TP DSKP content should be imported from the actual DSKP source,
-- not guessed or manually invented.

INSERT INTO kss_curriculum_versions (code, name, description, is_active)
VALUES (
    'KSSRPK-2017',
    'KSSR Pendidikan Khas (Masalah Pembelajaran) Semakan 2017',
    'GrowCheck KSS assessment curriculum master.',
    1
)
ON DUPLICATE KEY UPDATE
    name = VALUES(name),
    description = VALUES(description),
    is_active = VALUES(is_active);

INSERT INTO kss_subjects (code, name, is_active) VALUES
('BM',  'Bahasa Melayu', 1),
('BI',  'Bahasa Inggeris', 1),
('MAT', 'Matematik', 1),
('PI',  'Pendidikan Islam', 1),
('PM',  'Pendidikan Moral', 1)
ON DUPLICATE KEY UPDATE
    name = VALUES(name),
    is_active = VALUES(is_active);

-- Seed Tahun 1 subject mappings.
INSERT INTO kss_curriculum_subjects
    (curriculum_version_id, subject_id, year_level, display_name, is_active)
SELECT cv.id, s.id, 1, CONCAT(s.name, ' - Tahun 1'), 1
FROM kss_curriculum_versions cv
JOIN kss_subjects s ON s.code IN ('BM','BI','MAT','PI','PM')
WHERE cv.code = 'KSSRPK-2017'
ON DUPLICATE KEY UPDATE
    display_name = VALUES(display_name),
    is_active = VALUES(is_active);

-- ============================================================
-- END
-- ============================================================
