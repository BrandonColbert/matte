import Node, {TokenNode, RuleNode} from "./node.js"
import Treant from "./treant.js"

/**
 * @param node A descend node
 * @param tag Desired tooltip
 * @returns The corresponding Treant node
 */
export function tree(node: Node | string, tag?: string): Treant.Node {
	switch(typeof(node)) {
		case "string":
			return {
				text: {
					name: "self",
					"data-type": "invalid"
				}
			}
		case "object":
			if("value" in node) {
				let tokenNode = node as TokenNode
		
				return {
					text: {
						name: tokenNode.value,
						"data-tag": tag ?? tokenNode.symbol,
						"data-type": "value"
					}
				}
			} else if("branches" in node) {
				let ruleNode = node as RuleNode
		
				switch(Object.keys(ruleNode.branches).length) {
					case 0:
						return {
							text: {
								name: ruleNode.symbol,
								"data-tag": tag,
								"data-type": "invalid"
							}
						}
					case 1:
						let branchKey = Object.keys(ruleNode.branches)[0]
						let branch = ruleNode.branches[branchKey]
		
						return {
							text: {
								name: ruleNode.symbol,
								"data-tag": `${tag ?? branch.reqs}\t\u3008${branchKey}\u3009`
							},
							children: btt(branch)
						}
					default:
						return {
							text: {
								name: ruleNode.symbol,
								"data-tag": tag,
								"data-type": "branching"
							},
							children: Object.keys(ruleNode.branches).map(branchKey => {
								let branch = ruleNode.branches[branchKey]
				
								return {
									text: {
										name: branchKey,
										"data-tag": branch.reqs,
										"data-type": "branch"
									},
									children: btt(branch)
								}
							})
						}
				}
			}

			break
	}

	throw new Error(`Unable to create Treant node for '${node}'`)
}

function btt(branch: RuleNode.Branch): Treant.Node[] {
	return branch.entries.flatMap((entry, requirementIndex) => {
		let basePosition = `${1 + requirementIndex}`

		return entry.map((node, nodeIndex) => {
			let position = entry.length > 1 ? `${basePosition}.${1 + nodeIndex}` : basePosition

			return tree(node, `\u3008${position}\u3009\t${branch.reqs}`)
		})
	})
}

export default tree