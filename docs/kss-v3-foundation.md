# KSS Assessment V3 — Foundation Contract

Status: proposed for implementation. This document is the contract for the V3
vertical slice. It intentionally does not alter the legacy KSS tables or
endpoints.

## Scope and source material

V3 replaces the assessment-level semantics only. It reuses the existing
GrowCheck login, staff and student identities, API configuration, navigation,
theme, PDF/printing support and useful overall-TP professional-judgement UI.

Curriculum must be mapped from the supplied DSKP documents, not inferred from
the code format. The supplied PBD template is the reporting-layout reference.
The supplied student PTM report is a presentation/reference document, not a
curriculum source.

## Non-negotiable rules

1. A curriculum node has an explicit `node_role`: `CONTAINER`, `TP_GROUP`,
   `OBSERVATION_GROUP`, or `CRITERION`.
2. A `TP_GROUP` receives one TP1–TP6 professional judgement for each student
   and assessment cycle.
3. An `OBSERVATION_GROUP` receives one teacher observation. Its criteria are
   reference only.
4. A `CRITERION` never receives its own observation textbox or TP.
5. A TP is locked until every required observation group beneath that TP group
   has a non-empty saved observation.
6. A real class owns its students. A subject and its teacher assignment do not
   define a class.
7. A result belongs to student + class + subject + academic year + semester.
   The teacher is the assessor, not the owner of a result.
8. Semester 2 supersedes Semester 1 for the annual current result; they are
   never averaged. Semester 1 remains history.
9. Reassessment creates a new assessment cycle. Published reports retain a
   snapshot and never change retrospectively.
10. Legacy KSS data is never transformed into parent-level TP automatically.

## V3 table groups

All V3 tables use a `kss_v3_` prefix while the legacy module remains live. This
keeps rollout and rollback independent of the existing `kss_*` schema.

### Setup

| Table | Responsibility | Essential fields |
|---|---|---|
| `kss_v3_academic_years` | Academic-year lifecycle | `id`, `year`, `status` |
| `kss_v3_classes` | A real school class | `id`, `class_name`, `year_level`, `academic_year_id`, `homeroom_teacher_id`, `status` |
| `kss_v3_class_students` | Class membership | `class_id`, `student_id`, `status`, `joined_at`, `removed_at` |
| `kss_v3_subjects` | Canonical subjects | `id`, `code`, `name`, `is_active` |
| `kss_v3_class_subjects` | Subjects enabled for one class | `id`, `class_id`, `subject_id`, `academic_year_id`, `is_required`, `is_active` |
| `kss_v3_teacher_assignments` | Who may assess a class subject | `id`, `class_subject_id`, `teacher_id`, `assigned_at`, `ended_at`, `is_active` |
| `kss_v3_semesters` | Semester authority/lifecycle | `id`, `academic_year_id`, `code`, `status`, `starts_at`, `ends_at` |

Uniqueness: class name/year/year-level; active student membership per class;
one class subject per class/subject/year; and one active teacher assignment per
class subject unless co-teaching is explicitly introduced later.

### Curriculum

| Table | Responsibility | Essential fields |
|---|---|---|
| `kss_v3_curriculum_subjects` | DSKP version for subject/year | `id`, `subject_id`, `year_level`, `curriculum_code`, `display_name`, `is_active` |
| `kss_v3_curriculum_nodes` | Explicit semantic curriculum tree | `id`, `curriculum_subject_id`, `parent_id`, `code`, `title`, `node_role`, `sort_order`, `is_required`, `teacher_reference`, `is_active` |
| `kss_v3_tp_descriptors` | TP1–TP6 guidance | `id`, `tp_group_id`, `tp_level`, `description`, `sort_order` |

`parent_id` refers to another `kss_v3_curriculum_nodes.id`. Constraints must
ensure that a TP descriptor belongs only to a `TP_GROUP` node.

### Assessment and subject result

| Table | Responsibility | Essential fields |
|---|---|---|
| `kss_v3_assessment_cycles` | Immutable assessment/revision context | `id`, `class_subject_id`, `semester_id`, `student_id`, `cycle_no`, `cycle_type`, `status`, `supersedes_cycle_id`, `started_by_teacher_id`, `started_at`, `completed_at` |
| `kss_v3_observations` | One saved observation per observation group | `id`, `assessment_cycle_id`, `observation_group_id`, `observation_text`, `observed_by_teacher_id`, `observed_at` |
| `kss_v3_tp_group_results` | One TP result per TP group | `id`, `assessment_cycle_id`, `tp_group_id`, `tp_level`, `tp_descriptor_snapshot`, `teacher_summary`, `status`, `finalized_by_teacher_id`, `finalized_at` |
| `kss_v3_subject_results` | Subject-level mode/judgement result | `id`, `assessment_cycle_id`, `recommended_tp`, `final_tp`, `calculation_method`, `has_mode_tie`, `tie_candidates_json`, `professional_judgement_note`, `status`, `confirmed_by_teacher_id`, `confirmed_at` |
| `kss_v3_subject_result_items` | Result snapshot per TP group | `id`, `subject_result_id`, `tp_group_result_id`, `tp_group_code_snapshot`, `tp_group_title_snapshot`, `tp_level`, `teacher_summary_snapshot` |

Uniqueness: one observation per `assessment_cycle_id + observation_group_id`;
one TP result per `assessment_cycle_id + tp_group_id`; one subject result per
assessment cycle.

### Reporting

| Table | Responsibility | Essential fields |
|---|---|---|
| `kss_v3_subject_reports` | Official one-subject report snapshot | `id`, `subject_result_id`, `status`, `published_by_teacher_id`, `published_at` |
| `kss_v3_subject_report_items` | TP group snapshot in subject report | `report_id`, `tp_group_code_snapshot`, `tp_group_title_snapshot`, `tp_level`, `teacher_summary_snapshot` |
| `kss_v3_student_reports` | Official all-required-subject report | `id`, `class_id`, `student_id`, `semester_id`, `status`, `published_by_teacher_id`, `published_at` |
| `kss_v3_student_report_subjects` | Subject report snapshot in full report | `student_report_id`, `subject_report_id`, `subject_code_snapshot`, `subject_name_snapshot`, `overall_tp_snapshot` |

The report tables must store display snapshots, not only foreign keys to live
assessment data.

## Statuses

| Area | Allowed status |
|---|---|
| TP group progress | `NOT_STARTED`, `OBSERVING`, `READY_FOR_TP`, `COMPLETED` |
| Subject result | `NOT_STARTED`, `IN_PROGRESS`, `JUDGEMENT_REQUIRED`, `COMPLETED`, `PUBLISHED` |
| Semester | `UPCOMING`, `ACTIVE`, `SUPERSEDED`, `CLOSED` |
| Assessment cycle | `IN_PROGRESS`, `COMPLETED`, `SUPERSEDED`, `CANCELLED` |
| Report | `DRAFT`, `READY`, `PUBLISHED` |

`VOID` is reserved for an actually invalid record, never normal Sem 1 to Sem 2
progression.

## V3 API contract for the pilot

All calls use the existing Flutter API base URL and the existing POST form-body
convention unless an endpoint needs a larger JSON document. Endpoint names are
isolated with `kss_v3_`.

| Endpoint | Purpose |
|---|---|
| `kss_v3_my_teaching.php` | Active class-subject assignments for logged-in teacher, plus progress counts |
| `kss_v3_create_class.php` | Create a real class without choosing a subject |
| `kss_v3_class_detail.php` | Class, students, subjects, assignments and report readiness |
| `kss_v3_class_students.php` | List/add/remove class membership |
| `kss_v3_class_subjects.php` | Enable/disable required subjects and assign teachers |
| `kss_v3_class_subject_students.php` | Teacher-safe student list for one assignment and semester |
| `kss_v3_student_subject_assessment.php` | TP group progress for one student/subject/semester |
| `kss_v3_tp_group.php` | TP group, observation groups, criteria, saved drafts and descriptors |
| `kss_v3_save_observation.php` | Idempotent autosave of one observation group draft |
| `kss_v3_finalize_tp_group.php` | Validate observations, save TP and summary, then complete the group |
| `kss_v3_subject_overall_tp.php` | Calculate mode/tie or confirm allowed professional judgement |
| `kss_v3_subject_report.php` | Subject report data or publication snapshot |
| `kss_v3_student_report_readiness.php` | Required-subject completion for class teacher/coordinator |

Every endpoint must validate the authenticated/requesting staff member against
an active teacher assignment or homeroom/coordinator permission. The server,
not Flutter, enforces TP readiness and reporting authority.

## Pilot curriculum mapping format — Asas 3M / Bahasa Melayu Tahun 1

No production curriculum row is seeded until its source section is mapped and
reviewed. Use this CSV/worksheet shape for every DSKP node:

| source page | curriculum code | source text | parent code | node role | required | teacher reference |
|---|---|---|---|---|---|---|
| DSKP page | exact code | exact curriculum statement | parent code or blank | `CONTAINER` / `TP_GROUP` / `OBSERVATION_GROUP` / `CRITERION` | yes/no | optional implementation guidance |

The initial report grouping from the supplied PBD template is:

| Subject | Report section | Mapping decision required |
|---|---|---|
| Bahasa Melayu / Asas 3M | Mendengar dan Bertutur | Confirm DSKP TP groups and observation groups |
| Bahasa Melayu / Asas 3M | Membaca | Confirm DSKP TP groups and observation groups |
| Bahasa Melayu / Asas 3M | Menulis | Confirm DSKP TP groups and observation groups |
| Bahasa Melayu / Asas 3M | Keseluruhan | Subject-level mode/professional judgement, never a direct criterion assessment |

The page number and source text must be retained in the seed review sheet for
audit. Node role is decided by the intended PBD assessment action, not the
number of dots in the curriculum code.

## Delivery sequence

1. Review this foundation contract.
2. Inspect real database usage and choose legacy archive versus parallel V3
   rollout; do not migrate TP values.
3. Convert approved schema into a reversible SQL migration.
4. Complete and review the BM Year 1 mapping sheet.
5. Seed BM and build the backend vertical slice.
6. Build the corresponding Flutter V3 pages and test all non-negotiable rules.
7. Add Matematik, then Sains, then the remaining subjects.
8. Add cross-subject coordinator flow and full student reports after the
   single-subject vertical slice is stable.
