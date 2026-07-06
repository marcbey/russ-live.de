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
        this.scrollToTarget(target, { flush: link.dataset.anchorPosition === "flush" })
      }, { signal: this.abortController.signal })
    })

    this.alignInitialHash()
  }

  disconnect() {
    this.abortController?.abort()
  }

  alignInitialHash() {
    if (!window.location.hash) return

    const target = document.querySelector(window.location.hash)
    if (!target) return

    const align = () => {
      this.scrollToTarget(target, { smooth: false })
      window.requestAnimationFrame(() => this.scrollToTarget(target, { smooth: false }))
    }

    if (document.readyState === "complete") {
      align()
    } else {
      window.addEventListener("load", align, { once: true, signal: this.abortController.signal })
    }
  }

  scrollToTarget(target, { flush = false, smooth = true } = {}) {
    const targetTop = target.getBoundingClientRect().top + window.scrollY
    const offset = flush ? this.headerOffset() : this.scrollMargin(target)

    window.scrollTo({
      top: Math.max(targetTop - offset, 0),
      behavior: smooth ? "smooth" : "auto",
    })
  }

  scrollMargin(target) {
    const margin = Number.parseFloat(getComputedStyle(target).scrollMarginTop)

    return Number.isFinite(margin) && margin > 0 ? margin : this.headerOffset()
  }

  headerOffset() {
    const header = document.querySelector(".site-header")

    return header?.getBoundingClientRect().height || 0
  }
}
