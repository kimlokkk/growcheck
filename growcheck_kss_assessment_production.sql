-- ============================================================
-- GrowCheck KSS Assessment Module - PRODUCTION INSTALL
-- Target: MySQL 8.x / MariaDB (InnoDB, utf8mb4)
--
-- IMPORTANT:
-- 1) Intended for a fresh production installation with no existing KSS tables.
-- 2) It does NOT drop or modify existing GrowCheck student/teacher tables.
-- 3) teacher_id / student_id are stored as IDs from the existing
--    GrowCheck system, but no FK is added because the existing table
--    names/PK definitions are not confirmed yet.
-- ============================================================

SET NAMES utf8mb4;

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

CREATE TABLE kss_assessment_batches (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    class_id BIGINT UNSIGNED NOT NULL,
    reporting_period ENUM('SEM1','SEM2') NOT NULL,
    sequence_no INT UNSIGNED NOT NULL,
    assessment_type ENUM('INITIAL','REVISION') NOT NULL,
    revision_no INT UNSIGNED NOT NULL DEFAULT 0,
    status ENUM('IN_PROGRESS','PUBLISHED','CANCELLED') NOT NULL DEFAULT 'IN_PROGRESS',
    started_by_teacher_id BIGINT UNSIGNED NOT NULL,
    published_by_teacher_id BIGINT UNSIGNED NULL,
    started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    published_at DATETIME NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_kss_batch_sequence (class_id, reporting_period, sequence_no),
    KEY idx_kss_batch_status (class_id, reporting_period, status),
    CONSTRAINT fk_kss_batch_class FOREIGN KEY (class_id)
        REFERENCES kss_classes(id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- One cycle = one semester assessment for one SK in one class.
-- Semester 1 and Semester 2 are stored separately; earlier results are never overwritten.
CREATE TABLE kss_sk_assessment_cycles (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    class_id BIGINT UNSIGNED NOT NULL,
    content_standard_id BIGINT UNSIGNED NOT NULL,
    assessment_batch_id BIGINT UNSIGNED NULL,
    reporting_period ENUM('SEM1','SEM2') NOT NULL DEFAULT 'SEM1',
    attempt_no INT UNSIGNED NOT NULL DEFAULT 1,
    cycle_type ENUM('INITIAL','REVISION') NOT NULL DEFAULT 'INITIAL',
    phase ENUM('OBSERVATION','TP_ASSIGNMENT') NOT NULL DEFAULT 'OBSERVATION',
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
    KEY idx_kss_cycles_period (class_id, reporting_period, status),
    KEY idx_kss_sk_cycles_sk (content_standard_id),
    KEY idx_kss_cycles_batch (assessment_batch_id),
    CONSTRAINT fk_kss_cycles_batch FOREIGN KEY (assessment_batch_id)
        REFERENCES kss_assessment_batches(id) ON UPDATE CASCADE ON DELETE CASCADE,
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
    reporting_period ENUM('SEM1','SEM2') NOT NULL,
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
-- This prevents a saved semester report from changing after later assessments.
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
CREATE VIEW v_kss_latest_sk_results AS
SELECT
    r.id AS sk_result_id,
    cyc.id AS assessment_cycle_id,
    cyc.class_id,
    r.student_id,
    cyc.content_standard_id,
    cyc.reporting_period,
    cyc.assessment_batch_id,
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
INNER JOIN kss_assessment_batches batch_row
    ON batch_row.id = cyc.assessment_batch_id
   AND batch_row.status = 'PUBLISHED'
WHERE r.status = 'FINALIZED'
  AND NOT EXISTS (
      SELECT 1
      FROM kss_sk_results r2
      INNER JOIN kss_sk_assessment_cycles cyc2
          ON cyc2.id = r2.assessment_cycle_id
      INNER JOIN kss_assessment_batches batch2
          ON batch2.id = cyc2.assessment_batch_id
         AND batch2.status = 'PUBLISHED'
      WHERE r2.status = 'FINALIZED'
        AND r2.student_id = r.student_id
        AND cyc2.class_id = cyc.class_id
        AND cyc2.content_standard_id = cyc.content_standard_id
        AND cyc2.reporting_period = cyc.reporting_period
        AND (
            batch2.sequence_no > batch_row.sequence_no
            OR (batch2.sequence_no = batch_row.sequence_no AND r2.id > r.id)
        )
  );

-- Frequency / mode source.
-- Example output: TP3=2, TP4=3, TP5=1 for a student in a class.
CREATE VIEW v_kss_tp_frequency AS
SELECT
    class_id,
    student_id,
    reporting_period,
    tp_level,
    COUNT(*) AS tp_frequency
FROM v_kss_latest_sk_results
GROUP BY class_id, student_id, reporting_period, tp_level;

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


-- ============================================================
-- GrowCheck KSS Assessment - DSKP Tahun 1 Master Data
-- KSSR Pendidikan Khas (Masalah Pembelajaran) Semakan 2017
--
-- Extracted from the supplied Year 1 DSKP PDFs:
--   1) Asas 3M (Bahasa Melayu, Bahasa Inggeris, Matematik)
--   2) Pendidikan Islam
--   3) Pendidikan Moral
--
-- Requires the V2 tables:
-- kss_curriculum_versions, kss_subjects, kss_curriculum_subjects,
-- kss_domains, kss_content_standards, kss_learning_standards,
-- kss_performance_standards.
--
-- IMPORTANT SOURCE NOTE:
-- In the supplied Pendidikan Islam DSKP PDF page 41, SK 5.2
-- prints its SP codes as 5.1.1, 5.1.2 and 5.1.3.
-- This script PRESERVES those codes exactly as printed.
-- No silent correction to 5.2.1/5.2.2/5.2.3 has been made.
-- ============================================================

SET NAMES utf8mb4;
START TRANSACTION;

-- Ensure curriculum + subjects exist
INSERT INTO kss_curriculum_versions (code, name, description, is_active)
VALUES ('KSSRPK-2017',
        'KSSR Pendidikan Khas (Masalah Pembelajaran) Semakan 2017',
        'DSKP Tahun 1 supplied for GrowCheck KSS Assessment.',
        1)
ON DUPLICATE KEY UPDATE
    name = VALUES(name),
    description = VALUES(description),
    is_active = VALUES(is_active);

INSERT INTO kss_subjects (code, name, is_active) VALUES
('BM', 'Bahasa Melayu', 1),
('BI', 'Bahasa Inggeris', 1),
('MAT', 'Matematik', 1),
('PI', 'Pendidikan Islam', 1),
('PM', 'Pendidikan Moral', 1)
ON DUPLICATE KEY UPDATE
    name = VALUES(name),
    is_active = VALUES(is_active);

SET @cv_id := (
    SELECT id
    FROM kss_curriculum_versions
    WHERE code = 'KSSRPK-2017'
    LIMIT 1
);

INSERT INTO kss_curriculum_subjects
    (curriculum_version_id, subject_id, year_level, display_name, is_active)
SELECT @cv_id, s.id, 1, CONCAT(s.name, ' - Tahun 1'), 1
FROM kss_subjects s
WHERE s.code IN ('BM','BI','MAT','PI','PM')
ON DUPLICATE KEY UPDATE
    display_name = VALUES(display_name),
    is_active = VALUES(is_active);

SET @bm_y1 := (
    SELECT cs.id
    FROM kss_curriculum_subjects cs
    INNER JOIN kss_subjects s ON s.id = cs.subject_id
    WHERE cs.curriculum_version_id = @cv_id
      AND cs.year_level = 1
      AND s.code = 'BM'
    LIMIT 1
);

SET @bi_y1 := (
    SELECT cs.id
    FROM kss_curriculum_subjects cs
    INNER JOIN kss_subjects s ON s.id = cs.subject_id
    WHERE cs.curriculum_version_id = @cv_id
      AND cs.year_level = 1
      AND s.code = 'BI'
    LIMIT 1
);

SET @mat_y1 := (
    SELECT cs.id
    FROM kss_curriculum_subjects cs
    INNER JOIN kss_subjects s ON s.id = cs.subject_id
    WHERE cs.curriculum_version_id = @cv_id
      AND cs.year_level = 1
      AND s.code = 'MAT'
    LIMIT 1
);

SET @pi_y1 := (
    SELECT cs.id
    FROM kss_curriculum_subjects cs
    INNER JOIN kss_subjects s ON s.id = cs.subject_id
    WHERE cs.curriculum_version_id = @cv_id
      AND cs.year_level = 1
      AND s.code = 'PI'
    LIMIT 1
);

SET @pm_y1 := (
    SELECT cs.id
    FROM kss_curriculum_subjects cs
    INNER JOIN kss_subjects s ON s.id = cs.subject_id
    WHERE cs.curriculum_version_id = @cv_id
      AND cs.year_level = 1
      AND s.code = 'PM'
    LIMIT 1
);

-- ============================================================
-- BAHASA MELAYU - TAHUN 1
-- ============================================================

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@bm_y1, '1.0', 'KEMAHIRAN MENDENGAR', 1, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@bm_y1, '2.0', 'KEMAHIRAN BERTUTUR', 2, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@bm_y1, '3.0', 'KEMAHIRAN MEMBACA', 3, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@bm_y1, '4.0', 'KEMAHIRAN MENULIS', 4, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@bm_y1, '5.0', 'KEMAHIRAN KOMUNIKASI', 5, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 35: SK 1.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @bm_y1
      AND code = '1.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '1.1', 'Mendengar, mengajuk dan mengecam pelbagai bunyi', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '1.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '1.1.1', 'Mendengar, mengajuk dan mengecam pelbagai bunyi seperti; (i) suara atau perlakuan manusia (ii) bunyi haiwan (iii) bunyi kenderaan (iv) bunyi benda', NULL, 1, 1),
    (@sk_id, '1.1.2', 'Mendengar dan mengecam arah bunyi', NULL, 2, 1),
    (@sk_id, '1.1.3', 'Mendengar, mengecam dan membezakan bunyi', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Mengajuk bunyi yang didengar secara berpandu', 1, 1),
    (@sk_id, 2, 'Mengajuk bunyi yang didengar', 2, 1),
    (@sk_id, 3, 'Mengajuk, mengecam dan menunjukkan arah bunyi yang didengar', 3, 1),
    (@sk_id, 4, 'Membanding beza bunyi yang didengar dengan betul', 4, 1),
    (@sk_id, 5, 'Membanding beza bunyi yang didengar dengan betul dan yakin', 5, 1),
    (@sk_id, 6, 'Membimbing rakan menghubungkaitkan bunyi yang didengar dengan betul dan yakin', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 36: SK 1.2
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @bm_y1
      AND code = '1.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '1.2', 'Mendengar dan melafazkan ucapan bertatasusila', NULL, 2, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '1.2'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '1.2.1', 'Mendengar dan melafazkan ucapan bertatasusila seperti: (i) selamat pagi (ii) selamat tengah hari (iii) selamat petang (iv) selamat malam (v) selamat datang (vi) selamat pulang (vii) selamat tinggal (viii) selamat sejahtera (ix) terima kasih', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Melafazkan ucapan bertatasusila yang didengar secara berpandu', 1, 1),
    (@sk_id, 2, 'Melafazkan ucapan bertatasusila yang didengar', 2, 1),
    (@sk_id, 3, 'Melafazkan ucapan bertatasusila yang didengar dengan betul', 3, 1),
    (@sk_id, 4, 'Melafazkan ucapan bertatasusila yang didengar dengan betul dan beradab', 4, 1),
    (@sk_id, 5, 'Melafazkan ucapan bertatasusila yang didengar dengan yakin dan tekal', 5, 1),
    (@sk_id, 6, 'Melafazkan ucapan bertatasusila yang didengar dengan yakin, tekal dan boleh dicontohi', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 37: SK 2.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @bm_y1
      AND code = '2.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '2.1', 'Menama dan menggunakan alat pertuturan', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '2.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '2.1.1', 'Mengenal alat pertuturan seperti (i) bibir (ii) lidah', NULL, 1, 1),
    (@sk_id, '2.1.2', 'Menggunakan alat pertuturan dalam aktiviti seperti : (i) pernafasan (meniup objek) (ii) bubbling (iii) latihan otot muka (mimik muka)', NULL, 2, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Menamakan alat-alat pertuturan secara berpandu', 1, 1),
    (@sk_id, 2, 'Menamakan alat-alat pertuturan', 2, 1),
    (@sk_id, 3, 'Mengenal pasti alat pertuturan dan melakukan aktiviti pertuturan dengan betul', 3, 1),
    (@sk_id, 4, 'Menggunakan alat pertuturan dalam pelbagai aktiviti pertuturan dengan betul dan yakin', 4, 1),
    (@sk_id, 5, 'Menghubungkaitkan alat pertuturan dengan aktiviti secara tertib', 5, 1),
    (@sk_id, 6, 'Menghubungkaitkan alat pertuturan dengan aktiviti secara tertib dan boleh dicontohi', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 38: SK 2.2
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @bm_y1
      AND code = '2.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '2.2', 'Mengajuk, mengecam dan menamakan pelbagai bunyi', NULL, 2, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '2.2'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '2.2.1', 'Mengenal,mengajuk, mengecam dan menamakan pelbagai bunyi seperti; (i) suara atau perlakuan manusia (ii) bunyi haiwan (iii)bunyi kenderaan (iv)bunyi benda', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Mengajuk dan mengecam pelbagai bunyi seara berpandu', 1, 1),
    (@sk_id, 2, 'Mengajuk dan mengecam pelbagai bunyi', 2, 1),
    (@sk_id, 3, 'Mengajuk, mengecam dan menamakan pelbagai bunyi', 3, 1),
    (@sk_id, 4, 'Membezakan pelbagai bunyi yang didengar dengan betul', 4, 1),
    (@sk_id, 5, 'Menghasilkan pelbagai bunyi secara kreatif', 5, 1),
    (@sk_id, 6, 'Membantu rakan menghasilkan pelbagai bunyi secara kreatif', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 39: SK 2.3
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @bm_y1
      AND code = '2.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '2.3', 'Melafazkan ucapan bertatasusila', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '2.3'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '2.3.1', 'Mengajuk ucapan bertatasusila', NULL, 1, 1),
    (@sk_id, '2.3.2', 'Melafazkan ucapan bertatasusila', NULL, 2, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Mengajuk ucapan bertatasusila', 1, 1),
    (@sk_id, 2, 'Melafazkan ucapan bertatasusila', 2, 1),
    (@sk_id, 3, 'Melafazkan ucapan bertatasusila dalam pelbagai situasi', 3, 1),
    (@sk_id, 4, 'Melafazkan ucapan bertatasusila dalam pelbagai situasi dengan betul.', 4, 1),
    (@sk_id, 5, 'Melafazkan ucapan bertatasusila dalam pelbagai situasi dengan yakin dan tekal', 5, 1),
    (@sk_id, 6, 'Melafazkan ucapan bertatasusila dalam pelbagai situasi dengan yakin dan boleh dicontohi', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 41: SK 3.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @bm_y1
      AND code = '3.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '3.1', 'Mengecam dan menamakan objek', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '3.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '3.1.1', 'Mengecam objek; (i) persamaan (ii) perbezaan', NULL, 1, 1),
    (@sk_id, '3.1.2', 'Menamakan objek; (i) di dalam kelas (ii) di luar kelas', NULL, 2, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Mengecam objek secara rawak', 1, 1),
    (@sk_id, 2, 'Mengecam persamaan dan perbezaan objek', 2, 1),
    (@sk_id, 3, 'Mengecam dan menamakan objek di persekitaran murid', 3, 1),
    (@sk_id, 4, 'Membanding beza objek di persekitaran murid', 4, 1),
    (@sk_id, 5, 'Mengelaskan objek dengan yakin dan tekal', 5, 1),
    (@sk_id, 6, 'Mengelaskan objek dengan yakin, tekal dan boleh dicontohi.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 42: SK 3.2
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @bm_y1
      AND code = '3.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '3.2', 'Mengenal huruf', NULL, 2, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '3.2'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '3.2.1', 'Menyebut dan menamakan abjad', NULL, 1, 1),
    (@sk_id, '3.2.2', 'Membunyikan huruf vokal', NULL, 2, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Menyebut abjad secara berpandu', 1, 1),
    (@sk_id, 2, 'Menamakan abjad dengan bimbingan', 2, 1),
    (@sk_id, 3, 'Membunyikan huruf vokal', 3, 1),
    (@sk_id, 4, 'Membezakan huruf kecil dan huruf besar', 4, 1),
    (@sk_id, 5, 'Mengelaskan huruf kecil dan huruf besar secara yakin dan tekal', 5, 1),
    (@sk_id, 6, 'Menghubungkait huruf dengan objek secara yakin dan boleh dicontohi', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 43: SK 4.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @bm_y1
      AND code = '4.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '4.1', 'Menulis dengan kedudukan yang sesuai', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '4.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '4.1.1', 'Menggerakkan tangan, pergelangan tangan dan jari-jari secara bebas', NULL, 1, 1),
    (@sk_id, '4.1.2', 'Menggerakkan tangan secara terkawal', NULL, 2, 1),
    (@sk_id, '4.1.3', 'Menulis dengan kedudukan yang sesuai (postur badan)', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Melakukan aktiviti gerakan tangan, pergelangan tangan dan jari-jari', 1, 1),
    (@sk_id, 2, 'Menghasilkan lakaran secara bebas (contengan) dan terkawal (sambung titik/mazing)', 2, 1),
    (@sk_id, 3, 'Menulis menggunakan alatan dengan kedudukan (postur badan) yang sesuai', 3, 1),
    (@sk_id, 4, 'Menulis menggunakan alatan dengan kedudukan (postur badan) yang betul', 4, 1),
    (@sk_id, 5, 'Menulis menggunakan alatan dengan kedudukan yang sesuai secara yakin dan tekal', 5, 1),
    (@sk_id, 6, 'Menulis menggunakan alatan dengan kedudukan yang sesuai secara yakin, tekal dan boleh dicontohi', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 44: SK 4.2
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @bm_y1
      AND code = '4.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '4.2', 'Menulis secara mekanis', NULL, 2, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '4.2'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '4.2.1', 'Menulis huruf kecil dengan cara yang betul', NULL, 1, 1),
    (@sk_id, '4.2.2', 'Menulis huruf besar dengan cara yang betul', NULL, 2, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Menyurih huruf dengan bimbingan', 1, 1),
    (@sk_id, 2, 'Menyalin huruf', 2, 1),
    (@sk_id, 3, 'Menulis huruf', 3, 1),
    (@sk_id, 4, 'Menulis huruf dalam garisan yang disediakan dengan kemas', 4, 1),
    (@sk_id, 5, 'Menulis huruf dalam garisan dengan kemas dan betul', 5, 1),
    (@sk_id, 6, 'Menulis huruf dalam garisan dengan kemas, yakin, tekal dan boleh dicontohi', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 45: SK 5.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @bm_y1
      AND code = '5.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '5.1', 'Memerihalkan mengenai diri sendiri', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '5.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '5.1.1', 'Bersoal jawab mengenai diri sendiri tentang; (i) Nama (ii) Umur (iii) Jantina (iv) Tempat tinggal (v) Hobi', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Memberi respons mengenai diri sendiri secara berpandu', 1, 1),
    (@sk_id, 2, 'Memberi respons mengenai diri sendiri', 2, 1),
    (@sk_id, 3, 'Memerihalkan mengenai diri sendiri', 3, 1),
    (@sk_id, 4, 'Berbual mengenai diri sendiri dengan yakin', 4, 1),
    (@sk_id, 5, 'Berbual mengenai diri sendiri dengan yakin, tekal dan beradab', 5, 1),
    (@sk_id, 6, 'Bercerita mengenai diri sendiri dengan yakin, kreatif dan boleh dicontohi.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- ============================================================
-- BAHASA INGGERIS - TAHUN 1
-- ============================================================

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@bi_y1, '1.0', 'LISTENING DAN SPEAKING', 1, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@bi_y1, '2.0', 'READING', 2, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@bi_y1, '3.0', 'WRITING', 3, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 49: SK 1.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @bi_y1
      AND code = '1.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '1.1', 'Pupils will be able to listen and respond appropriately for a variety of purposes', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '1.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '1.1.1', 'Listen and respond to stimulus given (i) body percussions (hands, feet, fingers) (ii) voice sounds (animal, vehicle) (iii) environmental sounds (rain, waterfall) (iv) instrumental sounds (bell, castanet)', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Able to respond in a very limited level.', 1, 1),
    (@sk_id, 2, 'Able to respond in a limited level.', 2, 1),
    (@sk_id, 3, 'Able to respond in a satisfactory level.', 3, 1),
    (@sk_id, 4, 'Able to respond in a moderate level.', 4, 1),
    (@sk_id, 5, 'Able to respond in a good level.', 5, 1),
    (@sk_id, 6, 'Able to respond in an excellent level.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 50: SK 1.2
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @bi_y1
      AND code = '1.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '1.2', 'Pupils will be able to say words and speak confidently', NULL, 2, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '1.2'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '1.2.1', 'Talk about stimulus given (i) pictures (ii) songs (iii) objects', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Able to name the stimulus given.', 1, 1),
    (@sk_id, 2, 'Able to describe the stimulus given in a limited level.', 2, 1),
    (@sk_id, 3, 'Able to describe the stimulus given in a satisfactory level.', 3, 1),
    (@sk_id, 4, 'Able to explain about the stimulus given.', 4, 1),
    (@sk_id, 5, 'Able to discuss about the stimulus given.', 5, 1),
    (@sk_id, 6, 'Able to discuss about the stimulus given in details.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 51: SK 1.3
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @bi_y1
      AND code = '1.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '1.3', 'Pupils will be able to participate in daily conversations', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '1.3'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '1.3.1', 'Listen and respond appropriately for variety of purposes (i) express simple greetings (ii) introduce oneself (iii) follow simple instructions', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Able to listen and respond in a very limited level.', 1, 1),
    (@sk_id, 2, 'Able to listen and respond in a limited level.', 2, 1),
    (@sk_id, 3, 'Able to listen and give response in words.', 3, 1),
    (@sk_id, 4, 'Able to listen and give response in words appropriately.', 4, 1),
    (@sk_id, 5, 'Able to listen, respond and act accordingly.', 5, 1),
    (@sk_id, 6, 'Able to listen, respond and act accordingly in an exemplary manner.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 52: SK 1.4
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @bi_y1
      AND code = '1.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '1.4', 'Pupils will be able to understand and respond to oral text in a variety of context', NULL, 4, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '1.4'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '1.4.1', 'Respond with “YES” or “NO” based on the stimulus given: (i) stories (ii) pictures (iii) songs/rhymes', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Able to say “YES” and “NO”.', 1, 1),
    (@sk_id, 2, 'Able to know the meaning of “YES” and “NO”.', 2, 1),
    (@sk_id, 3, 'Able to understand and respond with “YES” or “NO” based on the stimulus given.', 3, 1),
    (@sk_id, 4, 'Able to understand and respond with “YES” or “NO” in a variety of context.', 4, 1),
    (@sk_id, 5, 'Able to understand and respond with “YES” or “NO” in a variety of context correctly.', 5, 1),
    (@sk_id, 6, 'Able to apply “YES” or “NO” answer appropriately in daily conversations.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 53: SK 2.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @bi_y1
      AND code = '2.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '2.1', 'PRE-READING Pupils will be able to identify and recognize letters prior to reading', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '2.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '2.1.1', 'Identify identical pictures/symbols/ shapes', NULL, 1, 1),
    (@sk_id, '2.1.2', 'Recognize letters (i) lower-case letters (ii) upper-case letters', NULL, 2, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'AbIe to identify pictures/symbols/shapes.', 1, 1),
    (@sk_id, 2, 'Able to match identical pictures/ symbols/shapes.', 2, 1),
    (@sk_id, 3, 'Able to recognize letters.', 3, 1),
    (@sk_id, 4, 'Able to name letters randomly.', 4, 1),
    (@sk_id, 5, 'Able to arrange letters in sequence.', 5, 1),
    (@sk_id, 6, 'Able to differentiate between lower-case and upper-case letters.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 54: SK 2.2
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @bi_y1
      AND code = '2.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '2.2', 'Pupils will be able to recognize and read words', NULL, 2, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '2.2'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '2.2.1', 'Identify initial letters with the correct pictures', NULL, 1, 1),
    (@sk_id, '2.2.2', 'Spell and read words', NULL, 2, 1),
    (@sk_id, '2.2.3', 'Read and understand words in a variety of context', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Able to identify the first letter in words.', 1, 1),
    (@sk_id, 2, 'Able to match initial letters with the correct pictures.', 2, 1),
    (@sk_id, 3, 'Able to imitate in spelling and reading words.', 3, 1),
    (@sk_id, 4, 'Able to read common sight words.', 4, 1),
    (@sk_id, 5, 'Able to read and match words with graphics and spoken words.', 5, 1),
    (@sk_id, 6, 'Able to read words in a variety of context in an exemplary manners.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 55: SK 3.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @bi_y1
      AND code = '3.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '3.1', 'PRE-WRITING Pupils will be able to master fine motor skills prior to writing', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '3.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '3.1.1', 'Demonstrate fine motor control of hands and fingers by: (i) handling objects and manipulating them (ii) moving hands and fingers using writing tools (iii) using correct posture and pencil hold grip (iv) scribbling in clockwise and anticlockwise movement (v) drawing simple strokes up and down (vi) drawing straight lines from left to right (vii) drawing patterns', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Able to demonstrate a very limited level of fine motor control of hands and fingers.', 1, 1),
    (@sk_id, 2, 'Able to demonstrate a limited level of fine motor control of hands and fingers.', 2, 1),
    (@sk_id, 3, 'Able to demonstrate a satisfactory level of fine motor control of hands and fingers.', 3, 1),
    (@sk_id, 4, 'Able to demonstrate a moderate level of fine motor control of hands and fingers.', 4, 1),
    (@sk_id, 5, 'Able to demonstrate a good level of fine motor control of hands and fingers.', 5, 1),
    (@sk_id, 6, 'Able to demonstrate an excellent fine motor control of hands and finger.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 56: SK 3.2
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @bi_y1
      AND code = '3.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '3.2', 'Pupils will be able to form letters and words in neat legible print', NULL, 2, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '3.2'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '3.2.1', 'Trace letters and numbers (i) lower-case letters (ii) upper-case letters (iii) numbers in numeral and word forms', NULL, 1, 1),
    (@sk_id, '3.2.2', 'Copy and write letters and numbers (i) lower-case letters (ii) upper-case letters (iii) numbers in numeral and word forms', NULL, 2, 1),
    (@sk_id, '3.2.3', 'Write words correctly', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Able to trace letters in a limited level.', 1, 1),
    (@sk_id, 2, 'Able to trace letters in neat legible print.', 2, 1),
    (@sk_id, 3, 'Able to copy letters in a limited level.', 3, 1),
    (@sk_id, 4, 'Able to copy letters in neat legible print.', 4, 1),
    (@sk_id, 5, 'Able to write words in a limited level.', 5, 1),
    (@sk_id, 6, 'Able to write words in neat legible print.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 57: SK 3.3
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @bi_y1
      AND code = '3.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '3.3', 'Pupils will be able to write and present ideas through a variety of media using appropriate language, form and style', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '3.3'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '3.3.1', 'Create simple creative works E.g. collage, cards, etc...', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Able to reproduce a very limited level of creative works.', 1, 1),
    (@sk_id, 2, 'Able to reproduce a limited level of creative works.', 2, 1),
    (@sk_id, 3, 'Able to reproduce a satisfactory level of creative works.', 3, 1),
    (@sk_id, 4, 'Able to produce creative works.', 4, 1),
    (@sk_id, 5, 'Able to produce a good level of creative works.', 5, 1),
    (@sk_id, 6, 'Able to produce an excellent level of creative works', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- ============================================================
-- MATEMATIK - TAHUN 1
-- ============================================================

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@mat_y1, '1.0', 'KONSEP NOMBOR', 1, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@mat_y1, '2.0', 'NOMBOR BULAT (dalam lingkungan 10)', 2, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@mat_y1, '3.0', 'OPERASI TAMBAH (dalam lingkungan 10)', 3, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@mat_y1, '4.0', 'OPERASI TOLAK (dalam lingkungan 10)', 4, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@mat_y1, '5.0', 'WANG', 5, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@mat_y1, '6.0', 'MASA DAN WAKTU', 6, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 61: SK 1.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @mat_y1
      AND code = '1.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '1.1', 'Objek mengikut warna asas (merah, biru, kuning)', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '1.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '1.1.1', 'Mengecam objek mengikut warna asas dengan menggunakan: (i) objek konkrit (ii) gambar', NULL, 1, 1),
    (@sk_id, '1.1.2', 'Menamakan objek mengikut warna asas: dengan menggunakan: (i) objek konkrit (ii) gambar', NULL, 2, 1),
    (@sk_id, '1.1.3', 'Mengasingkan objek mengikut warna asas dengan menggunakan: (i) objek konkrit (ii) gambar', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Memberi respons pada perkara yang berkaitan dengan objek dan warna asas.', 1, 1),
    (@sk_id, 2, 'Menamakan objek mengikut warna asas dengan menggunakan bahan bantu belajar', 2, 1),
    (@sk_id, 3, 'Menama dan mengasingkan objek mengikut warna asas.', 3, 1),
    (@sk_id, 4, 'Menama dan mengasingkan objek konkrit dan gambar objek mengikut warna asas dengan betul.', 4, 1),
    (@sk_id, 5, 'Menghubungkaitkan pengetahuan mengenal objek dan warnanya dalam persekitaran sebenar dengan betul dan yakin.', 5, 1),
    (@sk_id, 6, 'Menerangkan dengan jelas dan yakin mengenai pelbagai objek dan warnanya secara kreatif serta boleh dicontohi.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 62: SK 1.2
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @mat_y1
      AND code = '1.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '1.2', 'Objek mengikut bentuk asas (bulat, segi empat, segi tiga)', NULL, 2, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '1.2'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '1.2.1', 'Mengecam objek mengikut bentuk asas dengan menggunakan: (i) objek konkrit (ii) gambar', NULL, 1, 1),
    (@sk_id, '1.2.2', 'Menamakan objek mengikut bentuk asas dengan menggunakan: (i) objek konkrit (ii) gambar', NULL, 2, 1),
    (@sk_id, '1.2.3', 'Mengasingkan objek mengikut bentuk asas dengan menggunakan: (i) objek konkrit (ii) gambar', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Memberi respons pada perkara berkaitan dengan objek dan bentuk asas.', 1, 1),
    (@sk_id, 2, 'Menamakan objek mengikut bentuk asas dengan menggunakan bahan bantu belajar', 2, 1),
    (@sk_id, 3, 'Menama dan mengasingkan objek mengikut bentuk asas.', 3, 1),
    (@sk_id, 4, 'Menama dan mengasingkan objek konkrit dan gambar objek mengikut bentuk asas dengan betul.', 4, 1),
    (@sk_id, 5, 'Menghubungkaitkan pengetahuan mengenal objek dan bentuk dalam persekitaran sebenar dengan betul dan yakin.', 5, 1),
    (@sk_id, 6, 'Menerangkan dengan jelas dan yakin mengenai pelbagai objek dan bentuknya secara kreatif serta boleh dicontohi.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 63: SK 1.3
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @mat_y1
      AND code = '1.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '1.3', 'Objek mengikut saiz (kecil, besar)', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '1.3'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '1.3.1', 'Mengecam objek mengikut saiz dengan menggunakan: (i) objek konkrit (ii) gambar', NULL, 1, 1),
    (@sk_id, '1.3.2', 'Menamakan objek mengikut saiz dengan menggunakan: (i) objek konkrit (ii) gambar', NULL, 2, 1),
    (@sk_id, '1.3.3', 'Mengasingkan objek mengikut saiz dengan menggunakan: (i) objek konkrit (ii) gambar', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Memberi respons pada perkara berkaitan dengan objek dan saiz', 1, 1),
    (@sk_id, 2, 'Menamakan objek mengikut saiz dengan menggunakan bahan bantu belajar', 2, 1),
    (@sk_id, 3, 'Menama dan mengasingkan objek mengikut saiz.', 3, 1),
    (@sk_id, 4, 'Menama dan mengasingkan objek konkrit dan gambar objek mengikut saiz dengan betul.', 4, 1),
    (@sk_id, 5, 'Menghubungkaitkan pengetahuan mengenal objek dan saiz dalam persekitaran sebenar dengan betul dan yakin.', 5, 1),
    (@sk_id, 6, 'Menerangkan dengan jelas dan yakin mengenai pelbagai objek dan saiznya secara kreatif serta boleh dicontohi. .', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 65: SK 2.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @mat_y1
      AND code = '2.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '2.1', 'Nombor 0 (sifar) dan 10', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '2.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '2.1.1', 'Menyebut nombor', NULL, 1, 1),
    (@sk_id, '2.1.2', 'Mengenal simbol nombor', NULL, 2, 1),
    (@sk_id, '2.1.3', 'Menamakan nombor', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Memberi respons pada perkara berkaitan dengan nombor antara 0 (sifar) dan 10.', 1, 1),
    (@sk_id, 2, 'Mengenal nombor 0 (sifar) dan 10 dengan menggunakan bahan bantu belajar.', 2, 1),
    (@sk_id, 3, 'Menyebut dan menamakan nombor 0 (sifar) dan 10.', 3, 1),
    (@sk_id, 4, 'Menyebut dan menamakan nombor 0 (sifar) dan 10 dengan betul.', 4, 1),
    (@sk_id, 5, 'Menyebut dan menamakan nombor 0 (sifar) dan 10 pada situasi baharu dengan betul dan yakin.', 5, 1),
    (@sk_id, 6, 'Menggabungkan pengetahuan dan kemahiran menyebut dan menamakan nombor 0 (sifar) dan 10 secara kreatif serta boleh dicontohi.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 66: SK 2.2
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @mat_y1
      AND code = '2.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '2.2', 'Membilang nombor 0 hingga 10', NULL, 2, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '2.2'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '2.2.1', 'Membilang objek dalam kumpulan', NULL, 1, 1),
    (@sk_id, '2.2.2', 'Menyebut nombor secara tertib menaik', NULL, 2, 1),
    (@sk_id, '2.2.3', 'Menyusun nombor secara tertib menaik', NULL, 3, 1),
    (@sk_id, '2.2.4', 'Menyebut nombor secara tertib menurun', NULL, 4, 1),
    (@sk_id, '2.2.5', 'Menyusun nombor secara tertib menurun', NULL, 5, 1),
    (@sk_id, '2.2.6', 'Menyusun rangkaian nombor', NULL, 6, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Membilang objek secara rawak.', 1, 1),
    (@sk_id, 2, 'Membilang objek dan menyebut nombor 0 hingga 10 dengan menggunakan bahan bantu mengajar.', 2, 1),
    (@sk_id, 3, 'Membilang objek dan menyusun nombor 0 hingga 10 secara tertib menaik dan menurun.', 3, 1),
    (@sk_id, 4, 'Membilang objek dan menyusun nombor 0 hingga 10 secara tertib menaik dan menurun dengan cara betul.', 4, 1),
    (@sk_id, 5, 'Mengaplikasi pengetahuan dan kemahiran membilang objek dan menyusun nombor 0 hingga 10 dengan betul dan yakin.', 5, 1),
    (@sk_id, 6, 'Menggabungkan pengetahuan dan kemahiran membilang nombor secara kreatif serta boleh dicontohi.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 67: SK 2.3
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @mat_y1
      AND code = '2.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '2.3', 'Menggunakan nombor dalam kehidupan harian', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '2.3'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '2.3.1', 'Menyebut nombor dalam persekitaran', NULL, 1, 1),
    (@sk_id, '2.3.2', 'Membilang objek dalam persekitaran', NULL, 2, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Memberi respons pada perkara berkaitan dengan nombor dalam persekitaran', 1, 1),
    (@sk_id, 2, 'Membilang objek yang terdapat dalam persekitaran.', 2, 1),
    (@sk_id, 3, 'Menggunakan nombor dengan cara menyebut nombor dan membilang objek dalam persekitaran.', 3, 1),
    (@sk_id, 4, 'Membilang objek yang terdapat di persekitaran dengan betul.', 4, 1),
    (@sk_id, 5, 'Mengaplikasi pengetahuan dan kemahiran membilang objek menggunakan nombor yang betul dengan yakin', 5, 1),
    (@sk_id, 6, 'Menggabungkan pengetahuan dan kemahiran menyebut nombor dan membilang objek secara kreatif serta boleh dicontohi.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 68: SK 3.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @mat_y1
      AND code = '3.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '3.1', 'Konsep tambah', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '3.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '3.1.1', 'Menyatukan dua kumpulan objek', NULL, 1, 1),
    (@sk_id, '3.1.2', 'Menambah dengan membilang semua', NULL, 2, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Memberi respons pada perkara berkaitan dengan aktivti menambah sebarang nombor atau objek.', 1, 1),
    (@sk_id, 2, 'Menyatakan mengenai konsep tambah dengan menggunakan bahan bantu belajar.', 2, 1),
    (@sk_id, 3, 'Menyatukan dua kumpulan objek dan menambah dengan membilang semua.', 3, 1),
    (@sk_id, 4, 'Menyatukan dua kumpulan objek dan menambah dengan membilang semua dengan cara yang betul.', 4, 1),
    (@sk_id, 5, 'Mengaplikasi pengetahuan dan kemahiran menyatukan dua kumpulan objek dan menambah dengan membilang semua dengan betul dan yakin.', 5, 1),
    (@sk_id, 6, 'Menggabungkan pengetahuan dan kemahiran mengenai konsep tambah secara kreatif serta boleh dicontohi.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 69: SK 3.2
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @mat_y1
      AND code = '3.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '3.2', 'Menambah sebarang dua nombor dalam lingkungan 10', NULL, 2, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '3.2'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '3.2.1', 'Menambah nombor dengan menggunakan: (i) objek (ii) gambar', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Memberi respons pada perkara berkaitan dengan aktiviti menambah sebarang nombor atau objek', 1, 1),
    (@sk_id, 2, 'Menyatakan mengenai aktiviti menambah sebarang nombor dengan menggunakan bahan bantu belajar.', 2, 1),
    (@sk_id, 3, 'Menambah sebarang dua nombor dalam lingkungan 10 dengan menggunakan objek dan gambar.', 3, 1),
    (@sk_id, 4, 'Menambah sebarang dua nombor dalam lingkungan 10 dengan menggunakan objek dan gambar mengikut cara yang betul.', 4, 1),
    (@sk_id, 5, 'Mengaplikasi pengetahuan dan kemahiran menambah sebarang dua nombor dalam lingkungan 10 dengan betul dan yakin', 5, 1),
    (@sk_id, 6, 'Menggabungkan pengetahuan dan kemahiran menambah sebarang dua nombor secara kreatif serta boleh dicontohi.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 70: SK 4.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @mat_y1
      AND code = '4.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '4.1', 'Konsep tolak', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '4.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '4.1.1', 'Mengurangkan objek dalam kumpulan', NULL, 1, 1),
    (@sk_id, '4.1.2', 'Menolak dengan mencari perbezaan', NULL, 2, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Memberi respons pada perkara berkaitan dengan aktiviti menolak sebarang nombor atau objek.', 1, 1),
    (@sk_id, 2, 'Menolak sebarang nombor dengan menggunakan bahan bantu belajar.', 2, 1),
    (@sk_id, 3, 'Mengurangkan objek dalam kumpulan dan menolak dengan mencari perbezaan.', 3, 1),
    (@sk_id, 4, 'Mengurangkan objek dalam kumpulan dan menolak dengan mencari perbezaan dengan cara yang betul.', 4, 1),
    (@sk_id, 5, 'Mengaplikasi pengetahuan dan kemahiran mengurangkan objek dalam kumpulan dan menolak dengan mencari perbezaan dengan betul dan yakin.', 5, 1),
    (@sk_id, 6, 'Menggabungkan pengetahuan dan kemahiran mengurangkan objek dalam kumpulan dan menolak dengan mencari perbezaan secara kreatif serta boleh dicontohi.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 71: SK 4.2
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @mat_y1
      AND code = '4.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '4.2', 'Menolak sebarang dua nombor dalam lingkungan 10', NULL, 2, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '4.2'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '4.2.1', 'Menolak nombor dengan menggunakan: (i) objek (ii) gambar', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Memberi respons pada perkara yang berkaitan dengan aktiviti menolak sebarang nombor dalam lingkungan 10.', 1, 1),
    (@sk_id, 2, 'Menolak sebarang dua nombor dalam lingkungan 10 dengan menggunakan bahan bantu belajar.', 2, 1),
    (@sk_id, 3, 'Menolak sebarang dua nombor dalam lingkungan 10 dengan menggunakan objek dan gambar.', 3, 1),
    (@sk_id, 4, 'Menolak sebarang dua nombor dalam lingkungan 10 dengan menggunakan objek dan gambar dengan betul.', 4, 1),
    (@sk_id, 5, 'Mengaplikasi pengetahuan dan kemahiran menolak sebarang nombor dengan betul dan yakin', 5, 1),
    (@sk_id, 6, 'Menggabungkan pengetahuan dan kemahiran menolak sebarang nombor secara kreatif serta boleh dicontohi.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 72: SK 5.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @mat_y1
      AND code = '5.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '5.1', 'Wang Malaysia (wang syiling)', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '5.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '5.1.1', 'Menamakan wang syiling 5 sen, 10 sen, 20 sen dan 50 sen', NULL, 1, 1),
    (@sk_id, '5.1.2', 'Mengecam wang syiling 5 sen, 10 sen, 20 sen dan 50 sen', NULL, 2, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Memberi respons pada perkara yang berkaitan dengan wang Malaysia.', 1, 1),
    (@sk_id, 2, 'Menyatakan mengenai wang syiling dengan menggunakan bahan bantu belajar.', 2, 1),
    (@sk_id, 3, 'Mengecam dan menamakan wang syiling.', 3, 1),
    (@sk_id, 4, 'Mengecam dan menamakan wang-wang syiling dengan betul.', 4, 1),
    (@sk_id, 5, 'Membezakan antara wang syiling 5 sen, 10 sen, 20 sen dan 50 sen dengan betul dan yakin.', 5, 1),
    (@sk_id, 6, 'Menerangkan perbezaan dan persamaan wang-wang syiling Malaysia secara kreatif serta boleh dicontohi.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 73: SK 5.2
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @mat_y1
      AND code = '5.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '5.2', 'Nilai wang', NULL, 2, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '5.2'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '5.2.1', 'Menentukan nilai wang syiling 5 sen, 10 sen, 20 sen dan 50 sen', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Memberi respons pada perkara yang berkaitan dengan nilai wang syiling.', 1, 1),
    (@sk_id, 2, 'Menyatakan mengenai nilai wang syiling dengan menggunakan bahan bantu belajar.', 2, 1),
    (@sk_id, 3, 'Menentukan nilai wang syiling 5 sen, 10 sen, 20 sen dan 50 sen', 3, 1),
    (@sk_id, 4, 'Menentukan nilai wang syiling 5 sen, 10 sen, 20 sen dan 50 sen dengan betul.', 4, 1),
    (@sk_id, 5, 'Membezakan antara nilai wang syiling 5 sen, 10 sen, 20 sen dan 50 sen dengan betul, dan yakin.', 5, 1),
    (@sk_id, 6, 'Menerangkan perbezaan dan persamaan nilai wang syiling secara kreatif serta boleh dicontohi.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 74: SK 6.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @mat_y1
      AND code = '6.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '6.1', 'Waktu dalam satu hari (pagi, tengah hari, petang, malam)', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '6.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '6.1.1', 'Menamakan waktu dalam satu hari', NULL, 1, 1),
    (@sk_id, '6.1.2', 'Menyatakan waktu dalam satu hari berdasarkan gambar', NULL, 2, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Memberi respons pada perkara yang berkaitan dengan waktu dalam satu hari.', 1, 1),
    (@sk_id, 2, 'Menyatakan mengenai waktu dengan menggunakan bahan bantu belajar.', 2, 1),
    (@sk_id, 3, 'Menyatakan mengenai waktu dalam satu hari.', 3, 1),
    (@sk_id, 4, 'Menerangkan mengenai waktu dan aktiviti yang sesuai dilakukan dalam satu hari dengan betul.', 4, 1),
    (@sk_id, 5, 'Membezakan antara waktu dengan aktiviti-aktivti yang sesuai dilakukan dalam satu hari dengan betul dan yakin', 5, 1),
    (@sk_id, 6, 'Menerangkan perbezaan dan persamaan antara waktu dengan aktiviti-aktiviti yang sesuai dilakukan dalam satu hari secara kreatif serta boleh dicontohi.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 75: SK 6.2
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @mat_y1
      AND code = '6.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '6.2', 'Hari dalam satu minggu (Ahad, Isnin, Selasa, Rabu, Khamis, Jumaat, Sabtu)', NULL, 2, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '6.2'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '6.2.1', 'Menamakan hari dalam satu minggu', NULL, 1, 1),
    (@sk_id, '6.2.2', 'Menyatakan hari dalam satu minggu mengikut urutan', NULL, 2, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Memberi respons pada perkara yang berkaitan dengan hari dalam satu minggu.', 1, 1),
    (@sk_id, 2, 'Menamakan hari dalam satu minggu dengan menggunakan bahan bantu belajar.', 2, 1),
    (@sk_id, 3, 'Menyatakan mengenai hari dalam satu minggu.', 3, 1),
    (@sk_id, 4, 'Menyatakan hari dalam satu minggu mengikut urutan dengan betul.', 4, 1),
    (@sk_id, 5, 'Membezakan antara hari dengan aktiviti yang sesuai dilakukan dalam satu minggu dengan betul dan yakin.', 5, 1),
    (@sk_id, 6, 'Menerangkan perbezaaan dan persamaan antara hari dan aktiviti-aktiviti yang sesuai dilakukan dalam satu minggu secara kreatif serta boleh dicontohi.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- ============================================================
-- PENDIDIKAN ISLAM - TAHUN 1
-- ============================================================

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@pi_y1, '1.0', 'TILAWAH AL-QURAN', 1, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@pi_y1, '2.0', 'BACAAN DAN HAFAZAN', 2, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@pi_y1, '3.0', 'AKIDAH', 3, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@pi_y1, '4.0', 'IBADAH', 4, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@pi_y1, '5.0', 'ADAB DAN AKHLAK ISLAMIAH', 5, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@pi_y1, '6.0', 'SIRAH', 6, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 29: SK 1.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @pi_y1
      AND code = '1.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '1.1', 'Mengenal, menyebut dan membaca huruf hijaiyyah tunggal berbaris satu di atas.', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '1.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '1.1.1', 'Mengenal huruf hijaiyyah tunggal berbaris satu di atas ﺍ hingga ﻱ', NULL, 1, 1),
    (@sk_id, '1.1.2', 'Menyebut dan membaca huruf hijaiyyah tunggal ﺍ hingga ﻱ berbaris satu di atas.', NULL, 2, 1),
    (@sk_id, '1.1.3', 'Membunyikan huruf yang: i. Sama bentuk ii. Hampir sama bunyi', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Mengecam dan menunjuk beberapa huruf hijaiyyah tunggal berbaris satu di atas mengikut bacaan guru.', 1, 1),
    (@sk_id, 2, 'Membunyikan beberapa huruf hijaiyyah tunggal berbaris satu di atas tanpa bimbingan guru.', 2, 1),
    (@sk_id, 3, 'Mengenal, menyebut dan membaca huruf hijaiyyah tunggal berbaris satu di atas dengan talaqqi musyafahah.', 3, 1),
    (@sk_id, 4, 'Mengenal dan membaca huruf hijaiyyah tunggal berbaris satu di atas serta dapat membezakan huruf yang sama bentuk .', 4, 1),
    (@sk_id, 5, 'Mengenal dan membaca huruf hijaiyyah tunggal berbaris satu di atas serta dapat membezakan huruf yang sama bentuk dan hampir sama bunyi.', 5, 1),
    (@sk_id, 6, 'Membaca huruf hijaiyyah tunggal berbaris satu di atas dengan betul dan boleh dicontohi.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 30: SK 1.2
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @pi_y1
      AND code = '1.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '1.2', 'Mengenal, membunyi dan membaca dua huruf berbaris satu di atas', NULL, 2, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '1.2'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '1.2.1', 'Mengenal dua huruf bersambung dan tidak bersambung.', NULL, 1, 1),
    (@sk_id, '1.2.2', 'Membunyikan dua huruf berbaris satu di atas bersambung dan tidak bersambung.', NULL, 2, 1),
    (@sk_id, '1.2.3', 'Membaca dua huruf berbaris satu di atas bersambung dan tidak bersambung.', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Mengecam dua huruf bersambung dan tidak bersambung.', 1, 1),
    (@sk_id, 2, 'Membunyikan dua huruf berbaris satu di atas bersambung dan tidak bersambung.', 2, 1),
    (@sk_id, 3, 'Membaca dua huruf berbaris satu di atas dengan talaqqi musyafahah.', 3, 1),
    (@sk_id, 4, 'Membaca dua huruf berbaris satu di atas dengan betul.', 4, 1),
    (@sk_id, 5, 'Membaca dua huruf berbaris satu di atas dengan betul dan lancar.', 5, 1),
    (@sk_id, 6, 'Membaca dua huruf berbaris satu di atas dengan betul dan lancar serta boleh membimbing rakan.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 31: SK 2.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @pi_y1
      AND code = '2.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '2.1', 'Membaca surah al-Fatihah', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '2.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '2.1.1', 'Membaca surah al-Fatihah ayat satu hingga ayat dua.', NULL, 1, 1),
    (@sk_id, '2.1.2', 'Membaca surah al-Fatihah ayat tiga hingga ayat empat.', NULL, 2, 1),
    (@sk_id, '2.1.3', 'Membaca surah al-Fatihah ayat lima hingga ayat enam.', NULL, 3, 1),
    (@sk_id, '2.1.4', 'Membaca surah al-Fatihah ayat tujuh.', NULL, 4, 1),
    (@sk_id, '2.1.5', 'Membaca keseluruhan surah al-Fatihah.', NULL, 5, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Menyebut kalimah tertentu daripada surah al-Fatihah.', 1, 1),
    (@sk_id, 2, 'Menyebut kalimah demi kalimah mengikut turutan ayat yang betul.', 2, 1),
    (@sk_id, 3, 'Membaca surah al-Fatihah dengan talaqqi musyafahah.', 3, 1),
    (@sk_id, 4, 'Membaca surah al-Fatihah dengan betul tanpa bimbingan.', 4, 1),
    (@sk_id, 5, 'Membaca surah al-Fatihah dengan betul.', 5, 1),
    (@sk_id, 6, 'Membaca surah al-Fatihah dengan betul dan lancar serta boleh membimbing rakan.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 32: SK 2.2
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @pi_y1
      AND code = '2.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '2.2', 'Membaca dan menghafaz surah al- Fatihah.', NULL, 2, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '2.2'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '2.2.1', 'Membaca dan menghafaz surah al-Fatihah ayat satu hingga ayat dua.', NULL, 1, 1),
    (@sk_id, '2.2.2', 'Membaca dan menghafaz surah al-Fatihah ayat tiga hingga ayat empat .', NULL, 2, 1),
    (@sk_id, '2.2.3', 'Membaca dan menghafaz surah al-Fatihah ayat lima hingga ayat enam .', NULL, 3, 1),
    (@sk_id, '2.2.4', 'Membaca dan menghafaz ayat tujuh surah al- Fatihah.', NULL, 4, 1),
    (@sk_id, '2.2.5', 'Membaca dan menghafaz keseluruhan surah al- Fatihah.', NULL, 5, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Menyebut kalimah tertentu daripada surah al-Fatihah.', 1, 1),
    (@sk_id, 2, 'Menyebut kalimah demi kalimah mengikut turutan ayat yang betul.', 2, 1),
    (@sk_id, 3, 'Membaca dan menghafaz surah al-Fatihah dengan talaqqi musyafahah.', 3, 1),
    (@sk_id, 4, 'Membaca dan menghafaz surah al-Fatihah tanpa bimbingan.', 4, 1),
    (@sk_id, 5, 'Membaca dan menghafaz surah al-Fatihah dengan betul.', 5, 1),
    (@sk_id, 6, 'Membaca dan menghafaz surah al-Fatihah dengan betul dan lancar serta boleh dicontohi.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 33: SK 2.3
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @pi_y1
      AND code = '2.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '2.3', 'Membaca surah al- Ikhlas', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '2.3'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '2.3.1', 'Membaca surah al-Ikhlas ayat satu hingga ayat dua.', NULL, 1, 1),
    (@sk_id, '2.3.2', 'Membaca surah al-Ikhlas ayat tiga hingga ayat empat.', NULL, 2, 1),
    (@sk_id, '2.3.3', 'Membaca keseluruhan surah al-Ikhlas.', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Menyebut kalimah tertentu daripada surah al-Ikhlas.', 1, 1),
    (@sk_id, 2, 'Menyebut kalimah demi kalimah mengikut turutan ayat yang betul .', 2, 1),
    (@sk_id, 3, 'Membaca surah al-Ikhlas dengan talaqqi musyafahah.', 3, 1),
    (@sk_id, 4, 'Membaca surah al-Ikhlas tanpa bimbingan..', 4, 1),
    (@sk_id, 5, 'Membaca surah al-Ikhlas dengan betul..', 5, 1),
    (@sk_id, 6, 'Membaca surah al-Ikhlas dengan betul dan lancar serta boleh membimbing rakan.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 34: SK 2.4
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @pi_y1
      AND code = '2.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '2.4', 'Membaca dan menghafaz surah al- Ikhlas', NULL, 4, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '2.4'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '2.4.1', 'Membaca dan menghafaz surah al-Ikhlas ayat satu hingga ayat dua.', NULL, 1, 1),
    (@sk_id, '2.4.2', 'Membaca dan menghafaz surah al-Ikhlas ayat tiga hingga ayat empat.', NULL, 2, 1),
    (@sk_id, '2.4.3', 'Membaca dan menghafaz keseluruhan surah al- Ikhlas.', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Menyebut kalimah tertentu daripada surah al-Ikhlas.', 1, 1),
    (@sk_id, 2, 'Menyebut kalimah demi kalimah mengikut turutan ayat yang betul.', 2, 1),
    (@sk_id, 3, 'Membaca dan menghafaz surah al-Ikhlas dengan talaqqi musyafahah.', 3, 1),
    (@sk_id, 4, 'Membaca dan menghafaz surah al-Ikhlas tanpa bimbingan.', 4, 1),
    (@sk_id, 5, 'Membaca dan menghafaz surah al-Ikhlas dengan betul.', 5, 1),
    (@sk_id, 6, 'Membaca dan menghafaz surah al-Ikhlas dengan betul dan lancar serta boleh dicontohi.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 35: SK 3.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @pi_y1
      AND code = '3.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '3.1', 'Memahami Rukun Iman', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '3.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '3.1.1', 'Menyatakan pengertian Rukun Iman dan hukum beriman dengannya', NULL, 1, 1),
    (@sk_id, '3.1.2', 'Menyenaraikan Rukun Iman', NULL, 2, 1),
    (@sk_id, '3.1.3', 'Mengenalpasti enam perkara Rukun Iman', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Menyatakan pengertian Rukun Iman dan hukum beriman dengannya', 1, 1),
    (@sk_id, 2, 'Menyatakan beberapa Rukun Iman', 2, 1),
    (@sk_id, 3, 'Menyenaraikan Rukun Iman', 3, 1),
    (@sk_id, 4, 'Menyenaraikan Rukun Iman mengikut tertib', 4, 1),
    (@sk_id, 5, 'Mengenalpasti enam perkara dalam Rukun Iman.', 5, 1),
    (@sk_id, 6, 'Menjelaskan enam perkara dalam Rukun Iman', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 36: SK 3.2
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @pi_y1
      AND code = '3.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '3.2', 'Mengenal kekuasaan Allah SWT', NULL, 2, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '3.2'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '3.2.1', 'Mengenal makhluk ciptaan Allah SWT .', NULL, 1, 1),
    (@sk_id, '3.2.2', 'Membezakan ciptaan manusia dan ciptaan Allah SWT .', NULL, 2, 1),
    (@sk_id, '3.2.3', 'Mengenalpasti fungsi pancaindera ciptaan Allah SWT .', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Menyatakan makhluk ciptaan Allah .', 1, 1),
    (@sk_id, 2, 'Menamakan makhluk ciptaan Allah dan benda ciptaan manusia.', 2, 1),
    (@sk_id, 3, 'Membezakan makhluk ciptaan Allah SWT dan benda ciptaan manusia .', 3, 1),
    (@sk_id, 4, 'Menyatakan pancaindera kurniaan Allah SWT kepada manusia.', 4, 1),
    (@sk_id, 5, 'Mengenalpasti fungsi pancaindera ciptaan Allah SWT.', 5, 1),
    (@sk_id, 6, 'Menjelaskan fungsi pancaindera ciptaan Allah SWT.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 37: SK 4.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @pi_y1
      AND code = '4.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '4.1', 'Mengenal jenis-jenis air mutlak', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '4.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '4.1.1', 'Menyatakan pengertian air mutlak .', NULL, 1, 1),
    (@sk_id, '4.1.2', 'Menyatakan jenis-jenis air mutlak .', NULL, 2, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Menyatakan pengertian air mutlak.', 1, 1),
    (@sk_id, 2, 'Menyatakan beberapa contoh air mutlak.', 2, 1),
    (@sk_id, 3, 'Menyenaraikan air mutlak.', 3, 1),
    (@sk_id, 4, 'Mengenalpasti air mutlak dan bukan air mutlak.', 4, 1),
    (@sk_id, 5, 'Menjelaskan kegunaan air mutlak.', 5, 1),
    (@sk_id, 6, 'Mengenalpasti jenis-jenis air yang boleh digunakan untuk bersuci dan dapat membimbing rakan sebaya.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 38: SK 4.2
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @pi_y1
      AND code = '4.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '4.2', 'Memahami konsep asas istinjak', NULL, 2, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '4.2'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '4.2.1', 'Menyatakan pengertian istinjak dan hukumnya .', NULL, 1, 1),
    (@sk_id, '4.2.2', 'Menyatakan alat–alat untuk beristinjak .', NULL, 2, 1),
    (@sk_id, '4.2.3', 'Menyatakan tujuan beristinjak .', NULL, 3, 1),
    (@sk_id, '4.2.4', 'Menyatakan cara-cara beristinjak menggunakan air .', NULL, 4, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Menyatakan pengertian beristinjak dan hukumnya.', 1, 1),
    (@sk_id, 2, 'Menyatakan alat-alat untuk beristinjak.', 2, 1),
    (@sk_id, 3, 'Menyatakan tujuan dan cara-cara beristinjak.', 3, 1),
    (@sk_id, 4, 'Menyatakan tujuan beristinjak dan cara beristinjak menggunakan air dengan betul.', 4, 1),
    (@sk_id, 5, 'Menjelaskan cara beristinjak menggunakan bahan selain daripada air dengan betul.', 5, 1),
    (@sk_id, 6, 'Mengamalkan cara beristinjak dengan betul dalam kehidupan seharian.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 39: SK 4.3
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @pi_y1
      AND code = '4.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '4.3', 'Memahami konsep berwuduk', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '4.3'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '4.3.1', 'Menyatakan pengertian wuduk dan tujuannya.', NULL, 1, 1),
    (@sk_id, '4.3.2', 'Mengenal anggota wuduk.', NULL, 2, 1),
    (@sk_id, '4.3.3', 'Membaca lafaz niat wuduk.', NULL, 3, 1),
    (@sk_id, '4.3.4', 'Melakukan amali wuduk.', NULL, 4, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Menyatakan pengertian wuduk dan tujuannya.', 1, 1),
    (@sk_id, 2, 'Menyatakan anggota wuduk yang wajib.', 2, 1),
    (@sk_id, 3, 'Membaca lafaz niat wuduk dan menunjukkan cara berwuduk.', 3, 1),
    (@sk_id, 4, 'Membaca lafaz niat wuduk dan menunjukkan cara berwuduk dengan tertib dan betul.', 4, 1),
    (@sk_id, 5, 'Melakukan amali wuduk dengan sempurna.', 5, 1),
    (@sk_id, 6, 'Mengamalkan wuduk yang sempurna dalam kehidupan seharian.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 40: SK 5.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @pi_y1
      AND code = '5.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '5.1', 'Memahami dan mengamalkan adab makan', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '5.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '5.1.1', 'Menyatakan adab sebelum makan.', NULL, 1, 1),
    (@sk_id, '5.1.2', 'Menyatakan adab semasa makan .', NULL, 2, 1),
    (@sk_id, '5.1.3', 'Menyatakan adab-adab selepas makan .', NULL, 3, 1),
    (@sk_id, '5.1.4', 'Mengamalkan adab sebelum, semasa dan selepas makan .', NULL, 4, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Menyatakan adab-adab makan.', 1, 1),
    (@sk_id, 2, 'Membaca doa sebelum dan selepas makan.', 2, 1),
    (@sk_id, 3, 'Menyatakan adab sebelum, semasa dan selepas makan.', 3, 1),
    (@sk_id, 4, 'Menjelaskan adab sebelum, semasa dan selepas makan berdasarkan situasi.', 4, 1),
    (@sk_id, 5, 'Melakukan tunjuk cara adab sebelum, semasa dan selepas makan beserta bacaan doa dengan betul.', 5, 1),
    (@sk_id, 6, 'Mengamalkan adab-adab sebelum, semasa dan selepas makan dengan betul, istiqamah dan boleh dicontohi.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 41: SK 5.2
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @pi_y1
      AND code = '5.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '5.2', 'Memahami dan mengamalkan adab semasa belajar', NULL, 2, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '5.2'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '5.1.1', 'Menyatakan adab semasa belajar.', NULL, 1, 1),
    (@sk_id, '5.1.2', 'Membaca dan menghafaz doa belajar.', NULL, 2, 1),
    (@sk_id, '5.1.3', 'Mengamalkan adab semasa belajar.', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Menyatakan adab-adab semasa belajar.', 1, 1),
    (@sk_id, 2, 'Melafazkan doa belajar.', 2, 1),
    (@sk_id, 3, 'Menyatakan adab semasa belajar dan menghafaz doa belajar.', 3, 1),
    (@sk_id, 4, 'Mengenalpasti perlakuan beradab dan tidak beradab semasa belajar .', 4, 1),
    (@sk_id, 5, 'Menjelaskan adab semasa belajar berdasarkan situasi.', 5, 1),
    (@sk_id, 6, 'Mengamalkan adab semasa belajar secara istiqamah.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 42: SK 6.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @pi_y1
      AND code = '6.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '6.1', 'Mengenal Nabi Muhammad SAW dan keturunan baginda', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '6.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '6.1.1', 'Menyatakan nama rasul terakhir.', NULL, 1, 1),
    (@sk_id, '6.1.2', 'Menyatakan sifat-sifat Nabi Muhammad SAW.', NULL, 2, 1),
    (@sk_id, '6.1.3', 'Mengetahui salasilah keturunan Nabi Muhammad SAW.', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Menyatakan nama rasul yang terakhir.', 1, 1),
    (@sk_id, 2, 'Menyatakan sifat-sifat Nabi Muhamad SAW.', 2, 1),
    (@sk_id, 3, 'Menyatakan sifat-sifat dan salasilah keturunan Nabi Muhammad SAW secara ringkas.', 3, 1),
    (@sk_id, 4, 'Menyenaraikan sifat-sifat dan salasilah keturunan Nabi Muhammad SAW.', 4, 1),
    (@sk_id, 5, 'Menjelaskan salasilah keturunan dan mencontohi sifat-sifat Nabi Muhammad SAW.', 5, 1),
    (@sk_id, 6, 'Menceritakan salasilah keturunan dan mengamalkan sifat- sifat Nabi Muhammad SAW dalam kehidupan seharian dan boleh dicontohi.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- ============================================================
-- PENDIDIKAN MORAL - TAHUN 1
-- ============================================================

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@pm_y1, '1.0', 'KEPERCAYAAN KEPADA TUHAN', 1, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@pm_y1, '2.0', 'BAIK HATI', 2, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@pm_y1, '3.0', 'BERTANGGUNGJAWAB', 3, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@pm_y1, '4.0', 'BERTERIMA KASIH', 4, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@pm_y1, '5.0', 'HEMAH TINGGI', 5, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@pm_y1, '6.0', 'HORMAT', 6, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@pm_y1, '7.0', 'KASIH SAYANG', 7, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@pm_y1, '8.0', 'KEADILAN', 8, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@pm_y1, '9.0', 'KEBERANIAN', 9, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@pm_y1, '10.0', 'KEJUJURAN', 10, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@pm_y1, '11.0', 'KERAJINAN', 11, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@pm_y1, '12.0', 'KERJASAMA', 12, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@pm_y1, '13.0', 'KESEDERHANAAN', 13, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

INSERT INTO kss_domains
    (curriculum_subject_id, code, title, sort_order, is_active)
VALUES
    (@pm_y1, '14.0', 'TOLERANSI', 14, 1)
ON DUPLICATE KEY UPDATE
    title = VALUES(title),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 31: SK 1.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @pm_y1
      AND code = '1.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '1.1', 'Mengenal kepelbagaian ciptaan Tuhan', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '1.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '1.1.1', 'Menyebut benda ciptaan Tuhan yang terdapat di dalam bilik darjah', NULL, 1, 1),
    (@sk_id, '1.1.2', 'Menyebut benda bukan ciptaan Tuhan yang terdapat di dalam bilik darjah', NULL, 2, 1),
    (@sk_id, '1.1.3', 'Mengenalpasti benda ciptaan Tuhan dan benda bukan ciptaan Tuhan yang terdapat di dalam bilik darjah', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Mengenal benda yang terdapat di dalam bilik darjah.', 1, 1),
    (@sk_id, 2, 'Menyatakan benda yang terdapat di dalam bilik darjah.', 2, 1),
    (@sk_id, 3, 'Menyatakan benda ciptaan Tuhan dan benda bukan ciptaan Tuhan yang terdapat di dalam bilik darjah.', 3, 1),
    (@sk_id, 4, 'Mengenalpasti benda ciptaan Tuhan dan benda bukan ciptaan Tuhan di dalam bilik darjah.', 4, 1),
    (@sk_id, 5, 'Mengelaskan benda ciptaan Tuhan dan benda bukan ciptaan Tuhan di dalam bilik darjah.', 5, 1),
    (@sk_id, 6, 'Memberi contoh benda ciptaan Tuhan dan benda bukan ciptaan Tuhan di luar bilik darjah.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 32: SK 2.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @pm_y1
      AND code = '2.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '2.1', 'Membantu rakan', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '2.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '2.1.1', 'Menyatakan perlakuan membantu rakan', NULL, 1, 1),
    (@sk_id, '2.1.2', 'Menyatakan keperluan membantu rakan', NULL, 2, 1),
    (@sk_id, '2.1.3', 'Menunjukkan perlakuan membantu rakan', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Mengenal perlakuan membantu rakan.', 1, 1),
    (@sk_id, 2, 'Menyatakan perlakuan membantu rakan.', 2, 1),
    (@sk_id, 3, 'Mengenalpasti situasi rakan yang memerlukan bantuan.', 3, 1),
    (@sk_id, 4, 'Menunjukkan perlakuan membantu rakan mengikut situasi dan kemampuan.', 4, 1),
    (@sk_id, 5, 'Membantu rakan yang memerlukan bantuan.', 5, 1),
    (@sk_id, 6, 'Mengamalkan sikap membantu rakan.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 33: SK 3.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @pm_y1
      AND code = '3.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '3.1', 'Bertanggungjawab terhadap diri sendiri semasa di rumah', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '3.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '3.1.1', 'Menyatakan tanggungjawab terhadap diri sendiri semasa di rumah', NULL, 1, 1),
    (@sk_id, '3.1.2', 'Menyatakan keperluan melaksanakan tanggungjawab terhadap diri sendiri semasa di rumah', NULL, 2, 1),
    (@sk_id, '3.1.3', 'Melaksanakan tanggungjawab terhadap diri sendiri semasa di rumah', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Mengenal tanggungjawab terhadap diri sendiri semasa di rumah.', 1, 1),
    (@sk_id, 2, 'Menyatakan tanggungjawab terhadap diri sendiri semasa di rumah.', 2, 1),
    (@sk_id, 3, 'Menyatakan keperluan melaksanakan tanggungjawab terhadap diri sendiri semasa di rumah.', 3, 1),
    (@sk_id, 4, 'Menunjuk cara melaksanakan tanggungjawab terhadap diri sendiri semasa di rumah melalui aktiviti.', 4, 1),
    (@sk_id, 5, 'Melakukan tanggungjawab terhadap diri sendiri semasa di rumah.', 5, 1),
    (@sk_id, 6, 'Melakukan tanggungjawab terhadap diri sendiri semasa di rumah dengan perlakuan dan cara yang betul.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 34: SK 4.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @pm_y1
      AND code = '4.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '4.1', 'Mengucapkan terima kasih', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '4.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '4.1.1', 'Menyebut perkataan terima kasih', NULL, 1, 1),
    (@sk_id, '4.1.2', 'Menyatakan kepentingan mengucapkan ucapan terima kasih.', NULL, 2, 1),
    (@sk_id, '4.1.3', 'Mengucapkan terima kasih kepada guru dan rakan mengikut situasi', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Mengucapkan ucapan terima kasih.', 1, 1),
    (@sk_id, 2, 'Mengenalpasti situasi untuk mengucapkan terima kasih.', 2, 1),
    (@sk_id, 3, 'Mengucapkan terima kasih kepada guru dan rakan dengan bimbingan.', 3, 1),
    (@sk_id, 4, 'Mengucapkan terima kasih kepada guru dan rakan.', 4, 1),
    (@sk_id, 5, 'Menunjukkan perlakuan yang betul ketika mengucapkan terima kasih.', 5, 1),
    (@sk_id, 6, 'Membimbing rakan mengucapkan terima kasih dengan perlakuan yang betul.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 35: SK 5.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @pm_y1
      AND code = '5.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '5.1', 'Bersopan dalam tutur kata', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '5.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '5.1.1', 'Mengajuk tutur kata yang sopan', NULL, 1, 1),
    (@sk_id, '5.1.2', 'Menyatakan kelebihan bertutur kata sopan', NULL, 2, 1),
    (@sk_id, '5.1.3', 'Mengucapkan tutur kata yang sopan', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Menyatakan tutur kata yang sopan.', 1, 1),
    (@sk_id, 2, 'Mengenalpasti tutur kata yang sopan.', 2, 1),
    (@sk_id, 3, 'Menyatakan tutur kata yang sopan berdasarkan situasi.', 3, 1),
    (@sk_id, 4, 'Menuturkan tutur kata yang sopan.', 4, 1),
    (@sk_id, 5, 'Mengamalkan adab dalam tutur kata.', 5, 1),
    (@sk_id, 6, 'Membimbing rakan menutur tutur kata yang sopan.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 36: SK 6.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @pm_y1
      AND code = '6.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '6.1', 'Menghormati ahli keluarga', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '6.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '6.1.1', 'Menyatakan cara memuliakan ahli keluarga', NULL, 1, 1),
    (@sk_id, '6.1.2', 'Menyatakan kebaikan saling menghormati dalam keluarga', NULL, 2, 1),
    (@sk_id, '6.1.3', 'Menunjukkan cara memuliakan ahli keluarga', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Menyatakan cara memuliakan ahli keluarga.', 1, 1),
    (@sk_id, 2, 'Mengenalpasti cara memuliakan ahli keluarga.', 2, 1),
    (@sk_id, 3, 'Menunjuk cara memuliakan ahli keluarga.', 3, 1),
    (@sk_id, 4, 'Melaksanakan perlakuan memuliakan ahli keluarga.', 4, 1),
    (@sk_id, 5, 'Mengamalkan sikap menghormati ahli keluarga.', 5, 1),
    (@sk_id, 6, 'Membimbing rakan menghormati ahli keluarga.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 37: SK 7.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @pm_y1
      AND code = '7.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '7.1', 'Menyayangi diri', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '7.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '7.1.1', 'Menyatakan cara menjaga kebersihan diri', NULL, 1, 1),
    (@sk_id, '7.1.2', 'Menyatakan cara menjaga keselamatan diri', NULL, 2, 1),
    (@sk_id, '7.1.3', 'Mengamalkan sikap menjaga kebersihan dan keselamatan diri', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Menyatakan cara menyayangi diri.', 1, 1),
    (@sk_id, 2, 'Mengenalpasti cara menjaga kebersihan dan keselamatan diri.', 2, 1),
    (@sk_id, 3, 'Menunjuk cara menjaga kebersihan dan keselamatan diri.', 3, 1),
    (@sk_id, 4, 'Melakukan aktiviti menjaga kebersihan dan keselamatan diri pada masa dan situasi yang sesuai.', 4, 1),
    (@sk_id, 5, 'Melaksanakan aktiviti menjaga kebersihan dan keselamatan diri dengan tertib.', 5, 1),
    (@sk_id, 6, 'Mengamalkan sikap menjaga kebersihan dan keselamatan diri.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 38: SK 8.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @pm_y1
      AND code = '8.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '8.1', 'Bersikap adil dalam pergaulan seharian di dalam bilik darjah', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '8.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '8.1.1', 'Menyatakan situasi yang menunjukkan perlakuan adil di dalam bilik darjah', NULL, 1, 1),
    (@sk_id, '8.1.2', 'Menyatakan kebaikan bersikap adil dalam bilik darjah', NULL, 2, 1),
    (@sk_id, '8.1.3', 'Menunjukkan perlakuan bersikap adil di dalam bilik darjah', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Menyatakan situasi yang menunjukkan perlakuan adil.', 1, 1),
    (@sk_id, 2, 'Mengenalpasti situasi yang menunjukkan perlakuan adil.', 2, 1),
    (@sk_id, 3, 'Menunjukkan cara perlakuan bersikap adil dalam aktiviti di bilik darjah.', 3, 1),
    (@sk_id, 4, 'Melaksanakan perlakuan bersikap adil di dalam bilik darjah.', 4, 1),
    (@sk_id, 5, 'Melaksanakan perlakuan bersikap adil di dalam bilik darjah dengan beradab.', 5, 1),
    (@sk_id, 6, 'Mengamalkan sikap adil dalam perlakuan di dalam bilik darjah.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 39: SK 9.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @pm_y1
      AND code = '9.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '9.1', 'Bersikap berani semasa di bilik darjah', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '9.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '9.1.1', 'Menyatakan sikap berani berkomunikasi di dalam bilik darjah', NULL, 1, 1),
    (@sk_id, '9.1.2', 'Menyatakan kelebihan bersikap berani di dalam bilik darjah', NULL, 2, 1),
    (@sk_id, '9.1.3', 'Menunjukkan sikap berani berkomukasi di dalam bilik darjah', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Memberi tindakbalas semasa berkomunikasi.', 1, 1),
    (@sk_id, 2, 'Menyatakan perlakuan berani berkomunikasi di dalam bilik darjah.', 2, 1),
    (@sk_id, 3, 'Menunjuk cara perlakuan berani berkomunikasi dengan guru di dalam bilik darjah.', 3, 1),
    (@sk_id, 4, 'Melaksanakan perlakuan berani berkomunikasi di dalam bilik darjah.', 4, 1),
    (@sk_id, 5, 'Melaksanakan sikap berani berkomunikasi di dalam bilik darjah dengan beradab.', 5, 1),
    (@sk_id, 6, 'Mengamalkan perlakuan berani berkomunikasi.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 40: SK 10.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @pm_y1
      AND code = '10.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '10.1', 'Bersikap jujur dalam diri', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '10.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '10.1.1', 'Menyatakan perlakuan jujur', NULL, 1, 1),
    (@sk_id, '10.1.2', 'Menunjukkan perlakuan jujur berpandukan aktiviti', NULL, 2, 1),
    (@sk_id, '10.1.3', 'Mengamalkan sikap jujur dalam pergaulan seharian', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Menamakan perlakuan jujur dalam diri.', 1, 1),
    (@sk_id, 2, 'Mengenalpasti perlakuan jujur berdasarkan aktiviti.', 2, 1),
    (@sk_id, 3, 'Menunjuk cara perlakuan jujur di dalam aktiviti.', 3, 1),
    (@sk_id, 4, 'Melaksanakan perlakuan jujur dalam pergaulan seharian.', 4, 1),
    (@sk_id, 5, 'Mengamalkan sikap jujur dalam pergaulan seharian.', 5, 1),
    (@sk_id, 6, 'Membimbing rakan bersikap jujur.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 41: SK 11.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @pm_y1
      AND code = '11.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '11.1', 'Bersikap rajin dalam bilik darjah', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '11.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '11.1.1', 'Menamakan aktiviti yang menunjukkan sikap rajin di dalam bilik darjah', NULL, 1, 1),
    (@sk_id, '11.1.2', 'Menyatakan kelebihan bersikap rajin di dalam bilik darjah', NULL, 2, 1),
    (@sk_id, '11.1.3', 'Menunjukkan sikap rajin di dalam bilik darjah', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Menamakan aktiviti bersikap rajin.', 1, 1),
    (@sk_id, 2, 'Menyatakan aktiviti bersikap rajin di dalam bilik darjah.', 2, 1),
    (@sk_id, 3, 'Menunjukkan perlakuan bersikap rajin melalui aktiviti.', 3, 1),
    (@sk_id, 4, 'Melaksanakan perlakuan bersikap rajin di dalam bilik darjah.', 4, 1),
    (@sk_id, 5, 'Mengamalkan sikap rajin di dalam bilik darjah.', 5, 1),
    (@sk_id, 6, 'Membimbing rakan bersikap rajin.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 42: SK 12.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @pm_y1
      AND code = '12.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '12.1', 'Bekerjasama dengan rakan sekelas', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '12.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '12.1.1', 'Menyatakan aktiviti yang boleh dilakukan bersama rakan sekelas semasa di sekolah', NULL, 1, 1),
    (@sk_id, '12.1.2', 'Menyatakan perasaan bila dapat bekerjasama dengan rakan sekelas', NULL, 2, 1),
    (@sk_id, '12.1.3', 'Melakukan aktiviti kerjasama dengan rakan sekelas semasa di sekolah', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Menamakan aktiviti yang menunjukkan perlakuan bekerjasama.', 1, 1),
    (@sk_id, 2, 'Menyatakan aktiviti yang menunjukkan perlakuan bekerjasama dengan rakan sekelas semasa di sekolah.', 2, 1),
    (@sk_id, 3, 'Menunjuk cara perlakuan bekerjasama dengan rakan sekelas semasa di sekolah.', 3, 1),
    (@sk_id, 4, 'Melaksanakan perlakuan bekerjasama dengan rakan sekelas semasa di sekolah.', 4, 1),
    (@sk_id, 5, 'Mengamalkan perlakuan bekerjasama dengan rakan sekelas semasa di sekolah.', 5, 1),
    (@sk_id, 6, 'Membimbing rakan bersikap kerjasama.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 43: SK 13.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @pm_y1
      AND code = '13.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '13.1', 'Bersikap sederhana dalam diri', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '13.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '13.1.1', 'Menamakan perlakuan yang menunjukkan sikap sederhana dalam diri', NULL, 1, 1),
    (@sk_id, '13.1.2', 'Menyatakan kelebihan bersikap sederhana dalam diri', NULL, 2, 1),
    (@sk_id, '13.1.3', 'Menunjukkan sikap sederhana dalam diri', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Menamakan perlakuan yang menunjukkan sikap sederhana dalam diri.', 1, 1),
    (@sk_id, 2, 'Menyatakan cara bersikap sederhana dalam diri melalui aktiviti.', 2, 1),
    (@sk_id, 3, 'Menunjuk cara bersikap sederhana dalam diri.', 3, 1),
    (@sk_id, 4, 'Melaksanakan sikap sederhana dalam diri.', 4, 1),
    (@sk_id, 5, 'Mengamalkan sikap sederhana dalam diri.', 5, 1),
    (@sk_id, 6, 'Membimbing rakan bersikap sederhana.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

-- Source PDF page 44: SK 14.1
SET @domain_id := (
    SELECT id
    FROM kss_domains
    WHERE curriculum_subject_id = @pm_y1
      AND code = '14.0'
    LIMIT 1
);
INSERT INTO kss_content_standards
    (domain_id, code, statement, teacher_reference, sort_order, is_active)
VALUES
    (@domain_id, '14.1', 'Bersikap toleransi dengan rakan sekelas', NULL, 1, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    teacher_reference = VALUES(teacher_reference),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
SET @sk_id := (
    SELECT id
    FROM kss_content_standards
    WHERE domain_id = @domain_id
      AND code = '14.1'
    LIMIT 1
);
INSERT INTO kss_learning_standards
    (content_standard_id, code, statement, interpretation, sort_order, is_active)
VALUES
    (@sk_id, '14.1.1', 'Menyatakan perlakuan toleransi di dalam bilik darjah', NULL, 1, 1),
    (@sk_id, '14.1.2', 'Menyatakan kelebihan bertoleransi dengan rakan sekelas', NULL, 2, 1),
    (@sk_id, '14.1.3', 'Menunjukkan sikap toleransi semasa berada di dalam bilik darjah', NULL, 3, 1)
ON DUPLICATE KEY UPDATE
    statement = VALUES(statement),
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);
INSERT INTO kss_performance_standards
    (content_standard_id, tp_level, interpretation, sort_order, is_active)
VALUES
    (@sk_id, 1, 'Menamakan perlakuan toleransi berdasarkan situasi.', 1, 1),
    (@sk_id, 2, 'Menyatakan perlakuan toleransi di dalam bilik darjah.', 2, 1),
    (@sk_id, 3, 'Menunjuk cara perlakuan toleransi dengan rakan di dalam bilik darjah.', 3, 1),
    (@sk_id, 4, 'Melaksanakan sikap toleransi dengan rakan di dalam bilik darjah.', 4, 1),
    (@sk_id, 5, 'Mengamalkan sikap toleransi dengan rakan di dalam bilik darjah.', 5, 1),
    (@sk_id, 6, 'Menjadikan sikap toleransi sebagai contoh kepada rakan.', 6, 1)
ON DUPLICATE KEY UPDATE
    interpretation = VALUES(interpretation),
    sort_order = VALUES(sort_order),
    is_active = VALUES(is_active);

COMMIT;

-- ============================================================
-- Validation queries
-- ============================================================
SELECT
    s.name AS subject,
    cs.year_level,
    COUNT(DISTINCT d.id) AS domains,
    COUNT(DISTINCT sk.id) AS content_standards,
    COUNT(DISTINCT sp.id) AS learning_standards,
    COUNT(DISTINCT ps.id) AS performance_standard_rows
FROM kss_curriculum_subjects cs
INNER JOIN kss_subjects s ON s.id = cs.subject_id
LEFT JOIN kss_domains d ON d.curriculum_subject_id = cs.id
LEFT JOIN kss_content_standards sk ON sk.domain_id = d.id
LEFT JOIN kss_learning_standards sp ON sp.content_standard_id = sk.id
LEFT JOIN kss_performance_standards ps ON ps.content_standard_id = sk.id
WHERE cs.curriculum_version_id = @cv_id
  AND cs.year_level = 1
GROUP BY s.name, cs.year_level
ORDER BY s.name;