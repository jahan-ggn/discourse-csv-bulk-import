import Component from "@glimmer/component";
import icon from "discourse/helpers/d-icon";
import { and } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class ImportResults extends Component {
  get isSuccess() {
    return this.args.status === "complete";
  }

  get resultIcon() {
    return this.isSuccess ? "circle-check" : "circle-xmark";
  }

  get resultClass() {
    return this.isSuccess ? "success" : "error";
  }

  <template>
    <div class="import-results {{this.resultClass}}">
      <div class="results-header">
        {{icon this.resultIcon}}
        <h3>{{if
            this.isSuccess
            (i18n "csv_bulk_import.results.title")
            (i18n "csv_bulk_import.errors.title")
          }}</h3>
      </div>
      <p class="results-message">{{@message}}</p>

      {{#if (and this.isSuccess @progress)}}
        <div class="results-stats">
          <div class="stat-card imported">
            <span class="stat-value">{{@progress.imported_topics}}</span>
            <span class="stat-label">{{i18n
                "csv_bulk_import.results.imported_label"
              }}</span>
          </div>
          <div class="stat-card skipped">
            <span class="stat-value">{{@progress.skipped_topics}}</span>
            <span class="stat-label">{{i18n
                "csv_bulk_import.results.skipped_label"
              }}</span>
          </div>
          <div class="stat-card failed">
            <span class="stat-value">{{@progress.failed_topics}}</span>
            <span class="stat-label">{{i18n
                "csv_bulk_import.results.failed_label"
              }}</span>
          </div>
        </div>
      {{/if}}
    </div>
  </template>
}
