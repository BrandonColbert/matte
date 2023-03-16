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

export default Treant