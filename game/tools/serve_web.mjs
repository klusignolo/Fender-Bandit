// Serves the web export locally for checks: node game/tools/serve_web.mjs [port]
// then open http://localhost:8060. The build is single-threaded, so no COOP/COEP headers are needed.
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { extname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = fileURLToPath(new URL("../build/web/", import.meta.url));
const PORT = Number(process.argv[2] ?? 8060);
const TYPES = { ".html": "text/html", ".js": "text/javascript", ".wasm": "application/wasm", ".pck": "application/octet-stream", ".png": "image/png" };

createServer(async (req, res) => {
	const path = decodeURIComponent(new URL(req.url, "http://x").pathname).split("/").filter((p) => p && p !== "..").join("/") || "index.html";
	try {
		const body = await readFile(join(ROOT, path));
		res.writeHead(200, { "Content-Type": TYPES[extname(path)] ?? "application/octet-stream" });
		res.end(body);
	} catch {
		res.writeHead(404).end("not found");
	}
}).listen(PORT, () => console.log(`Serving ${ROOT} at http://localhost:${PORT}`));
