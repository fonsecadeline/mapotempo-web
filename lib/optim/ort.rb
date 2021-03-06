# Copyright © Mapotempo, 2013-2016
#
# This file is part of Mapotempo.
#
# Mapotempo is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Mapotempo is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Mapotempo. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#
require 'ai4r'
include Ai4r::Data
require_relative 'complete_linkage_max_distance'
include Ai4r::Clusterers

require 'rest_client'

class Ort

  attr_accessor :cache, :url

  def initialize(cache, url)
    @cache, @url = cache, url
  end

  def optimize(matrix, dimension, services, stores, rests, optimize_time, soft_upper_bound, cluster_threshold)
    if !stores.include?(:start)
      matrix = [[[0, 0]] * matrix.length] + matrix
      matrix.collect!{ |x| [[0, 0]] + x }
    end
    if !stores.include?(:stop)
      matrix += [[[0, 0]] * matrix.length]
      matrix.collect!{ |x| x + [[0, 0]] }
    end

    dimension = dimension == 'time' ? 0 : 1
    key = [soft_upper_bound, matrix.hash, dimension, services.hash, stores.hash, rests.hash, cluster_threshold]

    time_window = services.collect{ |service| [service[:start1], service[:end1], service[:start2], service[:end2], service[:duration]] }
    time_window.unshift [0, 2147483647, nil, nil, 0] # always a start for or-tools
    # time_window.push [0, 2147483647, nil, nil, 0] if stores.include? :stop
    rest_window = rests.collect{ |rest| [rest[:start1], rest[:end1], rest[:start2], rest[:end2], rest[:duration]] }
    res = cluster(matrix, dimension, time_window, cluster_threshold) { |matrix, time_window|
      result = @cache.read(key)
      if !result
        data = {
          matrix: matrix,
          time_window: time_window,
          rest_window: rest_window,
          optimize_time: optimize_time,
          soft_upper_bound: soft_upper_bound,
          iterations_without_improvment: 100,
          initial_time_out: 3000,
          time_out_multiplier: 2,
        }.to_json
        resource = RestClient::Resource.new(@url, timeout: nil)
        result = resource.post({data: data}, content_type: :json, accept: :json)
        @cache.write(key, result && result.body)
      end

      jdata = JSON.parse(result)
      jdata['optim']
    }

    if !stores.include?(:stop)
      res = res[0..-2]
    end
    if !stores.include?(:start)
      res = res[1..-1].collect{ |i| i - 1 }
    end
    if rests.size > 0
      res = res.collect{ |i| i > services.size ? i -1 : i }
    end
    res
  end

  private

  def cluster(matrix, dimension, time_window, time_threshold)
    original_matrix = matrix
    matrix, time_window, zip_key = zip_cluster(matrix, dimension, time_window, time_threshold)
    result = yield(matrix, time_window)
    unzip_cluster(result, zip_key, original_matrix, dimension)
  end

  def zip_cluster(matrix, dimension, time_window, time_threshold)
    data_set = DataSet.new(data_items: (1..(matrix.length - 2)).collect{ |i| [i] })
    c = CompleteLinkageMaxDistance.new
    c.distance_function = lambda do |a, b|
      time_window[a[0]] == time_window[b[0]] ? matrix[a[0]][b[0]][dimension] : Float::INFINITY
    end
    clusterer = c.build(data_set, time_threshold)

    new_size = clusterer.clusters.size

    # Build replacement list
    ptr = Array.new(new_size + 2)
    ptr[0] = 0
    ptr[new_size + 1] = matrix.size - 1
    new_time_window = Array.new(new_size + 1)
    new_time_window[0] = time_window[0]

    clusterer.clusters.each_with_index do |cluster, i|
      oi = cluster.data_items[0][0]
      ptr[i + 1] = oi
      new_time_window[i + 1] = time_window[oi]
    end

    # Fill new matrix
    new_matrix = Array.new(new_size + 2) { Array.new(new_size + 2) }
    (new_size + 2).times{ |i|
      (new_size + 2).times{ |j|
        new_matrix[i][j] = matrix[ptr[i]][ptr[j]]
      }
    }

    [new_matrix, new_time_window, clusterer.clusters]
  end

  def unzip_cluster(result, zip_key, original_matrix, dimension)
    ret = []
    result.size.times.collect{ |ii|
      i = result[ii]
      if i == 0
        ret << 0
      elsif i - 1 >= zip_key.length
        ret << i - 1 - zip_key.length + original_matrix.length - 1
      elsif zip_key[i - 1].data_items.length > 1
        sub = zip_key[i - 1].data_items.collect{ |i| i[0] }

        # Last non rest-without-location
        start = ret.reverse.find{ |r| r < original_matrix.size }

        j = 0
        while(result[ii + j] > zip_key.length) do # Next non rest-without-location
          j += 1
        end
        stop = result[ii + j] < zip_key.length ? zip_key[result[ii + j]].data_items[0][0] : original_matrix.length - 1

        sub_size = sub.length
        min_order = if sub_size <= 5
          sub.permutation.collect{ |p|
            last = start
            s = p.sum { |s|
              a, last = last, s
              original_matrix[a][s][dimension]
            } + original_matrix[p[-1]][stop][dimension]
            [s, p]
          }.min_by{ |a| a[0] }[1]
        else
          sim_annealing = SimAnnealing::SimAnnealing.new
          sim_annealing.start1 = start
          sim_annealing.stop1 = stop
          sim_annealing.matrix = original_matrix
          sim_annealing.dimension = dimension
          fact = (1..[sub_size, 8].min).reduce(1, :*) # Yes, compute factorial
          initial_order = [start] + sub + [stop]
          sub_size += 2
          r = sim_annealing.search(initial_order, fact, 100000.0, 0.999)[:vector]
          r = r.collect{ |i| initial_order[i] }
          index = r.index(start)
          if r[(index + 1) % sub_size] != stop && r[(index - 1) % sub_size] != stop
            # Not stop and start following
            sub
          else
            if r[(index + 1) % sub_size] == stop
              r.reverse!
              index = sub_size - 1 - index
            end
            r = index == 0 ? r : r[index..-1] + r[0..index - 1] # shift to replace start at beginning
            r[1..-2] # remove start and stop
          end
        end
        ret += min_order
      else
        ret << zip_key[i - 1].data_items[0][0]
      end
    }.flatten
    ret
  end
end

module SimAnnealing
  class SimAnnealing
    attr_accessor :start1, :stop1, :matrix, :dimension

    def euc_2d(c1, c2)
      if (c1 == start1 || c1 == stop1) && (c2 == start1 || c2 == stop1)
        0
      else
        matrix[c1][c2][dimension]
      end
    end
  end
end
