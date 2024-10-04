    fn get_$field_name$(world: dojo::world::IWorldDispatcher, $param_keys$) -> $field_type$ {
        let mut serialized = core::array::ArrayTrait::new();
        $serialized_param_keys$

        let mut values = dojo::model::Model::<$model_name$>::get_member(
            world,
            serialized.span(),
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

    fn set_$field_name$(self: @$model_name$, world: dojo::world::IWorldDispatcher, value: $field_type$) {
        let mut serialized = core::array::ArrayTrait::new();
        core::serde::Serde::serialize(@value, ref serialized);

        self.set_member(
            world,
            $field_selector$,
            serialized.span()
        );
    }