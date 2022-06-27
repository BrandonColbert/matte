export default interface Node {
	symbol: string
}

export interface TokenNode extends Node {
	value: string
}

export interface RuleNode extends Node {
	branches: {[key: string]: RuleNode.Branch}
}

export namespace RuleNode {
	export interface Branch {
		reqs: string
		entries: Node[][]
	}
}