// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import { Turbo } from "@hotwired/turbo-rails"
import "controllers"

// <turbo-stream action="visit" location="..."> navigates the whole page, so a
// form saved in the modal frame can land on the record it just created.
Turbo.StreamActions.visit = function () {
  Turbo.visit(this.getAttribute("location"))
}

if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("/service-worker")
}
