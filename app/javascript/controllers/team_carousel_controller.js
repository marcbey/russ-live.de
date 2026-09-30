import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["viewport", "card", "previous", "next"]

  connect() {
    this.abortController = new AbortController()
    this.updateButtons = this.updateButtons.bind(this)
    const { signal } = this.abortController

    this.viewportTarget.addEventListener("scroll", this.updateButtons, { passive: true, signal })
    window.addEventListener("resize", this.updateButtons, { signal })
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

    const cardWidth = this.cardTargets[0].getBoundingClientRect().width
    const styles = window.getComputedStyle(this.viewportTarget)
    const gap = Number.parseFloat(styles.columnGap || styles.gap) || 0
    const visibleCards = Math.max(1, Math.floor(this.viewportTarget.clientWidth / (cardWidth + gap)))

    this.viewportTarget.scrollBy({
      left: direction * (cardWidth + gap) * visibleCards,
      behavior: "smooth",
    })
  }

  updateButtons() {
    const tolerance = 2
    const atStart = this.viewportTarget.scrollLeft <= tolerance
    const atEnd = this.viewportTarget.scrollLeft + this.viewportTarget.clientWidth >= this.viewportTarget.scrollWidth - tolerance

    if (this.hasPreviousTarget) this.previousTarget.disabled = atStart
    if (this.hasNextTarget) this.nextTarget.disabled = atEnd
  }
}
