import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.abortController = new AbortController()
    this.links = [...this.element.querySelectorAll('a[href^="#"]')]
    this.sections = this.links
      .map((link) => {
        const target = document.querySelector(link.getAttribute("href"))
        return target ? { link, target } : null
      })
      .filter(Boolean)

    if (!this.sections.length) return

    this.links.forEach((link) => {
      link.addEventListener("click", (event) => this.scrollToLinkedSection(event, link), {
        signal: this.abortController.signal,
      })
    })

    this.updateActive()
    window.addEventListener("scroll", () => window.requestAnimationFrame(() => this.updateActive()), {
      passive: true,
      signal: this.abortController.signal,
    })
    window.addEventListener("resize", () => this.updateActive(), { signal: this.abortController.signal })
    this.alignInitialHash()
  }

  disconnect() {
    this.abortController?.abort()
  }

  scrollToLinkedSection(event, link) {
    const section = this.sections.find((item) => item.link === link)
    if (!section) return

    event.preventDefault()
    this.setActive(link)
    this.scrollToSection(section.target)
    history.pushState(null, "", link.getAttribute("href"))
  }

  alignInitialHash() {
    if (!window.location.hash) return

    const section = this.sections.find((item) => item.link.getAttribute("href") === window.location.hash)
    if (!section) return

    const align = () => {
      this.scrollToSection(section.target, false)
      this.setActive(section.link)
      window.requestAnimationFrame(() => this.scrollToSection(section.target, false))
    }

    if (document.readyState === "complete") {
      align()
    } else {
      window.addEventListener("load", align, { once: true, signal: this.abortController.signal })
    }
  }

  anchorLine() {
    return this.element.getBoundingClientRect().bottom + 40
  }

  stickyOffset() {
    const top = Number.parseFloat(getComputedStyle(this.element).top) || 0
    return top + this.element.offsetHeight
  }

  scrollToSection(target, smooth = true) {
    window.scrollTo({
      top: target.getBoundingClientRect().top + window.scrollY - this.stickyOffset(),
      behavior: smooth ? "smooth" : "auto",
    })
  }

  updateActive() {
    let active = this.sections[0]

    this.sections.forEach((section) => {
      if (section.target.getBoundingClientRect().top <= this.anchorLine()) active = section
    })

    this.setActive(active.link)
  }

  setActive(activeLink) {
    this.links.forEach((link) => {
      const active = link === activeLink
      const wasActive = link.classList.contains("is-active")

      link.classList.toggle("is-active", active)
      if (active) {
        link.setAttribute("aria-current", "true")
        if (!wasActive) {
          this.element.scrollTo({
            left: link.offsetLeft - (this.element.clientWidth - link.clientWidth) / 2,
            behavior: "smooth",
          })
        }
      } else {
        link.removeAttribute("aria-current")
      }
    })
  }
}
