# Controlled modern C MEX compiler selection basis

For the P1-COMPAT candidate, the expected compiler family is **Microsoft Visual C++ 2022 / Visual Studio 2022 Build Tools** on the `windows-2022` runner.

Policy:

- MATLAB R2023b supports Visual Studio 2022 Build Tools for C/C++ MEX builds.
- The workflow records the actual Visual Studio instances and MSVC toolset paths exposed by the runner.
- MATLAB enumerates installed supported compiler configurations with `mex.getCompilerConfigurations('C','Installed')`.
- Deterministic qualification requires **exactly one installed configuration whose `Language` is `C`**.
- That sole C configuration must match the Microsoft Visual C++ 2022 family.
- The harness then uses the documented `mex -setup C` selection path and verifies the selected Name, Manufacturer, Language, Version, Location and MexOpt against the preselected candidate.
- Multiple C configurations, an unexpected compiler family, or post-selection identity mismatch cause `COMPILER_SELECTION_FAIL`.
- No SDK emulation, compiler configuration-file editing, or NASA source modification is permitted.

This is a modern-toolchain compatibility run, not a historical runtime reproduction.
