import tree from "./tree.js"
import Treant from "./treant.js"

let source = new EventSource(`http://events.${window.location.host}`)
let astElement = document.querySelector<HTMLDivElement>("#ast")
let ast: Treant = null

// Listen for server-sent events
source.onmessage = (e: MessageEvent<string>) => {
	let event: {type: string, data?: any} = JSON.parse(atob(e.data))

	switch(event.type) {
		case "display": // Display a new syntax tree
			let {scrollLeft, scrollTop} = astElement

			// Create and assign new root node, then reload the tree
			let node = tree(event.data)
			ast.tree.initJsonConfig.nodeStructure = node
			ast.tree.reload()

			// Scroll back to previous location
			setScroll(astElement, scrollLeft, scrollTop)
			break
		case "reload":
			location.reload()
			break
	}
}

// Create the visual tree
ast = new Treant({
	chart: {
		container: "#ast",
		connectors: {
			type: "step",
			style: {
				stroke: "white"
			}
		},
		callback: {
			onTreeLoaded: () => {
				if(!ast)
					return

				// Add tooltip based on symbol
				for(let node of ast.tree.nodeDB.db) {
					let {text, nodeDOM: element} = node
					element.title = text["data-tag"] ?? ""
				}
			}
		}
	},
	nodeStructure: {}
})

// Enable panning and zooming
astElement.addEventListener("mousedown", pan)
astElement.addEventListener("wheel", zoom)
astElement.addEventListener("contextmenu", e => e.preventDefault())

/**
 * Scroll to the given position
 * @param element Element to scroll on
 */
function setScroll(element: Element, x: number, y: number): void {
	element.scrollLeft = Math.min(Math.max(0, x), element.scrollWidth)
	element.scrollTop = Math.min(Math.max(0, y), element.scrollHeight)
}

function pan(event: MouseEvent): void {
	switch(event.button) {
		case 0: // Left click pan when not on node
			let element = event.target as Element

			if(!element.matches("#ast, #ast > svg"))
				return

			break
		case 2: // Always pan on right click
			break
		default: // Do not pan when other mouse buttons are used
			return
	}

	event.preventDefault()
	event.stopPropagation()
	getSelection().removeAllRanges() // Deselect text before panning

	let element = event.currentTarget as Element
	let {scrollLeft, scrollTop} = element
	let [xi, yi] = [event.x, event.y]

	function update(e2: MouseEvent): void {
		let [xf, yf] = [e2.x, e2.y]
		let [dx, dy] = [xf - xi, yf - yi]
		setScroll(element, scrollLeft - dx, scrollTop - dy)
	}

	function stop(): void {
		window.removeEventListener("mousemove", update)
		window.removeEventListener("mouseup", stop)
		window.removeEventListener("mouseleave", stop)
	}

	window.addEventListener("mousemove", update)
	window.addEventListener("mouseup", stop)
	window.addEventListener("mouseleave", stop)
}

function zoom(event: WheelEvent): void {
	// Prevent scrolling
	event.preventDefault()
	event.stopImmediatePropagation()

	// Zoom to based on scroll wheel delta
	let zoomInitial = parseFloat(getComputedStyle(astElement).getPropertyValue("--zoom"))
	let zoomFinal = Math.min(Math.max(0.1, zoomInitial - event.deltaY / 1000), 2)
	astElement.style.setProperty("--zoom", zoomFinal.toString())

	// Pan to correct position after zooming
	let {scrollLeft, scrollTop, scrollWidth, scrollHeight} = astElement
	let scale = (zoomFinal - zoomInitial) * 0.15

	setScroll(
		astElement,
		scrollLeft + scrollWidth * scale,
		scrollTop + scrollHeight * scale
	)
}