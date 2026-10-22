import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["salutation", "firstName", "lastName", "address", "city", "phone", "email", "position", "status", "message"]
  static values = {
    recipient: String,
    subject: String,
    interestLine: String,
    personalDetailsHeading: String,
    salutationLabel: String,
    firstNameLabel: String,
    lastNameLabel: String,
    addressLabel: String,
    cityLabel: String,
    phoneLabel: String,
    emailLabel: String,
    positionLabel: String,
    statusLabel: String,
    messageLabel: String,
  }

  prepare(event) {
    if (!this.element.checkValidity()) return

    event.preventDefault()

    const body = [
      this.interestLine,
      "",
      this.messageTarget.value.trim(),
      "",
      this.personalDetailsHeading,
      `${this.salutationLabelValue}: ${this.salutationTarget.value}`,
      `${this.firstNameLabelValue}: ${this.firstNameTarget.value.trim()}`,
      `${this.lastNameLabelValue}: ${this.lastNameTarget.value.trim()}`,
      `${this.addressLabelValue}: ${this.addressTarget.value.trim()}`,
      `${this.cityLabelValue}: ${this.cityTarget.value.trim()}`,
      `${this.phoneLabelValue}: ${this.phoneTarget.value.trim()}`,
      `${this.emailLabelValue}: ${this.emailTarget.value.trim()}`,
      `${this.positionLabelValue}: ${this.positionTarget.value.trim()}`,
      ...this.statusDetails,
    ].join("\n")

    window.location.href = `mailto:${this.recipientValue}?subject=${encodeURIComponent(this.subject)}&body=${encodeURIComponent(body)}`
  }

  get subject() {
    return this.subjectValue || "Bewerbung"
  }

  get statusDetails() {
    const statuses = this.statusTargets.filter(input => input.checked).map(input => input.value)
    return statuses.length ? [`${this.statusLabelValue}: ${statuses.join(", ")}`] : []
  }

  get interestLine() {
    return this.interestLineValue || `Ich interessiere mich für die Stelle ${this.positionTarget.value.trim()}.`
  }

  get personalDetailsHeading() {
    return this.personalDetailsHeadingValue || "Meine Daten:"
  }
}
