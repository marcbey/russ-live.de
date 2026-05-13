import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["viewport", "card"]

  connect() {
    this.abortController = new AbortController()
    const { signal } = this.abortController

    this.viewportTarget.addEventListener("scroll", () => this.updateButtons(), {
      passive: true,
      signal,
    })

    window.addEventListener("resize", () => this.updateButtons(), { signal })
    this.updateButtons()
  }

  disconnect() {
    this.abortController?.abort()
  }

  previous() {
    this.slideBy(-1)
  }

  next() {
    this.slideBy(1)
  }

  slideBy(direction) {
    if (!this.hasCardTarget) return

    const card = this.cardTargets[0]
    const styles = window.getComputedStyle(this.viewportTarget.firstElementChild)
    const gap = Number.parseFloat(styles.columnGap || styles.gap) || 0
    const visibleCards = window.matchMedia("(max-width: 900px)").matches ? 1 : 5
    const distance = (card.getBoundingClientRect().width + gap) * visibleCards * direction

    this.viewportTarget.scrollBy({ left: distance, behavior: "smooth" })
  }

  updateButtons() {
    const previousButton = this.element.querySelector('[data-action*="events-slider#previous"]')
    const nextButton = this.element.querySelector('[data-action*="events-slider#next"]')
    const maxScrollLeft = this.viewportTarget.scrollWidth - this.viewportTarget.clientWidth - 1

    previousButton?.toggleAttribute("disabled", this.viewportTarget.scrollLeft <= 1)
    nextButton?.toggleAttribute("disabled", this.viewportTarget.scrollLeft >= maxScrollLeft)
  }
}
