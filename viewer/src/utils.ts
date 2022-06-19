import fs from "fs/promises"
import module from "module"
import path from "path"
import http from "http"
import url from "url"

// Find path to package.json and viewer app
export const appPath = path.dirname(path.dirname(url.fileURLToPath(import.meta.url)))
export const execPath = path.dirname(appPath)

// Create require relative to app path
export const require = module.createRequire(path.join(appPath, "/"))

/**
 * Sends a file over an http response
 * @param res HTTP response to send the file over
 * @param file Path to the file
 */
export async function send(res: http.ServerResponse, file: string): Promise<void> {
	// Get the file location relative to the app directory
	let actualFile = path.join(appPath, file)

	// Check if file exists
	try {
		await fs.access(actualFile)
	} catch(e) {
		if(e instanceof Error)
			await displayError(res, e.message, 404)

		return
	}

	// If the file is a directory, assume the filename is index
	if((await fs.stat(actualFile)).isDirectory()) {
		let ext = path.parse(actualFile).ext
		await send(res, `${file}/index.${ext ? ext : "html"}`)

		return
	}

	// Read and send content at file location
	try {
		let content = await fs.readFile(actualFile)

		res.setHeader("Content-Type", getContentType(actualFile))
		res.end(content, "utf-8")
	} catch(e) {
		if(e instanceof Error)
			await displayError(res, e.message, 500)

		return
	}
}

/**
 * Displays an error page with the specified error
 * @param res HTTP response to send the page over
 * @param msg Error message
 * @param statusCode Error status code
 */
export async function displayError(res: http.ServerResponse, msg: string, statusCode: number = 200): Promise<void> {
	// Escape msg html
	let text = msg.replace(/[&"'<>]/g, v => {
		switch(v) {
			case "&": return "&amp;"
			case `"`: return "&quot;"
			case `'`: return "&#39;"
			case "<": return "&lt;"
			case ">": return "&gt;"
			default: return v
		}
	})

	// Get error page and insert message
	let errorHTML = (await fs.readFile(path.join(appPath, "error.html"))).toString()
	let html = errorHTML.replace(/<body>(\s*)<\/body>/, () => `<div>${text}</div>`)

	// Show page
	res.writeHead(statusCode, {"Content-Type": "text/html"})
	res.write(html)
	res.end()
}

/**
 * @param file Path to a file
 * @returns MIME type of the file
 */
export function getContentType(file: string): string {
	switch(path.parse(file).ext) {
		case ".ico": return "image/x-icon"
		case ".html": return "text/html"
		case ".js": return "text/javascript"
		case ".json": return "application/json"
		case ".css": return "text/css"
		case ".png": return "image/png"
		case ".jpg": return "image/jpeg"
		case ".wav": return "audio/wav"
		case ".mp3": return "audio/mpeg"
		case ".svg": return "image/svg+xml"
		case ".pdf": return "application/pdf"
		case ".doc": return "application/msword"
		default: return "text/plain"
	}
}

/**
 * @returns Key-value mapped CLI parameters
 */
export function getOptions(): {[key: string]: string} {
	// Find key-value pairs in the form "-{key}={value}"
	return Object.fromEntries(process.argv.slice(2).map(arg => {
		if(!arg.startsWith("-"))
			return null

		let [key, value] = arg.slice(1).split("=", 2)

		return [key, value]
	}).filter(v => v != null))
}