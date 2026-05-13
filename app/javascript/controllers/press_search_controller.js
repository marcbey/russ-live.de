import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "card", "group", "count", "empty"]

  connect() {
    this.abortController = new AbortController()
    this.inputTarget.addEventListener("input", () => this.render(), { signal: this.abortController.signal })
    this.inputTarget.form?.addEventListener("reset", () => window.requestAnimationFrame(() => this.render()), {
      signal: this.abortController.signal,
    })
    this.render()
  }

  disconnect() {
    this.abortController?.abort()
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

    this.countTarget.textContent = `${visible} ${visible === 1 ? "Presseeintrag" : "Presseeinträge"}`
    this.emptyTarget.hidden = visible > 0
  }

  normalize(value) {
    return value.toLocaleLowerCase("de-DE").normalize("NFD").replace(/[\u0300-\u036f]/g, "")
  }
}
