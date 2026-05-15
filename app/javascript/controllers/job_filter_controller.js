import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.abortController = new AbortController()
    this.bindFilters()
  }

  disconnect() {
    this.abortController?.abort()
  }

  bindFilters() {
    const nav = this.element.querySelector(".job-category-filter-nav")
    const rows = this.element.querySelectorAll(".job-table-row[data-job-categories]")
    if (!nav || rows.length === 0) return

    nav.querySelectorAll("button[data-job-category]").forEach((button) => {
      button.addEventListener("click", () => {
        const category = button.dataset.jobCategory || "all"
        nav.querySelectorAll("button").forEach((item) => item.setAttribute("aria-pressed", "false"))
        button.setAttribute("aria-pressed", "true")

        rows.forEach((row) => {
          const categories = (row.dataset.jobCategories || "").split(" ").filter(Boolean)
          row.hidden = category !== "all" && !categories.includes(category)
        })
      }, { signal: this.abortController.signal })
    })
  }
}
