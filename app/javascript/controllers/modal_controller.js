import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]
  static values = { open: Boolean, removeOnClose: Boolean }

  connect() {
    if (this.openValue) this.show()
  }

  show() {
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.classList.add("modal-closing")
    this.dialogTarget.addEventListener("transitionend", () => {
      this.dialogTarget.classList.remove("modal-closing")
      this.dialogTarget.close()
    }, { once: true })
  }

  // Fires however the dialog closed: Cancel, the close button, the backdrop
  // or Escape. A modal loaded into a Turbo frame removes itself so the frame
  // is empty again and the next edit link loads a fresh form.
  closed() {
    if (!this.removeOnCloseValue) return

    this.element.closest("turbo-frame")?.removeAttribute("src")
    this.element.remove()
  }

  backdropClick(event) {
    if (event.target === this.dialogTarget) {
      this.close()
    }
  }
}
