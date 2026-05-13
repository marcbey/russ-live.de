import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["trigger", "lightbox", "image", "caption", "download", "close"]

  connect() {
    this.abortController = new AbortController()
    this.activeIndex = 0

    this.lightboxTarget.addEventListener("click", (event) => {
      if (event.target === this.lightboxTarget) this.close()
    }, { signal: this.abortController.signal })

    document.addEventListener("keydown", (event) => {
      if (this.lightboxTarget.hidden) return

      if (event.key === "Escape") this.close()
      if (event.key === "ArrowLeft") this.previous()
      if (event.key === "ArrowRight") this.next()
    }, { signal: this.abortController.signal })
  }

  disconnect() {
    this.abortController?.abort()
    document.body.style.overflow = ""
  }

  open(event) {
    const index = this.triggerTargets.indexOf(event.currentTarget)

    this.render(index)
    this.lightboxTarget.hidden = false
    document.body.style.overflow = "hidden"
    this.closeTarget.focus()
  }

  close() {
    this.lightboxTarget.hidden = true
    document.body.style.overflow = ""
  }

  previous() {
    this.render(this.activeIndex - 1)
  }

  next() {
    this.render(this.activeIndex + 1)
  }

  render(index) {
    this.activeIndex = (index + this.triggerTargets.length) % this.triggerTargets.length

    const trigger = this.triggerTargets[this.activeIndex]
    const src = trigger.dataset.lightboxSrc || ""
    const alt = trigger.dataset.lightboxAlt || "Pressebild"

    this.imageTarget.src = src
    this.imageTarget.alt = alt
    this.captionTarget.textContent = alt
    this.downloadTarget.href = src
  }
}
