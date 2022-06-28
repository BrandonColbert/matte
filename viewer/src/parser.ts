import path from "path"
import Options from "./options.js"
import Node from "./node.js"
import {cwd, stdout} from "process"
import * as childProcess from "child_process"

export class Parser {
	private baseArgs: string[] = []

	public constructor() {
		// Add lua executable name
		if(!Options.has("lua"))
			throw new Error("No Lua runtime specified")

		if(!(Options.has("src") || Options.has("srcPath")))
			throw new Error("No source specified")

		// Add parser main file path
		if(Options.has("parser")) {
			this.baseArgs.push("main.lua")
			this.baseArgs.push("-parse")
		} else
			throw new Error("No parser directory specified")

		// Add optional entry rule
		if(Options.has("entry"))
			this.baseArgs.push(`-entry=${Options.get("entry")}`)
	}

	public async run(): Promise<Node> {
		let args: string[] = [...this.baseArgs]

		// Add source code to parse
		if(Options.has("src"))
			args.push(`-src=${Options.get("src")}`)
		else if(Options.has("srcPath"))
			args.push(`-input=${path.join(cwd(), Options.get("srcPath"))}`)

		// Run the parser in its directory
		let [line, errText] = ["", ""]
		let process = childProcess.spawn(Options.get("lua"), args, {
			cwd: Options.get("parser"),
			timeout: 5000
		})

		process.stderr.on("data", (chunk: Buffer) => errText += chunk.toString())

		process.stdout.on("data", (chunk: Buffer) => {
			let data = line + chunk.toString()
			let lines = data.split(/(\n)/g)

			let lastLineIndex = lines.length - 1 - lines.slice()
				.reverse()
				.findIndex(line => !/^\s*$/.test(line))

			let head = lines.slice(0, lastLineIndex).join("")
			let tail = lines.slice(lastLineIndex).join("")

			// Keep the last non-empty line
			line = tail

			// Print every line up to but excluding the last non-empty line
			if(Options.has("log"))
				stdout.write(head)
		})

		await new Promise<void>((resolve, reject) => {
			process.on("close", () => resolve())
			process.on("error", code => reject(code))
		})

		if(Options.has("log"))
			console.log()

		if(errText)
			console.error(errText)

		try {
			// Convert last line of parser output to JSON ast
			return JSON.parse(line.trim())
		} catch(e) {
			console.log(`Last line of output is not valid JSON:\n\t${line}`)
			return null
		}
	}
}

export default Parser