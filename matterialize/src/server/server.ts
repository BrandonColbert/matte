import url from "url"
import http from "http"
import EventEmitter from "events"
import {AddressInfo} from "net"
import {send, displayError} from "./utils/serve.js"

/**
 * HTTP Server capable of sending events to the client
 */
export class Server extends EventEmitter {
	#subdomains: Map<string, Server.Handler> = new Map()
	#connected: Set<Server.Connection> = new Set()
	#server: http.Server

	/**
	 * @param port Port to host the server on. If unspecified, a random available port is chosen
	 * @param callback Called once the server loads
	 */
	public constructor(port: number = 0, callback?: (this: Server) => void) {
		super()

		this.#server = http.createServer(async (req, res) => {
			let location = url.parse(`http://${req.headers.host}${req.url}`)
			let subdomain = location.hostname.split(".").slice(0, -1).join("")

			switch(subdomain) {
				case "": // Provide the requested file
					await send(res, location.pathname)
					break
				case "events": // Provide server-sent events
					res.writeHead(200, {
						"Content-Type": "text/event-stream",
						"Cache-Control": "no-cache",
						"Connection": "keep-alive",
						"Access-Control-Allow-Origin": "*"
					})

					// Register the connection
					let connection: Server.Connection = {request: req, response: res}

					let onDisconnect = () => {
						this.#connected.delete(connection)
						this.emit("disconnect", connection)
					}

					req.on("close", onDisconnect)
					req.on("end", onDisconnect)

					this.#connected.add(connection)
					this.emit("connect", connection)
					break
				default:
					if(this.#subdomains.has(subdomain)) {
						let handler = this.#subdomains.get(subdomain)
						let connection: Server.Connection = {request: req, response: res}

						handler(connection)
					} else
						await displayError(res, `Invalid subdomain '${subdomain}'`)

					break
			}
		})

		// Listen on the specified port, only allowing local connections
		this.#server.listen(port, "localhost", callback.bind(this))
	}

	/**
	 * Port being listened on
	 */
	public get port(): number {
		let address = this.#server.address() as AddressInfo
		return address.port
	}

	public createSubdomain(path: string, handler: Server.Handler): void {
		this.#subdomains.set(path, handler)
	}

	/**
	 * Send an event to the client
	 * @param type Event type
	 * @param data Event data
	 */
	public send(type: string, data?: any): void {
		// Convert data to base64 string
		let dataText = JSON.stringify({type: type, data: data})
		let bufferText = Buffer.from(dataText, "binary").toString("base64")

		// Send data to each client
		for(let {response} of [...this.#connected]) {
			// Ignore unwritable connections
			if(response.writableEnded)
				continue

			// Send data through response
			response.write(`data: ${bufferText}\n`)
			response.write("\n")
		}
	}

	/**
	 * Close connections
	 */
	public close(): void {
		// End responses
		for(let {response} of this.#connected)
			response.end()

		this.#connected.clear()
	}
}

export namespace Server {
	export interface Connection {
		request: http.IncomingMessage
		response: http.ServerResponse
	}

	export type Handler = (connection: Connection) => void
}

export default Server