import Component from "@glimmer/component";
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
      <div class="progress-header">
        <div class="spinner-icon"></div>
        <span class="progress-message">{{@message}}</span>
      </div>

      {{#if @progress}}
        <div class="progress-bar-container">
          <div
            class="progress-bar-fill"
            style="width: {{this.progressPercent}}%"
          ></div>
        </div>
        <div class="progress-stats">
          <span class="stat imported">{{icon "check"}}
            {{@progress.imported_topics}}
            imported</span>
          <span class="stat skipped">{{icon "forward"}}
            {{@progress.skipped_topics}}
            skipped</span>
          <span class="stat failed">{{icon "xmark"}}
            {{@progress.failed_topics}}
            failed</span>
          <span class="stat total">{{icon "list"}}
            {{@progress.total_topics}}
            total</span>
        </div>
      {{/if}}
    </div>
  </template>
}
