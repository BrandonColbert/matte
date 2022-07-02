/**
 * Scroll to the given position
 * @param element Element to scroll on
 */
export default function setScroll(element: Element, x: number, y: number): void {
	element.scrollLeft = Math.min(Math.max(0, x), element.scrollWidth)
	element.scrollTop = Math.min(Math.max(0, y), element.scrollHeight)
}