import Syntax from "../common/syntax.js"
import Treant from "./treant.js"
import tree from "./tree.js"
import setScroll from "./utils/scroll.js"

let serverAddress: string

if(location.host)
	serverAddress = window.location.host
else if(location.hash.length > 1)
	serverAddress = `localhost:${window.location.hash.slice(1)}`

export default class Viewer {
	public static readonly serverAddress: string = serverAddress
	public readonly element: HTMLDivElement
	public file: string
	public rule: string
	private syntaxTree: Treant

	public constructor(selector: string) {
		this.element = document.querySelector(selector)

		// Create the visual tree
		this.syntaxTree = new Treant({
			chart: {
				container: "#ast",
				connectors: {
					type: "step",
					style: {
						stroke: "white"
					}
				}
			},
			nodeStructure: {}
		})

		// Listen for server-sent events
		if(Viewer.serverAddress) {
			let events = new EventSource(`http://events.${Viewer.serverAddress}`)
			events.onmessage = (e: MessageEvent<string>) => this.onMessage(e.data)
		}
	}

	public display(node: Syntax.Node): void {
		let {scrollLeft, scrollTop} = this.element

		// Create and assign new root node, then reload the tree
		this.syntaxTree.tree.initJsonConfig.nodeStructure = tree(node)
		this.syntaxTree.tree.reload()

		// Scroll back to previous location
		setScroll(this.element, scrollLeft, scrollTop)
	}

	public async requestSyntaxTree(): Promise<void> {
		let url = `http://parse.${Viewer.serverAddress}/${this.file}?${this.rule}`
	
		let response = await fetch(url)
		let node = await response.json()
	
		this.display(node)
	}

	private onMessage(data: string): void {
		let event: {type: string, data?: any} = JSON.parse(atob(data))

		switch(event.type) {
			case "reload":
				location.reload()
				break
			case "programMod":
				this.requestSyntaxTree()
				break
			case "fileMod":
				let file: string = event.data

				if(this.file == file)
					this.requestSyntaxTree()
				break
			default:
				console.error("Unrecognized server-event", event)
				break
		}
	}
}