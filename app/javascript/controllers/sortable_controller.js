import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import Sortable from "sortablejs"

// Drag-to-reorder for a playlist's rows. Each row carries the URL that moves
// it (data-sortable-url) and the position it holds (data-position). A drop
// sends the position of the row it landed on; the server answers with a page
// refresh, which renumbers the list.
export default class extends Controller {
  connect() {
    this.sortable = Sortable.create(this.element, {
      handle: "[data-sortable-handle]",
      animation: 150,
      onStart: () => { this.positions = this.rows.map((row) => row.dataset.position) },
      onEnd: (event) => this.moved(event)
    })
  }

  disconnect() {
    this.sortable?.destroy()
  }

  get rows() {
    return Array.from(this.element.children)
  }

  moved({ item, oldIndex, newIndex }) {
    if (oldIndex === newIndex) return

    this.move(item.dataset.sortableUrl, this.positions[newIndex])
  }

  async move(url, position) {
    const response = await fetch(url, {
      method: "PATCH",
      headers: {
        "Accept": "text/vnd.turbo-stream.html",
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      },
      body: new URLSearchParams({ position })
    })

    if (response.ok) {
      Turbo.renderStreamMessage(await response.text())
    } else {
      Turbo.visit(window.location.href, { action: "replace" })
    }
  }
}
