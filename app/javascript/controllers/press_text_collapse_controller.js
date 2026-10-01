import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["body", "button"]

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
    const isExpanded = !this.element.classList.contains("is-expanded")

    this.setExpanded(isExpanded)

    if (!isExpanded) {
      requestAnimationFrame(() => this.scrollToTextStart())
    }
  }

  refresh() {
    const wasExpanded = this.element.classList.contains("is-expanded")

    this.setExpanded(false)
    this.element.classList.add("is-overflowing")

    const collapsedHeight = Number.parseFloat(getComputedStyle(this.bodyTarget).maxHeight)
    const overflows = this.bodyTarget.scrollHeight > collapsedHeight + 1

    this.element.classList.toggle("is-overflowing", overflows)
    this.buttonTarget.hidden = !overflows
    this.setExpanded(overflows && wasExpanded)
  }

  setExpanded(isExpanded) {
    this.element.classList.toggle("is-expanded", isExpanded)
    this.buttonTarget.setAttribute("aria-expanded", isExpanded.toString())
  }

  scrollToTextStart() {
    const scrollTarget = this.element.closest(".press-text-panel")?.querySelector(".eyebrow") || this.bodyTarget
    const headerHeight = document.querySelector(".page-header")?.offsetHeight || 0
    const scrollGap = window.matchMedia("(max-width: 700px)").matches ? 88 : 28
    const top = scrollTarget.getBoundingClientRect().top + window.scrollY - headerHeight - scrollGap
    const behavior = window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth"

    window.scrollTo({ top, behavior })
  }
}
