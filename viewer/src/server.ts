import url from "url"
import http from "http"
import EventEmitter from "events"
import {AddressInfo} from "net"
import {send, displayError} from "./utils.js"

/**
 * HTTP Server capable of sending events to the client
 */
export default class Server extends EventEmitter {
	#connected: Set<http.ServerResponse> = new Set()
	#server: http.Server

	/**
	 * @param port Port to host the server on. If unspecified, a random available port is chosen
	 * @param callback Called once the server loads
	 */
	public constructor(port: number = 0, callback?: () => void) {
		super()

		this.#server = http.createServer(async (req, res) => {
			let location = url.parse(`http://${req.headers.host}${req.url}`)
			let subdomains = location.hostname.split(".")

			switch(subdomains.length) {
				case 1: // Provide the requested file
					await send(res, location.pathname)
					break
				case 2:
					switch(subdomains[0]) {
						case "events": // Provide server-sent events
							res.writeHead(200, {
								"Content-Type": "text/event-stream",
								"Cache-Control": "no-cache",
								"Connection": "keep-alive",
								"Access-Control-Allow-Origin": "*"
							})

							// Register the connection
							this.#connected.add(res)
							this.emit("connected", req, res)
							break
						default:
							await displayError(res, `Invalid subdomain '${subdomains[0]}'`)
							break
					}

					break
				default:
					await displayError(res, `Unexpected location '${location.host}'`)
					break
			}
		})

		// Listen on the specified port, only allowing local connections
		this.#server.listen(port, "localhost", callback)
	}

	/**
	 * Port being listened on
	 */
	public get port(): number {
		let address = this.#server.address() as AddressInfo
		return address.port
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
		for(let res of [...this.#connected]) {
			// Remove closed connections
			if(res.writableEnded) {
				this.#connected.delete(res)
				continue
			}

			// Send data through response
			res.write(`data: ${bufferText}\n`)
			res.write("\n")
		}
	}

	/**
	 * Close connections
	 */
	public close(): void {
		// End responses
		for(let res of this.#connected)
			res.end()

		this.#connected.clear()
	}
}