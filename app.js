function bindSmoothAnchors() {
  document.querySelectorAll('a[href^="#"]').forEach((link) => {
    link.addEventListener("click", (event) => {
      const targetId = link.getAttribute("href");
      if (!targetId || targetId === "#") return;

      const target = document.querySelector(targetId);
      if (!target) return;

      event.preventDefault();
      target.scrollIntoView({ behavior: "smooth", block: "start" });
    });
  });
}

function bindMobileMenu() {
  const header = document.querySelector(".site-header");
  const nav = document.querySelector(".main-nav");
  const button = document.querySelector(".mobile-menu-button");
  if (!header || !nav || !button) return;

  if (!nav.id) nav.id = "main-navigation";
  button.setAttribute("aria-controls", nav.id);
  button.setAttribute("aria-expanded", "false");

  function setOpen(open) {
    header.classList.toggle("is-menu-open", open);
    button.classList.toggle("is-active", open);
    button.setAttribute("aria-expanded", String(open));
    button.setAttribute("aria-label", open ? "Menü schließen" : "Menü öffnen");
  }

  button.addEventListener("click", () => {
    setOpen(!header.classList.contains("is-menu-open"));
  });

  nav.querySelectorAll("a").forEach((link) => {
    link.addEventListener("click", () => setOpen(false));
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") setOpen(false);
  });

  window.addEventListener("resize", () => {
    if (window.matchMedia("(min-width: 901px)").matches) setOpen(false);
  });
}

function bindAccordions() {
  document.querySelectorAll(".accordion-item").forEach((item) => {
    const trigger = item.querySelector(".accordion-trigger");
    const icon = item.querySelector(".accordion-icon");
    if (!trigger) return;

    trigger.addEventListener("click", () => {
      const open = item.classList.toggle("is-open");
      trigger.setAttribute("aria-expanded", String(open));
      if (icon) icon.textContent = open ? "−" : "+";
    });
  });
}

function createReferenceMosaicFiller(left, top, width, height) {
  const filler = document.createElement("div");
  filler.className = "reference-mosaic-filler";
  filler.setAttribute("aria-hidden", "true");
  filler.style.left = `${left}px`;
  filler.style.top = `${top}px`;
  filler.style.width = `${width}px`;
  filler.style.height = `${height}px`;
  return filler;
}

function arrangeReferenceMosaic(target) {
  if (!target) return;

  target.querySelectorAll(".reference-mosaic-filler").forEach((filler) => filler.remove());
  const cards = [...target.querySelectorAll(".reference-card:not([hidden])")];
  if (!cards.length) {
    target.style.height = "0";
    return;
  }

  const gap = Number.parseFloat(getComputedStyle(target).getPropertyValue("--mosaic-gap")) || 6;
  const columns = window.matchMedia("(max-width: 520px)").matches ? 2 : window.matchMedia("(max-width: 900px)").matches ? 3 : 4;
  const innerWidth = target.clientWidth - gap * 2;
  const columnWidth = (innerWidth - gap * (columns - 1)) / columns;
  const columnHeights = Array(columns).fill(0);
  const columnSegments = Array.from({ length: columns }, () => []);

  cards.forEach((card) => {
    const image = card.querySelector("img");
    const span = card.classList.contains("mosaic-wide") ? Math.min(2, columns) : 1;
    const width = columnWidth * span + gap * (span - 1);
    const ratio = image?.naturalWidth ? image.naturalHeight / image.naturalWidth : 1;
    const detailMinimumHeight = window.matchMedia("(max-width: 520px)").matches ? 290 : 300;
    const height = card.classList.contains("is-flipped") ? Math.max(width * ratio, detailMinimumHeight) : width * ratio;

    let column = 0;
    let top = Number.POSITIVE_INFINITY;

    for (let index = 0; index <= columns - span; index += 1) {
      const candidateTop = Math.max(...columnHeights.slice(index, index + span));
      if (candidateTop < top) {
        top = candidateTop;
        column = index;
      }
    }

    const left = gap + column * (columnWidth + gap);
    card.style.left = `${left}px`;
    card.style.top = `${top}px`;
    card.style.width = `${width}px`;
    card.style.height = `${height}px`;

    for (let index = column; index < column + span; index += 1) {
      columnHeights[index] = top + height + gap;
      columnSegments[index].push({ top, bottom: top + height });
    }
  });

  const mosaicHeight = Math.max(...columnHeights);
  target.style.height = `${mosaicHeight}px`;

  columnSegments.forEach((segments, column) => {
    let previousBottom = 0;
    const left = gap + column * (columnWidth + gap);

    segments
      .sort((a, b) => a.top - b.top)
      .forEach((segment) => {
        const fillerTop = previousBottom + gap;
        const fillerHeight = segment.top - fillerTop - gap;

        if (fillerHeight > gap * 2) {
          target.appendChild(createReferenceMosaicFiller(left, fillerTop, columnWidth, fillerHeight));
        }

        previousBottom = Math.max(previousBottom, segment.bottom);
      });

    // Interior fillers keep the dense poster-wall rhythm; trailing fillers would
    // look like orphaned blocks before the footer.
  });
}

function bindReferenceFilters() {
  const nav = document.querySelector(".references-year-nav");
  const mosaic = document.querySelector('[data-layout="mosaic"]');
  if (!nav || !mosaic) return;

  nav.querySelectorAll("button[data-year]").forEach((button) => {
    button.addEventListener("click", () => {
      const year = button.dataset.year || "all";
      nav.querySelectorAll("button").forEach((item) => item.setAttribute("aria-pressed", "false"));
      button.setAttribute("aria-pressed", "true");
      mosaic.querySelectorAll(".reference-card").forEach((card) => {
        card.hidden = year !== "all" && card.dataset.year !== year;
        if (card.hidden) {
          card.classList.remove("is-flipped");
          card.querySelector(".reference-card-flip")?.setAttribute("aria-pressed", "false");
        }
      });
      arrangeReferenceMosaic(mosaic);
    });
  });
}

function bindReferenceCardFlips() {
  const usesHover = () => window.matchMedia("(hover: hover) and (pointer: fine)").matches;

  function setCardFlipped(card, button, flipped) {
    const mosaic = card.closest('[data-layout="mosaic"]');
    card.classList.toggle("is-flipped", flipped);
    button.setAttribute("aria-pressed", String(flipped));
    button.setAttribute(
      "aria-label",
      flipped
        ? `Bild zu ${card.querySelector(".reference-card-name")?.textContent || "dieser Referenz"} anzeigen`
        : `Details zu ${card.querySelector(".reference-card-name")?.textContent || "dieser Referenz"} anzeigen`
    );
    if (mosaic) arrangeReferenceMosaic(mosaic);
  }

  document.querySelectorAll(".reference-card-flip").forEach((button) => {
    const card = button.closest(".reference-card");
    if (!card) return;
    let lastPointerType = "";

    button.addEventListener("pointerdown", (event) => {
      lastPointerType = event.pointerType;
    });

    button.addEventListener("touchend", () => {
      lastPointerType = "touch";
    }, { passive: true });

    button.addEventListener("click", () => {
      if (usesHover() || lastPointerType !== "touch") {
        button.blur();
        return;
      }

      setCardFlipped(card, button, !card.classList.contains("is-flipped"));
    });

    card.addEventListener("mouseenter", () => {
      if (usesHover()) setCardFlipped(card, button, true);
    });

    card.addEventListener("mouseleave", () => {
      if (usesHover()) setCardFlipped(card, button, false);
    });
  });

  document.addEventListener("keydown", (event) => {
    if (event.key !== "Escape") return;
    document.querySelectorAll(".reference-card.is-flipped").forEach((card) => {
      card.classList.remove("is-flipped");
      card.querySelector(".reference-card-flip")?.setAttribute("aria-pressed", "false");
    });
  });
}

function bindReferenceMosaics() {
  const mosaics = document.querySelectorAll('[data-layout="mosaic"]');
  if (!mosaics.length) return;

  const layout = () => {
    mosaics.forEach((mosaic) => requestAnimationFrame(() => arrangeReferenceMosaic(mosaic)));
  };

  mosaics.forEach((mosaic) => {
    mosaic.querySelectorAll("img").forEach((image) => {
      if (!image.complete) image.addEventListener("load", layout, { once: true });
    });
  });

  layout();
  window.addEventListener("resize", layout);
}

function bindSliders() {
  document.querySelectorAll("[data-slider]").forEach((slider) => {
    const slides = [...slider.querySelectorAll(".klassik-slide")];
    const previousButton = slider.querySelector(".klassik-slider-arrow-prev");
    const nextButton = slider.querySelector(".klassik-slider-arrow-next");
    const title = slider.querySelector(".klassik-slider-meta h3");
    const details = slider.querySelector(".klassik-slider-meta p");
    const meta = slider.querySelector(".klassik-slider-meta");
    let activeIndex = Math.max(0, slides.findIndex((slide) => slide.classList.contains("is-active")));
    let transitionTimer = null;

    function render() {
      const previous = (activeIndex + slides.length - 1) % slides.length;
      const next = (activeIndex + 1) % slides.length;

      slides.forEach((slide, index) => {
        const isActive = index === activeIndex;
        slide.classList.toggle("is-active", isActive);
        slide.classList.toggle("is-prev", index === previous);
        slide.classList.toggle("is-next", index === next);
        slide.classList.toggle("is-hidden", !isActive && index !== previous && index !== next);
        slide.setAttribute("aria-hidden", isActive ? "false" : "true");
      });

      if (title) title.textContent = slides[activeIndex].dataset.title || "";
      if (details) details.textContent = slides[activeIndex].dataset.meta || "";
      if (meta) {
        meta.classList.remove("is-updating");
        window.requestAnimationFrame(() => meta.classList.add("is-updating"));
      }
    }

    function setActive(index) {
      if (index === activeIndex || !slides.length) return;
      activeIndex = index;
      slider.classList.add("is-moving");
      window.clearTimeout(transitionTimer);
      transitionTimer = window.setTimeout(() => slider.classList.remove("is-moving"), 720);
      render();
    }

    slides.forEach((slide, index) => {
      slide.addEventListener("click", () => setActive(index));
      slide.addEventListener("keydown", (event) => {
        if (event.key !== "Enter" && event.key !== " ") return;
        event.preventDefault();
        setActive(index);
      });
    });

    previousButton?.addEventListener("click", () => setActive((activeIndex + slides.length - 1) % slides.length));
    nextButton?.addEventListener("click", () => setActive((activeIndex + 1) % slides.length));
    render();
  });
}

bindSmoothAnchors();
bindMobileMenu();
bindAccordions();
bindReferenceCardFlips();
bindReferenceFilters();
bindReferenceMosaics();
bindSliders();
