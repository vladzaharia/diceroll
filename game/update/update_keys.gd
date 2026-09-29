extends RefCounted
## Public key that signs the update manifests (update-<channel>.json.sig).
## RSA (3072-bit), PKCS#1 v1.5 over SHA-256, PEM "BEGIN PUBLIC KEY" (SubjectPublicKeyInfo),
## i.e. the output of `openssl rsa -in update_signing.pem -pubout`.
##
## PLACEHOLDER: replaced by the CI/release engineer with the real release key. While empty,
## every manifest fails verification, so no update is ever offered or applied (fail closed).
## Tests never use this constant: they pass tests/fixtures/update/test_signing.pub.pem.

const PUBLIC_KEY_PEM := ""
