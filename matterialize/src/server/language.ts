import path from "path"
import fs from "fs/promises"
import {spawn} from "child_process"
import Syntax from "../common/syntax.js"

export class Language {
	private readonly options: Language.Options

	public constructor(options: Language.Options) {
		this.options = options
		this.options.logger ??= {}
		this.options.logger.stdout ??= line => process.stdout.write(line)
		this.options.logger.stderr ??= line => process.stderr.write(line)
	}

	public async parse(options: Language.Mode.Options.Parse): Promise<Syntax.Node> {
		let text = ""

		// Create lua process
		let p = spawn(
			this.options.luaPath,
			[
				path.normalize(this.options.mainPath),
				"-mode=parse",
				options.entry ? `-entry=${options.entry}` : null
			].filter(v => v != null),
			{
				// cwd: mainPath.dir,
				timeout: 5000
			}
		)

		p.stdout.on("data", (chunk: Buffer) => {
			let s = chunk.toString()
			text += s

			this.options.logger.stdout?.(s)
		})

		p.stderr.on("data", (chunk: Buffer) => {
			this.options.logger.stderr?.(chunk.toString())
		})

		// Send source to stdin
		let src = await fs.readFile(path.join(process.cwd(), options.input))
		p.stdin.write(src.toString(), "utf-8")
		p.stdin.write("\n", "utf-8")
		p.stdin.end()

		// Wait for completetion
		await new Promise<void>((resolve, reject) => {
			p.on("close", () => resolve())
			p.on("error", code => reject(code))
		})

		try {
			// Convert last line of parser output to JSON ast
			return JSON.parse(text.trim())
		} catch(e) {
			console.error(`Output is not valid JSON:\n${text}`)
			return null
		}
	}
}

export namespace Language {
	export interface Options {
		/** Path to the lua executable */
		luaPath: string

		/** Path to the lua file to run */
		mainPath: string

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

export default Language