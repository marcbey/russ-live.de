import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "previewFrame",
    "previewImage",
    "previewBox",
    "focusX",
    "focusY",
    "zoom",
    "gridVariant",
    "zoomOutput",
    "saveGridVariant",
    "saveFocusX",
    "saveFocusY",
    "saveZoom"
  ]

  connect() {
    this.boundUpdate = () => this.update()
    this.boundDrag = (event) => this.drag(event)
    this.boundEndDrag = () => this.endDrag()

    if (this.hasPreviewImageTarget) this.previewImageTarget.addEventListener("load", this.boundUpdate)

    if (typeof ResizeObserver !== "undefined") {
      this.resizeObserver = new ResizeObserver(this.boundUpdate)
      if (this.hasPreviewFrameTarget) this.resizeObserver.observe(this.previewFrameTarget)
      if (this.hasPreviewImageTarget) this.resizeObserver.observe(this.previewImageTarget)
    }

    this.update()
  }

  disconnect() {
    if (this.hasPreviewImageTarget) this.previewImageTarget.removeEventListener("load", this.boundUpdate)
    this.endDrag()
    this.resizeObserver?.disconnect()
  }

  update() {
    const focusX = this.readValue("focusX", 50)
    const focusY = this.readValue("focusY", 50)
    const zoom = this.readValue("zoom", 100)
    const gridVariant = this.hasGridVariantTarget ? this.gridVariantTarget.value : "1x1"

    if (this.hasPreviewFrameTarget) this.previewFrameTarget.dataset.gridVariant = gridVariant
    this.updateCropBox(this.cropGeometry({ focusX, focusY, zoom }))

    if (this.hasZoomOutputTarget) this.zoomOutputTarget.textContent = `${Math.round(zoom)}%`
    if (this.hasSaveGridVariantTarget) this.saveGridVariantTarget.value = gridVariant
    if (this.hasSaveFocusXTarget) this.saveFocusXTarget.value = focusX
    if (this.hasSaveFocusYTarget) this.saveFocusYTarget.value = focusY
    if (this.hasSaveZoomTarget) this.saveZoomTarget.value = zoom
  }

  startDrag(event) {
    if (!this.hasFocusXTarget || !this.hasFocusYTarget) return
    if (!this.hasPreviewFrameTarget || !this.hasPreviewImageTarget || !this.hasPreviewBoxTarget) return
    if (event.button !== undefined && event.button !== 0) return

    const geometry = this.cropGeometry()
    if (!geometry) return

    this.dragState = {
      startClientX: event.clientX,
      startClientY: event.clientY,
      ...geometry
    }

    this.previewFrameTarget.classList.add("is-dragging")
    window.addEventListener("pointermove", this.boundDrag)
    window.addEventListener("pointerup", this.boundEndDrag)
    window.addEventListener("pointercancel", this.boundEndDrag)
    event.preventDefault()
  }

  drag(event) {
    if (!this.dragState) return

    const deltaX = event.clientX - this.dragState.startClientX
    const deltaY = event.clientY - this.dragState.startClientY
    const cropNaturalLeft = this.clamp(
      this.dragState.cropNaturalLeft + ((deltaX / this.dragState.imageRectWidth) * this.dragState.naturalWidth),
      0,
      this.dragState.naturalWidth - this.dragState.visibleNaturalWidth
    )
    const cropNaturalTop = this.clamp(
      this.dragState.cropNaturalTop + ((deltaY / this.dragState.imageRectHeight) * this.dragState.naturalHeight),
      0,
      this.dragState.naturalHeight - this.dragState.visibleNaturalHeight
    )

    this.focusXTarget.value = ((cropNaturalLeft + (this.dragState.visibleNaturalWidth / 2)) / this.dragState.naturalWidth) * 100
    this.focusYTarget.value = ((cropNaturalTop + (this.dragState.visibleNaturalHeight / 2)) / this.dragState.naturalHeight) * 100
    this.update()
  }

  endDrag() {
    this.dragState = null
    this.previewFrameTarget?.classList.remove("is-dragging")
    window.removeEventListener("pointermove", this.boundDrag)
    window.removeEventListener("pointerup", this.boundEndDrag)
    window.removeEventListener("pointercancel", this.boundEndDrag)
  }

  updateCropBox(geometry) {
    if (!this.hasPreviewFrameTarget || !this.hasPreviewBoxTarget) return

    if (!geometry) {
      this.previewBoxTarget.classList.add("is-hidden")
      return
    }

    this.previewBoxTarget.style.left = `${geometry.left}px`
    this.previewBoxTarget.style.top = `${geometry.top}px`
    this.previewBoxTarget.style.width = `${geometry.width}px`
    this.previewBoxTarget.style.height = `${geometry.height}px`
    this.previewBoxTarget.classList.remove("is-hidden")
  }

  cropGeometry(values = {}) {
    const naturalWidth = this.previewImageTarget.naturalWidth
    const naturalHeight = this.previewImageTarget.naturalHeight
    if (!naturalWidth || !naturalHeight) return null

    const frameRect = this.previewFrameTarget.getBoundingClientRect()
    const imageRect = this.previewImageTarget.getBoundingClientRect()
    if (!frameRect.width || !frameRect.height || !imageRect.width || !imageRect.height) return null

    const focusX = values.focusX ?? this.readValue("focusX", 50)
    const focusY = values.focusY ?? this.readValue("focusY", 50)
    const zoomScale = Math.max(values.zoom ?? this.readValue("zoom", 100), 100) / 100
    const cropRatio = this.gridVariantRatio()
    const naturalRatio = naturalWidth / naturalHeight
    let visibleNaturalWidth
    let visibleNaturalHeight

    if (naturalRatio > cropRatio) {
      visibleNaturalHeight = naturalHeight / zoomScale
      visibleNaturalWidth = visibleNaturalHeight * cropRatio
    } else {
      visibleNaturalWidth = naturalWidth / zoomScale
      visibleNaturalHeight = visibleNaturalWidth / cropRatio
    }

    const focusNaturalX = (focusX / 100) * naturalWidth
    const focusNaturalY = (focusY / 100) * naturalHeight
    const cropNaturalLeft = this.clamp(focusNaturalX - (visibleNaturalWidth / 2), 0, naturalWidth - visibleNaturalWidth)
    const cropNaturalTop = this.clamp(focusNaturalY - (visibleNaturalHeight / 2), 0, naturalHeight - visibleNaturalHeight)
    const imageScaleX = imageRect.width / naturalWidth
    const imageScaleY = imageRect.height / naturalHeight

    return {
      naturalWidth,
      naturalHeight,
      imageRectWidth: imageRect.width,
      imageRectHeight: imageRect.height,
      visibleNaturalWidth,
      visibleNaturalHeight,
      cropNaturalLeft,
      cropNaturalTop,
      left: (imageRect.left - frameRect.left) + (cropNaturalLeft * imageScaleX),
      top: (imageRect.top - frameRect.top) + (cropNaturalTop * imageScaleY),
      width: visibleNaturalWidth * imageScaleX,
      height: visibleNaturalHeight * imageScaleY
    }
  }

  gridVariantRatio() {
    const gridVariant = this.hasGridVariantTarget ? this.gridVariantTarget.value : "1x1"

    if (gridVariant === "2x1") return 2
    if (gridVariant === "1x2") return 0.5

    return 1
  }

  readValue(targetName, fallback) {
    const target = this[`${targetName}Target`]
    const value = Number.parseFloat(target?.value || "")
    return Number.isFinite(value) ? value : fallback
  }

  clamp(value, min, max) {
    return Math.min(Math.max(value, min), max)
  }
}
