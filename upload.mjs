import { S3Client } from "@aws-sdk/client-s3";
import { Upload } from "@aws-sdk/lib-storage";
import fs from "fs";

const ACCOUNT_ID = "a31609200a5a21de9275ad815e47548b";
const ACCESS_KEY_ID = "44470eb9c76bd31af844a1928181cc15";
const SECRET_ACCESS_KEY = "97c4677ce8669568ae35168d3fd254f3a79246643df2f53ceeb97e985eb29961";

const client = new S3Client({
  region: "auto",
  endpoint: `https://${ACCOUNT_ID}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: ACCESS_KEY_ID,
    secretAccessKey: SECRET_ACCESS_KEY,
  },
});

const filePath = "./tiles.db";
const fileStream = fs.createReadStream(filePath);
const fileSize = fs.statSync(filePath).size;

const upload = new Upload({
  client,
  params: {
    Bucket: "earth-tiles",
    Key: "tiles.db",
    Body: fileStream,
  },
  queueSize: 4, // 4 concurrent uploads
  partSize: 1024 * 1024 * 100, // 100 MB chunks for 2.2GB file
  leavePartsOnError: false,
});

let lastTime = Date.now();
upload.on("httpUploadProgress", (progress) => {
  const now = Date.now();
  const total = progress.total || fileSize;
  if (now - lastTime > 2000) {
      console.log(`Uploaded ${(progress.loaded / 1024 / 1024).toFixed(2)} MB of ${(total / 1024 / 1024).toFixed(2)} MB (${((progress.loaded / total) * 100).toFixed(2)}%)`);
      lastTime = now;
  }
});

upload.done()
  .then(() => {
    console.log(`Uploaded ${(fileSize / 1024 / 1024).toFixed(2)} MB of ${(fileSize / 1024 / 1024).toFixed(2)} MB (100.00%)`);
    console.log("Upload complete!");
  })
  .catch((err) => {
    console.error("Upload failed:", err);
    process.exit(1);
  });
