import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "clear"]

  connect() {
    this.toggle()
  }

  toggle() {
    if (!this.hasClearTarget || !this.hasInputTarget) return

    this.clearTarget.classList.toggle("is-visible", this.inputTarget.value.length > 0)
  }

  clear() {
    if (!this.hasInputTarget) return

    this.inputTarget.value = ""
    this.toggle()
    this.element.requestSubmit()
  }
}
