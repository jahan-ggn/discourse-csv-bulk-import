import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import { i18n } from "discourse-i18n";
import ImportDetails from "./bulk-import/import-details";
import ImportProgress from "./bulk-import/import-progress";
import ImportResults from "./bulk-import/import-results";

export default class BulkImportUploader extends Component {
  @tracked uploading = false;
  @tracked jobId = null;
  @tracked status = null;
  @tracked message = null;
  @tracked progress = null;
  @tracked errors = null;

  constructor() {
    super(...arguments);

    this.uppyUpload = new UppyUpload(getOwner(this), {
      id: "csv-bulk-import-uploader",
      type: "zip",
      uploadUrl: "/discourse-csv-bulk-import/import",
      preventDirectS3Uploads: true,
      validateUploadedFilesOptions: {
        skipValidation: true,
      },
      onBeforeUpload: () => {
        this.uploading = true;
        this.status = "uploading";
        this.message = i18n("csv_bulk_import.status.uploading");
        this.progress = null;
        this.errors = null;
      },
      uploadDone: (result) => {
        if (result.job_id) {
          this.jobId = result.job_id;
          this.status = "queued";
          this.message = i18n("csv_bulk_import.status.queued");
          this.subscribeToStatus(result.job_id);
        }
      },
      onUploadError: (err) => {
        this.uploading = false;
        this.status = "failed";
        this.message =
          err?.toString() || i18n("csv_bulk_import.status.upload_failed");
      },
    });
  }

  get messageBus() {
    return getOwner(this).lookup("service:message-bus");
  }

  get isComplete() {
    return this.status === "complete";
  }

  get isFailed() {
    return this.status === "failed";
  }

  get isRunning() {
    return (
      this.uploading || this.status === "running" || this.status === "queued"
    );
  }

  get hasDetails() {
    return this.progress?.details?.length > 0 || this.errors?.length > 0;
  }

  get allErrors() {
    const errors = [];
    if (this.errors?.length) {
      errors.push(...this.errors);
    }
    if (this.progress?.errors?.length) {
      errors.push(...this.progress.errors);
    }
    return errors;
  }

  get showResults() {
    return this.isComplete || this.isFailed;
  }

  @action
  setupUploader(element) {
    this.uppyUpload.setup(element);
  }

  @action
  reset() {
    this.status = null;
    this.message = null;
    this.progress = null;
    this.errors = null;
    this.uploading = false;
    this.jobId = null;
  }

  subscribeToStatus(jobId) {
    this.messageBus.subscribe(
      `/csv-bulk-import/status/${jobId}`,
      this.onStatusUpdate
    );
    this.pollStatus(jobId);
  }

  async pollStatus(jobId) {
    const poll = async () => {
      try {
        const data = await ajax(
          `/discourse-csv-bulk-import/import/status/${jobId}`
        );
        if (data && data.status !== "queued") {
          this.onStatusUpdate(data);
          if (data.status !== "complete" && data.status !== "failed") {
            setTimeout(poll, 3000);
          }
          return;
        }
      } catch (error) {
        // eslint-disable-next-line no-console
        console.error("Polling errors:", error);
      }
      setTimeout(poll, 3000);
    };
    setTimeout(poll, 2000);
  }

  @bind
  onStatusUpdate(data) {
    this.status = data.status;
    this.message = data.message;
    this.progress = data.progress;
    this.errors = data.errors;

    if (data.status === "complete" || data.status === "failed") {
      this.uploading = false;
      this.messageBus.unsubscribe(
        `/csv-bulk-import/status/${this.jobId}`,
        this.onStatusUpdate
      );
    }
  }

  <template>
    <div class="bulk-import-uploader">
      <div class="import-instructions">
        <div class="instructions-header">
          {{icon "circle-info"}}
          <span>{{i18n "csv_bulk_import.instructions"}}</span>
        </div>
        <ul>
          <li>{{icon "file-csv"}}
            {{i18n "csv_bulk_import.instructions_csv"}}</li>
          <li>{{icon "folder-open"}}
            {{i18n "csv_bulk_import.instructions_media"}}</li>
        </ul>
      </div>

      {{#unless this.isRunning}}
        <label class="upload-zone">
          <input
            {{didInsert this.setupUploader}}
            class="choose-file-input"
            type="file"
            accept=".zip"
          />
          {{#if this.uppyUpload.uploading}}
            <div class="upload-zone-uploading">
              <div class="spinner-icon"></div>
              <p>{{i18n "csv_bulk_import.status.uploading"}}</p>
            </div>
          {{else}}
            <div class="upload-zone-empty">
              {{icon "cloud-arrow-up"}}
              <p class="drop-text">{{i18n "csv_bulk_import.drop_zone"}}</p>
              <span class="btn btn-default">{{icon "folder-open"}}
                {{i18n "csv_bulk_import.choose_file"}}</span>
            </div>
          {{/if}}
        </label>
      {{/unless}}

      {{#if this.isRunning}}
        <ImportProgress @message={{this.message}} @progress={{this.progress}} />
      {{/if}}

      {{#if this.showResults}}
        <ImportResults
          @status={{this.status}}
          @message={{this.message}}
          @progress={{this.progress}}
        />
      {{/if}}

      {{#if this.hasDetails}}
        <ImportDetails @details={{this.progress.details}} />
      {{/if}}

      {{#if this.showResults}}
        <div class="upload-actions">
          <DButton
            @icon="arrow-rotate-right"
            @label="csv_bulk_import.upload_another"
            @action={{this.reset}}
            class="btn-default"
          />
        </div>
      {{/if}}
    </div>
  </template>
}
