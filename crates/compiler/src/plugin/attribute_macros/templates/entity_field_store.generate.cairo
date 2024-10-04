    fn get_$field_name$(world: dojo::world::IWorldDispatcher, entity_id: felt252) -> $field_type$ {
        let mut values = dojo::model::ModelEntity::<$model_name$Entity>::get_member(
            world,
            entity_id,
            $field_selector$
        );
        let field_value = core::serde::Serde::<$field_type$>::deserialize(ref values);

        if core::option::OptionTrait::<$field_type$>::is_none(@field_value) {
            panic!(
                "Field `$model_name$::$field_name$`: deserialization failed."
            );
        }

        core::option::OptionTrait::<$field_type$>::unwrap(field_value)
    }

    fn set_$field_name$(self: @$model_name$Entity, world: dojo::world::IWorldDispatcher, value: $field_type$) {
        let mut serialized = core::array::ArrayTrait::new();
        core::serde::Serde::serialize(@value, ref serialized);

        self.set_member(
            world,
            $field_selector$,
            serialized.span()
        );
    }