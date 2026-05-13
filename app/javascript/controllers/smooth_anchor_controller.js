import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.abortController = new AbortController()

    this.element.querySelectorAll('a[href^="#"]').forEach((link) => {
      if (link.closest(".services-jump-nav")) return

      link.addEventListener("click", (event) => {
        const targetId = link.getAttribute("href")
        if (!targetId || targetId === "#") return

        const target = document.querySelector(targetId)
        if (!target) return

        event.preventDefault()

        if (link.dataset.anchorPosition === "flush") {
          const targetTop = target.getBoundingClientRect().top + window.scrollY
          window.scrollTo({ top: targetTop, behavior: "smooth" })
          return
        }

        target.scrollIntoView({ behavior: "smooth", block: "start" })
      }, { signal: this.abortController.signal })
    })
  }

  disconnect() {
    this.abortController?.abort()
  }
}
