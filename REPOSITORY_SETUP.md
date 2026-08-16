# Public repository setup

Recommended repository name: `agtf30-native-reference` (or another neutral equivalent).

Recommended description: `Generic NASA AGTF30/T-MATS native source-reference CI harness.`

Required visibility for the intended licensing path: **public**.

The initial public root commit is an immutable audit record and must not be rewritten. Any remediation must be added as a normal descendant commit. The controlled acquisition workflow may be launched only from the exact public harness commit that has completed the required review and non-controlled smoke successfully. Record that full 40-hex Git commit SHA and launch `workflow_dispatch` with `AUTHORIZE_CONTROLLED_P1` and the same SHA as `expected_harness_sha`.

Do not treat push/pull-request smoke output as controlled source evidence.

The repository requires no checkout, secret, token, path, or access to downstream private engineering repositories.

## Public commit identity

Repository/project anonymity and personal anonymity are separate. If personal identity should not be linked to public history, use a neutral account or organization and a non-identifying public commit author/email before creating the first public commit.

The authoritative native acquisition must remain the pinned `matlab-actions/run-command` step in the reviewed controlled workflow. Do not replace it with a direct `matlab.exe` shell launch without reopening the licensing/tooling review.
