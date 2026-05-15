export function applyReferenceImageCrop(frame, image, values = {}) {
  const geometry = referenceImageGeometry(frame, image, values)
  if (!geometry) return null

  image.style.height = `${geometry.imageHeight}px`
  image.style.left = `${geometry.left}px`
  image.style.bottom = "auto"
  image.style.maxWidth = "none"
  image.style.objectFit = "fill"
  image.style.objectPosition = "center"
  image.style.position = "absolute"
  image.style.right = "auto"
  image.style.top = `${geometry.top}px`
  image.style.transform = "none"
  image.style.transformOrigin = "center"
  image.style.width = `${geometry.imageWidth}px`

  return geometry
}

export function referenceImageGeometry(frame, image, values = {}) {
  if (!frame || !image) return null

  const naturalWidth = image.naturalWidth
  const naturalHeight = image.naturalHeight
  if (!naturalWidth || !naturalHeight) return null

  const frameRect = frame.getBoundingClientRect()
  if (!frameRect.width || !frameRect.height) return null

  const focusX = readNumber(values.focusX, 50)
  const focusY = readNumber(values.focusY, 50)
  const zoomScale = Math.max(readNumber(values.zoom, 100), 100) / 100
  const naturalRatio = naturalWidth / naturalHeight
  const frameRatio = frameRect.width / frameRect.height
  const coverScale = naturalRatio > frameRatio ? frameRect.height / naturalHeight : frameRect.width / naturalWidth
  const visibleNaturalWidth = Math.min(naturalWidth, frameRect.width / (coverScale * zoomScale))
  const visibleNaturalHeight = Math.min(naturalHeight, frameRect.height / (coverScale * zoomScale))
  const cropNaturalLeft = clamp(
    ((focusX / 100) * naturalWidth) - (visibleNaturalWidth / 2),
    0,
    naturalWidth - visibleNaturalWidth
  )
  const cropNaturalTop = clamp(
    ((focusY / 100) * naturalHeight) - (visibleNaturalHeight / 2),
    0,
    naturalHeight - visibleNaturalHeight
  )
  const renderedScale = coverScale * zoomScale

  return {
    naturalWidth,
    naturalHeight,
    frameWidth: frameRect.width,
    frameHeight: frameRect.height,
    imageRectWidth: naturalWidth * renderedScale,
    imageRectHeight: naturalHeight * renderedScale,
    imageWidth: naturalWidth * renderedScale,
    imageHeight: naturalHeight * renderedScale,
    visibleNaturalWidth,
    visibleNaturalHeight,
    cropNaturalLeft,
    cropNaturalTop,
    left: -(cropNaturalLeft * renderedScale),
    top: -(cropNaturalTop * renderedScale)
  }
}

function readNumber(value, fallback) {
  const number = Number.parseFloat(value)
  return Number.isFinite(number) ? number : fallback
}

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max)
}
