# Generic P1 evidence transfer plan

GitHub Actions artifact retention is transport/storage only.

After a qualifying controlled run, download the generic source-evidence artifact and preserve at minimum:

1. artifact digest reported by the upload action;
2. public repository identity, expected reviewed harness SHA and actual harness commit SHA;
3. workflow/ref, Run ID and Run Attempt;
4. acquisition UTC and actor;
5. pinned action dependency register and action runtimes;
6. runner image identity, installed toolsets, Python version and Python executable;
7. exact NASA source commits and source-archive SHA-256 values;
8. pre/post tracked-source cleanliness records;
9. dependency/Cantera assessment;
10. MATLAB/Simulink/compiler identity and build log;
11. timeout/watchdog record;
12. complete generic reference-grid execution summary;
13. raw MAT outputs for every attempted point;
14. derivative schema-inventory outputs;
15. exact reviewed semantic mapping contract and mapping SHA-256;
16. per-point semantic-deck candidate outputs and semantic execution summaries;
17. machine-readable current-run warning review;
18. evidence SHA-256 manifest;
19. CI transport record.

The receiving controlled environment should calculate its own package SHA-256 and retain the imported artifact independently of CI retention.

The public artifact is generic NASA-source evidence only. Any downstream engineering authority is established separately after controlled ingestion and applicability assessment.
