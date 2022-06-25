import fs from "fs/promises"
import Options from "./options.js"
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

	public async process(): Promise<Parser.Node> {
		let args: string[] = [...this.baseArgs]

		// Add source code to parse
		if(Options.has("src"))
			args.push(`-src=${Options.get("src")}`)
		else if(Options.has("srcPath")) {
			try {
				await fs.access(Options.get("srcPath"))
			} catch(e) {
				console.log(`\nUnable to read file: ${Options.get("srcPath")}`)
				return null
			}

			let data = await fs.readFile(Options.get("srcPath"))
			let text = data.toString()
			let src = text.trim()

			if(!text) {
				let stats = await fs.stat(Options.get("srcPath"))

				if(stats.size == 0)
					args.push(`-src=`)
				else
					return await this.process()
			}

			args.push(`-src=${src}`)
		}

		// Run the parser in its directory
		let output = ""
		let process = childProcess.spawn(Options.get("lua"), args, {
			cwd: Options.get("parser"),
			timeout: 5000
		})

		process.stderr.on("data", (chunk: Buffer) => {
			if(Options.has("log"))
				console.log(chunk.toString())
		})

		process.stdout.on("data", (chunk: Buffer) => {
			let line = chunk.toString()
			output += line

			if(Options.has("log"))
				console.log(line)
		})

		await new Promise<void>((resolve, reject) => {
			process.on("close", () => resolve())
			process.on("error", code => reject(code))
		})

		let lines = output.trim().split(/\r?\n/)
		let line = lines.at(-1)

		try {
			// Convert last line of parser output to JSON ast
			return JSON.parse(line)
		} catch(e) {
			console.log(`Last line of output is not valid JSON:\n\t${line}`)
			return null
		}
	}
}

export namespace Parser {
	export interface Node {
		symbol: string
	}

	export interface TokenNode extends Node {
		value: string
	}

	export interface RuleNode extends Node {
		branches: {[key: number]: RuleNode.Branch}
	}

	export namespace RuleNode {
		export interface Branch {
			reqs: string
			entries: Node[][]
		}
	}
}

export default Parser