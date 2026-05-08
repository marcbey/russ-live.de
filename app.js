const state = {
  content: null,
};

function textNode(tag, text, className) {
  const element = document.createElement(tag);
  if (className) element.className = className;
  element.textContent = text;
  return element;
}

function renderParagraphs(target, paragraphs) {
  target.replaceChildren();
  paragraphs.forEach((paragraph) => {
    target.appendChild(textNode("p", paragraph));
  });
}

function renderServices(services) {
  const target = document.querySelector('[data-render="services"]');
  if (!target) return;
  target.replaceChildren();

  services.forEach((service, index) => {
    const item = document.createElement("article");
    item.className = `accordion-item${index === 0 ? " is-open" : ""}`;

    const trigger = document.createElement("button");
    trigger.className = "accordion-trigger";
    trigger.type = "button";
    trigger.setAttribute("aria-expanded", index === 0 ? "true" : "false");
    trigger.append(textNode("span", service.title));
    trigger.append(textNode("span", index === 0 ? "−" : "+", "accordion-icon"));

    const panel = document.createElement("div");
    panel.className = "accordion-panel";
    const panelInner = document.createElement("div");
    panelInner.className = "accordion-panel-inner";
    service.body.forEach((paragraph) => panelInner.append(textNode("p", paragraph)));
    panel.appendChild(panelInner);

    trigger.addEventListener("click", () => {
      const open = item.classList.toggle("is-open");
      trigger.setAttribute("aria-expanded", String(open));
      trigger.querySelector(".accordion-icon").textContent = open ? "−" : "+";
    });

    item.append(trigger, panel);
    target.appendChild(item);
  });
}

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

function renderReferences(references) {
  const target = document.querySelector('[data-render="references"]');
  if (!target) return;
  target.replaceChildren();

  const limit = Number(target.dataset.limit || references.length);
  const railMode = target.dataset.mode === "rail";
  references.slice(0, limit).forEach((reference) => {
    const figure = document.createElement("figure");
    figure.className = `reference-card ${railMode ? "rail-card" : ""} ${reference.size || "small"}`;

    const image = document.createElement("img");
    image.src = reference.image;
    image.alt = reference.title;
    image.loading = "lazy";

    figure.append(image, textNode("figcaption", reference.title));
    target.appendChild(figure);
  });
}

const featuredReferences = [
  {
    title: "Five Finger Death Punch",
    meta: "Rock / Metal · Porsche-Arena Stuttgart",
    image: "assets/references/featured/bild1.jpg",
  },
  {
    title: "AC/DC",
    meta: "Stadionproduktion · Stuttgart",
    image: "assets/references/featured/bild2.jpg",
  },
  {
    title: "David Garrett",
    meta: "Arena-Konzert · Liederhalle Stuttgart",
    image: "assets/references/featured/bild3.jpg",
  },
];

function renderFeaturedReferences() {
  const targets = document.querySelectorAll('[data-render="featured-references"]');
  targets.forEach((target) => {
    let activeIndex = 0;
    let transitionTimer = null;

    const viewport = document.createElement("div");
    viewport.className = "klassik-slider-viewport";

    const previousButton = document.createElement("button");
    previousButton.className = "klassik-slider-arrow klassik-slider-arrow-prev";
    previousButton.type = "button";
    previousButton.setAttribute("aria-label", "Vorherige Referenz");
    previousButton.textContent = "‹";

    const nextButton = document.createElement("button");
    nextButton.className = "klassik-slider-arrow klassik-slider-arrow-next";
    nextButton.type = "button";
    nextButton.setAttribute("aria-label", "Nächste Referenz");
    nextButton.textContent = "›";

    const stage = document.createElement("div");
    stage.className = "klassik-slider-stage";

    const meta = document.createElement("div");
    meta.className = "klassik-slider-meta";
    const marker = document.createElement("span");
    marker.className = "klassik-slider-marker";
    const text = document.createElement("div");
    text.className = "klassik-slider-text";
    const title = textNode("h3", "");
    const details = textNode("p", "");
    const referenceLink = document.createElement("a");
    referenceLink.className = "section-button klassik-slider-button";
    referenceLink.href = "referenzen.html";
    referenceLink.textContent = "Referenzen";
    text.append(title, details);
    meta.append(marker, text, referenceLink);

    function itemFor(slide, index) {
      const item = document.createElement("figure");
      item.className = "klassik-slide";
      item.dataset.index = String(index);
      item.tabIndex = 0;
      const image = document.createElement("img");
      image.src = slide.image;
      image.alt = slide.title;
      item.appendChild(image);
      item.addEventListener("click", () => {
        setActive(index);
      });
      item.addEventListener("keydown", (event) => {
        if (event.key !== "Enter" && event.key !== " ") return;
        event.preventDefault();
        setActive(index);
      });
      return item;
    }

    featuredReferences.forEach((slide, index) => {
      stage.appendChild(itemFor(slide, index));
    });

    function setActive(index) {
      if (index === activeIndex) return;
      activeIndex = index;
      target.classList.add("is-moving");
      window.clearTimeout(transitionTimer);
      transitionTimer = window.setTimeout(() => {
        target.classList.remove("is-moving");
      }, 720);
      render();
    }

    function render() {
      const previous = (activeIndex + featuredReferences.length - 1) % featuredReferences.length;
      const next = (activeIndex + 1) % featuredReferences.length;
      stage.querySelectorAll(".klassik-slide").forEach((item) => {
        const index = Number(item.dataset.index);
        const isActive = index === activeIndex;
        const isPrevious = index === previous;
        const isNext = index === next;
        item.classList.toggle("is-active", isActive);
        item.classList.toggle("is-prev", isPrevious);
        item.classList.toggle("is-next", isNext);
        item.classList.toggle("is-hidden", !isActive && !isPrevious && !isNext);
        item.setAttribute("aria-hidden", index === activeIndex ? "false" : "true");
        item.setAttribute("aria-label", featuredReferences[index].title);
      });
      meta.classList.remove("is-updating");
      window.requestAnimationFrame(() => meta.classList.add("is-updating"));
      title.textContent = featuredReferences[activeIndex].title;
      details.textContent = featuredReferences[activeIndex].meta;
    }

    previousButton.addEventListener("click", () => {
      setActive((activeIndex + featuredReferences.length - 1) % featuredReferences.length);
    });

    nextButton.addEventListener("click", () => {
      setActive((activeIndex + 1) % featuredReferences.length);
    });

    render();
    viewport.append(previousButton, stage, nextButton);
    target.replaceChildren(viewport, meta);
  });
}

function renderTeam(team) {
  const target = document.querySelector('[data-render="team"]');
  if (!target) return;
  target.replaceChildren();

  team.forEach((member) => {
    const card = document.createElement("article");
    card.className = "team-card";

    const image = document.createElement("img");
    image.src = member.image;
    image.alt = member.name;
    image.loading = "lazy";

    card.append(image, textNode("h3", member.name), textNode("p", member.role));
    target.appendChild(card);
  });
}

function hydrate(content) {
  state.content = content;

  const heroTitle = document.getElementById("hero-title");
  const heroIntro = document.getElementById("hero-intro");
  if (heroTitle) heroTitle.textContent = "Ihr örtlicher Veranstalter für Stuttgart";
  if (heroIntro) heroIntro.textContent = content.home.intro[0] || "";
  renderServices(content.services);
  renderReferences(content.references);
  renderFeaturedReferences();
  const about = document.querySelector('[data-render="about"]');
  if (about) renderParagraphs(about, content.about.body);
  renderTeam(content.team);
  const contact = document.querySelector('[data-render="contact"]');
  if (contact) renderParagraphs(contact, content.contact.body);
}

fetch("content/site.json")
  .then((response) => response.json())
  .then(hydrate)
  .catch((error) => {
    console.error("Could not load content/site.json", error);
  });

bindSmoothAnchors();
