import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "card", "group", "count", "empty"]
  static values = {
    locale: { type: String, default: "de-DE" },
    pluralLabel: String,
    singularLabel: String,
  }

  connect() {
    this.render()
    this.scrollToSearchAnchor()
  }

  submit(event) {
    event.preventDefault()
    this.render()
  }

  render() {
    const query = this.normalize(this.inputTarget.value.trim())
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
