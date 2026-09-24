# KSS V3 — Bahasa Melayu Tahun 1 Mapping Review

Status: draft for business review. This is not a seed script and no V3
curriculum data has been inserted from it.

## Sources checked

- DSKP Asas 3M Tahun 1, pages 25–35 (PDF pages 35–45).
- Current legacy BM master data in `kss_domains`, `kss_content_standards`,
  `kss_learning_standards`, and `kss_performance_standards`.
- Supplied KSS V3 business rule: a parent assessment group receives TP while
  its smaller groups receive observations.

## Proposed V3 tree

For the pilot, the DSKP component headings become V3 `TP_GROUP` nodes. Their
existing SK become `OBSERVATION_GROUP` nodes and SP become `CRITERION` nodes.
This follows the agreed V3 rule and does not infer role from the number of dots.

| DSKP page | Code | Title | V3 role | Parent |
|---|---|---|---|---|
| 25–26 | 1.0 | Kemahiran Mendengar | `TP_GROUP` | — |
| 25 | 1.1 | Mendengar, mengajuk dan mengecam pelbagai bunyi | `OBSERVATION_GROUP` | 1.0 |
| 25 | 1.1.1 | Mendengar, mengajuk dan mengecam pelbagai bunyi | `CRITERION` | 1.1 |
| 25 | 1.1.2 | Mendengar dan mengecam arah bunyi | `CRITERION` | 1.1 |
| 25 | 1.1.3 | Mendengar, mengecam dan membezakan bunyi | `CRITERION` | 1.1 |
| 26 | 1.2 | Mendengar dan melafazkan ucapan bertatasusila | `OBSERVATION_GROUP` | 1.0 |
| 26 | 1.2.1 | Mendengar dan melafazkan ucapan bertatasusila | `CRITERION` | 1.2 |
| 27 | 2.0 | Kemahiran Bertutur | `TP_GROUP` | — |
| 27 | 2.1 | Menama dan menggunakan alat pertuturan | `OBSERVATION_GROUP` | 2.0 |
| 27 | 2.1.1 | Mengenal alat pertuturan | `CRITERION` | 2.1 |
| 27 | 2.1.2 | Menggunakan alat pertuturan dalam aktiviti | `CRITERION` | 2.1 |
| 28 | 2.2 | Mengajuk, mengecam dan menamakan pelbagai bunyi | `OBSERVATION_GROUP` | 2.0 |
| 28 | 2.2.1 | Mengenal, mengajuk, mengecam dan menamakan pelbagai bunyi | `CRITERION` | 2.2 |
| 29 | 2.3 | Melafazkan ucapan bertatasusila | `OBSERVATION_GROUP` | 2.0 |
| 29 | 2.3.1 | Mengajuk ucapan bertatasusila | `CRITERION` | 2.3 |
| 29 | 2.3.2 | Melafazkan ucapan bertatasusila | `CRITERION` | 2.3 |
| 31 | 3.0 | Kemahiran Membaca | `TP_GROUP` | — |
| 31 | 3.1 | Mengecam dan menamakan objek | `OBSERVATION_GROUP` | 3.0 |
| 31 | 3.1.1 | Mengecam objek | `CRITERION` | 3.1 |
| 31 | 3.1.2 | Menamakan objek | `CRITERION` | 3.1 |
| 32 | 3.2 | Mengenal huruf | `OBSERVATION_GROUP` | 3.0 |
| 32 | 3.2.1 | Menyebut dan menamakan abjad | `CRITERION` | 3.2 |
| 32 | 3.2.2 | Membunyikan huruf vokal | `CRITERION` | 3.2 |
| 33 | 4.0 | Kemahiran Menulis | `TP_GROUP` | — |
| 33 | 4.1 | Menulis dengan kedudukan yang sesuai | `OBSERVATION_GROUP` | 4.0 |
| 33 | 4.1.1 | Menggerakkan tangan, pergelangan tangan dan jari-jari secara bebas | `CRITERION` | 4.1 |
| 33 | 4.1.2 | Menggerakkan tangan secara terkawal | `CRITERION` | 4.1 |
| 33 | 4.1.3 | Menulis dengan kedudukan yang sesuai (postur badan) | `CRITERION` | 4.1 |
| 34 | 4.2 | Menulis secara mekanis | `OBSERVATION_GROUP` | 4.0 |
| 34 | 4.2.1 | Menulis huruf kecil dengan cara yang betul | `CRITERION` | 4.2 |
| 34 | 4.2.2 | Menulis huruf besar dengan cara yang betul | `CRITERION` | 4.2 |
| 35 | 5.0 | Kemahiran Komunikasi | `TP_GROUP` | — |
| 35 | 5.1 | Memerihalkan mengenai diri sendiri | `OBSERVATION_GROUP` | 5.0 |
| 35 | 5.1.1 | Bersoal jawab mengenai diri sendiri | `CRITERION` | 5.1 |

## Required decision: TP descriptors at V3 parent level

The DSKP prints one TP1–TP6 descriptor set alongside each existing SK (for
example, 1.1 and 1.2), while this V3 proposal puts one TP on parent 1.0. The
existing SK-level descriptor rows cannot be copied into a parent TP group
without changing their meaning.

Before seed, choose and record one of these approved sources for the TP1–TP6
descriptors of each V3 TP group:

1. An approved KSS/PBD parent-group descriptor set; or
2. A teacher-authored parent-group rubric reviewed and approved by KSS; or
3. Change the proposed assessment level for that component after reviewing the
   real KSS assessment/report workflow.

Until that decision is made, the node hierarchy can be seeded but
`kss_v3_tp_descriptors` must remain empty. The UI must not allow TP
finalisation without a complete parent-level descriptor set.

## Pilot acceptance criteria

For one BM student and TP group 1.0:

1. The teacher sees two observation groups: 1.1 and 1.2.
2. Each observation group has one observation field.
3. Its SP rows are visible as criteria/reference only.
4. TP finalisation is locked until both observations are saved and non-empty.
5. Finalisation stores exactly one TP result for 1.0 after parent-level TP
   descriptors are approved.
