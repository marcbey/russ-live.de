import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.abortController = new AbortController()
    this.update()

    window.addEventListener("scroll", () => window.requestAnimationFrame(() => this.update()), {
      passive: true,
      signal: this.abortController.signal,
    })
    window.addEventListener("resize", () => this.update(), { signal: this.abortController.signal })
  }

  disconnect() {
    this.abortController?.abort()
  }

  update() {
    this.element.classList.toggle("is-scrolled", window.scrollY > 10)
  }
}
