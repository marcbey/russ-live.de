import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    threshold: { type: Number, default: 480 }
  }

  connect() {
    this.abortController = new AbortController()
    this.update()

    window.addEventListener("scroll", () => window.requestAnimationFrame(() => this.update()), {
      passive: true,
      signal: this.abortController.signal
    })
  }

  disconnect() {
    this.abortController?.abort()
  }

  scroll(event) {
    event.preventDefault()

    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    window.scrollTo({ top: 0, behavior: reducedMotion ? "auto" : "smooth" })
  }

  update() {
    this.element.classList.toggle("is-visible", window.scrollY > this.thresholdValue)
  }
}
