class AlterRouterUrlApiVersion < ActiveRecord::Migration
  def up
    add_column :routers, :url, :string, null: true
    Router.all.each do |router|
      router.update(url: router.url_time + '/0.1') if router.url_time
    end
    remove_column :routers, :url_time
    remove_column :routers, :url_distance
    remove_column :routers, :url_isochrone
    remove_column :routers, :url_isodistance
  end

  def down
    add_column :routers, :url_time, :string, null: true
    add_column :routers, :url_distance, :string, null: true
    add_column :routers, :url_isochrone, :string, null: true
    add_column :routers, :url_isodistance, :string, null: true
    Router.all.each do |router|
      router.update(url_time: router.url.gsub(/\/0.1$/, '')) if router.url
    end
    remove_column :routers, :url
  end
end
