import util from "util"
import http from "http"
import open from "open"
import chokidar from "chokidar"
import Server from "./server.js"
import Parser from "./parser.js"
import Options from "./options.js"
import {appPath} from "./utils.js"

let server: Server = null
let parser: Parser = null

/**
 * Starts the viewer
 */
async function run(): Promise<void> {
	if(Options.count == 0 || Options.has("help")) // Show help if no cli parameters specified
		Options.help()

	// Prepare for parsing
	if(Options.has("parser")) {
		parser = new Parser()

		// Generate output immediately
		if(Options.has("print"))
			await generate()
	}

	if(Options.has("display")) {
		// Start the viewer server
		let port = parseInt(Options.get("port"))

		server = new Server(port ? port : undefined, async () => {
			console.log(`Started viewer on port ${server.port}`)

			if(!port) // If the port was not specified, open the server in the browser
				await open(`http://localhost:${server.port}`)
		})

		// Generate output for new connections
		server.on("connected", async (req: http.IncomingMessage) => {
			if(await generate())
				console.log(`\ngenerated for client: ${req.headers.origin}`)
		})
	}

	// Watch files to regenerate output and exit on keypress
	if(Options.has("watch")) {
		let paths = [
			Options.get("parser"),
			Options.get("srcPath")
		].filter(d => d != null)

		// Regenerate output when parser files or source file change
		for(let path of paths)
			chokidar.watch(path).on("change", async path => {
				if(await generate())
					console.log(`\nregenerated for file: ${path}`)
			})

		// Reload viewer page since source changed
		chokidar.watch(appPath).on("change", path => {
			server?.send("reload")
			console.log(`\nreloaded for file: ${path}`)
		})

		// Exit on any key press
		process.stdin.setRawMode(true)
		process.stdin.resume()
		process.stdin.on("data", () => process.exit())
	}
}

/**
 * Generate parser output
 * @returns Whether output could be generated
 */
async function generate(): Promise<boolean> {
	let node = await parser.run()

	if(!node)
		return false

	// Print syntax tree to console
	if(Options.has("print"))
		console.log(`\n${util.inspect(node, {
			showHidden: true,
			depth: null,
			colors: true
		})}`)

	// Update viewer with new ast
	if(Options.has("display"))
		server?.send("display", node)

	return true
}

// Start the viewer
run()