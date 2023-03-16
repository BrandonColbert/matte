import Viewer from "./client/viewer.js"
import setScroll from "./client/utils/scroll.js"
import InputField from "./client/utils/inputField.js"

// Create page elements
let viewer = new Viewer("#ast")

let ruleField = new InputField(
	document.querySelector<HTMLDivElement>("#rule > .value"),
	async value => {
		viewer.rule = value
		viewer.requestSyntaxTree()
		localStorage.setItem("rule", value)
	},
	localStorage.getItem("rule") ?? "entry"
)

let fileField = new InputField(
	document.querySelector<HTMLDivElement>("#file > .value"),
	async value => {
		viewer.file = value
		viewer.requestSyntaxTree()
		localStorage.setItem("file", value)
	},
	localStorage.getItem("file") ?? "main.dt"
)

// Enable panning and zooming
viewer.element.addEventListener("mousedown", pan)
viewer.element.addEventListener("wheel", zoom)
viewer.element.addEventListener("contextmenu", e => e.preventDefault())

// Show file list dropdown for file field
fileField.element.addEventListener("click", showFiles)

// Display syntax tree
viewer.file = fileField.value
viewer.rule = ruleField.value
viewer.requestSyntaxTree()

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
	let zoomInitial = parseFloat(getComputedStyle(viewer.element).getPropertyValue("--zoom"))
	let zoomFinal = Math.min(Math.max(0.1, zoomInitial - event.deltaY / 1000), 2)
	viewer.element.style.setProperty("--zoom", zoomFinal.toString())

	// Pan to correct position after zooming
	let {scrollLeft, scrollTop, scrollWidth, scrollHeight} = viewer.element
	let scale = (zoomFinal - zoomInitial) * 0.15

	setScroll(
		viewer.element,
		scrollLeft + scrollWidth * scale,
		scrollTop + scrollHeight * scale
	)
}

async function showFiles(): Promise<void> {
	let list = document.querySelector("#file > #list")

	// Clear existing files
	while(list.lastElementChild)
		list.lastElementChild.remove()

	// Get new files
	let response = await fetch(`http://files.${Viewer.serverAddress}`)
	let files: string[] = await response.json()

	// Populate datalist
	for(let file of files) {
		let option = document.createElement("option")
		option.value = file
		list.append(option)
	}
}