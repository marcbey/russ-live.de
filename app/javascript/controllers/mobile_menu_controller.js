import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "nav"]
  static values = {
    closeLabel: String,
    openLabel: String,
  }

  connect() {
    this.abortController = new AbortController()
    const { signal } = this.abortController

    if (!this.navTarget.id) this.navTarget.id = "main-navigation"
    this.buttonTarget.setAttribute("aria-controls", this.navTarget.id)
    this.setOpen(false)

    this.navTarget.querySelectorAll("a").forEach((link) => {
      link.addEventListener("click", () => this.setOpen(false), { signal })
    })

    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape") this.setOpen(false)
    }, { signal })

    window.addEventListener("resize", () => {
      if (window.matchMedia("(min-width: 901px)").matches) this.setOpen(false)
    }, { signal })
  }

  disconnect() {
    this.abortController?.abort()
  }

  toggle() {
    this.setOpen(!this.element.classList.contains("is-menu-open"))
  }

  setOpen(open) {
    this.element.classList.toggle("is-menu-open", open)
    this.buttonTarget.classList.toggle("is-active", open)
    this.buttonTarget.setAttribute("aria-expanded", String(open))
    this.buttonTarget.setAttribute("aria-label", open ? this.closeLabel : this.openLabel)
  }

  get closeLabel() {
    return this.closeLabelValue || "Close menu"
  }

  get openLabel() {
    return this.openLabelValue || "Open menu"
  }
}
