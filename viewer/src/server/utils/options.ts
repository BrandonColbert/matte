import {require} from "./app.js"

// Find key-value pairs in the form "-{key}={value}"
const parameters: Parameters = Object.fromEntries(process.argv.slice(2).map(arg => {
	if(!arg.startsWith("-"))
		return null

	let [key, value] = arg.slice(1).split("=", 2)

	return [key, value]
}).filter(v => v != null))

// Retrieve parameter names and descriptions from file
let descriptions: {[key: string]: string} = require("./data/clip.json")

export default class Options {
	/**
	 * List of parameters defined in 'clip.json'
	 */
	public static get parameters(): string[] {
		return Object.keys(descriptions)
	}

	/**
	 * Number of CLI parameters provided
	 */
	public static get count(): number {
		return Object.keys(parameters).length
	}

	/**
	 * @param name CLI parameter name
	 * @returns Whether CLI parameter exists
	 */
	public static has<T extends keyof Parameters>(name: T): boolean {
		return name in parameters
	}

	/**
	 * @param name CLI parameter name
	 * @returns The key-value mapped CLI parameter
	 */
	public static get<T extends keyof Parameters>(name: T): Parameters[T] {
		return parameters[name]
	}

	/**
	 * @param name CLI parameter name
	 * @returns Description for CLI parameter
	 */
	public static getDescription<T extends keyof Parameters>(name: T): string {
		return descriptions[name]
	}

	/**
	 * Show help in the terminal
	 */
	public static help(): void {
		let names = this.parameters.sort()
		let width = Math.max(...names.map(name => name.length))

		for(let name of names)
			console.log(`-${name.padEnd(width)}\t${descriptions[name]}`)
	}
}

export interface Parameters {
	/**
	 * Port to host the server on.
	 * 
	 * If unspecified, an available OS provided port will be used.
	 */
	port: string

	/**
	 * Root directory of the Descend files to view.
	 */
	root: string

	/** Lua executable path */
	lua: string

	/** Main lua file */
	main: string

	/**
	 * Whether to print help.
	 * 
	 * Defaults to false.
	 */
	help?: null

	/**
	 * Whether to print Descend logs to the console.
	 * 
	 * Defaults to false.
	 */
	log?: null
}