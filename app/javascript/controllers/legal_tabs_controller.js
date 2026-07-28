import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    this.activate(this.activeTab || this.tabTargets[0])
  }

  select(event) {
    event.preventDefault()
    this.activate(event.currentTarget)
  }

  navigate(event) {
    const keys = ["ArrowLeft", "ArrowRight", "Home", "End"]
    if (!keys.includes(event.key)) return

    event.preventDefault()

    const currentIndex = this.tabTargets.indexOf(event.currentTarget)
    let nextIndex = currentIndex

    if (event.key === "ArrowLeft") nextIndex = currentIndex - 1
    if (event.key === "ArrowRight") nextIndex = currentIndex + 1
    if (event.key === "Home") nextIndex = 0
    if (event.key === "End") nextIndex = this.tabTargets.length - 1

    const normalizedIndex = (nextIndex + this.tabTargets.length) % this.tabTargets.length
    const nextTab = this.tabTargets[normalizedIndex]
    nextTab.focus()
    this.activate(nextTab)
  }

  activate(activeTab) {
    const activePanelId = activeTab.getAttribute("aria-controls")

    this.tabTargets.forEach((tab) => {
      const active = tab === activeTab
      tab.classList.toggle("is-active", active)
      tab.setAttribute("aria-selected", String(active))
      tab.tabIndex = active ? 0 : -1
    })

    this.panelTargets.forEach((panel) => {
      const active = panel.id === activePanelId
      panel.classList.toggle("is-active", active)
      panel.setAttribute("aria-hidden", String(!active))
    })
  }

  get activeTab() {
    return this.tabTargets.find((tab) => tab.classList.contains("is-active"))
  }
}
