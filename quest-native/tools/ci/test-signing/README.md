# TEST-ONLY signing key

`dahrooj-test.keystore` (alias `dahrooj-test`, password `dahrooj-test-only`) is public on
purpose: it lets successive sideload test builds install over each other. It is never used
for the Meta Horizon Store; store builds use the private key from repository secrets
(DAHROOJ_KEYSTORE_B64 / _ALIAS / _PASSWORD).
