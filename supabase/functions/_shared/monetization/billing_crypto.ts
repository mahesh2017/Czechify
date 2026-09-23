// Purchase-token handling. Tokens are looked up by SHA-256 digest and stored
// only encrypted (AES-256-GCM); the key never leaves the billing functions.

const encoder = new TextEncoder();

function base64UrlEncode(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replaceAll("+", "-")
    .replaceAll("/", "_").replace(/=+$/, "");
}

function base64Decode(value: string): Uint8Array<ArrayBuffer> {
  const normal = value.replaceAll("-", "+").replaceAll("_", "/");
  const binary = atob(normal + "=".repeat((4 - normal.length % 4) % 4));
  const bytes = new Uint8Array(new ArrayBuffer(binary.length));
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", encoder.encode(value));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

async function importKey(
  raw: string,
  algorithm: AesKeyAlgorithm | HmacImportParams,
  usages: KeyUsage[],
): Promise<CryptoKey> {
  const bytes = base64Decode(raw);
  if (bytes.length !== 32) throw new Error("Key must be 32 bytes");
  return await crypto.subtle.importKey("raw", bytes, algorithm, false, usages);
}

export interface TokenCipher {
  encrypt(token: string): Promise<string>;
  decrypt(sealed: string): Promise<string>;
}

/** `v1.<iv>.<ciphertext>`, base64url. A new random IV per token. */
export async function createTokenCipher(rawKey: string): Promise<TokenCipher> {
  const key = await importKey(rawKey, { name: "AES-GCM", length: 256 }, [
    "encrypt",
    "decrypt",
  ]);
  return {
    async encrypt(token) {
      const iv = crypto.getRandomValues(new Uint8Array(12));
      const sealed = await crypto.subtle.encrypt(
        { name: "AES-GCM", iv },
        key,
        encoder.encode(token),
      );
      return `v1.${base64UrlEncode(iv)}.${
        base64UrlEncode(new Uint8Array(sealed))
      }`;
    },
    async decrypt(sealed) {
      const [version, iv, body] = sealed.split(".");
      if (version !== "v1" || !iv || !body) {
        throw new Error("Unknown token format");
      }
      const plain = await crypto.subtle.decrypt(
        { name: "AES-GCM", iv: base64Decode(iv) },
        key,
        base64Decode(body),
      );
      return new TextDecoder().decode(plain);
    },
  };
}

/**
 * Stable opaque Play account reference: HMAC-SHA256 of the user ID, 43
 * base64url characters (Play allows 64). Never the raw ID or an email.
 */
export async function deriveObfuscatedAccountId(
  rawKey: string,
  userId: string,
): Promise<string> {
  const key = await importKey(rawKey, { name: "HMAC", hash: "SHA-256" }, [
    "sign",
  ]);
  const mac = await crypto.subtle.sign("HMAC", key, encoder.encode(userId));
  return base64UrlEncode(new Uint8Array(mac));
}
