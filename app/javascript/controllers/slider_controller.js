import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.abortController = new AbortController()
    this.slides = [...this.element.querySelectorAll(".klassik-slide")]
    this.previousButton = this.element.querySelector(".klassik-slider-arrow-prev")
    this.nextButton = this.element.querySelector(".klassik-slider-arrow-next")
    this.title = this.element.querySelector(".klassik-slider-meta h3")
    this.dateLocation = this.element.querySelector(".klassik-slider-date-location")
    this.partner = this.element.querySelector(".klassik-slider-partner")
    this.meta = this.element.querySelector(".klassik-slider-meta")
    this.activeIndex = Math.max(0, this.slides.findIndex((slide) => slide.classList.contains("is-active")))

    this.slides.forEach((slide, index) => {
      slide.addEventListener("click", () => this.setActive(index), { signal: this.abortController.signal })
      slide.addEventListener("keydown", (event) => {
        if (event.key !== "Enter" && event.key !== " ") return

        event.preventDefault()
        this.setActive(index)
      }, { signal: this.abortController.signal })
    })

    this.previousButton?.addEventListener("click", () => {
      this.setActive((this.activeIndex + this.slides.length - 1) % this.slides.length)
    }, { signal: this.abortController.signal })

    this.nextButton?.addEventListener("click", () => {
      this.setActive((this.activeIndex + 1) % this.slides.length)
    }, { signal: this.abortController.signal })

    this.render()
  }

  disconnect() {
    window.clearTimeout(this.transitionTimer)
    this.abortController?.abort()
  }

  setActive(index) {
    if (index === this.activeIndex || !this.slides.length) return

    this.activeIndex = index
    this.element.classList.add("is-moving")
    window.clearTimeout(this.transitionTimer)
    this.transitionTimer = window.setTimeout(() => this.element.classList.remove("is-moving"), 720)
    this.render()
  }

  render() {
    if (!this.slides.length) return

    const previous = (this.activeIndex + this.slides.length - 1) % this.slides.length
    const next = (this.activeIndex + 1) % this.slides.length

    this.slides.forEach((slide, index) => {
      const isActive = index === this.activeIndex
      slide.classList.toggle("is-active", isActive)
      slide.classList.toggle("is-prev", index === previous)
      slide.classList.toggle("is-next", index === next)
      slide.classList.toggle("is-hidden", !isActive && index !== previous && index !== next)
      slide.setAttribute("aria-hidden", isActive ? "false" : "true")
    })

    if (this.title) this.title.textContent = this.slides[this.activeIndex].dataset.title || ""
    if (this.dateLocation) this.dateLocation.textContent = this.slides[this.activeIndex].dataset.dateLocation || ""
    if (this.partner) this.partner.textContent = this.slides[this.activeIndex].dataset.partner || ""
    if (this.meta) {
      this.meta.classList.remove("is-updating")
      window.requestAnimationFrame(() => this.meta.classList.add("is-updating"))
    }
  }
}
