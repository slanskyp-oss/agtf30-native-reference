# Repository scope and information firewall

This public repository is a generic NASA propulsion-source reference harness. It is intentionally isolated from downstream private engineering data and repositories.

## Allowed public scope

Only generic source-reference tooling, public NASA source identities, generic in-envelope source conditions, CI/provenance tooling, generic raw native outputs, derivative schema-discovery data, and integrity manifests are in scope.

## Information flow

Required direction:

**public NASA source → public generic native evidence → offline/private downstream assessment**

The reverse direction is prohibited. The public workflow shall not receive downstream private design, requirement, mission, installation, audit, registry or decision data.

## Access boundary

No cross-repository checkout or private-project secret is required or permitted for the controlled workflow. The public runner operates only on this harness plus the exact public NASA source checkouts declared by the harness.

## Authority boundary

Artifacts produced here are generic NASA-source evidence only. They do not establish authority for a downstream vehicle, installation, selected production engine, mission or requirement until separately ingested and assessed in the applicable private controlled environment.

## MATLAB action execution

The authoritative native acquisition executes through the pinned MathWorks Run MATLAB Command action in a public GitHub-hosted workflow. Direct shell launch of MATLAB is not an authoritative controlled path.
