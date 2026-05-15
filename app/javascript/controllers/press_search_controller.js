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
  }

  submit(event) {
    event.preventDefault()
    this.render()
  }

  reset() {
    window.requestAnimationFrame(() => this.render())
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

  get pluralLabel() {
    return this.pluralLabelValue || "Press entries"
  }

  get singularLabel() {
    return this.singularLabelValue || "Press entry"
  }
}
