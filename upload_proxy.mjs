import fs from 'fs';
import { fileURLToPath } from 'url';

const CHUNK_SIZE = 50 * 1024 * 1024; // 50MB chunks
const FILE_PATH = './tiles.db';
const KEY = 'tiles.db';
// The worker URL will be replaced later
const WORKER_URL = 'https://r2-proxy.imwr35.workers.dev'; 

async function uploadFile() {
  const stats = fs.statSync(FILE_PATH);
  const fileSize = stats.size;
  
  console.log(`Starting upload for ${KEY} (${(fileSize / 1024 / 1024).toFixed(2)} MB)`);

  // 1. Create Multipart Upload
  const createRes = await fetch(`${WORKER_URL}/${KEY}?uploads=true`, { method: 'POST' });
  if (!createRes.ok) throw new Error(`Create failed: ${await createRes.text()}`);
  const { uploadId } = await createRes.json();
  console.log(`Created upload: ${uploadId}`);

  const fd = fs.openSync(FILE_PATH, 'r');
  const uploadedParts = [];
  let offset = 0;
  let partNumber = 1;

  while (offset < fileSize) {
    const end = Math.min(offset + CHUNK_SIZE, fileSize);
    const size = end - offset;
    const buffer = Buffer.alloc(size);
    fs.readSync(fd, buffer, 0, size, offset);

    console.log(`Uploading part ${partNumber} (${(size / 1024 / 1024).toFixed(2)} MB)...`);
    const partRes = await fetch(`${WORKER_URL}/${KEY}?partNumber=${partNumber}&uploadId=${uploadId}`, {
      method: 'PUT',
      body: buffer
    });

    if (!partRes.ok) {
      console.error(`Failed part ${partNumber}:`, await partRes.text());
      throw new Error(`Part ${partNumber} failed`);
    }

    const { etag } = await partRes.json();
    uploadedParts.push({ partNumber, etag });
    console.log(`Uploaded part ${partNumber}. ETag: ${etag}. Progress: ${((end / fileSize) * 100).toFixed(2)}%`);

    offset += size;
    partNumber++;
  }
  fs.closeSync(fd);

  // 3. Complete Upload
  console.log('Completing upload...');
  const completeRes = await fetch(`${WORKER_URL}/${KEY}?uploadId=${uploadId}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ parts: uploadedParts })
  });

  if (!completeRes.ok) throw new Error(`Complete failed: ${await completeRes.text()}`);
  console.log('Upload complete successfully!');
}

uploadFile().catch(console.error);
