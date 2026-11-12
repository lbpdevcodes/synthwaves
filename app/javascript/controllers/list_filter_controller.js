import { Controller } from "@hotwired/stimulus"

// Hides the items whose data-filter-text doesn't contain what is typed in
// the input, and shows the empty message when nothing is left.
export default class extends Controller {
  static targets = ["input", "item", "empty"]

  filter() {
    const query = this.inputTarget.value.trim().toLowerCase()
    let shown = 0

    this.itemTargets.forEach((item) => {
      const match = item.dataset.filterText.includes(query)
      item.hidden = !match
      if (match) shown++
    })

    if (this.hasEmptyTarget) this.emptyTarget.classList.toggle("hidden", shown > 0)
  }
}
