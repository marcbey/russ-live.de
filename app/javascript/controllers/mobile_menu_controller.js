import { Controller } from "@hotwired/stimulus"

const DESKTOP_BREAKPOINT = "(min-width: 1071px)"

export default class extends Controller {
  static targets = ["button", "nav", "submenuToggle"]
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
      if (window.matchMedia(DESKTOP_BREAKPOINT).matches) this.setOpen(false)
    }, { signal })
  }

  disconnect() {
    this.abortController?.abort()
  }

  toggle() {
    this.setOpen(!this.element.classList.contains("is-menu-open"))
  }

  toggleSubmenu(event) {
    const button = event.currentTarget
    const shouldOpen = button.getAttribute("aria-expanded") !== "true"

    this.submenuToggleTargets.forEach((toggle) => {
      this.setSubmenuOpen(toggle, toggle === button && shouldOpen)
    })
  }

  setOpen(open) {
    this.element.classList.toggle("is-menu-open", open)
    this.buttonTarget.classList.toggle("is-active", open)
    this.buttonTarget.setAttribute("aria-expanded", String(open))
    this.buttonTarget.setAttribute("aria-label", open ? this.closeLabel : this.openLabel)
    if (!open) this.submenuToggleTargets.forEach((button) => this.setSubmenuOpen(button, false))
  }

  setSubmenuOpen(button, open) {
    button.closest(".nav-item")?.classList.toggle("is-submenu-open", open)
    button.setAttribute("aria-expanded", String(open))
    button.setAttribute("aria-label", open ? button.dataset.closeLabel : button.dataset.openLabel)
  }

  get closeLabel() {
    return this.closeLabelValue || "Close menu"
  }

  get openLabel() {
    return this.openLabelValue || "Open menu"
  }
}
