// HTTP plumbing for the functions in index.ts. It has no Firebase state, so
// tests can load it without initializing the Admin SDK.

interface CorsRequest {
  method: string;
  headers: Record<string, string | string[] | undefined>;
}

interface CorsResponse {
  set(field: string, value: string): unknown;
  vary(field: string): unknown;
  status(code: number): { end(): unknown };
}

// Browsers may reuse a preflight this long (Chrome caps it at 2 hours).
const PREFLIGHT_MAX_AGE_SECONDS = 3600;

// The policy of firebase-functions' `cors: true` (any origin: the Firebase ID
// token, not the origin, authorizes a request), plus Access-Control-Max-Age,
// which `cors: true` cannot set, so the app doesn't send a preflight before
// every chat message. Answers a preflight and returns true; otherwise adds the
// CORS headers and returns false.
export function applyCors(req: CorsRequest, res: CorsResponse): boolean {
  const origin = req.headers.origin;
  res.set('Access-Control-Allow-Origin', typeof origin === 'string' && origin ? origin : '*');
  res.vary('Origin');
  if (req.method !== 'OPTIONS') return false;
  const requested = req.headers['access-control-request-headers'];
  res.set('Access-Control-Allow-Methods', 'POST');
  res.set('Access-Control-Allow-Headers',
    typeof requested === 'string' && requested ? requested : 'authorization, content-type');
  res.vary('Access-Control-Request-Headers');
  res.set('Access-Control-Max-Age', String(PREFLIGHT_MAX_AGE_SECONDS));
  res.status(204).end();
  return true;
}

export const MAX_RECEIPT_BYTES = 5 * 1024 * 1024;
const MAX_RECEIPT_BASE64_LENGTH = Math.ceil(MAX_RECEIPT_BYTES / 3) * 4;
const BASE64 = /^[A-Za-z0-9+/]+={0,2}$/;

// The receipt image, or null when it is missing, malformed, or larger than
// MAX_RECEIPT_BYTES. The app sends `imageBase64`; apps released before it send
// `imageBytes` as a JSON array of 0–255 integers, accepted for one release.
export function receiptImage(data: unknown): Uint8Array | number[] | null {
  if (!data || typeof data !== 'object') return null;
  const {imageBase64, imageBytes} = data as Record<string, unknown>;
  if (typeof imageBase64 === 'string') {
    if (imageBase64.length > MAX_RECEIPT_BASE64_LENGTH || imageBase64.length % 4 !== 0 ||
        !BASE64.test(imageBase64)) return null;
    const bytes = Buffer.from(imageBase64, 'base64');
    return bytes.length > 0 && bytes.length <= MAX_RECEIPT_BYTES ? bytes : null;
  }
  if (Array.isArray(imageBytes) && imageBytes.length > 0 && imageBytes.length <= MAX_RECEIPT_BYTES &&
      imageBytes.every(b => Number.isInteger(b) && b >= 0 && b <= 255)) return imageBytes;
  return null;
}

// The OCR provider request, unchanged: {"fileName":…,"imageBytes":[0–255,…]}.
// Written as text so a multi-megabyte image never becomes an array of numbers.
export function ocrProviderBody(fileName: string, bytes: Uint8Array | number[]): string {
  return `{"fileName":${JSON.stringify(fileName)},"imageBytes":[${bytes.join(',')}]}`;
}
