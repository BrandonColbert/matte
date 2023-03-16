export class InputField<T extends HTMLElement> {
	public readonly element: T

	public constructor(element: T, assign: InputField.Assign, defaultValue?: string) {
		this.element = element
		this.value = this.value ? this.value : defaultValue

		element.onkeydown = e => {
			switch(e.key) {
				case "Enter":
					e.preventDefault()
					
					if(this.value)
						assign(this.value)

					break
				default:
					break
			}
		}
	}

	public get value(): string {
		if(this.element instanceof HTMLInputElement)
			return this.element.value
		else
			return this.element.textContent
	}

	private set value(value: string) {
		if(this.element instanceof HTMLInputElement)
			this.element.value = value
		else
			this.element.textContent = value
	}
}

export namespace InputField {
	export type Assign = (value: string) => void
}

export default InputField