import { Controller } from "@hotwired/stimulus"
import { buildTrackFromElement } from "helpers/track_builder"

export default class extends Controller {
  playAll() {
    const tracks = this.collectTracks()
    if (tracks.length === 0) return

    document.dispatchEvent(new CustomEvent("queue:playAll", {
      detail: { tracks, startIndex: 0 }
    }))
  }

  collectTracks() {
    const rows = this.element.querySelectorAll("[data-controller~='song-row']")
    return Array.from(rows).map(el => buildTrackFromElement(el))
  }
}
