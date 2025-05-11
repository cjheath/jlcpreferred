# ruby -w
#
# Fixup script for JLC library imported using easyeda2kicad
#
require 'kicad'
require 'debug'

=begin
For all symbols
* create (property "PartNumber"...) to be a copy of (property "Value"...) but (at 0 0 0)
* change (property "Datasheet" to be (at 0 0 0)
* add (hide yes) to (effects) of (property "LCSC Part")
+ change (property "Footprint" to be (at 0 0 0)

For each resistor and capacitor:
* add (pin_numbers (hide yes))
* add (pin_names (hide yes))
* change (property "Reference" to be (at 0 3.08 0)
* change (property "Value" to be (at 0 -3.08 0)
- change (property "Value" to be the semantic value of the part
- populate the Description property with text from the appropriate field on the LCSC web page for the part
=end

# Hide a pin_names or pin_numbers node:
def hide p
  if p.hide
    p.hide.hide = :yes
  else  # Add a hide node
    p.children.append(KiCad.parse('(hide yes)')&.value)
  end
end

k = KiCad.load('jlcpreferred.kicad_sym').value

k.all_symbol.
  each do |s|
    # Create PartNumber from Value if there isn't one
    unless s.property('PartNumber')
      s['PartNumber'] = s.property('Value')
      s.property_node('PartNumber').hidden = true
    end

    # Hide "LCSC Part" if present
    if s.property('LCSC Part')
      s.property_node('LCSC Part').hidden = true
    end

    footprint_node = s.property_node('Footprint')
    if footprint_node
      at = footprint_node.at
      if at && (at.x != 0 || at.y != 0 || at.angle != 0)
        puts "#{s.id} has footprint at (#{at.x}, #{at.y}, #{at.angle}) - not resetting"
      end
    end

    # If there are 3 or fewer pin numbers, hide them:
    pins = s.all_pin
    if pins.size == 0 && s.all_symbol.size > 0
      pins = s.all_symbol[0].all_pin
    end
    if pins.size <= 3
      pin_number_node = s.pin_numbers
      if pin_number_node
        hide(pin_number_node)
      else
        puts "#{s.id} has no pin_number node, adding it"
        s.children.prepend(KiCad.parse('(pin_numbers(hide yes))')&.value)
      end
    end
  end

# Move all Datasheet properties to be at 0,-5.08,0, and hidden
k.all_symbol.           # All top-level symbols
  map do |s|            # The property node for the data sheet property, if any
    s.property_node("Datasheet")
  end.
  each do |ds|          # and it's not positioned at 0,0,0
    next nil unless ds  # Skip if there's no Datasheet property

    # Hide it
    ds.hidden = true

    # Move it to 0,-5.08,0:
    at = ds.at
    if at && (at.x != 0 || at.y != 5.08 || at.angle != 0)
      at.x = at.angle = 0
      at.y = -5.08
    end
  end

# For all R's, 'L's, C's and 'X's:
k.all_symbol.
  each do |s|
    reference = s.property('Reference')
    next unless ['R', 'L', 'C', 'X'].include?(reference)

    # Hide PartNumbers:
    s.property_node('PartNumber')&.hidden = true

    # Reposition Reference and Value display:
    reference_node = s.property_node('Reference')
    at = reference_node.at
    if at
      at.x = at.angle = 0
      at.y = 3.08
    else
      puts "#{s.id} has no Reference property to move"
    end

    # Move the Value:
    # REVISIT: Find the south-most graphic element and place text below/above that
    value_node = s.property_node('Value')
    at = value_node.at
    if at
      at.x = at.angle = 0
      at.y = -3.08
    else
      puts "#{s.id} has no Value property to move"
    end

    # If there are pin names, hide them:
    pin_name_node = s.pin_names
    if pin_name_node
      hide(pin_name_node)
    else
      puts "#{s.id} has no pin_name node, adding it"
      s.children.prepend(KiCad.parse('(pin_names(hide yes))')&.value)
    end

  end

File.open('rewrite.kicad_sym', 'w') { |f| f.puts k.emit }
