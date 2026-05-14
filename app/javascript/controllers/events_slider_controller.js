import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["viewport", "card"]
  static values = {
    cursor: String,
    maxPagesDesktop: { type: Number, default: 3 },
    maxPagesMobile: { type: Number, default: 2 },
    perPage: { type: Number, default: 10 },
    url: String,
  }

  connect() {
    this.abortController = new AbortController()
    this.requestAbortController = null
    this.loading = false
    this.pageIndex = 0
    this.pages = []
    this.storedPages = new Map()
    this.userInteracted = false
    this.raf = null
    const { signal } = this.abortController

    this.handleScroll = this.handleScroll.bind(this)
    this.markUserInteraction = this.markUserInteraction.bind(this)

    this.viewportTarget.addEventListener("scroll", this.handleScroll, {
      passive: true,
      signal,
    })
    this.viewportTarget.addEventListener("keydown", this.markUserInteraction, { signal })
    this.viewportTarget.addEventListener("pointerdown", this.markUserInteraction, { passive: true, signal })
    this.viewportTarget.addEventListener("touchstart", this.markUserInteraction, { passive: true, signal })
    this.viewportTarget.addEventListener("wheel", this.markUserInteraction, { passive: true, signal })

    window.addEventListener("resize", () => this.updateButtons(), { signal })
    this.registerInitialPage()
    this.updateButtons()
  }

  disconnect() {
    if (this.raf) window.cancelAnimationFrame(this.raf)
    this.abortPendingRequest()
    this.abortController?.abort()
  }

  previous() {
    this.slideBy(-1)
  }

  next() {
    this.slideBy(1)
  }

  slideBy(direction) {
    if (!this.hasCardTarget) return

    this.markUserInteraction()

    if (direction > 0 && this.atEnd() && this.canLoad) {
      this.load({ advance: true })
      return
    }

    const card = this.cardTargets[0]
    const styles = window.getComputedStyle(this.viewportTarget.firstElementChild)
    const gap = Number.parseFloat(styles.columnGap || styles.gap) || 0
    const visibleCards = window.matchMedia("(max-width: 900px)").matches ? 1 : 5
    const distance = (card.getBoundingClientRect().width + gap) * visibleCards * direction

    this.viewportTarget.scrollBy({ left: distance, behavior: "smooth" })
  }

  handleScroll() {
    this.updateButtons()
    if (!this.userInteracted) return

    this.scheduleLaneWork()
  }

  markUserInteraction() {
    this.userInteracted = true
  }

  async load({ advance = false } = {}) {
    if (this.loading || !this.canLoad) return

    this.loading = true
    this.abortPendingRequest()

    const abortController = new AbortController()
    this.requestAbortController = abortController

    try {
      const response = await fetch(this.requestUrl(), {
        headers: {
          Accept: "text/html",
          "X-Requested-With": "XMLHttpRequest",
        },
        credentials: "same-origin",
        signal: abortController.signal,
      })

      if (!response.ok) throw new Error(`Homepage events lane request failed (${response.status})`)

      const html = await response.text()
      const nextCursor = response.headers.get("X-Homepage-Lane-Next-Cursor") || ""
      let appendedElements = []

      if (html.trim().length > 0) appendedElements = this.appendPage(html)

      this.cursorValue = nextCursor
      this.updateButtons()
      this.scheduleLaneWork()
      if (advance) this.scrollToAppendedPage(appendedElements)
    } catch (error) {
      if (error.name !== "AbortError") console.error(error)
    } finally {
      if (this.requestAbortController === abortController) this.requestAbortController = null
      this.loading = false
    }
  }

  requestUrl() {
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("cursor", this.cursorValue)
    url.searchParams.set("per_page", this.perPageValue.toString())
    return url.toString()
  }

  appendPage(html) {
    const template = document.createElement("template")
    template.innerHTML = html.trim()
    const elements = Array.from(template.content.children).filter((element) => element instanceof HTMLElement)
    if (elements.length === 0) return []

    const index = ++this.pageIndex
    elements.forEach((element) => {
      element.dataset.eventsSliderPage = index.toString()
      this.viewportTarget.appendChild(element)
    })
    this.pages.push({ index, elements })
    return elements
  }

  scrollToAppendedPage(elements) {
    const firstElement = elements.find((element) => element instanceof HTMLElement)
    if (!firstElement) return

    window.requestAnimationFrame(() => {
      this.viewportTarget.scrollTo({ left: firstElement.offsetLeft, behavior: "smooth" })
    })
  }

  registerInitialPage() {
    const elements = Array.from(this.viewportTarget.children).filter((element) => element instanceof HTMLElement)
    elements.forEach((element) => {
      element.dataset.eventsSliderPage = "0"
    })
    this.pages = [{ index: 0, elements }]
  }

  scheduleLaneWork() {
    if (this.raf) return

    this.raf = window.requestAnimationFrame(() => {
      this.raf = null
      this.restoreNearbyPlaceholders()
      this.pruneDistantPages()
      if (this.nearEnd()) this.load()
    })
  }

  pruneDistantPages() {
    const activePages = this.pages.filter((page) => !this.pagePruned(page))
    const removableCount = activePages.length - this.maxRenderedPages
    if (removableCount <= 0) return

    const pruneBefore = this.viewportTarget.scrollLeft - this.viewportTarget.clientWidth
    let pruned = 0

    for (const page of activePages) {
      if (pruned >= removableCount) break
      if (this.pageEnd(page) >= pruneBefore) continue

      this.prunePage(page)
      pruned += 1
    }
  }

  prunePage(page) {
    const stored = []

    page.elements = page.elements.map((element) => {
      if (!element.isConnected || this.isPlaceholder(element)) return element

      const placeholder = document.createElement(element.tagName.toLowerCase())
      placeholder.className = `${element.className} home-events-placeholder`
      placeholder.dataset.eventsSliderPage = page.index.toString()
      placeholder.dataset.eventsSliderPlaceholder = "true"
      placeholder.setAttribute("aria-hidden", "true")
      stored.push(element.outerHTML)
      element.replaceWith(placeholder)
      return placeholder
    })

    if (stored.length > 0) this.storedPages.set(page.index, stored)
  }

  restoreNearbyPlaceholders() {
    const viewportStart = this.viewportTarget.scrollLeft - this.viewportTarget.clientWidth
    const viewportEnd = this.viewportTarget.scrollLeft + (this.viewportTarget.clientWidth * 2)

    this.pages.forEach((page) => {
      if (!this.pagePruned(page)) return
      if (this.pageEnd(page) < viewportStart || this.pageStart(page) > viewportEnd) return

      this.restorePage(page)
    })
  }

  restorePage(page) {
    const stored = this.storedPages.get(page.index)
    if (!stored) return

    page.elements = page.elements.map((placeholder, index) => {
      if (!this.isPlaceholder(placeholder)) return placeholder

      const template = document.createElement("template")
      template.innerHTML = stored[index] || ""
      const restored = template.content.firstElementChild
      if (!(restored instanceof HTMLElement)) return placeholder

      restored.dataset.eventsSliderPage = page.index.toString()
      placeholder.replaceWith(restored)
      return restored
    })

    this.storedPages.delete(page.index)
  }

  nearEnd() {
    if (!this.canLoad) return false

    const remaining = this.viewportTarget.scrollWidth - this.viewportTarget.clientWidth - this.viewportTarget.scrollLeft
    return remaining < this.viewportTarget.clientWidth * 1.15
  }

  atEnd() {
    const maxScrollLeft = this.viewportTarget.scrollWidth - this.viewportTarget.clientWidth
    return this.viewportTarget.scrollLeft >= maxScrollLeft - 4
  }

  updateButtons() {
    const previousButton = this.element.querySelector('[data-action*="events-slider#previous"]')
    const nextButton = this.element.querySelector('[data-action*="events-slider#next"]')
    const maxScrollLeft = this.viewportTarget.scrollWidth - this.viewportTarget.clientWidth - 1

    previousButton?.toggleAttribute("disabled", this.viewportTarget.scrollLeft <= 1)
    nextButton?.toggleAttribute("disabled", this.viewportTarget.scrollLeft >= maxScrollLeft && !this.canLoad)
  }

  pageStart(page) {
    return Math.min(...page.elements.map((element) => element.offsetLeft))
  }

  pageEnd(page) {
    return Math.max(...page.elements.map((element) => element.offsetLeft + element.offsetWidth))
  }

  pagePruned(page) {
    return page.elements.some((element) => this.isPlaceholder(element))
  }

  isPlaceholder(element) {
    return element.dataset.eventsSliderPlaceholder === "true"
  }

  abortPendingRequest() {
    if (!this.requestAbortController) return

    this.requestAbortController.abort()
    this.requestAbortController = null
  }

  get canLoad() {
    return this.hasUrlValue && this.hasCursorValue && this.cursorValue.length > 0
  }

  get maxRenderedPages() {
    return window.matchMedia("(max-width: 900px)").matches ? this.maxPagesMobileValue : this.maxPagesDesktopValue
  }
}
