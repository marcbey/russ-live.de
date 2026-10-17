import { Controller } from "@hotwired/stimulus"

const DESKTOP_BREAKPOINT = "(min-width: 1071px)"
const FOCUSABLE = 'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'

export default class extends Controller {
  static targets = ["button", "nav", "submenuToggle"]
  static values = { closeLabel: String, openLabel: String }

  connect() {
    this.abortController = new AbortController()
    const { signal } = this.abortController
    this.inertElements = new Map()
    if (!this.navTarget.id) this.navTarget.id = "main-navigation"
    this.buttonTarget.setAttribute("aria-controls", this.navTarget.id)
    this.setOpen(false, { restoreFocus: false })

    this.navTarget.querySelectorAll("a").forEach((link) => {
      link.addEventListener("click", () => this.setOpen(false), { signal })
    })
    this.navTarget.querySelectorAll(".has-submenu").forEach((item) => {
      item.addEventListener("pointerenter", () => this.syncSubmenu(item), { signal })
      item.addEventListener("pointerleave", () => {
        if (!item.contains(document.activeElement)) item.classList.remove("is-submenu-dismissed")
        this.syncSubmenu(item)
      }, { signal })
      item.addEventListener("focusin", () => this.syncSubmenu(item), { signal })
      item.addEventListener("focusout", (event) => {
        if (item.contains(event.relatedTarget)) return

        item.classList.remove("is-submenu-dismissed")
        this.syncSubmenu(item)
      }, { signal })
      this.syncSubmenu(item)
    })

    document.addEventListener("keydown", (event) => this.handleKeydown(event), { signal })
    document.addEventListener("focusin", (event) => {
      if (this.isOpen && !this.navTarget.contains(event.target) && event.target !== this.buttonTarget) this.focusMenu()
    }, { signal })
    document.addEventListener("turbo:before-cache", () => this.setOpen(false), { signal })
    window.addEventListener("resize", () => {
      if (this.isDesktop) this.setOpen(false)
      this.navTarget.querySelectorAll(".has-submenu").forEach((item) => this.syncSubmenu(item))
    }, { signal })
  }

  disconnect() {
    this.setOpen(false)
    this.abortController?.abort()
  }

  toggle() {
    this.setOpen(!this.isOpen)
  }

  toggleSubmenu(event) {
    const button = event.currentTarget
    const shouldOpen = button.getAttribute("aria-expanded") !== "true"
    this.submenuToggleTargets.forEach((toggle) => {
      toggle.closest(".nav-item")?.classList.remove("is-submenu-dismissed")
      this.setSubmenuOpen(toggle, toggle === button && shouldOpen)
    })
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      const item = document.activeElement.closest(".has-submenu")
      if (item && (this.isDesktop || item.classList.contains("is-submenu-open"))) {
        event.preventDefault()
        item.classList.add("is-submenu-dismissed")
        const toggle = item.querySelector(".nav-submenu-toggle")
        if (toggle) this.setSubmenuOpen(toggle, false)
        item.querySelector(".nav-submenu").inert = true
        item.querySelector(":scope > a")?.focus()
      } else if (this.isOpen) {
        event.preventDefault()
        this.setOpen(false)
      }
    }
    if (event.key !== "Tab" || !this.isOpen) return

    const controls = [...this.navTarget.querySelectorAll(FOCUSABLE), this.buttonTarget]
      .filter((control) => control.getClientRects().length && !control.closest("[inert]"))
    const index = controls.indexOf(document.activeElement)
    const nextIndex = (index + (event.shiftKey ? -1 : 1) + controls.length) % controls.length
    event.preventDefault()
    controls[nextIndex]?.focus()
  }

  setOpen(open, { restoreFocus = true } = {}) {
    const wasOpen = this.isOpen
    this.element.classList.toggle("is-menu-open", open)
    this.buttonTarget.classList.toggle("is-active", open)
    this.buttonTarget.setAttribute("aria-expanded", String(open))
    this.buttonTarget.setAttribute("aria-label", open ? this.closeLabel : this.openLabel)
    if (open && !wasOpen) {
      this.previousOverflow = document.body.style.overflow
      document.body.style.overflow = "hidden"
      let branch = this.element
      while (branch.parentElement) {
        [...branch.parentElement.children].filter((sibling) => sibling !== branch).forEach((sibling) => {
          this.inertElements.set(sibling, sibling.inert)
          sibling.inert = true
        })
        branch = branch.parentElement
        if (branch === document.body) break
      }
      this.focusMenu()
    } else if (!open) {
      this.inertElements.forEach((inert, element) => { element.inert = inert })
      this.inertElements.clear()
      if (wasOpen) document.body.style.overflow = this.previousOverflow
      this.submenuToggleTargets.forEach((button) => this.setSubmenuOpen(button, false))
      if (wasOpen && restoreFocus) {
        const target = this.isDesktop ? this.navTarget.querySelector("a") : this.buttonTarget
        if (target?.isConnected) target.focus({ preventScroll: true })
      }
    }
  }

  focusMenu() {
    this.navTarget.querySelector("a")?.focus({ preventScroll: true })
  }

  syncSubmenu(item) {
    const open = this.isDesktop
      ? !item.classList.contains("is-submenu-dismissed") && (item.matches(":hover") || item.contains(document.activeElement))
      : item.classList.contains("is-submenu-open")
    item.querySelector(".nav-submenu").inert = !open
  }

  setSubmenuOpen(button, open) {
    const item = button.closest(".nav-item")
    item?.classList.toggle("is-submenu-open", open)
    button.setAttribute("aria-expanded", String(open))
    button.setAttribute("aria-label", open ? button.dataset.closeLabel : button.dataset.openLabel)
    if (item) this.syncSubmenu(item)
  }

  get isOpen() {
    return this.element.classList.contains("is-menu-open")
  }

  get isDesktop() {
    return window.matchMedia(DESKTOP_BREAKPOINT).matches
  }

  get closeLabel() { return this.closeLabelValue || "Close menu" }
  get openLabel() { return this.openLabelValue || "Open menu" }
}
