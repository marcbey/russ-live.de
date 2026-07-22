import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["track", "group"]
  static values = {
    baseSpeed: { type: Number, default: 15 },
    slideDuration: { type: Number, default: 650 },
    speedScale: { type: Number, default: 4 },
  }

  connect() {
    this.abortController = new AbortController()
    this.mediaQuery = window.matchMedia("(prefers-reduced-motion: reduce)")
    this.position = 0
    this.paused = false
    this.dragging = false
    this.dragged = false
    this.dragStartX = 0
    this.dragStartPosition = 0
    this.dragPointerId = null
    this.previousTimestamp = null
    this.slideAnimation = null

    this.animate = this.animate.bind(this)
    this.handleClick = this.handleClick.bind(this)
    this.handlePointerDown = this.handlePointerDown.bind(this)
    this.handlePointerEnter = this.handlePointerEnter.bind(this)
    this.handlePointerLeave = this.handlePointerLeave.bind(this)
    this.handlePointerMove = this.handlePointerMove.bind(this)
    this.handlePointerUp = this.handlePointerUp.bind(this)
    this.handleMotionPreferenceChange = this.handleMotionPreferenceChange.bind(this)
    this.measure = this.measure.bind(this)

    const { signal } = this.abortController
    this.element.addEventListener("click", this.handleClick, { capture: true, signal })
    this.element.addEventListener("pointerdown", this.handlePointerDown, { signal })
    this.element.addEventListener("pointerenter", this.handlePointerEnter, { signal })
    this.element.addEventListener("pointerleave", this.handlePointerLeave, { signal })
    window.addEventListener("pointermove", this.handlePointerMove, { signal })
    window.addEventListener("pointerup", this.handlePointerUp, { signal })
    window.addEventListener("pointercancel", this.handlePointerUp, { signal })
    this.mediaQuery.addEventListener("change", this.handleMotionPreferenceChange, { signal })

    if (typeof ResizeObserver !== "undefined") {
      this.resizeObserver = new ResizeObserver(this.measure)
      this.resizeObserver.observe(this.element)
      if (this.hasGroupTarget) this.resizeObserver.observe(this.groupTargets[0])
    }

    this.measure()
    this.handleMotionPreferenceChange()
  }

  disconnect() {
    if (this.frame) window.cancelAnimationFrame(this.frame)
    this.resizeObserver?.disconnect()
    this.abortController?.abort()
  }

  previous() {
    this.slideBy(this.cardStep())
  }

  next() {
    this.slideBy(-this.cardStep())
  }

  handleClick(event) {
    if (!this.dragged) return

    event.preventDefault()
    event.stopPropagation()
    this.dragged = false
  }

  handlePointerEnter() {
    this.paused = true
  }

  handlePointerLeave(event) {
    if (this.dragging) return

    this.paused = false
  }

  handlePointerDown(event) {
    if (event.button !== undefined && event.button !== 0) return
    if (event.target.closest?.(".reference-marquee-controls")) return
    if (event.target.closest?.(".reference-marquee-cta")) return

    this.dragging = true
    this.dragged = false
    this.paused = true
    this.slideAnimation = null
    this.dragStartX = event.clientX
    this.dragStartPosition = this.position
    this.element.classList.add("is-dragging")
  }

  handlePointerMove(event) {
    if (!this.dragging) return

    const deltaX = event.clientX - this.dragStartX
    if (!this.dragged && Math.abs(deltaX) <= 12) return

    this.dragged = true
    if (this.dragPointerId !== event.pointerId) {
      this.dragPointerId = event.pointerId
      this.element.setPointerCapture?.(event.pointerId)
    }

    this.position = this.dragStartPosition + deltaX
    this.wrapPosition()
    this.render()
    event.preventDefault()
  }

  handlePointerUp(event) {
    if (!this.dragging) return

    this.dragging = false
    this.dragPointerId = null
    this.paused = this.element.matches(":hover")
    this.element.classList.remove("is-dragging")
    this.element.releasePointerCapture?.(event.pointerId)
  }

  handleMotionPreferenceChange() {
    if (this.mediaQuery.matches) {
      if (this.frame) window.cancelAnimationFrame(this.frame)
      this.frame = null
      this.previousTimestamp = null
      this.trackTarget.style.transform = "none"
      return
    }

    if (!this.frame) this.frame = window.requestAnimationFrame(this.animate)
  }

  measure() {
    const group = this.groupTargets[0]
    this.groupWidth = group?.getBoundingClientRect().width || this.trackTarget.scrollWidth / 2
  }

  animate(timestamp) {
    if (!this.previousTimestamp) this.previousTimestamp = timestamp

    const elapsedSeconds = Math.min((timestamp - this.previousTimestamp) / 1000, 0.05)
    this.previousTimestamp = timestamp

    if (this.slideAnimation) {
      this.updateSlideAnimation(timestamp)
    } else if (!this.paused && !this.dragging) {
      this.position -= this.pixelsPerSecond() * elapsedSeconds
      this.wrapPosition()
      this.render()
    }

    this.frame = window.requestAnimationFrame(this.animate)
  }

  slideBy(distance) {
    if (this.mediaQuery.matches) {
      this.moveBy(distance)
      return
    }

    const from = this.normalizedSlideStart(distance)
    this.position = from
    this.slideAnimation = {
      from,
      to: from + distance,
      start: null,
    }
  }

  moveBy(distance) {
    this.position += distance
    this.wrapPosition()
    this.render()
  }

  normalizedSlideStart(distance) {
    if (!this.groupWidth) return this.position
    if (distance > 0 && this.position + distance >= 0) return this.position - this.groupWidth

    return this.position
  }

  cardStep() {
    const firstCard = this.groupTargets[0]?.querySelector(".reference-marquee-card")
    if (!firstCard) return this.element.clientWidth * 0.6

    const styles = window.getComputedStyle(this.groupTargets[0])
    const gap = Number.parseFloat(styles.columnGap || styles.gap) || 0

    return firstCard.getBoundingClientRect().width + gap
  }

  render() {
    this.trackTarget.style.transform = `translate3d(${this.position}px, 0, 0)`
  }

  pixelsPerSecond() {
    return this.baseSpeedValue * this.speedScaleValue
  }

  updateSlideAnimation(timestamp) {
    if (!this.slideAnimation.start) this.slideAnimation.start = timestamp

    const progress = Math.min((timestamp - this.slideAnimation.start) / this.slideDurationValue, 1)
    const easedProgress = 1 - ((1 - progress) ** 3)

    this.position = this.slideAnimation.from + ((this.slideAnimation.to - this.slideAnimation.from) * easedProgress)
    this.render()

    if (progress < 1) return

    this.slideAnimation = null
    this.wrapPosition()
    this.render()
  }

  wrapPosition() {
    if (!this.groupWidth) return

    if (this.position <= -this.groupWidth) this.position += this.groupWidth
    if (this.position >= 0) this.position -= this.groupWidth
  }
}
