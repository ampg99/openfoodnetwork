Spree::Variant.class_eval do
  attr_accessible :unit_value, :unit_description

  validates_presence_of :unit_value,
                        if: -> v { %w(weight volume).include? v.product.variant_unit },
                        unless: :is_master

  validates_presence_of :unit_description,
                        if: -> v { v.product.variant_unit.present? && v.unit_value.nil? },
                        unless: :is_master

  after_save :update_units

  def delete_unit_option_values
    ovs = self.option_values.where('option_type_id IN (?)',
                                   Spree::Product.all_variant_unit_option_types)
    self.option_values.destroy ovs
  end


  private

  def update_units
    option_type = self.product.variant_unit_option_type

    if option_type
      name = option_value_name
      ov = Spree::OptionValue.where(option_type_id: option_type, name: name, presentation: name).first || Spree::OptionValue.create!({option_type: option_type, name: name, presentation: name}, without_protection: true)
      option_values << ov #unless option_values.include? ov
    end
  end

  def option_value_name
    value, unit = option_value_value_unit

    name_fields = []
    name_fields << "#{value} #{unit}" if value.present? && unit.present?
    name_fields << unit_description   if unit_description.present?
    name_fields.join ' '
  end

  def option_value_value_unit
    units = {'weight' => {1.0 => 'g', 1000.0 => 'kg', 1000000.0 => 'T'},
             'volume' => {0.001 => 'mL', 1.0 => 'L', 1000000.0 => 'ML'}}

    if unit_value.present?

      if %w(weight volume).include? self.product.variant_unit
        unit = units[self.product.variant_unit].select { |scale, unit_name|
          unit_value / scale > 1
        }.to_a.last
        unit = units[self.product.variant_unit].first if unit.nil?

        unit_scale = unit[0]
        unit_name = unit[1]

        value = unit_value / unit_scale

      else
        value = unit_value
        unit_name = self.product.variant_unit_name
        unit_name = unit_name.pluralize if value > 1
      end

      value = value.to_i if value == value.to_i

    else
      value = unit_name = nil
    end

    [value, unit_name]
  end

end
