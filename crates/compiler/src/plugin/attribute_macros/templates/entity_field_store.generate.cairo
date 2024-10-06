    fn get_$field_name$(world: dojo::world::IWorldDispatcher, entity_id: felt252) -> $field_type$ {
        dojo::model::members::MemberSerdeImpl::<$field_type$>::deserialize_member(
            $model_name$ModelEntityImpl::get_member(world, entity_id, $field_selector$)
        )

    }

    fn set_$field_name$(world: dojo::world::IWorldDispatcher, entity_id: felt252, value: $field_type$) {
        $model_name$ModelEntityImpl::set_member(
            world,
            entity_id,
            $field_selector$,
            dojo::model::members::MemberSerdeImpl::<$field_type$>::serialize_member(value)
        );
    }