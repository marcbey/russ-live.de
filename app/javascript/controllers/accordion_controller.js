import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.abortController = new AbortController()

    this.items.forEach((item) => {
      const trigger = item.querySelector(".accordion-trigger")
      if (!trigger) return

      trigger.addEventListener("click", () => {
        const open = !item.classList.contains("is-open")
        this.closeItemsExcept(item)
        this.setItemOpen(item, open)
      }, { signal: this.abortController.signal })
    })
  }

  disconnect() {
    this.abortController?.abort()
  }

  get items() {
    return Array.from(this.element.children).filter((child) => child.classList.contains("accordion-item"))
  }

  closeItemsExcept(activeItem) {
    this.items.forEach((item) => {
      if (item !== activeItem) this.setItemOpen(item, false)
    })
  }

  setItemOpen(item, open) {
    const trigger = item.querySelector(".accordion-trigger")
    const icon = item.querySelector(".accordion-icon")

    item.classList.toggle("is-open", open)
    trigger?.setAttribute("aria-expanded", String(open))
    if (icon) icon.textContent = open ? "−" : "+"
  }
}
