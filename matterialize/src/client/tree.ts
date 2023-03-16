import Syntax from "../common/syntax.js"
import Treant from "./treant.js"

/**
 * @param node A syntax node
 * @param tag Desired tooltip
 * @returns The corresponding Treant node
 */
export function tree(node: Syntax.Node | string, tag?: string): Treant.Node {
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
				let tokenNode = node as Syntax.TokenNode
		
				return {
					text: {
						name: JSON.stringify(tokenNode.value).slice(1, -1),
						"data-tag": tag ?? tokenNode.symbol,
						"data-type": "value"
					}
				}
			} else if("branches" in node) {
				let ruleNode = node as Syntax.RuleNode
		
				switch(Object.keys(ruleNode.branches).length) {
					case 0:
						return {
							text: {
								name: ruleNode.symbol,
								"data-tag": tag ?? "",
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
								"data-tag": tag ?? "",
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

	return {
		text: {
			name: "?",
			"data-type": "invalid"
		}
	}
}

function btt(branch: Syntax.RuleNode.Branch): Treant.Node[] {
	return branch.entries.flatMap((entry, requirementIndex) => {
		let basePosition = `${1 + requirementIndex}`

		return entry.map((node, nodeIndex) => {
			let position = entry.length > 1 ? `${basePosition}.${1 + nodeIndex}` : basePosition

			return tree(node, `\u3008${position}\u3009\t${branch.reqs}`)
		})
	})
}

export default tree