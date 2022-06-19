/**
 * Converts a Descend AST into a Treant Tree
 * @param obj Descend Node
 * @returns Corresponding Treant Node
 */
export function tree(obj: any): Treant.Node

/**
 * @param text Node text
 * @param children Node children
 * @returns A Treant Node with the given values
 */
export function tree(text: Treant.Node.Text, children: Treant.Node[]): Treant.Node

export function tree(...par1: any[]): Treant.Node {
	switch(par1.length) {
		case 1:
			let node: Treant.Node = {text: {}}
			let obj: any = par1[0]

			if("symbol" in obj) {
				let name: string = obj.symbol

				if("value" in obj) { // Lexer Token
					node.text.name = `(${name} '${obj.value}')`
					node.text["data-tag"] = "Value"
				} else if("branches" in obj) { // Rule branches
					node.text.name = name

					let branches: {[key: string]: any} = obj.branches

					if(Object.keys(branches).length == 1) { // Directly connect to only available branch
						let branch = Object.values(branches)[0]
						node.children = [tree(branch)]
					} else // Connect to all branches
						node.children = Object.keys(branches).map(key => tree(
							{name: `{branch ${key}}`, "data-tag": "Special"},
							[tree(branches[key])]
						))
				} else
					node.text.name = name
			} else if("reqs" in obj) { // Rule requirements
				let name = obj.reqs

				if("entries" in obj) { // Requirement entries
					node.text.name = name
					node.text["data-tag"] = "Requirements"
					node.children = []

					for(let entry of obj.entries as any[][]) {
						if(entry.length == 1) {
							let x = entry[0]

							if(typeof(x) == "string")
								node.children.push(tree(
									{name: "{self}", "data-tag": "Special"},
									null
								))
							else
								node.children.push(tree(x))
						} else
							node.children.push(tree(
								{name: "{entry}", "data-tag": "Special"},
								entry.map(subentry => tree(subentry))
							))
					}
				}
			}

			return node
		case 2:
			let text: Treant.Node.Text = par1[0]
			let children: Treant.Node[] = par1[1]

			return {text: text, children: children}
		default:
			return null
	}
}

export const Treant: Treant = (window as any).Treant

export interface Treant {
	new(options: Treant.Options): this
	[key: string]: any
	[key: number]: any
}

export namespace Treant {
	export interface Options {
		chart: any
		nodeStructure: Node
	}

	export interface Node {
		text?: Node.Text
		children?: Node[]
	}

	export namespace Node {
		export interface Text {
			name?: string
			[key: string]: string
			[key: number]: any
		}
	}
}

export default tree