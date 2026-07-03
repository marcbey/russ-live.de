import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["name", "company", "email", "phone", "message"]
  static values = {
    recipient: String,
    subject: String,
    nameLabel: String,
    companyLabel: String,
    emailLabel: String,
    phoneLabel: String,
  }

  prepare(event) {
    if (!this.element.checkValidity()) return

    event.preventDefault()

    const body = [
      `${this.nameLabelValue}: ${this.nameTarget.value.trim()}`,
      `${this.companyLabelValue}: ${this.companyTarget.value.trim()}`,
      `${this.emailLabelValue}: ${this.emailTarget.value.trim()}`,
      `${this.phoneLabelValue}: ${this.phoneTarget.value.trim()}`,
      "",
      this.messageTarget.value.trim(),
    ].join("\n")

    window.location.href = `mailto:${this.recipientValue}?subject=${encodeURIComponent(this.subject)}&body=${encodeURIComponent(body)}`
  }

  get subject() {
    return this.subjectValue || "Kontaktanfrage"
  }
}
