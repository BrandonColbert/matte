import fs from "fs/promises"
import path from "path"

export default async function filesOf(dir: string): Promise<string[]> {
	let absoluteDir = path.join(process.cwd(), dir)
	let filenames = await fs.readdir(absoluteDir)

	let files = filenames.map(async filename => {
		let absoluteFile = path.join(absoluteDir, filename)
		let file = path.join(dir, filename)

		let stat = await fs.stat(absoluteFile)

		if(stat.isDirectory())
			return await filesOf(file)
		else
			return [file]
	})

	return (await Promise.all(files)).flat()
}