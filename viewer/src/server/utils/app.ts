import module from "module"
import path from "path"
import url from "url"

/** Path to the viewer app which is in the same folder as the package.json */
export const appPath = pathParent(url.fileURLToPath(import.meta.url), 4)

/** A require that operates relative to the app path */
export const require = module.createRequire(path.join(appPath, "/"))

function pathParent(filePath: string, level: number = 1): string {
	return [...Array<void>(level)].reduce(p => path.dirname(p), filePath)
}