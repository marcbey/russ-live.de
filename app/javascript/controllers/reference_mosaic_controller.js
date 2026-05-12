import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.abortController = new AbortController()
    this.layout = this.layout.bind(this)
    this.bindFilters()
    this.bindCardFlips()
    this.bindImageLoading()
    this.layout()
    window.addEventListener("resize", this.layout, { signal: this.abortController.signal })
  }

  disconnect() {
    this.abortController?.abort()
  }

  bindFilters() {
    const nav = this.element.querySelector(".references-year-nav")
    const mosaic = this.mosaic
    if (!nav || !mosaic) return

    nav.querySelectorAll("button[data-year]").forEach((button) => {
      button.addEventListener("click", () => {
        const year = button.dataset.year || "all"
        nav.querySelectorAll("button").forEach((item) => item.setAttribute("aria-pressed", "false"))
        button.setAttribute("aria-pressed", "true")

        mosaic.querySelectorAll(".reference-card").forEach((card) => {
          card.hidden = year !== "all" && card.dataset.year !== year
          if (card.hidden) {
            card.classList.remove("is-flipped")
            card.querySelector(".reference-card-flip")?.setAttribute("aria-pressed", "false")
          }
        })

        this.layout()
      }, { signal: this.abortController.signal })
    })
  }

  bindCardFlips() {
    this.element.querySelectorAll(".reference-card-flip").forEach((button) => {
      const card = button.closest(".reference-card")
      if (!card) return

      let lastPointerType = ""

      button.addEventListener("pointerdown", (event) => {
        lastPointerType = event.pointerType
      }, { signal: this.abortController.signal })

      button.addEventListener("touchend", () => {
        lastPointerType = "touch"
      }, { passive: true, signal: this.abortController.signal })

      button.addEventListener("click", () => {
        if (this.usesHover() || lastPointerType !== "touch") {
          button.blur()
          return
        }

        this.setCardFlipped(card, button, !card.classList.contains("is-flipped"))
      }, { signal: this.abortController.signal })

      card.addEventListener("mouseenter", () => {
        if (this.usesHover()) this.setCardFlipped(card, button, true)
      }, { signal: this.abortController.signal })

      card.addEventListener("mouseleave", () => {
        if (this.usesHover()) this.setCardFlipped(card, button, false)
      }, { signal: this.abortController.signal })
    })

    document.addEventListener("keydown", (event) => {
      if (event.key !== "Escape") return

      this.element.querySelectorAll(".reference-card.is-flipped").forEach((card) => {
        card.classList.remove("is-flipped")
        card.querySelector(".reference-card-flip")?.setAttribute("aria-pressed", "false")
      })
      this.layout()
    }, { signal: this.abortController.signal })
  }

  bindImageLoading() {
    this.element.querySelectorAll('[data-layout="mosaic"] img').forEach((image) => {
      if (!image.complete) image.addEventListener("load", this.layout, { once: true, signal: this.abortController.signal })
    })
  }

  layout() {
    window.requestAnimationFrame(() => this.arrangeReferenceMosaic(this.mosaic))
  }

  arrangeReferenceMosaic(target) {
    if (!target) return

    target.querySelectorAll(".reference-mosaic-filler").forEach((filler) => filler.remove())
    const cards = [...target.querySelectorAll(".reference-card:not([hidden])")]
    if (!cards.length) {
      target.style.height = "0"
      return
    }

    const gap = Number.parseFloat(getComputedStyle(target).getPropertyValue("--mosaic-gap")) || 6
    const columns = window.matchMedia("(max-width: 520px)").matches ? 2 : window.matchMedia("(max-width: 900px)").matches ? 3 : 4
    const innerWidth = target.clientWidth - gap * 2
    const columnWidth = (innerWidth - gap * (columns - 1)) / columns
    const columnHeights = Array(columns).fill(0)
    const columnSegments = Array.from({ length: columns }, () => [])

    cards.forEach((card) => {
      const image = card.querySelector("img")
      const span = card.classList.contains("mosaic-wide") ? Math.min(2, columns) : 1
      const width = columnWidth * span + gap * (span - 1)
      const ratio = image?.naturalWidth ? image.naturalHeight / image.naturalWidth : 1
      const detailMinimumHeight = window.matchMedia("(max-width: 520px)").matches ? 290 : 300
      const height = card.classList.contains("is-flipped") ? Math.max(width * ratio, detailMinimumHeight) : width * ratio

      let column = 0
      let top = Number.POSITIVE_INFINITY

      for (let index = 0; index <= columns - span; index += 1) {
        const candidateTop = Math.max(...columnHeights.slice(index, index + span))
        if (candidateTop < top) {
          top = candidateTop
          column = index
        }
      }

      const left = gap + column * (columnWidth + gap)
      card.style.left = `${left}px`
      card.style.top = `${top}px`
      card.style.width = `${width}px`
      card.style.height = `${height}px`

      for (let index = column; index < column + span; index += 1) {
        columnHeights[index] = top + height + gap
        columnSegments[index].push({ top, bottom: top + height })
      }
    })

    target.style.height = `${Math.max(...columnHeights)}px`
    this.addInteriorFillers(target, columnSegments, columnWidth, gap)
  }

  addInteriorFillers(target, columnSegments, columnWidth, gap) {
    columnSegments.forEach((segments, column) => {
      let previousBottom = 0
      const left = gap + column * (columnWidth + gap)

      segments
        .sort((a, b) => a.top - b.top)
        .forEach((segment) => {
          const fillerTop = previousBottom + gap
          const fillerHeight = segment.top - fillerTop - gap

          if (fillerHeight > gap * 2) {
            target.appendChild(this.createFiller(left, fillerTop, columnWidth, fillerHeight))
          }

          previousBottom = Math.max(previousBottom, segment.bottom)
        })
    })
  }

  createFiller(left, top, width, height) {
    const filler = document.createElement("div")
    filler.className = "reference-mosaic-filler"
    filler.setAttribute("aria-hidden", "true")
    filler.style.left = `${left}px`
    filler.style.top = `${top}px`
    filler.style.width = `${width}px`
    filler.style.height = `${height}px`
    return filler
  }

  setCardFlipped(card, button, flipped) {
    card.classList.toggle("is-flipped", flipped)
    button.setAttribute("aria-pressed", String(flipped))
    button.setAttribute("aria-label", flipped ? `Bild zu ${this.cardName(card)} anzeigen` : `Details zu ${this.cardName(card)} anzeigen`)
    this.layout()
  }

  cardName(card) {
    return card.querySelector(".reference-card-name")?.textContent || "dieser Referenz"
  }

  usesHover() {
    return window.matchMedia("(hover: hover) and (pointer: fine)").matches
  }

  get mosaic() {
    return this.element.querySelector('[data-layout="mosaic"]')
  }
}
