import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "menu"]

  connect() {
    this.abortController = new AbortController()
    this.setOpen(false)

    this.menuTarget.querySelectorAll("a").forEach((link) => {
      link.addEventListener("click", () => this.setOpen(false), { signal: this.abortController.signal })
    })

    document.addEventListener("click", (event) => {
      if (!this.element.contains(event.target)) this.setOpen(false)
    }, { signal: this.abortController.signal })

    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape") this.setOpen(false)
    }, { signal: this.abortController.signal })

    window.addEventListener("resize", () => {
      if (window.matchMedia("(min-width: 901px)").matches) this.setOpen(false)
    }, { signal: this.abortController.signal })
  }

  disconnect() {
    this.abortController?.abort()
  }

  toggle() {
    this.setOpen(!this.element.classList.contains("is-open"))
  }

  setOpen(open) {
    this.element.classList.toggle("is-open", open)
    this.buttonTarget.setAttribute("aria-expanded", String(open))
  }
}
