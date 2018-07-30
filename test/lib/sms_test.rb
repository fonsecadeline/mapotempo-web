require 'test_helper'

class SmsTest < ActionController::TestCase

    test 'should fill data in sms template' do
        route = routes(:route_one_one)
        route.planning.customer.reseller.sms_api_key = 'fake api key'
        route.planning.customer.reseller.sms_api_secret = 'fake secrete'
        route.vehicle_usage.vehicle.phone_number = '0554389586'
        route.planning.customer.sms_concat = false

        notification = Notifications.new service: :fake_service

        template = File.read(Rails.root.join('test/fixtures/files/sms_template.txt'))

        route.stops[0..2].each { |s|
            date = route.planning.date || Time.zone.today
            remplacement = {
                date: I18n.l(date, format: :weekday),
                time: date.beginning_of_day + s.time,
                visit_ref: "fake ref for all !! =)",
                quantities: VisitQuantities.normalize(s.visit, nil).map{ |q| q[:quantity_formatted] }.join(' ').tr("\u202F", ' '),
                vehicle_name: route.vehicle_usage.vehicle.name,
                phone_number: route.vehicle_usage.vehicle.phone_number
            }
            cont = notification.content(template, remplacement, !route.planning.customer.sms_concat)

            assert_not_nil cont
            assert cont.include? route.vehicle_usage.vehicle.phone_number
            assert cont.include? route.vehicle_usage.vehicle.name
        }

    end
end
