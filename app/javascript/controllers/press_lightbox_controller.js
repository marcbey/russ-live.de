import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["trigger", "lightbox", "image", "caption", "download", "close"]
  static values = {
    fallbackAlt: String,
  }

  connect() {
    this.abortController = new AbortController()
    this.activeIndex = 0
    this.inertElements = new Map()

    this.lightboxTarget.addEventListener("click", (event) => {
      if (event.target === this.lightboxTarget) this.close()
    }, { signal: this.abortController.signal })

    document.addEventListener("keydown", (event) => {
      if (this.lightboxTarget.hidden) return

      if (event.key === "Tab") {
        const controls = [...this.lightboxTarget.querySelectorAll('button:not([disabled]), a[href], [tabindex]:not([tabindex="-1"])')]
          .filter((control) => control.getClientRects().length)
        const index = controls.indexOf(document.activeElement)
        const nextIndex = (index + (event.shiftKey ? -1 : 1) + controls.length) % controls.length
        event.preventDefault()
        controls[nextIndex]?.focus()
      }
      if (event.key === "Escape") {
        event.preventDefault()
        this.close()
      }
      if (event.key === "ArrowLeft") this.previous()
      if (event.key === "ArrowRight") this.next()
    }, { signal: this.abortController.signal })
    document.addEventListener("focusin", (event) => {
      if (!this.lightboxTarget.hidden && !this.lightboxTarget.contains(event.target)) this.closeTarget.focus()
    }, { signal: this.abortController.signal })
    document.addEventListener("turbo:before-cache", () => this.close(), { signal: this.abortController.signal })
  }

  disconnect() {
    this.close()
    this.abortController?.abort()
  }

  open(event) {
    const index = this.triggerTargets.indexOf(event.currentTarget)

    this.activeTrigger = event.currentTarget
    this.render(index)
    this.previousOverflow = document.body.style.overflow
    this.lightboxTarget.hidden = false
    document.body.style.overflow = "hidden"
    this.closeTarget.focus()
    let branch = this.lightboxTarget
    while (branch.parentElement) {
      [...branch.parentElement.children].filter((sibling) => sibling !== branch).forEach((sibling) => {
        this.inertElements.set(sibling, sibling.inert)
        sibling.inert = true
      })
      branch = branch.parentElement
      if (branch === document.body) break
    }
  }

  close() {
    if (this.lightboxTarget.hidden) return

    this.lightboxTarget.hidden = true
    this.inertElements.forEach((inert, element) => { element.inert = inert })
    this.inertElements.clear()
    document.body.style.overflow = this.previousOverflow
    if (this.activeTrigger?.isConnected) this.activeTrigger.focus({ preventScroll: true })
    this.activeTrigger = null
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
    const download = trigger.dataset.lightboxDownload || src
    const alt = trigger.dataset.lightboxAlt || this.fallbackAlt
    const caption = trigger.dataset.lightboxCaption || ""

    this.imageTarget.src = src
    this.imageTarget.alt = alt
    this.captionTarget.textContent = caption
    this.downloadTarget.href = download
  }

  get fallbackAlt() {
    return this.fallbackAltValue || "Press image"
  }
}
