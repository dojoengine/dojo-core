    fn get_$field_name$(world: dojo::world::IWorldDispatcher, key: $type_name$KeyType) -> $field_type$ {
        $type_name$WorldStore::get_member::<$field_type$>(@world, $field_selector$, key)
    }

    fn get_$field_name$_from_id(world: dojo::world::IWorldDispatcher, entity_id: felt252) -> $field_type$ {
        $type_name$WorldStore::get_member_from_id::<$field_type$>(@world, $field_selector$, entity_id)
    }

    fn update_$field_name$_from_id(world: dojo::world::IWorldDispatcher, key: $type_name$KeyType, value: $field_type$) {
        $type_name$WorldStore::update_member::<$field_type$>(world, $field_selector$, entity_id, value);
    }

    fn update_$field_name$_from_id(world: dojo::world::IWorldDispatcher, entity_id: felt252, value: $field_type$) {
        $type_name$WorldStore::update_member_from_id::<$field_type$>(world, $field_selector$, entity_id, value);
    }

