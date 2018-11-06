require 'test_helper'

class ImportCsvTest < ActiveSupport::TestCase
  setup do
    @importer = ImporterDestinations.new(customers(:customer_one))
  end

  test 'should upload' do
    file = ActionDispatch::Http::UploadedFile.new({
      tempfile: File.new(Rails.root.join('test/fixtures/files/import_stores_one.csv')),
    })
    file.original_filename = 'import_stores_one.csv'

    import_csv = ImportCsv.new(importer: @importer, replace: false, file: file)
    assert import_csv.valid?
  end

  test 'shoud not import too many destinations' do
    importer_destinations = ImporterDestinations.new(@customer)
    def importer_destinations.max_lines
      2
    end

    file = ActionDispatch::Http::UploadedFile.new({
      tempfile: File.new(Rails.root.join('test/fixtures/files/import_destinations_many-utf-8.csv')),
    })
    file.original_filename = 'import_destinations_many-utf-8.csv'

    assert_difference('Destination.count', 0) do
      assert !ImportCsv.new(importer: importer_destinations, replace: false, file: file).import
    end
  end

  test 'shoud not import without file' do
    assert_difference('Destination.count', 0) do
      assert !ImportCsv.new(importer: @importer, replace: false, file: nil).import
    end
  end

  test 'shoud not import invalid' do
    file = ActionDispatch::Http::UploadedFile.new({
      tempfile: File.new(Rails.root.join('test/fixtures/files/import_invalid.csv')),
    })
    file.original_filename = 'import_invalid.csv'

    assert_difference('Destination.count', 0) do
      o = ImportCsv.new(importer: @importer, replace: false, file: file)
      assert !o.import
      assert o.errors[:base][0].match('ligne 2')
    end
  end

  test 'should upload plan when vehicle number is less or equal to maximum allowed' do
    stub_request(:post, %r{/0.1/routes.json}).to_return(status: 200)
    file = ActionDispatch::Http::UploadedFile.new(tempfile: File.new(Rails.root.join('test/fixtures/files/import_more_route_than_vehicle.csv')))
    file.original_filename = 'import_more_route_than_vehicle.csv'
    customer = customers(:customer_one_other)
    customer.update(max_vehicles: 1)
    @importer = ImporterDestinations.new(customer)
    import_csv = ImportCsv.new(importer: @importer, replace: true, file: file)

    assert_not import_csv.import
    assert_equal I18n.t('errors.planning.import_too_many_routes'), import_csv.errors.messages[:base].first
  end

  test 'should upload plan when vehicle number is equal to maximum allowed and destinations are not affected' do
    stub_request(:post, %r{/0.1/routes.json}).to_return(status: 200)
    file = ActionDispatch::Http::UploadedFile.new(tempfile: File.new(Rails.root.join('test/fixtures/files/import_enough_route_for_vehicle_and_destination_not_affected.csv')))
    file.original_filename = 'import_enough_route_for_vehicle_and_destination_not_affected.csv'
    customer = customers(:customer_one_other)
    customer.update(max_vehicles: 1)
    @importer = ImporterDestinations.new(customer)
    import_csv = ImportCsv.new(importer: @importer, replace: true, file: file)

    assert import_csv.import
  end
end
