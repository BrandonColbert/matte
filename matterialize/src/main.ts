import open from "open"
import path from "path"
import chokidar from "chokidar"
import Server from "./server/server.js"
import Language from "./server/language.js"
import Options from "./server/utils/options.js"
import filesOf from "./server/utils/files.js"
import {appPath} from "./server/utils/app.js"

// Show help if no cli parameters specified
if(Options.count == 0 || Options.has("help")) {
	Options.help()
	process.exit()
}

// Prepare the language caller
let language = new Language({
	luaPath: Options.get("lua"),
	mainPath: Options.get("main"),
	logger: {
		stdout: () => {}
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

	let node = await language.parse({
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

	let root = path.join(Options.get("root"))
	let files = await filesOf(root)
	files = files.map(p => p.slice(root.length + path.sep.length))

	response.end(JSON.stringify(files), "utf-8")
})

// Reload viewer page when page source changes
chokidar.watch(appPath).on("change", () => server.send("reload"))

// Signal when the language program's source is changed
chokidar.watch(path.dirname(Options.get("main"))).on("change", p => {
	console.log(`\nLanguage program modified in file: ${p}`)
	server.send("programMod")
})

// Signal when matter's source is changed
chokidar.watch("matter").on("change", p => {
	console.log(`\nmatter backend modified in file: ${p}`)
	server.send("programMod")
})

// Signal when a language file is changed
chokidar.watch(Options.get("root")).on("change", p => {
	console.log(`\nLanguage file modified: ${p}`)

	let root = path.join(Options.get("root"))
	server.send("fileMod", p.slice(root.length + path.sep.length))
})

// Exit on any key press
process.stdin.setRawMode(true)
process.stdin.resume()
process.stdin.on("data", () => process.exit())