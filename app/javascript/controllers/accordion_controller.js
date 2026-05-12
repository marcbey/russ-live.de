import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.abortController = new AbortController()

    this.element.querySelectorAll(".accordion-item").forEach((item) => {
      const trigger = item.querySelector(".accordion-trigger")
      const icon = item.querySelector(".accordion-icon")
      if (!trigger) return

      trigger.addEventListener("click", () => {
        const open = item.classList.toggle("is-open")
        trigger.setAttribute("aria-expanded", String(open))
        if (icon) icon.textContent = open ? "−" : "+"
      }, { signal: this.abortController.signal })
    })
  }

  disconnect() {
    this.abortController?.abort()
  }
}
