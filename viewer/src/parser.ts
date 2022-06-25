import fs from "fs/promises"
import Options from "./options.js"
import {stdout} from "process"
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

			// Retry if file could not be read
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
		let [line, errText] = ["", ""]
		let process = childProcess.spawn(Options.get("lua"), args, {
			cwd: Options.get("parser"),
			timeout: 5000
		})

		process.stderr.on("data", (chunk: Buffer) => errText += chunk.toString())

		process.stdout.on("data", (chunk: Buffer) => {
			let data = line + chunk.toString()
			let lines = data.split(/\r?\n/)

			let lastLineIndex = lines.length - 1 - lines.slice().reverse().findIndex(line => Boolean(line))
			let head = lines.slice(0, lastLineIndex).join("\n")
			let tail = lines.slice(lastLineIndex).join("\n")

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

		if(errText) {
			console.error(errText)
			return null
		}

		try {
			// Convert last line of parser output to JSON ast
			return JSON.parse(line.trim())
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