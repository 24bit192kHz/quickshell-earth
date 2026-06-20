export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const key = url.pathname.slice(1);
    
    if (request.method === "POST" && url.searchParams.has("uploads")) {
      const upload = await env.BUCKET.createMultipartUpload(key);
      return new Response(JSON.stringify({ uploadId: upload.uploadId, key: upload.key }), {
        headers: { "Content-Type": "application/json" }
      });
    }

    if (request.method === "PUT" && url.searchParams.has("partNumber") && url.searchParams.has("uploadId")) {
      const uploadId = url.searchParams.get("uploadId");
      const partNumber = parseInt(url.searchParams.get("partNumber"));
      
      const upload = env.BUCKET.resumeMultipartUpload(key, uploadId);
      try {
        const part = await upload.uploadPart(partNumber, request.body);
        return new Response(JSON.stringify({ etag: part.etag, partNumber: part.partNumber }), {
          headers: { "Content-Type": "application/json" }
        });
      } catch (e) {
        return new Response(e.message, { status: 500 });
      }
    }

    if (request.method === "POST" && url.searchParams.has("uploadId")) {
      const uploadId = url.searchParams.get("uploadId");
      const body = await request.json();
      
      const upload = env.BUCKET.resumeMultipartUpload(key, uploadId);
      try {
        const object = await upload.complete(body.parts);
        return new Response(JSON.stringify({ etag: object.etag }), {
          headers: { "Content-Type": "application/json" }
        });
      } catch (e) {
        return new Response(e.message, { status: 500 });
      }
    }

    return new Response("Not Found", { status: 404 });
  }
};
