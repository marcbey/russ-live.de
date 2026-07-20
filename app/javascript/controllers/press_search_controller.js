import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "input", "card", "group", "count", "empty", "suggestions", "suggestion"]
  static values = {
    locale: { type: String, default: "de-DE" },
    pluralLabel: String,
    singularLabel: String,
  }

  connect() {
    this.activeSuggestionIndex = -1
    this.visibleSuggestions = []
    this.render()
    this.scrollToSearchAnchor()
  }

  submit(event) {
    event.preventDefault()
    const query = this.normalize(this.inputTarget.value.trim())

    if (query && this.visibleSuggestions.length > 0) {
      const suggestion = this.visibleSuggestions[Math.max(this.activeSuggestionIndex, 0)]
      window.location.assign(suggestion.href)
      return
    }

    this.render()
  }

  render() {
    const rawQuery = this.inputTarget.value.trim()
    const query = this.normalize(rawQuery)
    let visible = 0

    this.cardTargets.forEach((card) => {
      const name = this.normalize(card.dataset.artistName || card.textContent || "")
      const matches = !query || name.includes(query)

      card.hidden = !matches
      if (matches) visible += 1
    })

    this.groupTargets.forEach((group) => {
      group.hidden = !group.querySelector("[data-press-search-target='card']:not([hidden])")
    })

    this.countTarget.textContent = `${visible} ${visible === 1 ? this.singularLabel : this.pluralLabel}`
    this.emptyTarget.hidden = visible > 0
    this.renderSuggestions(query)
  }

  navigate(event) {
    if (event.key === "Escape") {
      this.closeSuggestions()
      return
    }

    if (!["ArrowDown", "ArrowUp", "Enter"].includes(event.key)) return

    if (event.key === "Enter") return
    if (this.visibleSuggestions.length === 0) return

    event.preventDefault()

    const direction = event.key === "ArrowDown" ? 1 : -1
    const lastIndex = this.visibleSuggestions.length - 1

    if (this.activeSuggestionIndex === -1) {
      this.activeSuggestionIndex = direction > 0 ? 0 : lastIndex
    } else {
      this.activeSuggestionIndex = (this.activeSuggestionIndex + direction + this.visibleSuggestions.length) % this.visibleSuggestions.length
    }

    this.updateActiveSuggestion()
  }

  scheduleClose() {
    window.setTimeout(() => {
      if (this.formTarget.contains(document.activeElement)) return

      this.closeSuggestions()
    }, 80)
  }

  renderSuggestions(query) {
    if (!this.hasSuggestionsTarget) return

    this.activeSuggestionIndex = -1
    this.visibleSuggestions = []

    this.suggestionTargets.forEach((suggestion) => {
      const text = this.normalize(suggestion.dataset.suggestionText || suggestion.dataset.artistName || suggestion.textContent || "")
      const matches = Boolean(query) && text.includes(query)

      suggestion.hidden = !matches
      suggestion.setAttribute("aria-selected", "false")
      suggestion.classList.remove("is-active")

      if (matches) this.visibleSuggestions.push(suggestion)
    })

    if (this.visibleSuggestions.length > 0) {
      this.openSuggestions()
    } else {
      this.closeSuggestions()
    }
  }

  openSuggestions() {
    this.suggestionsTarget.hidden = false
    this.inputTarget.setAttribute("aria-expanded", "true")
    this.inputTarget.removeAttribute("aria-activedescendant")
  }

  closeSuggestions() {
    if (this.hasSuggestionsTarget) this.suggestionsTarget.hidden = true

    this.activeSuggestionIndex = -1
    this.inputTarget.setAttribute("aria-expanded", "false")
    this.inputTarget.removeAttribute("aria-activedescendant")
    this.suggestionTargets.forEach((suggestion) => {
      suggestion.setAttribute("aria-selected", "false")
      suggestion.classList.remove("is-active")
    })
  }

  updateActiveSuggestion() {
    this.visibleSuggestions.forEach((suggestion, index) => {
      const active = index === this.activeSuggestionIndex

      suggestion.classList.toggle("is-active", active)
      suggestion.setAttribute("aria-selected", String(active))

      if (active) this.inputTarget.setAttribute("aria-activedescendant", suggestion.id)
    })
  }

  normalize(value) {
    return value.toLocaleLowerCase(this.localeValue).normalize("NFD").replace(/[\u0300-\u036f]/g, "")
  }

  scrollToSearchAnchor() {
    if (window.location.hash !== "#press-search") return
    if (!window.matchMedia("(max-width: 1070px)").matches) return

    this.element.querySelector(".press-hero")?.classList.add("is-search-anchor")

    window.requestAnimationFrame(() => {
      const header = document.querySelector(".site-header")
      const headerHeight = header?.getBoundingClientRect().height || 0
      const top = this.element.querySelector("#press-search").getBoundingClientRect().top + window.scrollY - headerHeight - 10

      window.scrollTo({ top: Math.max(top, 0), behavior: "auto" })
    })
  }

  get pluralLabel() {
    return this.pluralLabelValue || "Press entries"
  }

  get singularLabel() {
    return this.singularLabelValue || "Press entry"
  }
}
