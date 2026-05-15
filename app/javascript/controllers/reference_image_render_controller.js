import { Controller } from "@hotwired/stimulus"
import { applyReferenceImageCrop } from "./reference_image_geometry"

export default class extends Controller {
  static targets = ["frame", "image"]
  static values = {
    focusX: Number,
    focusY: Number,
    zoom: Number
  }

  connect() {
    this.boundRender = () => this.render()

    if (this.hasImageTarget) this.imageTarget.addEventListener("load", this.boundRender)

    if (typeof ResizeObserver !== "undefined") {
      this.resizeObserver = new ResizeObserver(this.boundRender)
      if (this.hasFrameTarget) this.resizeObserver.observe(this.frameTarget)
    }

    this.render()
  }

  disconnect() {
    if (this.hasImageTarget) this.imageTarget.removeEventListener("load", this.boundRender)
    this.resizeObserver?.disconnect()
  }

  focusXValueChanged() {
    this.render()
  }

  focusYValueChanged() {
    this.render()
  }

  zoomValueChanged() {
    this.render()
  }

  render() {
    if (!this.hasFrameTarget || !this.hasImageTarget) return

    applyReferenceImageCrop(this.frameTarget, this.imageTarget, {
      focusX: this.hasFocusXValue ? this.focusXValue : 50,
      focusY: this.hasFocusYValue ? this.focusYValue : 50,
      zoom: this.hasZoomValue ? this.zoomValue : 100
    })
  }
}
