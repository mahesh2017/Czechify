import { CompactSign, importJWK, type JWK } from "npm:jose@6.2.12";

/** Fixed EdDSA/Ed25519 and key ID. No client-provided signing options. */
export async function createSnapshotSigner(jwk: JWK, keyId: string) {
  if (
    jwk.kty !== "OKP" || jwk.crv !== "Ed25519" || !jwk.d ||
    !/^[a-zA-Z0-9_-]{1,64}$/.test(keyId)
  ) {
    throw new Error("Invalid snapshot signing configuration");
  }
  const key = await importJWK(jwk, "EdDSA");
  return (payload: Record<string, unknown>) =>
    new CompactSign(
      new TextEncoder().encode(JSON.stringify(payload)),
    ).setProtectedHeader({
      alg: "EdDSA",
      kid: keyId,
      typ: "czechify-entitlements+jws",
    }).sign(key);
}
