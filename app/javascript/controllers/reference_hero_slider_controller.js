import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slide"]
  static values = {
    interval: { type: Number, default: 6200 },
  }

  connect() {
    this.abortController = new AbortController()
    this.mediaQuery = window.matchMedia("(prefers-reduced-motion: reduce)")
    this.activeIndex = Math.max(0, this.slideTargets.findIndex((slide) => slide.classList.contains("is-active")))
    this.paused = false

    this.handlePointerEnter = this.handlePointerEnter.bind(this)
    this.handlePointerLeave = this.handlePointerLeave.bind(this)
    this.handleFocusIn = this.handleFocusIn.bind(this)
    this.handleFocusOut = this.handleFocusOut.bind(this)
    this.handleMotionPreferenceChange = this.handleMotionPreferenceChange.bind(this)

    const { signal } = this.abortController
    this.element.addEventListener("pointerenter", this.handlePointerEnter, { signal })
    this.element.addEventListener("pointerleave", this.handlePointerLeave, { signal })
    this.element.addEventListener("focusin", this.handleFocusIn, { signal })
    this.element.addEventListener("focusout", this.handleFocusOut, { signal })
    this.mediaQuery.addEventListener("change", this.handleMotionPreferenceChange, { signal })

    this.render()
    this.handleMotionPreferenceChange()
  }

  disconnect() {
    this.stopAutoplay()
    this.abortController?.abort()
  }

  previous() {
    this.show(this.activeIndex - 1)
    this.restartAutoplay()
  }

  next() {
    this.show(this.activeIndex + 1)
    this.restartAutoplay()
  }

  handlePointerEnter() {
    this.paused = true
    this.stopAutoplay()
  }

  handlePointerLeave() {
    this.paused = false
    this.startAutoplay()
  }

  handleFocusIn() {
    this.paused = true
    this.stopAutoplay()
  }

  handleFocusOut() {
    if (this.element.contains(document.activeElement)) return

    this.paused = false
    this.startAutoplay()
  }

  handleMotionPreferenceChange() {
    this.restartAutoplay()
  }

  startAutoplay() {
    if (this.timer || this.paused || this.mediaQuery.matches || this.slideTargets.length < 2) return

    this.timer = window.setInterval(() => this.show(this.activeIndex + 1), this.intervalValue)
  }

  stopAutoplay() {
    window.clearInterval(this.timer)
    this.timer = null
  }

  restartAutoplay() {
    this.stopAutoplay()
    this.startAutoplay()
  }

  show(index) {
    if (!this.slideTargets.length) return

    this.activeIndex = (index + this.slideTargets.length) % this.slideTargets.length
    this.render()
  }

  render() {
    this.slideTargets.forEach((slide, index) => {
      const active = index === this.activeIndex
      slide.classList.toggle("is-active", active)
      slide.setAttribute("aria-hidden", active ? "false" : "true")
    })
  }
}
