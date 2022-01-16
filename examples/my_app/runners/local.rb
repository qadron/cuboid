require_relative '../application'

puts
ap '=' * 80
ap "#{'-' * 36} Local #{'-' * 37}"
ap '=' * 80
puts

MyApp.options = {
  'id' => [1, 2, 3]
}

MyApp.run
# :run
# [
#   [0] 1,
#   [1] 2,
#   [2] 3
# ]

ap MyApp.statistics
# {
#   :runtime => 0.000982
# }

ap MyApp.generate_report.data
# [
#   [0] 1,
#   [1] 2,
#   [2] 3
# ]
