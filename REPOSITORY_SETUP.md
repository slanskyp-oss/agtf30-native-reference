# Public repository setup

Recommended repository name: `agtf30-native-reference` (or another neutral equivalent).

Recommended description: `Generic NASA AGTF30/T-MATS native source-reference CI harness.`

Required visibility for the intended licensing path: **public**.

The first public commit should contain only this reviewed allowlisted tree. Record its full 40-hex Git commit SHA. The controlled acquisition workflow must then be launched manually with `workflow_dispatch`, `AUTHORIZE_CONTROLLED_P1`, and the exact same reviewed SHA as `expected_harness_sha`.

Do not treat push/pull-request smoke output as controlled source evidence.

The repository requires no checkout, secret, token, path, or access to downstream private engineering repositories.

## Public commit identity

Repository/project anonymity and personal anonymity are separate. If personal identity should not be linked to public history, use a neutral account or organization and a non-identifying public commit author/email before creating the first public commit.

The authoritative native acquisition must remain the pinned `matlab-actions/run-command` step in the reviewed controlled workflow. Do not replace it with a direct `matlab.exe` shell launch without reopening the licensing/tooling review.
