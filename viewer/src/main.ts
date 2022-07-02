import open from "open"
import path from "path"
import chokidar from "chokidar"
import Server from "./server/server.js"
import Descend from "./server/descend.js"
import Options from "./server/utils/options.js"
import filesOf from "./server/utils/files.js"
import {appPath} from "./server/utils/app.js"

// Show help if no cli parameters specified
if(Options.count == 0 || Options.has("help")) {
	Options.help()
	process.exit()
}

// Prepare the Descend caller
let descend = new Descend({
	luaPath: Options.get("lua"),
	descendPath: Options.get("main"),
	logger: {
		stdout: Options.has("log") ? null : () => {}
	}
})

// Create the viewer server
let port = Options.has("port") ? parseInt(Options.get("port")) : undefined
let server = new Server(port, async function() {
	console.log(`Started viewer on port: ${this.port}`)

	if(!port) // If the port was not specified, open the server in the browser
		await open(`http://localhost:${this.port}`)
})

server.createSubdomain("parse", async ({request, response}) => {
	response.writeHead(200, {
		"Content-Type": "application/json",
		"Access-Control-Allow-Origin": "*"
	})

	let url = new URL(request.url, `http://${request.headers.host}`)

	let file = url.pathname.slice(1)
	let rule = url.search.slice(1)

	let node = await descend.parse({
		input: path.join(Options.get("root"), file),
		entry: rule
	})

	response.end(JSON.stringify(node ?? {}), "utf-8")
})

server.createSubdomain("files", async ({request, response}) => {
	response.writeHead(200, {
		"Content-Type": "application/json",
		"Access-Control-Allow-Origin": "*"
	})

	let root = Options.get("root")
	let files = await filesOf(root)
	files = files.map(p => p.split(path.sep).slice(1).join(path.sep))

	response.end(JSON.stringify(files), "utf-8")
})

// Reload viewer page when page source changes
chokidar.watch(appPath).on("change", () => server.send("reload"))

// Signal when the Descend program's source is changed
chokidar.watch(path.dirname(Options.get("main"))).on("change", p => {
	console.log(`\nDescend program modified in file: ${p}`)
	server.send("programMod")
})

// Signal when a Descend file is changed
chokidar.watch(Options.get("root")).on("change", p => {
	console.log(`\nDescend file modified: ${p}`)
	server.send("fileMod", p.split(path.sep).slice(1).join(path.sep))
})

// Exit on any key press
process.stdin.setRawMode(true)
process.stdin.resume()
process.stdin.on("data", () => process.exit())