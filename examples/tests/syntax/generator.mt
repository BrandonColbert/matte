fn range(count: number, reverse: bool = false): Generator<number> {
	for i in 0..count {
		yield i
	}
}

let [a, b, c] = [...range(3, reverse: true)]