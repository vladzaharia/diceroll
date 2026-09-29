extends RefCounted
## Public key that signs the update manifests (update-<channel>.json.sig).
## RSA (3072-bit), PKCS#1 v1.5 over SHA-256, PEM "BEGIN PUBLIC KEY" (SubjectPublicKeyInfo),
## i.e. the output of `openssl rsa -in update_signing.pem -pubout`.
##
## The private half is the UPDATE_SIGNING_KEY secret (docs/RELEASE.md). An empty key fails
## closed: every manifest fails verification, so no update is ever offered or applied.
## Tests never use this constant: they pass tests/fixtures/update/test_signing.pub.pem.

const PUBLIC_KEY_PEM := """-----BEGIN PUBLIC KEY-----
MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAkM9TDbB0LsCc8OVEjYjm
o6MIQSOQ4J7Q1s6FAcLyZvNfQ5IejHGMdnGtOSwyNAw1e5YNxbNeN06MX+7kUt6x
ldYe2ebh58Wk20RGoASHiY8UHJnzTId0otXYYXc/5gwJuxDvSfaMYpMT7vI3rwzA
j3fMmYnsCEWT9Z8c+O+Cof/zDvrkuxmTd0k88m6eRsoi5dYgsHbWr9eCi4Cu0w4r
B+6qSpQux6Ie1At43oT1tH03bDuBxFPPnJSa/ap2jNdrw2Z8MhbBg6BEhzm38c8f
VZnVPfMtjSQWwUKPRXlJSKcMU1XGap71UPGe1ID5Bf1t7B4MP/CAtCNRM9BTaiza
AmfHfVpPLKkP+FokBbno2hkZDeUxW+Oxr10B3yEoWj2rYncFVHD0sSwGrnFoya0l
D+uW3wFZEfxX+t6z6Ihk0i7KU6sDAQhHFuPoSp/jG7v112JsJTVB6sgqyOAO5VW1
Ydd2nu7VJFwYkXrMMpPl2N9l0NuTd5ebFPXcn7eNnc11AgMBAAE=
-----END PUBLIC KEY-----
"""
