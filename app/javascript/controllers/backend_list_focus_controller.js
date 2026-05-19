import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { storageKey: String }

  connect() {
    this.boundRemember = () => this.rememberScroll()
    this.element.addEventListener("scroll", this.boundRemember)
    this.restoreScroll()
  }

  disconnect() {
    this.element.removeEventListener("scroll", this.boundRemember)
  }

  rememberScroll() {
    window.sessionStorage.setItem(this.storageKey(), String(this.element.scrollTop))
  }

  restoreScroll() {
    const saved = window.sessionStorage.getItem(this.storageKey())
    if (saved === null) return

    this.element.scrollTop = Number.parseInt(saved, 10) || 0
  }

  storageKey() {
    const suffix = this.hasStorageKeyValue ? this.storageKeyValue : "default"
    return `backend-references-list-scroll:${suffix}`
  }
}
