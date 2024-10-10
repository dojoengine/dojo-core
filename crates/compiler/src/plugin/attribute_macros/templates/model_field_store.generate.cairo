    fn get_$field_name$(self: @dojo::world::IWorldDispatcher, key: $model_type$KeyType) -> $field_type$ {
        $model_type$Store::get_member(self, $field_selector$, key)
    }

    fn get_$field_name$_from_id(self: @dojo::world::IWorldDispatcher, entity_id: felt252) -> $field_type$ {
        $model_type$EntityStore::get_member_from_id(self, $field_selector$, entity_id)
    }

    fn update_$field_name$(self: dojo::world::IWorldDispatcher, key: $model_type$KeyType, value: $field_type$) {
        $model_type$Store::update_member(self, $field_selector$, key, value);
    }

    fn update_$field_name$_from_id(self: dojo::world::IWorldDispatcher, entity_id: felt252, value: $field_type$) {
        $model_type$EntityStore::update_member_from_id(self, $field_selector$, entity_id, value);
    }

