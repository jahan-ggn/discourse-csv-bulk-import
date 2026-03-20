# frozen_string_literal: true

DiscourseCsvBulkImport::Engine.routes.draw do
  resource :import, only: [:create], controller: "import"
  get "/import/status/:job_id" => "import#status"
end

Discourse::Application.routes.draw { mount ::DiscourseCsvBulkImport::Engine, at: "discourse-csv-bulk-import" }
