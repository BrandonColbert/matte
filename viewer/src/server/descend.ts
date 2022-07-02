import path from "path"
import {spawn} from "child_process"
import Syntax from "../common/syntax.js"

export class Descend {
	private readonly options: Descend.Options

	public constructor(options: Descend.Options) {
		this.options = options
		this.options.logger ??= {}
		this.options.logger.stdout ??= line => process.stdout.write(line)
		this.options.logger.stderr ??= line => process.stderr.write(line)
	}

	public async parse(options: Descend.Mode.Options.Parse): Promise<Syntax.Node> {
		let descendPath = path.parse(this.options.descendPath)
		let lastLine: string, outText: string, errText: string

		// Create lua process
		let p = spawn(
			this.options.luaPath,
			[
				descendPath.base,
				"-parse",
				options.src ? `-src=${options.src}` : null,
				options.input ? `-input=${path.join(process.cwd(), options.input)}` : null,
				options.output ? `-output=${path.join(process.cwd(), options.output)}` : null,
				options.entry ? `-entry=${options.entry}` : null
			].filter(v => v != null),
			{
				cwd: descendPath.dir,
				timeout: 5000
			}
		)

		p.stdout.on("data", (chunk: Buffer) => {
			let [lines, tail] = Descend.toLines(outText, chunk.toString())

			let lineIndex = lines.length - 1 - lines.slice()
				.reverse()
				.findIndex(line => !/^\s*$/.test(line))

			lastLine = lines.slice(lineIndex).join("")
			outText = lastLine + tail

			for(let line of lines.slice(0, lineIndex))
				this.options.logger.stdout?.(line)
		})

		p.stderr.on("data", (chunk: Buffer) => {
			let [lines, tail] = Descend.toLines(errText, chunk.toString())
			errText = tail

			for(let line of lines)
				this.options.logger.stderr?.(line)
		})

		// Wait for completetion
		await new Promise<void>((resolve, reject) => {
			p.on("close", () => resolve())
			p.on("error", code => reject(code))
		})

		try {
			// Convert last line of parser output to JSON ast
			return JSON.parse(lastLine.trim())
		} catch(e) {
			console.error(`Last line of output is not valid JSON:\n\t${lastLine}`)
			return null
		}
	}

	public async transpile(options: Descend.Mode.Options.Transpile): Promise<string> {
		throw new Error("Not implemented")
	}

	public async run(options: Descend.Mode.Options.Run): Promise<void> {
		throw new Error("Not implemented")
	}

	private static toLines(head: string | null, tail: string | null): [string[], string] {
		head ??= ""
		tail ??= ""

		let lines = (head + tail).split(/(\n)/g)
		let lastLineIndex = lines.length - 1 - lines.slice()
			.reverse()
			.findIndex(line => /^.*\n$/.test(line))

		return [
			lines.slice(0, lastLineIndex),
			lines.slice(lastLineIndex).join("")
		]
	}
}

export namespace Descend {
	export interface Options {
		/** Path to the lua executable */
		luaPath: string

		/** Path to the lua file to run */
		descendPath: string

		logger?: Options.Logger
	}

	export namespace Options {
		export interface Logger {
			stdout?: (line: string) => void
			stderr?: (line: string) => void
		}
	}

	export namespace Mode {
		export interface Options {
			src?: string
			input?: string
		}
	
		export namespace Options {
			export interface Parse extends Options {
				output?: string
				entry?: string
			}
	
			export interface Transpile extends Options {
				output?: string
			}
	
			export interface Run extends Options {
				args?: string[]
			}
		}
	}
}

export default Descend