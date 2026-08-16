# Source dependency / Cantera preflight basis

The public harness does not add the T-MATS `Cantera_Enabled` MATLAB path by default.

Before every controlled build, `scripts/source_dependency_preflight.ps1` scans the actual detached exact AGTF30 checkout for:

- T-MATS reference/library strings used by AGTF30;
- `Cantera`, `TMATSC`, or `Cantera_Enabled` markers.

It writes `source_dependency_assessment.json` and `source_dependency_assessment.md` into the evidence tree. If the execution path requires Cantera, preflight fails and build is prohibited until the dependency is separately reviewed and provisioned. No alternate Cantera version is installed silently.
