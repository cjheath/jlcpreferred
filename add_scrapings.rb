# ruby -w
#
# Fixup descriptions and values in JLC library using screen scrapings
#
require 'kicad'
require 'debug'

details =
  File.open('Data/partDetails.txt') do |f|
    f.readlines
  end.map(&:chomp)

i = 0
by_fives = details.group_by{|l| g = i/5; i += 1; g }
parts = (0...by_fives.size).map{|g| by_fives[g]}
$by_part_number = Hash[parts.map{|p| [p[0], p[1..3]]}]             # part_number -> [description, manufacturer]
# pp $by_part_number

k = KiCad.load('jlcpreferred.kicad_sym').value

def update s
  value_node = s.property_node('Value')
  puts "#{s.id} has no Value node" && return unless value_node

  part_number = s.property('PartNumber')
  puts "#{s.id} has no PartNumber" && return unless part_number

  part = $by_part_number[part_number]
  puts "#{s.id} (#{part_number}) wasn't found in scrapings" && return unless part

  lcsc = part[0]
  description = part[1]
  manufacturer = part[2]

  description_node = s.property_node('Description')
  if !description_node
    s.children.append(KiCad.parse(%Q{(property "Description" "#{description}")})&.value)
  else
    description_node.value = description
  end
  puts "#{s.id} (#{part_number}): Description set"

  reference = s.property('Reference')

  match = /\b[0-9][^ ]*([ΩFH]|MHz)\b/.match(description)
  puts "#{s.id} (#{part_number}): no value matched in #{description}" && return unless match

  value = match[0]

  case reference
  when 'R'
    # puts "Setting resistor #{part_number} to #{value}"
    value_node.value = value
    puts "#{s.id} (#{part_number}): Resistance set"

  when 'C'
    # puts "Setting capacitor #{part_number} to #{value}"
    value_node.value = value
    puts "#{s.id} (#{part_number}): Capacitance set"

  when 'L'
    value_node.value = value
    puts "#{s.id} (#{part_number}): Inductance set"

  when 'X'
    value_node.value = value
    puts "#{s.id} (#{part_number}): Frequency set"

  else
    puts "Skipping #{part_number}, not RLC"
  end
end

k.all_symbol.
  each do |s|
    update(s)
  end

File.open('rewrite.kicad_sym', 'w') { |f| f.puts k.emit }
