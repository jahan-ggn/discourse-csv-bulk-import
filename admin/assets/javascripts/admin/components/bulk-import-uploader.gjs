import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import ImportDetails from "./bulk-import/import-details";
import ImportProgress from "./bulk-import/import-progress";
import ImportResults from "./bulk-import/import-results";

export default class BulkImportUploader extends Component {
  @tracked file = null;
  @tracked uploading = false;
  @tracked jobId = null;
  @tracked status = null;
  @tracked message = null;
  @tracked progress = null;
  @tracked errors = null;
  @tracked dragOver = false;

  willDestroy() {
    super.willDestroy(...arguments);
    this.cleanupPreviousJob();
  }

  get messageBus() {
    return getOwner(this).lookup("service:message-bus");
  }

  get fileName() {
    return this.file?.name;
  }

  get fileSize() {
    const bytes = this.file?.size;
    if (!bytes) {
      return null;
    }
    if (bytes < 1024 * 1024) {
      return `${(bytes / 1024).toFixed(1)} KB`;
    }
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
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

  get hasValidationErrors() {
    return this.errors?.length > 0;
  }

  get hasDetails() {
    return this.progress?.details?.length > 0;
  }

  get showResults() {
    return this.isComplete || this.isFailed;
  }

  get canUpload() {
    return this.file && !this.isRunning;
  }

  cleanupPreviousJob() {
    if (this.jobId) {
      this.messageBus.unsubscribe(
        `/csv-bulk-import/status/${this.jobId}`,
        this.onStatusUpdate
      );
      this.jobId = null;
    }
  }

  clearResults() {
    this.status = null;
    this.message = null;
    this.progress = null;
    this.errors = null;
  }

  @action
  onFileSelected(event) {
    const selected = event.target.files[0];
    if (selected?.name.endsWith(".zip")) {
      this.cleanupPreviousJob();
      this.clearResults();
      this.file = selected;
    }
    // Reset input so re-selecting the same file triggers change
    event.target.value = "";
  }

  @action
  onDragOver(event) {
    event.preventDefault();
    this.dragOver = true;
  }

  @action
  onDragLeave(event) {
    event.preventDefault();
    this.dragOver = false;
  }

  @action
  onDrop(event) {
    event.preventDefault();
    this.dragOver = false;
    const dropped = event.dataTransfer.files[0];
    if (dropped?.name.endsWith(".zip")) {
      this.cleanupPreviousJob();
      this.clearResults();
      this.file = dropped;
    }
  }

  @action
  async upload() {
    if (!this.file) {
      return;
    }

    this.cleanupPreviousJob();
    this.uploading = true;
    this.status = "uploading";
    this.message = i18n("csv_bulk_import.status.uploading");
    this.progress = null;
    this.errors = null;

    try {
      const formData = new FormData();
      formData.append("file", this.file);

      const result = await ajax("/discourse-csv-bulk-import/import", {
        type: "POST",
        data: formData,
        processData: false,
        contentType: false,
      });

      if (result.job_id) {
        this.file = null;
        this.jobId = result.job_id;
        this.status = "queued";
        this.message = i18n("csv_bulk_import.status.queued");
        this.subscribeToStatus(result.job_id);
      }
    } catch (err) {
      this.uploading = false;
      this.status = "failed";
      this.message =
        err?.jqXHR?.responseJSON?.errors?.join(", ") ||
        err?.jqXHR?.responseJSON?.error ||
        i18n("csv_bulk_import.status.upload_failed");
    }
  }

  @action
  reset() {
    this.cleanupPreviousJob();
    this.clearResults();
    this.file = null;
    this.uploading = false;
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
      if (this.jobId !== jobId || this.isDestroying || this.isDestroyed) {
        return;
      }
      try {
        const data = await ajax(
          `/discourse-csv-bulk-import/import/status/${jobId}`
        );
        if (this.jobId !== jobId || this.isDestroying || this.isDestroyed) {
          return;
        }
        if (data && data.status !== "queued") {
          this.onStatusUpdate(data);
          if (data.status !== "complete" && data.status !== "failed") {
            setTimeout(poll, 3000);
          }
          return;
        }
      } catch (error) {
        if (this.jobId !== jobId || this.isDestroying || this.isDestroyed) {
          return;
        }
        // eslint-disable-next-line no-console
        console.error("Polling error:", error);
      }
      setTimeout(poll, 3000);
    };
    setTimeout(poll, 2000);
  }

  @bind
  onStatusUpdate(data) {
    if (!this.jobId || this.status === "uploading") {
      return;
    }

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
        <div class="import-instructions__header">
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

      {{#if this.isRunning}}
        <ImportProgress @message={{this.message}} @progress={{this.progress}} />
      {{else}}
        {{#if this.fileName}}
          <div
            class="upload-zone upload-zone--has-file"
            {{on "dragover" this.onDragOver}}
            {{on "dragleave" this.onDragLeave}}
            {{on "drop" this.onDrop}}
          >
            <div class="upload-zone__selected">
              {{icon "file-zipper"}}
              <div class="upload-zone__file-info">
                <span class="upload-zone__file-name">{{this.fileName}}</span>
                <span class="upload-zone__file-size">{{this.fileSize}}</span>
              </div>
            </div>
          </div>

          <div class="upload-actions">
            <DButton
              @icon="upload"
              @label="csv_bulk_import.upload_button"
              @action={{this.upload}}
              class="btn-primary"
            />
            <label class="change-file-label">
              <input
                type="file"
                accept=".zip"
                class="choose-file-input"
                {{on "change" this.onFileSelected}}
              />
              <span class="btn btn-default">{{icon "folder-open"}}
                {{i18n "csv_bulk_import.change_file"}}</span>
            </label>
          </div>
        {{else}}
          <label
            class="upload-zone {{if this.dragOver 'upload-zone--drag-over'}}"
            {{on "dragover" this.onDragOver}}
            {{on "dragleave" this.onDragLeave}}
            {{on "drop" this.onDrop}}
          >
            <input
              type="file"
              accept=".zip"
              class="choose-file-input"
              {{on "change" this.onFileSelected}}
            />
            <div class="upload-zone__empty">
              {{icon "cloud-arrow-up"}}
              <p class="upload-zone__drop-text">{{i18n
                  "csv_bulk_import.drop_zone"
                }}</p>
              <span class="btn btn-default">{{icon "folder-open"}}
                {{i18n "csv_bulk_import.choose_file"}}</span>
            </div>
          </label>
        {{/if}}

        {{#if this.showResults}}
          <ImportResults
            @status={{this.status}}
            @message={{this.message}}
            @progress={{this.progress}}
          />
        {{/if}}

        {{#if this.hasValidationErrors}}
          <div class="import-validation-errors">
            <div class="import-validation-errors__header">
              {{icon "triangle-exclamation"}}
              <h4>{{i18n "csv_bulk_import.validation_errors.title"}}</h4>
            </div>
            <ul class="import-validation-errors__list">
              {{#each this.errors as |error|}}
                <li class="import-validation-errors__item">{{error}}</li>
              {{/each}}
            </ul>
          </div>
        {{/if}}

        {{#if this.hasDetails}}
          <ImportDetails @details={{this.progress.details}} />
        {{/if}}

        {{#if this.showResults}}
          <div class="upload-actions">
            <label class="upload-another-label">
              <input
                type="file"
                accept=".zip"
                class="choose-file-input"
                {{on "change" this.onFileSelected}}
              />
              <span class="btn btn-default">{{icon "arrow-rotate-right"}}
                {{i18n "csv_bulk_import.upload_another"}}</span>
            </label>
          </div>
        {{/if}}
      {{/if}}
    </div>
  </template>
}
