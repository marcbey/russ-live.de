import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["body", "button", "toggle"]

  connect() {
    this.refreshOnResize = () => this.refresh()
    window.addEventListener("resize", this.refreshOnResize)
    this.refresh()
    document.fonts?.ready.then(() => this.refresh())
  }

  disconnect() {
    window.removeEventListener("resize", this.refreshOnResize)
  }

  toggle() {
    this.toggleTarget.setAttribute("aria-expanded", this.toggleTarget.checked.toString())
  }

  refresh() {
    const wasExpanded = this.toggleTarget.checked
    this.toggleTarget.checked = false
    this.element.classList.add("is-overflowing")

    const collapsedHeight = Number.parseFloat(getComputedStyle(this.bodyTarget).maxHeight)
    const overflows = this.bodyTarget.scrollHeight > collapsedHeight + 1

    this.element.classList.toggle("is-overflowing", overflows)
    this.toggleTarget.checked = overflows && wasExpanded
    this.buttonTarget.hidden = !overflows
    this.toggle()
  }
}
