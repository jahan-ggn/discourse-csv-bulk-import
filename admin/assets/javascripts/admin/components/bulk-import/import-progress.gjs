import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import icon from "discourse/helpers/d-icon";

export default class ImportProgress extends Component {
  get progressPercent() {
    const p = this.args.progress;
    if (!p || !p.total_topics) {
      return 0;
    }
    const processed =
      (p.imported_topics || 0) +
      (p.skipped_topics || 0) +
      (p.failed_topics || 0);
    return Math.round((processed / p.total_topics) * 100);
  }

  <template>
    <div class="import-progress">
      <div class="import-progress__header">
        <div class="import-progress__spinner"></div>
        <span class="import-progress__message">{{@message}}</span>
      </div>

      {{#if @progress}}
        <div class="import-progress__bar">
          <div
            class="import-progress__bar-fill"
            style={{htmlSafe (concat "width: " this.progressPercent "%")}}
          ></div>
        </div>
        <div class="import-progress__stats">
          <span
            class="import-progress__stat import-progress__stat--imported"
          >{{icon "check"}}
            {{@progress.imported_topics}}
            imported</span>
          <span
            class="import-progress__stat import-progress__stat--skipped"
          >{{icon "forward"}}
            {{@progress.skipped_topics}}
            skipped</span>
          <span
            class="import-progress__stat import-progress__stat--failed"
          >{{icon "xmark"}}
            {{@progress.failed_topics}}
            failed</span>
          <span
            class="import-progress__stat import-progress__stat--total"
          >{{icon "list"}}
            {{@progress.total_topics}}
            total</span>
        </div>
      {{/if}}
    </div>
  </template>
}
