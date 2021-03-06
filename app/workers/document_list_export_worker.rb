class DocumentListExportWorker
  include Sidekiq::Worker

  def perform(filter_options, user_id)
    user = User.find(user_id)
    filter = create_filter(filter_options, user)
    csv = generate_csv(filter)
    send_mail(csv, user, filter)
  end

private

  def send_mail(csv, user, filter)
    Notifications.document_list(csv, user.email, filter.page_title).deliver
  end

  def create_filter(filter_options, user)
    Admin::EditionFilter.new(Edition, user, filter_options.symbolize_keys)
  end

  def generate_csv(filter)
    CSV.generate do |csv|
      csv << DocumentListExportPresenter.header_row
      filter.editions_for_csv.each do |edition|
        presenter = DocumentListExportPresenter.new(edition)
        csv << presenter.row
      end
    end
  end
end
