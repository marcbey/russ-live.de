import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item"]
  static values = { url: String }

  dragStart(event) {
    this.draggedItem = event.currentTarget
    this.draggedItem.classList.add("is-dragging")
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", this.draggedItem.dataset.backendSortableListJobId)
  }

  dragOver(event) {
    event.preventDefault()
    if (!this.draggedItem) return

    const target = event.currentTarget
    if (target === this.draggedItem) return

    const targetRect = target.getBoundingClientRect()
    const insertAfter = event.clientY > targetRect.top + (targetRect.height / 2)
    this.element.insertBefore(this.draggedItem, insertAfter ? target.nextElementSibling : target)
  }

  drop(event) {
    event.preventDefault()
    this.saveOrder()
  }

  dragEnd() {
    this.draggedItem?.classList.remove("is-dragging")
    this.draggedItem = null
  }

  async saveOrder() {
    if (!this.hasUrlValue) return

    this.element.classList.add("is-saving")

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: this.headers(),
        body: JSON.stringify({ job_ids: this.orderedJobIds() })
      })

      if (!response.ok) throw new Error("Reihenfolge konnte nicht gespeichert werden.")
    } catch (_error) {
      window.location.reload()
    } finally {
      this.element.classList.remove("is-saving")
    }
  }

  orderedJobIds() {
    return this.itemTargets.map((item) => item.dataset.backendSortableListJobId)
  }

  headers() {
    return {
      "Accept": "application/json",
      "Content-Type": "application/json",
      "X-CSRF-Token": this.csrfToken()
    }
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }
}
