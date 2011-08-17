module CustomFields
  module Types
    module HasMany

      class ReverseLookupProxyCollection < ProxyCollection

        attr_accessor :reverse_lookup_field, :previous_state

        def initialize(parent, target_klass, field_name, options = {})
          super

          self.reverse_lookup_field = options[:reverse_lookup_field].to_sym

          if self.parent.new_record?
            self.previous_state = { :ids => [], :values => [] }
          else
            self.reload
          end
        end

        def store_values
          true # do nothing
        end

        def persist
          (self.previous_state[:ids] - self.ids).each do |id|
            self.set_foreign_key_and_position(id, nil)
          end

          self.ids.each_with_index do |id, position|
            self.set_foreign_key_and_position(id, self.parent._id, position)
          end

          if self.target_klass.embedded?
            self.target_klass._parent.save!(:validate => false)
          end

          self.reset_previous_state
        end

        def <<(id_or_object)
          object = self.object_for_sure(id_or_object)

          foreign_key = object.send(self.reverse_lookup_field)

          if foreign_key && foreign_key != self.parent._id
            raise ArgumentError, "Object #{object} cannot be added: already has a different foreign key"
          end

          self.ids << self.id_for_sure(object._id)
          self.values << self.object_for_sure(object)
        end

        def reload
          self.update(self.reverse_collection)

          self.reset_previous_state
        end

        protected

        def reverse_collection
          self.collection.where(self.reverse_lookup_field => self.parent._id).order_by([[:"#{self.reverse_lookup_field}_position", :asc]])
        end

        def set_foreign_key_and_position(object_id, value, position = nil)
          if self.target_klass.embedded?
            object = self.collection.find(object_id)
          else
            object = self.previous_state[:values].detect { |o| o._id == object_id }
          end

          object.send("#{self.reverse_lookup_field}=".to_sym, value)

          object.send("#{self.reverse_lookup_field}_position=".to_sym, position)

          if self.target_klass.embedded?
            object.save(:validate => false)
          end
        end

        def reset_previous_state
          self.previous_state = {
            :ids    => self.ids.clone,
            :values => self.values.clone
          }
        end

      end

    end
  end
end